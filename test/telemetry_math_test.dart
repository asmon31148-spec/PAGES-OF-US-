import 'package:flutter_test/flutter_test.dart';
import 'package:pages_of_us/core/utils/telemetry_math.dart';

void main() {
  group('TelemetryMath - Local Midnight & Daily Summary', () {
    test('localDateKeyFor respects local timezone offset and pads month/day', () {
      // 2026-03-08T18:29:00Z + 330m (IST +05:30) = 2026-03-08 23:59 IST
      final beforeMidnightUtc = DateTime.utc(2026, 3, 8, 18, 29, 0);
      expect(
        TelemetryMath.localDateKeyFor(beforeMidnightUtc, offsetMinutes: 330),
        '2026-03-08',
      );

      // 2 minutes later = 2026-03-09 00:01 IST -> new day padded YYYY-MM-DD
      final afterMidnightUtc = DateTime.utc(2026, 3, 8, 18, 31, 0);
      expect(
        TelemetryMath.localDateKeyFor(afterMidnightUtc, offsetMinutes: 330),
        '2026-03-09',
      );
      expect(
        TelemetryMath.isNewLocalDay(
          storedDateKey: '2026-03-08',
          nowUtc: afterMidnightUtc,
          offsetMinutes: 330,
        ),
        isTrue,
      );
    });

    test('DailyActivitySummary roundtrips cleanly to and from JSON', () {
      const original = DailyActivitySummary(
        userId: 'user_abc',
        dateKey: '2026-03-09',
        unlockCount: 14,
        lockCount: 13,
        screenTimeSeconds: 5400,
        steps: 6420,
        distanceKm: 4.85,
        walkingTimeSeconds: 3120,
        appTimeSeconds: 900,
        stopsCount: 3,
        source: 'health_connect',
        updatedAt: '2026-03-09T23:55:00Z',
      );

      final parsed = DailyActivitySummary.fromJson(original.toJson());
      expect(parsed.userId, 'user_abc');
      expect(parsed.dateKey, '2026-03-09');
      expect(parsed.unlockCount, 14);
      expect(parsed.lockCount, 13);
      expect(parsed.screenTimeSeconds, 5400);
      expect(parsed.steps, 6420);
      expect(parsed.distanceKm, closeTo(4.85, 0.001));
      expect(parsed.walkingTimeSeconds, 3120);
      expect(parsed.appTimeSeconds, 900);
      expect(parsed.stopsCount, 3);
      expect(parsed.source, 'health_connect');
    });
  });

  group('TelemetryMath - Step Baseline & Reboot Recovery', () {
    test('initial baseline does not attribute historical boot steps to today', () {
      final s0 = StepBaselineState.empty('2026-03-09');
      final s1 = TelemetryMath.applyRawStepReading(
        current: s0,
        rawStepsSinceBoot: 50000,
        currentDateKey: '2026-03-09',
      );
      expect(s1.hasBaseline, isTrue);
      expect(s1.baselineRaw, 50000);
      expect(s1.todaySteps, 0);

      final s2 = TelemetryMath.applyRawStepReading(
        current: s1,
        rawStepsSinceBoot: 51234,
        currentDateKey: '2026-03-09',
      );
      expect(s2.todaySteps, 1234);
    });

    test('device reboot preserves pre-reboot steps and continues counting', () {
      var state = StepBaselineState.empty('2026-03-09');
      state = TelemetryMath.applyRawStepReading(
        current: state,
        rawStepsSinceBoot: 20000,
        currentDateKey: '2026-03-09',
      );
      state = TelemetryMath.applyRawStepReading(
        current: state,
        rawStepsSinceBoot: 21500,
        currentDateKey: '2026-03-09',
      );
      expect(state.todaySteps, 1500);

      // Device reboots mid-day and raw step counter restarts at 320
      state = TelemetryMath.applyRawStepReading(
        current: state,
        rawStepsSinceBoot: 320,
        currentDateKey: '2026-03-09',
      );
      expect(state.todaySteps, 1820);

      // Midnight rollover resets todaySteps back to 0 cleanly
      final nextDay = TelemetryMath.applyRawStepReading(
        current: state,
        rawStepsSinceBoot: 420,
        currentDateKey: '2026-03-10',
      );
      expect(nextDay.todaySteps, 0);
      expect(nextDay.baselineRaw, 420);
    });
  });

  group('TelemetryMath - Unlock/Lock Events & Screen Time', () {
    test('aggregates unlock/lock counts, timestamps, and session durations accurately', () {
      // Reference day: 2026-03-09 in UTC (offsetMinutes: 0)
      final yestUnlock = DateTime.utc(2026, 3, 8, 23, 30, 0).millisecondsSinceEpoch;
      final todayUnlock1 = DateTime.utc(2026, 3, 9, 8, 0, 0).millisecondsSinceEpoch;
      final todayLock1 = DateTime.utc(2026, 3, 9, 8, 5, 0).millisecondsSinceEpoch;
      final todayUnlock2 = DateTime.utc(2026, 3, 9, 9, 0, 0).millisecondsSinceEpoch;
      final nowUtc = DateTime.utc(2026, 3, 9, 9, 2, 0);

      final summary = TelemetryMath.aggregateScreenEvents(
        events: [
          ScreenEvent(type: 'unlock', timestampMs: yestUnlock),
          ScreenEvent(type: 'unlock', timestampMs: todayUnlock1),
          ScreenEvent(type: 'lock', timestampMs: todayLock1),
          ScreenEvent(type: 'unlock', timestampMs: todayUnlock2),
        ],
        nowUtc: nowUtc,
        isCurrentlyScreenOn: true,
        isCurrentlyUnlocked: true,
        timeZoneOffsetMinutes: 0,
      );

      expect(summary.unlockCountToday, 2);
      expect(summary.lockCountToday, 1);
      expect(summary.lastUnlockedAt?.millisecondsSinceEpoch, todayUnlock2);
      expect(summary.lastLockedAt?.millisecondsSinceEpoch, todayLock1);
      expect(summary.sessionDurationsSeconds, contains(300));
      // 300s closed session + 120s active session = 420s
      expect(summary.screenTimeSecondsToday, 420);
    });
  });

  group('TelemetryMath - GPS Distance Filtering & Trail Sums', () {
    test('rejects low-accuracy spikes and indoor jitter while summing real walk', () {
      final t0 = DateTime.utc(2026, 3, 9, 10, 0, 0);
      final pts = <GpsTrackPoint>[
        // Origin
        GpsTrackPoint(lat: 28.6139, lng: 77.2090, timestamp: t0, accuracyMeters: 10),
        // Poor accuracy GPS spike (95m accuracy -> ignored)
        GpsTrackPoint(
          lat: 28.6239,
          lng: 77.2090,
          timestamp: t0.add(const Duration(seconds: 20)),
          accuracyMeters: 95,
        ),
        // Tiny indoor jitter (~2m -> < 8m minSegmentMeters -> ignored)
        GpsTrackPoint(
          lat: 28.613915,
          lng: 77.209005,
          timestamp: t0.add(const Duration(seconds: 40)),
          accuracyMeters: 12,
        ),
        // Real walk ~555m north (0.005 deg lat ~= 0.556 km)
        GpsTrackPoint(
          lat: 28.6189,
          lng: 77.2090,
          timestamp: t0.add(const Duration(minutes: 6)),
          accuracyMeters: 10,
          speedMps: 1.5,
        ),
      ];

      final distKm = TelemetryMath.computeVerifiedGpsDistanceKm(pts);
      expect(distKm, closeTo(0.556, 0.03));
    });

    test('sumTrailKm preserves sparse saved days across 7-day and 30-day windows', () {
      final saved = <DailyActivitySummary>[
        // Day outside 30-day window -> excluded
        const DailyActivitySummary(userId: 'p1', dateKey: '2026-01-01', distanceKm: 10.0),
        // Day 20 days ago -> included in 30d only
        const DailyActivitySummary(userId: 'p1', dateKey: '2026-02-20', distanceKm: 4.0),
        // Day 3 days ago -> included in both 7d and 30d
        const DailyActivitySummary(userId: 'p1', dateKey: '2026-03-06', distanceKm: 2.5),
        // Saved entry for today should be overridden by live todayDistanceKm (not double-counted)
        const DailyActivitySummary(userId: 'p1', dateKey: '2026-03-09', distanceKm: 0.5),
      ];

      final week = TelemetryMath.sumTrailKm(
        savedDays: saved,
        todayDistanceKm: 1.5,
        todayDateKey: '2026-03-09',
        windowDays: 7,
      );
      final month = TelemetryMath.sumTrailKm(
        savedDays: saved,
        todayDistanceKm: 1.5,
        todayDateKey: '2026-03-09',
        windowDays: 30,
      );

      expect(week, closeTo(4.0, 0.001));
      expect(month, closeTo(8.0, 0.001));
    });
  });

  group('TelemetryMath - Shared Partner Resolution & Discrepancy', () {
    test('never fabricates steps from distance when step sources are unavailable', () {
      final resolved = TelemetryMath.resolvePartnerActivity(
        telemetrySteps: null,
        locationSteps: null,
        gpsJourneyKm: 3.2,
        telemetryDistanceKm: null,
        telemetryWalkingSeconds: 1800, // 30 min walking
        locationActiveMinutes: null,
        telemetryAppSeconds: 600, // 10 min app usage
        telemetryActivity: null,
        speedMps: 1.4,
        savedSummaries: const [],
        todayDateKey: '2026-03-09',
      );

      // Must remain null ("Unknown" in UI), NEVER 3.2 * 1300
      expect(resolved.stepsToday, isNull);
      expect(resolved.distanceKmToday, closeTo(3.2, 0.001));
      expect(resolved.walkingMinutesToday, 30);
      expect(resolved.appMinutesToday, 10);
      expect(resolved.activityState, 'walking');
    });

    test('checkStepsVsDistanceDiscrepancy flags impossible step-vs-GPS combinations', () {
      final indoorHighSteps = TelemetryMath.checkStepsVsDistanceDiscrepancy(
        steps: 2400,
        gpsDistanceKm: 0.02,
      );
      expect(indoorHighSteps.hasDiscrepancy, isTrue);

      final vehicleGpsOnly = TelemetryMath.checkStepsVsDistanceDiscrepancy(
        steps: 0,
        gpsDistanceKm: 1.8,
      );
      expect(vehicleGpsOnly.hasDiscrepancy, isTrue);

      final consistentWalk = TelemetryMath.checkStepsVsDistanceDiscrepancy(
        steps: 2000,
        gpsDistanceKm: 1.4,
      );
      expect(consistentWalk.hasDiscrepancy, isFalse);
    });

    test('isTimestampStale & formatAgeLabel report staleness accurately', () {
      final now = DateTime.utc(2026, 3, 9, 12, 0, 0);
      expect(TelemetryMath.isTimestampStale(null, now: now), isTrue);
      expect(
        TelemetryMath.isTimestampStale(
          now.subtract(const Duration(minutes: 2)),
          now: now,
        ),
        isFalse,
      );
      expect(
        TelemetryMath.isTimestampStale(
          now.subtract(const Duration(minutes: 10)),
          now: now,
        ),
        isTrue,
      );
      expect(
        TelemetryMath.formatAgeLabel(
          now.subtract(const Duration(minutes: 10)),
          now: now,
        ),
        '10m ago',
      );
    });
  });
}
