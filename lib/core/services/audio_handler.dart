import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:audio_service/audio_service.dart';

class SanctuaryAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  Future<void> Function()? onPlayCallback;
  Future<void> Function()? onPauseCallback;
  Future<void> Function()? onSkipNextCallback;
  Future<void> Function()? onSkipPreviousCallback;
  Future<void> Function(Duration)? onSeekCallback;

  void updateSong({
    required String id,
    required String title,
    required String artist,
    required Duration duration,
    Uri? artUri,
  }) {
    mediaItem.add(
      MediaItem(
        id: id,
        album: 'Pages of Us Sanctuary',
        title: title,
        artist: artist,
        duration: duration,
        artUri: artUri,
      ),
    );
  }

  void updatePlaybackState({
    required bool isPlaying,
    required Duration position,
    required Duration duration,
  }) {
    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          isPlaying ? MediaControl.pause : MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: isPlaying ? AudioProcessingState.ready : AudioProcessingState.idle,
        playing: isPlaying,
        updatePosition: position,
        bufferedPosition: duration,
      ),
    );
  }

  void clearNotification() {
    playbackState.add(
      playbackState.value.copyWith(
        playing: false,
        processingState: AudioProcessingState.idle,
        controls: [],
      ),
    );
  }

  @override
  Future<void> play() async {
    try {
      if (onPlayCallback != null) await onPlayCallback!();
    } catch (e) {
      debugPrint('Notification play error: $e');
    }
  }

  @override
  Future<void> pause() async {
    try {
      if (onPauseCallback != null) await onPauseCallback!();
    } catch (e) {
      debugPrint('Notification pause error: $e');
    }
  }

  @override
  Future<void> skipToNext() async {
    try {
      if (onSkipNextCallback != null) await onSkipNextCallback!();
    } catch (e) {
      debugPrint('Notification skipToNext error: $e');
    }
  }

  @override
  Future<void> skipToPrevious() async {
    try {
      if (onSkipPreviousCallback != null) await onSkipPreviousCallback!();
    } catch (e) {
      debugPrint('Notification skipToPrevious error: $e');
    }
  }

  @override
  Future<void> seek(Duration position) async {
    try {
      if (onSeekCallback != null) await onSeekCallback!(position);
    } catch (e) {
      debugPrint('Notification seek error: $e');
    }
  }
}
