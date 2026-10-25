import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

class AudioProvider extends ChangeNotifier {
  final AudioPlayer _musicPlayer = AudioPlayer();
  bool _isPlaying = false;
  bool _wasPlayingBeforeDuck = false;
  String _currentTrackTitle = 'Piano Sanctuary';

  bool get isPlaying => _isPlaying;
  String get currentTrackTitle => _currentTrackTitle;

  AudioProvider() {
    _musicPlayer.setReleaseMode(ReleaseMode.loop);
  }

  Future<void> toggleMusic() async {
    if (_isPlaying) {
      await _musicPlayer.pause();
      _isPlaying = false;
    } else {
      try {
        await _musicPlayer.play(
          UrlSource(
            'https://cdn.pixabay.com/download/audio/2022/05/27/audio_1808fbf07a.mp3?filename=lofi-study-112191.mp3',
          ),
        );
        _isPlaying = true;
      } catch (_) {
        // Fallback / offline
        _isPlaying = false;
      }
    }
    notifyListeners();
  }

  // Audio Ducking for Voice Whispers, Video Playback & Modals
  void duckForMedia() {
    if (_isPlaying) {
      _wasPlayingBeforeDuck = true;
      _musicPlayer.pause();
      _isPlaying = false;
      notifyListeners();
    }
  }

  void restoreFromMedia() {
    if (_wasPlayingBeforeDuck) {
      _musicPlayer.resume();
      _isPlaying = true;
      _wasPlayingBeforeDuck = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _musicPlayer.dispose();
    super.dispose();
  }
}
