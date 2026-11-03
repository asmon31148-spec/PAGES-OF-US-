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
  WatchCallService._internal();

  final FirebaseDatabase _rtdb = FirebaseDatabase.instance;

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  bool _isRenderersInitialized = false;

  // Reactive state notifiers
  final ValueNotifier<WatchCallStatus> callStatus = ValueNotifier(WatchCallStatus.idle);
  final ValueNotifier<bool> isMicMuted = ValueNotifier(false);
  final ValueNotifier<bool> isCameraOff = ValueNotifier(false);
  final ValueNotifier<bool> isPartnerCameraOff = ValueNotifier(false);
  final ValueNotifier<bool> isPartnerMicMuted = ValueNotifier(false);
  final ValueNotifier<String> callerNameNotifier = ValueNotifier('');
  final ValueNotifier<String> callerUidNotifier = ValueNotifier('');

  // Active call session metadata
  String? _currentRoomCode;
  String? _myUid;
  String? _myName;

  StreamSubscription? _signalingSub;
  StreamSubscription? _candidateSub;
  StreamSubscription? _partnerStatusSub;

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

  /// Pre-initialize video renderers
  Future<void> initRenderers() async {
    if (_isRenderersInitialized) return;
    await localRenderer.initialize();
    await remoteRenderer.initialize();
    _isRenderersInitialized = true;
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
        if (callStatus.value == WatchCallStatus.calling && callerUid == myUid) {
          // Callee answered! Set remote description from answer
          final answerMap = data['answer'] as Map<dynamic, dynamic>?;
          if (answerMap != null && _peerConnection != null) {
            final sdp = answerMap['sdp']?.toString() ?? '';
            final type = answerMap['type']?.toString() ?? 'answer';
            _peerConnection?.setRemoteDescription(RTCSessionDescription(sdp, type));
            callStatus.value = WatchCallStatus.connected;
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

  /// Request permissions and create local user media stream
  Future<bool> _openUserMedia() async {
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
      },
      'video': {
        'mandatory': {
          'minWidth': '320',
          'minHeight': '240',
          'minFrameRate': '20',
        },
        'facingMode': 'user',
        'optional': [],
      }
    };

    try {
      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      localRenderer.srcObject = _localStream;
      isCameraOff.value = false;
      isMicMuted.value = false;
      return true;
    } catch (e) {
      debugPrint('Error getting user media: $e');
      return false;
    }
  }

  /// Start a video call (Offer creation)
  Future<void> startCall({required String roomCode, required String myUid, required String myName}) async {
    _currentRoomCode = roomCode.trim().toUpperCase();
    _myUid = myUid;
    _myName = myName;

    final mediaReady = await _openUserMedia();
    if (!mediaReady) return;

    callStatus.value = WatchCallStatus.calling;

    // 1. Create Peer Connection
    _peerConnection = await createPeerConnection(_iceConfig);

    // 2. Add local tracks to PeerConnection
    _localStream?.getTracks().forEach((track) {
      _peerConnection?.addTrack(track, _localStream!);
    });

    // 3. Listen for remote stream
    _peerConnection?.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
        remoteRenderer.srcObject = _remoteStream;
        callStatus.value = WatchCallStatus.connected;
      }
    };

    // 4. Send ICE Candidates to RTDB
    _peerConnection?.onIceCandidate = (RTCIceCandidate candidate) {
      if (candidate.candidate == null) return;
      _rtdb.ref('watchRooms/$_currentRoomCode/call/candidates/$myUid').push().set({
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
    };

    // 5. Create SDP Offer
    final offer = await _peerConnection!.createOffer({
      'offerToReceiveAudio': 1,
      'offerToReceiveVideo': 1,
    });
    await _peerConnection!.setLocalDescription(offer);

    // 6. Write Offer to Firebase RTDB
    await _rtdb.ref('watchRooms/$_currentRoomCode/call').update({
      'state': 'calling',
      'callerUid': myUid,
      'callerName': myName,
      'offer': {
        'sdp': offer.sdp,
        'type': offer.type,
      },
    });

    // 7. Publish initial local status
    _updateTrackStatusInDb();

    // 8. Listen for ICE candidates from partner
    _subscribeToRemoteCandidates();
  }

  /// Answer an incoming video call (Answer creation)
  Future<void> answerCall({required String roomCode, required String myUid, required String myName}) async {
    _currentRoomCode = roomCode.trim().toUpperCase();
    _myUid = myUid;
    _myName = myName;

    final mediaReady = await _openUserMedia();
    if (!mediaReady) {
      declineCall();
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

    // 4. Listen for remote stream
    _peerConnection?.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
        remoteRenderer.srcObject = _remoteStream;
        callStatus.value = WatchCallStatus.connected;
      }
    };

    // 5. Send ICE Candidates to RTDB
    _peerConnection?.onIceCandidate = (RTCIceCandidate candidate) {
      if (candidate.candidate == null) return;
      _rtdb.ref('watchRooms/$_currentRoomCode/call/candidates/$myUid').push().set({
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
    };

    // 6. Set Remote Description (Offer)
    final sdp = offerMap['sdp']?.toString() ?? '';
    final type = offerMap['type']?.toString() ?? 'offer';
    await _peerConnection!.setRemoteDescription(RTCSessionDescription(sdp, type));

    // 7. Create SDP Answer
    final answer = await _peerConnection!.createAnswer({
      'offerToReceiveAudio': 1,
      'offerToReceiveVideo': 1,
    });
    await _peerConnection!.setLocalDescription(answer);

    // 8. Write Answer to RTDB
    await _rtdb.ref('watchRooms/$_currentRoomCode/call').update({
      'state': 'connected',
      'answer': {
        'sdp': answer.sdp,
        'type': answer.type,
      },
    });

    callStatus.value = WatchCallStatus.connected;

    // 9. Publish local status
    _updateTrackStatusInDb();

    // 10. Listen for partner candidates
    _subscribeToRemoteCandidates();
  }

  void _subscribeToRemoteCandidates() {
    if (_currentRoomCode == null || _myUid == null) return;
    _candidateSub?.cancel();

    _candidateSub = _rtdb.ref('watchRooms/$_currentRoomCode/call/candidates').onChildAdded.listen((event) {
      final fromUid = event.snapshot.key;
      if (fromUid == _myUid) return; // Ignore own candidates

      if (event.snapshot.value is Map) {
        final val = event.snapshot.value as Map<dynamic, dynamic>;
        val.forEach((_, candData) {
          if (candData is Map && _peerConnection != null) {
            final candidate = RTCIceCandidate(
              candData['candidate']?.toString() ?? '',
              candData['sdpMid']?.toString() ?? '',
              (candData['sdpMLineIndex'] as num?)?.toInt() ?? 0,
            );
            _peerConnection?.addCandidate(candidate);
          }
        });
      }
    });
  }

  /// Decline incoming call
  Future<void> declineCall() async {
    if (_currentRoomCode != null) {
      await _rtdb.ref('watchRooms/$_currentRoomCode/call').update({
        'state': 'declined',
      });
    }
    _cleanUpLocalCall();
  }

  /// End ongoing call
  Future<void> endCall() async {
    if (_currentRoomCode != null) {
      await _rtdb.ref('watchRooms/$_currentRoomCode/call').set({
        'state': 'idle',
      });
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
      localRenderer.dispose();
      remoteRenderer.dispose();
      _isRenderersInitialized = false;
    }
  }
}
