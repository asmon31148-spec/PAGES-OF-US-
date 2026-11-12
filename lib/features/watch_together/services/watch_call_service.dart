import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';

enum WatchCallStatus {
  idle,
  calling,   // Caller has initiated call, waiting for answer
  ringing,   // Callee sees incoming call prompt
  connected, // Both peers connected, media streaming
  ended,
}

class WatchCallService {
  static final WatchCallService instance = WatchCallService._internal();
  WatchCallService._internal() {
    callStatus.addListener(() {
      if (callStatus.value == WatchCallStatus.connected) {
        _startDurationTimer();
      } else {
        _stopDurationTimer();
      }
    });
  }

  Timer? _durationTimer;
  final ValueNotifier<int> callDurationSeconds = ValueNotifier(0);

  String get formattedCallDuration {
    final s = callDurationSeconds.value;
    final minutes = (s ~/ 60).toString().padLeft(2, '0');
    final seconds = (s % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    callDurationSeconds.value = 0;
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      callDurationSeconds.value++;
    });
  }

  void _stopDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = null;
    callDurationSeconds.value = 0;
  }

  final FirebaseDatabase _rtdb = FirebaseDatabase.instance;

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  RTCVideoRenderer localRenderer = RTCVideoRenderer();
  RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  bool _isRenderersInitialized = false;

  // Reactive state notifiers
  final ValueNotifier<WatchCallStatus> callStatus = ValueNotifier(WatchCallStatus.idle);
  final ValueNotifier<bool> isMicMuted = ValueNotifier(false);
  final ValueNotifier<bool> isCameraOff = ValueNotifier(false);
  final ValueNotifier<bool> isPartnerCameraOff = ValueNotifier(false);
  final ValueNotifier<bool> isPartnerMicMuted = ValueNotifier(false);
  final ValueNotifier<int> remoteStreamVersion = ValueNotifier(0);
  final ValueNotifier<int> localStreamVersion = ValueNotifier(0);
  final ValueNotifier<String> callerNameNotifier = ValueNotifier('');
  final ValueNotifier<String> callerUidNotifier = ValueNotifier('');

  // Active call session metadata
  String? _currentRoomCode;
  String? _myUid;
  String? _myName;

  StreamSubscription? _signalingSub;
  StreamSubscription? _candidateSub;
  StreamSubscription? _partnerStatusSub;

  final List<RTCIceCandidate> _queuedRemoteCandidates = [];
  bool _isRemoteDescriptionSet = false;
  bool _isApplyingRemoteAnswer = false;
  bool _isAnsweringCall = false;

  final Map<String, dynamic> _iceConfig = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun2.l.google.com:19302'},
      {'urls': 'stun:stun3.l.google.com:19302'},
      {'urls': 'stun:stun4.l.google.com:19302'},
    ],
    'sdpSemantics': 'unified-plan',
  };

  /// Pre-initialize video renderers safely
  Future<void> initRenderers() async {
    if (_isRenderersInitialized) return;
    try {
      await localRenderer.initialize();
      await remoteRenderer.initialize();
      _isRenderersInitialized = true;
    } catch (e) {
      debugPrint('Error initializing renderers: $e');
    }
  }

  /// Listen for incoming calls while in a watch room
  void listenForCalls({required String roomCode, required String myUid}) {
    _currentRoomCode = roomCode.trim().toUpperCase();
    _myUid = myUid;

    _signalingSub?.cancel();
    final callRef = _rtdb.ref('watchRooms/$_currentRoomCode/call');

    _signalingSub = callRef.onValue.listen((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) {
        if (callStatus.value != WatchCallStatus.idle) {
          _cleanUpLocalCall();
        }
        return;
      }

      final data = event.snapshot.value as Map<dynamic, dynamic>;
      final state = data['state']?.toString() ?? 'idle';
      final callerUid = data['callerUid']?.toString() ?? '';
      final callerName = data['callerName']?.toString() ?? 'Partner';

      callerNameNotifier.value = callerName;
      callerUidNotifier.value = callerUid;

      if (state == 'calling') {
        if (callerUid != myUid) {
          // Partner initiated call -> Ringing state on this device
          if (callStatus.value != WatchCallStatus.connected && callStatus.value != WatchCallStatus.calling) {
            callStatus.value = WatchCallStatus.ringing;
          }
        }
      } else if (state == 'connected') {
        if (callStatus.value == WatchCallStatus.calling &&
            callerUid == myUid &&
            !_isRemoteDescriptionSet &&
            !_isApplyingRemoteAnswer) {
          // Callee answered! Set remote description from answer exactly once.
          final answerMap = data['answer'] as Map<dynamic, dynamic>?;
          if (answerMap != null && _peerConnection != null) {
            _isApplyingRemoteAnswer = true;
            final sdp = answerMap['sdp']?.toString() ?? '';
            final type = answerMap['type']?.toString() ?? 'answer';
            () async {
              try {
                await _peerConnection?.setRemoteDescription(RTCSessionDescription(sdp, type));
                _isRemoteDescriptionSet = true;
                await _drainQueuedCandidates();
                try {
                  await Helper.setSpeakerphoneOn(true);
                } catch (_) {}
                callStatus.value = WatchCallStatus.connected;
              } catch (e) {
                debugPrint('Error setting remote description on caller: $e');
              } finally {
                _isApplyingRemoteAnswer = false;
              }
            }();
          }
        }
      } else if (state == 'idle' || state == 'declined' || state == 'ended') {
        if (callStatus.value != WatchCallStatus.idle) {
          _cleanUpLocalCall();
        }
      }
    });

    // Listen to partner media track states (camera off, mic mute)
    _listenToPartnerTrackState();
  }

  void _listenToPartnerTrackState() {
    if (_currentRoomCode == null || _myUid == null) return;
    _partnerStatusSub?.cancel();
    _partnerStatusSub = _rtdb.ref('watchRooms/$_currentRoomCode/call/status').onValue.listen((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) return;
      final data = event.snapshot.value as Map<dynamic, dynamic>;
      data.forEach((uid, val) {
        if (uid != _myUid && val is Map) {
          isPartnerCameraOff.value = val['isCameraOff'] == true;
          isPartnerMicMuted.value = val['isMicMuted'] == true;
        }
      });
    });
  }

  /// Request permissions and create local user media stream with safe fallbacks
  Future<bool> _openUserMedia() async {
    try {
      final cameraStatus = await Permission.camera.request();
      final micStatus = await Permission.microphone.request();

      if (!cameraStatus.isGranted || !micStatus.isGranted) {
        debugPrint('Camera or Microphone permissions not granted');
        return false;
      }

      await initRenderers();

      final Map<String, dynamic> mediaConstraints = {
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
          'highpassFilter': true,
        },
        'video': {
          'facingMode': 'user',
          'width': {'ideal': 1280, 'max': 1920},
          'height': {'ideal': 720, 'max': 1080},
          'frameRate': {'ideal': 30, 'max': 30},
        }
      };

      try {
        _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      } catch (e) {
        debugPrint('Failed with resolution constraints, falling back to basic: $e');
        _localStream = await navigator.mediaDevices.getUserMedia({
          'audio': true,
          'video': {'facingMode': 'user'},
        });
      }

      localRenderer.srcObject = _localStream;
      localStreamVersion.value++;
      isCameraOff.value = false;
      isMicMuted.value = false;
      return true;
    } catch (e) {
      debugPrint('Error getting user media: $e');
      return false;
    }
  }

  /// Optimize SDP bandwidth attributes for crystal-clear video streaming
  String _optimizeSdp(String sdp) {
    var modified = sdp;
    if (modified.contains('m=video')) {
      modified = modified.replaceAllMapped(
        RegExp(r'(m=video[^\r\n]*[\r\n]+)'),
        (match) => '${match.group(1)}b=AS:2000\r\n',
      );
    }
    return modified;
  }

  /// Attaches an incoming remote track (stream-backed or track-only in unified-plan)
  /// and notifies the UI immediately so remote video never stays stuck on placeholder.
  Future<void> _attachRemoteTrack(RTCTrackEvent event) async {
    try {
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
      } else {
        _remoteStream ??= await createLocalMediaStream('remote_${DateTime.now().millisecondsSinceEpoch}');
        await _remoteStream!.addTrack(event.track);
      }
      remoteRenderer.srcObject = _remoteStream;
      remoteStreamVersion.value++;
      try {
        await Helper.setSpeakerphoneOn(true);
      } catch (_) {}
      callStatus.value = WatchCallStatus.connected;
    } catch (e) {
      debugPrint('Error attaching remote track: $e');
    }
  }

  /// Start a video call (Offer creation)
  Future<void> startCall({required String roomCode, required String myUid, required String myName}) async {
    try {
      _currentRoomCode = roomCode.trim().toUpperCase();
      _myUid = myUid;
      _myName = myName;
      _queuedRemoteCandidates.clear();
      _isRemoteDescriptionSet = false;
      _isApplyingRemoteAnswer = false;

      final mediaReady = await _openUserMedia();
      if (!mediaReady) return;

      callStatus.value = WatchCallStatus.calling;

      // Clean up previous call session in RTDB completely to ensure fresh slate
      try {
        await _rtdb.ref('watchRooms/$_currentRoomCode/call').remove();
      } catch (_) {}

      // 1. Create Peer Connection
      _peerConnection = await createPeerConnection(_iceConfig);

      // 2. Add local tracks to PeerConnection
      _localStream?.getTracks().forEach((track) {
        _peerConnection?.addTrack(track, _localStream!);
      });

      // 3. Listen for remote stream / tracks
      _peerConnection?.onTrack = (RTCTrackEvent event) {
        _attachRemoteTrack(event);
      };

      // 4. Send ICE Candidates to RTDB under callerCandidates
      _peerConnection?.onIceCandidate = (RTCIceCandidate candidate) {
        if (candidate.candidate == null) return;
        _rtdb.ref('watchRooms/$_currentRoomCode/call/callerCandidates').push().set({
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        });
      };

      // 5. Create SDP Offer with bitrate optimization
      final offer = await _peerConnection!.createOffer({
        'offerToReceiveAudio': 1,
        'offerToReceiveVideo': 1,
      });
      final optimizedSdp = _optimizeSdp(offer.sdp ?? '');

      // 6. Write Offer to Firebase RTDB BEFORE setLocalDescription so ICE candidates
      // emitted immediately during local description setup are never wiped by .set().
      await _rtdb.ref('watchRooms/$_currentRoomCode/call').set({
        'callSessionId': DateTime.now().millisecondsSinceEpoch.toString(),
        'state': 'calling',
        'callerUid': myUid,
        'callerName': myName,
        'createdAt': ServerValue.timestamp,
        'offer': {
          'sdp': optimizedSdp,
          'type': offer.type,
        },
      });

      await _peerConnection!.setLocalDescription(RTCSessionDescription(optimizedSdp, offer.type));

      // 7. Publish initial local status
      _updateTrackStatusInDb();

      // 8. Listen for ICE candidates from callee
      _subscribeToCandidates(path: 'watchRooms/$_currentRoomCode/call/calleeCandidates');
    } catch (e) {
      debugPrint('Error starting call: $e');
      _cleanUpLocalCall();
    }
  }

  /// Answer an incoming video call (Answer creation)
  Future<void> answerCall({required String roomCode, required String myUid, required String myName}) async {
    if (_isAnsweringCall) return;
    _isAnsweringCall = true;
    try {
      _currentRoomCode = roomCode.trim().toUpperCase();
      _myUid = myUid;
      _myName = myName;
      _queuedRemoteCandidates.clear();
      _isRemoteDescriptionSet = false;
      _isApplyingRemoteAnswer = false;

      final mediaReady = await _openUserMedia();
      if (!mediaReady) {
        await declineCall();
        return;
      }

      // 1. Fetch Offer from RTDB
      final snapshot = await _rtdb.ref('watchRooms/$_currentRoomCode/call').get();
      if (!snapshot.exists || snapshot.value == null) return;

      final data = snapshot.value as Map<dynamic, dynamic>;
      final offerMap = data['offer'] as Map<dynamic, dynamic>?;
      if (offerMap == null) return;

      // 2. Create Peer Connection
      _peerConnection = await createPeerConnection(_iceConfig);

      // 3. Add local tracks
      _localStream?.getTracks().forEach((track) {
        _peerConnection?.addTrack(track, _localStream!);
      });

      // 4. Listen for remote stream / tracks
      _peerConnection?.onTrack = (RTCTrackEvent event) {
        _attachRemoteTrack(event);
      };

      // 5. Send Callee ICE Candidates to RTDB under calleeCandidates
      _peerConnection?.onIceCandidate = (RTCIceCandidate candidate) {
        if (candidate.candidate == null) return;
        _rtdb.ref('watchRooms/$_currentRoomCode/call/calleeCandidates').push().set({
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        });
      };

      // 6. Set Remote Description (Offer)
      final sdp = offerMap['sdp']?.toString() ?? '';
      final type = offerMap['type']?.toString() ?? 'offer';
      await _peerConnection!.setRemoteDescription(RTCSessionDescription(sdp, type));
      _isRemoteDescriptionSet = true;

      // 7. Subscribe to caller candidates
      _subscribeToCandidates(path: 'watchRooms/$_currentRoomCode/call/callerCandidates');

      // 8. Create SDP Answer
      final answer = await _peerConnection!.createAnswer({
        'offerToReceiveAudio': 1,
        'offerToReceiveVideo': 1,
      });
      final optimizedAnswerSdp = _optimizeSdp(answer.sdp ?? '');
      await _peerConnection!.setLocalDescription(RTCSessionDescription(optimizedAnswerSdp, answer.type));

      try {
        await Helper.setSpeakerphoneOn(true);
      } catch (_) {}

      // 9. Write Answer to RTDB
      await _rtdb.ref('watchRooms/$_currentRoomCode/call').update({
        'state': 'connected',
        'connectedAt': ServerValue.timestamp,
        'answer': {
          'sdp': optimizedAnswerSdp,
          'type': answer.type,
        },
      });

      // Flush any queued candidates that arrived before description was set
      await _drainQueuedCandidates();

      callStatus.value = WatchCallStatus.connected;

      // 10. Publish local status
      _updateTrackStatusInDb();
    } catch (e) {
      debugPrint('Error in answerCall: $e');
      await declineCall();
    } finally {
      _isAnsweringCall = false;
    }
  }

  void _subscribeToCandidates({required String path}) {
    _candidateSub?.cancel();
    _candidateSub = _rtdb.ref(path).onChildAdded.listen((event) async {
      if (!event.snapshot.exists || event.snapshot.value == null) return;
      try {
        final val = event.snapshot.value as Map<dynamic, dynamic>;
        final candidateStr = val['candidate']?.toString() ?? '';
        final sdpMid = val['sdpMid']?.toString() ?? '';
        final sdpMLineIndex = (val['sdpMLineIndex'] as num?)?.toInt() ?? 0;

        if (candidateStr.isEmpty) return;

        final candidate = RTCIceCandidate(candidateStr, sdpMid, sdpMLineIndex);

        if (_peerConnection != null && _isRemoteDescriptionSet) {
          await _peerConnection?.addCandidate(candidate);
        } else {
          _queuedRemoteCandidates.add(candidate);
        }
      } catch (e) {
        debugPrint('Error processing incoming ICE candidate: $e');
      }
    });
  }

  Future<void> _drainQueuedCandidates() async {
    if (_peerConnection == null || !_isRemoteDescriptionSet) return;
    for (final candidate in _queuedRemoteCandidates) {
      try {
        await _peerConnection?.addCandidate(candidate);
      } catch (e) {
        debugPrint('Error adding queued candidate: $e');
      }
    }
    _queuedRemoteCandidates.clear();
  }

  /// Decline incoming call
  Future<void> declineCall() async {
    if (_currentRoomCode != null) {
      try {
        await _rtdb.ref('watchRooms/$_currentRoomCode/call').update({
          'state': 'declined',
        });
      } catch (_) {}
    }
    _cleanUpLocalCall();
  }

  /// End ongoing call
  Future<void> endCall() async {
    if (_currentRoomCode != null) {
      try {
        await _rtdb.ref('watchRooms/$_currentRoomCode/call').set({
          'state': 'idle',
          'endedAt': ServerValue.timestamp,
        });
      } catch (_) {}
    }
    _cleanUpLocalCall();
  }

  /// Toggle Microphone Mute
  void toggleMic() {
    if (_localStream != null) {
      final audioTracks = _localStream!.getAudioTracks();
      if (audioTracks.isNotEmpty) {
        final current = audioTracks[0].enabled;
        audioTracks[0].enabled = !current;
        isMicMuted.value = !audioTracks[0].enabled;
        _updateTrackStatusInDb();
      }
    }
  }

  /// Toggle Camera On / Off
  void toggleCamera() {
    if (_localStream != null) {
      final videoTracks = _localStream!.getVideoTracks();
      if (videoTracks.isNotEmpty) {
        final current = videoTracks[0].enabled;
        videoTracks[0].enabled = !current;
        isCameraOff.value = !videoTracks[0].enabled;
        _updateTrackStatusInDb();
      }
    }
  }

  /// Flip front / back camera
  Future<void> switchCamera() async {
    if (_localStream != null) {
      final videoTracks = _localStream!.getVideoTracks();
      if (videoTracks.isNotEmpty) {
        await Helper.switchCamera(videoTracks[0]);
      }
    }
  }

  void _updateTrackStatusInDb() {
    if (_currentRoomCode == null || _myUid == null) return;
    try {
      _rtdb.ref('watchRooms/$_currentRoomCode/call/status/$_myUid').set({
        'isCameraOff': isCameraOff.value,
        'isMicMuted': isMicMuted.value,
        'updatedAt': ServerValue.timestamp,
      });
    } catch (_) {}
  }

  void _cleanUpLocalCall() {
    callStatus.value = WatchCallStatus.idle;
    isMicMuted.value = false;
    isCameraOff.value = false;
    isPartnerCameraOff.value = false;
    isPartnerMicMuted.value = false;

    _candidateSub?.cancel();
    _candidateSub = null;
    _queuedRemoteCandidates.clear();
    _isRemoteDescriptionSet = false;
    _isApplyingRemoteAnswer = false;
    _isAnsweringCall = false;
    remoteStreamVersion.value++;
    localStreamVersion.value++;

    try {
      _localStream?.getTracks().forEach((track) {
        track.stop();
      });
      _localStream?.dispose();
      _localStream = null;
    } catch (_) {}

    try {
      _remoteStream?.dispose();
      _remoteStream = null;
    } catch (_) {}

    try {
      _peerConnection?.close();
      _peerConnection?.dispose();
      _peerConnection = null;
    } catch (_) {}

    localRenderer.srcObject = null;
    remoteRenderer.srcObject = null;
  }

  /// Full teardown on exiting screen/room
  void dispose() {
    _signalingSub?.cancel();
    _signalingSub = null;
    _partnerStatusSub?.cancel();
    _partnerStatusSub = null;
    _cleanUpLocalCall();

    if (_isRenderersInitialized) {
      try {
        localRenderer.srcObject = null;
        remoteRenderer.srcObject = null;
        localRenderer.dispose();
        remoteRenderer.dispose();
      } catch (_) {}
      // Instantiate fresh renderers so initialize() works on the next session
      localRenderer = RTCVideoRenderer();
      remoteRenderer = RTCVideoRenderer();
      _isRenderersInitialized = false;
    }
  }
}
