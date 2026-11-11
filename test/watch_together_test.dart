import 'package:flutter_test/flutter_test.dart';
import 'package:pages_of_us/features/watch_together/models/watch_room_model.dart';
import 'package:pages_of_us/features/watch_together/services/watch_video_service.dart';

void main() {
  group('WatchPlayback - Sync Model & Sequence Ordering', () {
    test('serializes and parses actionSeq and playback fields cleanly', () {
      const pb = WatchPlayback(
        isPlaying: true,
        positionMs: 81400,
        updatedAt: 1700000123456,
        updatedBy: 'uid_partner',
        speed: 1.0,
        buffering: false,
        actionSeq: 12,
      );

      final parsed = WatchPlayback.fromMap(pb.toMap());
      expect(parsed.isPlaying, isTrue);
      expect(parsed.positionMs, 81400);
      expect(parsed.updatedBy, 'uid_partner');
      expect(parsed.actionSeq, 12);
    });
  });

  group('WatchVideoService - HD Stream Quality Ordering', () {
    test('extractSelectableQualities prioritizes HD variants ahead of SD/360p', () {
      const sources = [
        WatchStreamSource(
          url: 'https://example.com/360.mp4',
          label: 'vr_mp4_0',
          qualityLabel: '360p',
          resolutionHeight: 360,
        ),
        WatchStreamSource(
          url: 'http://127.0.0.1:9999/stream?key=proxy',
          label: 'vr_proxy_0',
          qualityLabel: '360p',
          resolutionHeight: 360,
        ),
        WatchStreamSource(
          url: 'https://example.com/1080.m3u8',
          label: 'ios_hls_1080p',
          qualityLabel: '1080p',
          resolutionHeight: 1080,
        ),
        WatchStreamSource(
          url: 'https://example.com/720.m3u8',
          label: 'ios_hls_720p',
          qualityLabel: '720p',
          resolutionHeight: 720,
        ),
      ];

      final selectable = WatchVideoService.instance.extractSelectableQualities(sources);
      expect(selectable.map((s) => s.qualityLabel).toList(), ['1080p', '720p', '360p']);
      expect(selectable.any((s) => s.label.contains('proxy')), isFalse);
    });
  });
}
