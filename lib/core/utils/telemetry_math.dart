import 'dart:math' as math;

class ScreenEvent {
  final String type; // 'unlock' | 'lock' | 'screen_on'
  final int timestampMs;
  final int durationSeconds;

  const ScreenEvent({
    required this.type,
    required this.timestampMs,
    this.durationSeconds = 0,
  });

  factory ScreenEvent.fromJson(Map<String, dynamic> json) {
    final tsVal = json['tsMs'] ?? json['ts'] ?? json['timestampMs'];
    final durVal = json['durationSec'] ?? json['durationSeconds'] ?? 0;
    return ScreenEvent(
      type: json['type']?.toString() ?? 'unlock',
      timestampMs: (tsVal as num?)?.toInt() ?? 0,
      durationSeconds: (durVal as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'tsMs': timestampMs,
        if (durationSeconds > 0) 'durationSec': durationSeconds,
      };
}

class ScreenActivitySummary {
  final int unlockCountToday;
  final int lockCountToday;
  final DateTime? lastUnlockedAt;
  final DateTime? lastLockedAt;
  final bool isScreenOn;
  final bool isDeviceUnlocked;
  final int screenTimeSecondsToday;
  final List<int> sessionDurationsSeconds;

  const ScreenActivitySummary({
    required this.unlockCountToday,
    required this.lockCountToday,
    this.lastUnlockedAt,
    this.lastLockedAt,
    required this.isScreenOn,
    required this.isDeviceUnlocked,
    required this.screenTimeSecondsToday,
    required this.sessionDurationsSeconds,
  });
}

class StepBaselineState {
  final String dateKey;
  final bool hasBaseline;
  final int baselineRaw;
  final int lastRaw;
  final int todaySteps;

  const StepBaselineState({
    required this.dateKey,
    required this.hasBaseline,
    required this.baselineRaw,
    required this.lastRaw,
    required this.todaySteps,
  });

  factory StepBaselineState.empty(String dateKey) => StepBaselineState(
        dateKey: dateKey,
        hasBaseline: false,
        baselineRaw: 0,
        lastRaw: 0,
        todaySteps: 0,
      );
}

class GpsTrackPoint {
  final double lat;
  final double lng;
  final DateTime timestamp;
  final double accuracyMeters;
  final double speedMps;

  const GpsTrackPoint({
    required this.lat,
    required this.lng,
    required this.timestamp,
    this.accuracyMeters = 0.0,
    this.speedMps = 0.0,
  });
}

class DiscrepancyReport {
  final bool hasDiscrepancy;
  final String reason;

  String get note => reason;

  const DiscrepancyReport({
    required this.hasDiscrepancy,
    this.reason = '',
  });
}

class DailyActivitySummary {
  final String userId;
  final String dateKey; // YYYY-MM-DD in partner local timezone
  final int unlockCount;
  final int lockCount;
  final int screenTimeSeconds;
  final int steps;
  final double distanceKm;
  final int walkingTimeSeconds;
  final int appTimeSeconds;
  final int stopsCount;
  final String source;
  final String updatedAt;

  const DailyActivitySummary({
    required this.userId,
    required this.dateKey,
    this.unlockCount = 0,
    this.lockCount = 0,
    this.screenTimeSeconds = 0,
    this.steps = 0,
    this.distanceKm = 0.0,
    this.walkingTimeSeconds = 0,
    this.appTimeSeconds = 0,
    this.stopsCount = 0,
    this.source = 'unknown',
    this.updatedAt = '',
  });

  factory DailyActivitySummary.fromJson(Map<String, dynamic> json) {
    return DailyActivitySummary(
      userId: json['userId']?.toString() ?? '',
      dateKey: json['dateKey']?.toString() ?? '',
      unlockCount: (json['unlockCount'] as num?)?.toInt() ?? 0,
      lockCount: (json['lockCount'] as num?)?.toInt() ?? 0,
      screenTimeSeconds: (json['screenTimeSeconds'] as num?)?.toInt() ?? 0,
      steps: (json['steps'] as num?)?.toInt() ?? 0,
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0.0,
      walkingTimeSeconds: (json['walkingTimeSeconds'] as num?)?.toInt() ?? 0,
      appTimeSeconds: (json['appTimeSeconds'] as num?)?.toInt() ?? 0,
      stopsCount: (json['stopsCount'] as num?)?.toInt() ?? 0,
      source: json['source']?.toString() ?? 'unknown',
      updatedAt: json['updatedAt']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'dateKey': dateKey,
        'unlockCount': unlockCount,
        'lockCount': lockCount,
        'screenTimeSeconds': screenTimeSeconds,
        'steps': steps,
        'distanceKm': double.parse(distanceKm.toStringAsFixed(4)),
        'walkingTimeSeconds': walkingTimeSeconds,
        'appTimeSeconds': appTimeSeconds,
        'stopsCount': stopsCount,
        'source': source,
        'updatedAt': updatedAt,
      };
}

class TelemetryMath {
  TelemetryMath._();

  /// Returns YYYY-MM-DD in the specified UTC offset (defaults to device local offset).
  static String localDateKeyFor(
    DateTime utcOrLocal, {
    int? offsetMinutes,
    int? timeZoneOffsetMinutes,
  }) {
    final utc = utcOrLocal.toUtc();
    final offset = offsetMinutes ?? timeZoneOffsetMinutes ?? DateTime.now().timeZoneOffset.inMinutes;
    final shifted = utc.add(Duration(minutes: offset));
    final y = shifted.year.toString().padLeft(4, '0');
    final m = shifted.month.toString().padLeft(2, '0');
    final d = shifted.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Returns UTC DateTime corresponding to 12:00 AM of the current local day for offsetMinutes.
  static DateTime startOfLocalDayUtc(DateTime nowUtc, int offsetMinutes) {
    final shifted = nowUtc.toUtc().add(Duration(minutes: offsetMinutes));
    final midnightShifted = DateTime.utc(shifted.year, shifted.month, shifted.day);
    return midnightShifted.subtract(Duration(minutes: offsetMinutes));
  }

  static bool isNewLocalDay({
    required String storedDateKey,
    required DateTime nowUtc,
    required int offsetMinutes,
  }) {
    if (storedDateKey.isEmpty) return false;
    return storedDateKey != localDateKeyFor(nowUtc, offsetMinutes: offsetMinutes);
  }

  /// Applies a raw cumulative Android TYPE_STEP_COUNTER reading to today's baseline.
  /// Handles both first baseline calibration, midnight rollover, and hardware reboot resets.
  static StepBaselineState applyRawStepReading({
    required StepBaselineState current,
    required int rawStepsSinceBoot,
    required String currentDateKey,
  }) {
    if (rawStepsSinceBoot < 0) return current;

    // Midnight rollover or first baseline recorded: do NOT count accumulated boot steps as today's steps
    if (current.dateKey != currentDateKey || !current.hasBaseline) {
      return StepBaselineState(
        dateKey: currentDateKey,
        hasBaseline: true,
        baselineRaw: rawStepsSinceBoot,
        lastRaw: rawStepsSinceBoot,
        todaySteps: 0,
      );
    }

    // Normal increment or hardware reboot (counter resets below lastRaw)
    final delta = rawStepsSinceBoot >= current.lastRaw
        ? (rawStepsSinceBoot - current.lastRaw)
        : rawStepsSinceBoot;

    return StepBaselineState(
      dateKey: currentDateKey,
      hasBaseline: true,
      baselineRaw: current.baselineRaw,
      lastRaw: rawStepsSinceBoot,
      todaySteps: current.todaySteps + (delta > 0 ? delta : 0),
    );
  }

  /// Aggregates today's unlock/lock event log into counts, last timestamps, and screen sessions.
  static ScreenActivitySummary aggregateScreenEvents({
    required List<ScreenEvent> events,
    required DateTime nowUtc,
    required bool isCurrentlyScreenOn,
    required bool isCurrentlyUnlocked,
    int? timeZoneOffsetMinutes,
  }) {
    final offset = timeZoneOffsetMinutes ?? DateTime.now().timeZoneOffset.inMinutes;
    final dayStartUtc = startOfLocalDayUtc(nowUtc, offset);
    final dayStartMs = dayStartUtc.millisecondsSinceEpoch;
    final nowMs = nowUtc.toUtc().millisecondsSinceEpoch;

    final sorted = List<ScreenEvent>.from(events)
      ..sort((a, b) => a.timestampMs.compareTo(b.timestampMs));

    int unlocks = 0;
    int locks = 0;
    int? lastUnlockMs;
    int? lastLockMs;
    int? activeSessionStartMs;
    final sessions = <int>[];
    int totalScreenMs = 0;

    for (final ev in sorted) {
      if (ev.timestampMs <= 0) continue;
      final isToday = ev.timestampMs >= dayStartMs && ev.timestampMs <= nowMs + 60000;
      if (ev.type == 'unlock') {
        lastUnlockMs = ev.timestampMs;
        if (isToday) {
          unlocks++;
          activeSessionStartMs ??= ev.timestampMs;
        }
      } else if (ev.type == 'lock') {
        lastLockMs = ev.timestampMs;
        if (isToday) {
          locks++;
          if (activeSessionStartMs != null && ev.timestampMs > activeSessionStartMs) {
            final durMs = ev.timestampMs - activeSessionStartMs;
            totalScreenMs += durMs;
            sessions.add((durMs / 1000).round());
          }
          activeSessionStartMs = null;
        }
      }
    }

    // Include ongoing active unlocked session up to now
    if (isCurrentlyUnlocked && activeSessionStartMs != null && nowMs > activeSessionStartMs) {
      final ongoingMs = nowMs - activeSessionStartMs;
      totalScreenMs += ongoingMs;
      sessions.add((ongoingMs / 1000).round());
    }

    return ScreenActivitySummary(
      unlockCountToday: unlocks,
      lockCountToday: locks,
      lastUnlockedAt: lastUnlockMs != null
          ? DateTime.fromMillisecondsSinceEpoch(lastUnlockMs, isUtc: true)
          : null,
      lastLockedAt: lastLockMs != null
          ? DateTime.fromMillisecondsSinceEpoch(lastLockMs, isUtc: true)
          : null,
      isScreenOn: isCurrentlyScreenOn,
      isDeviceUnlocked: isCurrentlyUnlocked,
      screenTimeSecondsToday: (totalScreenMs / 1000).round(),
      sessionDurationsSeconds: sessions,
    );
  }

  /// Great-circle Haversine distance in kilometers.
  static double haversineKm(double lat1, double lng1, double lat2, double lng2) {
    const earthRadiusKm = 6371.0;
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(lat1)) *
            math.cos(_toRad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  static double _toRad(double deg) => deg * math.pi / 180.0;

  /// Sums verified travel distance across GPS points while rejecting stationary indoor jitter.
  static double computeVerifiedGpsDistanceKm(
    List<GpsTrackPoint> points, {
    double maxAccuracyMeters = 35.0,
    double minSegmentMeters = 8.0,
    bool walkingOnly = false,
  }) {
    if (points.length < 2) return 0.0;

    final sorted = List<GpsTrackPoint>.from(points)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    double totalKm = 0.0;
    GpsTrackPoint? prevValid;

    for (final p in sorted) {
      if (p.lat == 0.0 && p.lng == 0.0) continue;
      if (p.accuracyMeters > maxAccuracyMeters) continue;

      if (prevValid == null) {
        prevValid = p;
        continue;
      }

      if (walkingOnly && (p.speedMps > 5.0 || prevValid.speedMps > 5.0)) {
        prevValid = p;
        continue;
      }

      final segKm = haversineKm(prevValid.lat, prevValid.lng, p.lat, p.lng);
      final segMeters = segKm * 1000.0;

      // Ignore indoor drift hops smaller than minSegmentMeters or below combined GPS noise floor
      final combinedAcc = math.max(prevValid.accuracyMeters, p.accuracyMeters);
      final dynamicMinMeters = math.max(minSegmentMeters, combinedAcc * 0.75);
      if (segMeters < dynamicMinMeters) {
        continue;
      }

      // Guard against impossible teleports (> 45 m/s sustained)
      final dtSeconds = p.timestamp.difference(prevValid.timestamp).inSeconds;
      if (dtSeconds > 0 && (segMeters / dtSeconds) > 45.0) {
        continue;
      }
      if (walkingOnly && segKm >= 1.5) {
        prevValid = p;
        continue;
      }

      totalKm += segKm;
      prevValid = p;
    }

    return totalKm;
  }

  /// Cross-checks steps against GPS distance so mismatches are surfaced in debug logs.
  static DiscrepancyReport checkStepsVsDistanceDiscrepancy({
    required int steps,
    double? gpsDistanceKm,
    double? distanceKm,
  }) {
    final resolvedGpsKm = gpsDistanceKm ?? distanceKm ?? 0.0;
    if (steps >= 800 && resolvedGpsKm < 0.08) {
      return DiscrepancyReport(
        hasDiscrepancy: true,
        reason:
            '$steps steps recorded but GPS path is only ${(resolvedGpsKm * 1000).round()}m (indoor walk or throttled background GPS)',
      );
    }
    if (steps == 0 && resolvedGpsKm >= 0.4) {
      return DiscrepancyReport(
        hasDiscrepancy: true,
        reason:
            'GPS recorded ${resolvedGpsKm.toStringAsFixed(2)}km with 0 steps (vehicle transit or step sensor inactive)',
      );
    }
    if (steps > 0 && resolvedGpsKm > 0.05) {
      final impliedKmFromSteps = (steps * 0.72) / 1000.0;
      if (impliedKmFromSteps > resolvedGpsKm * 4.5 && (impliedKmFromSteps - resolvedGpsKm) > 1.2) {
        return DiscrepancyReport(
          hasDiscrepancy: true,
          reason:
              '$steps steps (~${impliedKmFromSteps.toStringAsFixed(2)}km) disagrees with GPS ${resolvedGpsKm.toStringAsFixed(2)}km',
        );
      }
    }
    return const DiscrepancyReport(hasDiscrepancy: false);
  }

  /// Sums saved daily summaries over the trailing [windowDays] (7 or 30) including today.
  /// Days with no saved record do NOT zero out existing days.
  static double sumTrailKm({
    required List<DailyActivitySummary> savedDays,
    required double todayDistanceKm,
    required String todayDateKey,
    required int windowDays,
  }) {
    final parsedToday = DateTime.tryParse(todayDateKey);
    if (parsedToday == null) return todayDistanceKm;

    final cutoff = DateTime(parsedToday.year, parsedToday.month, parsedToday.day)
        .subtract(Duration(days: windowDays - 1));

    final byDate = <String, double>{};
    for (final day in savedDays) {
      final dt = DateTime.tryParse(day.dateKey);
      if (dt == null) continue;
      final normalized = DateTime(dt.year, dt.month, dt.day);
      if (!normalized.isBefore(cutoff) && !normalized.isAfter(parsedToday)) {
        byDate[day.dateKey] = day.distanceKm > 0 ? day.distanceKm : 0.0;
      }
    }

    // Today's live figure overrides saved draft if larger or newer
    final existingToday = byDate[todayDateKey] ?? 0.0;
    byDate[todayDateKey] = todayDistanceKm > existingToday ? todayDistanceKm : existingToday;

    double total = 0.0;
    for (final km in byDate.values) {
      total += km;
    }
    return total;
  }

  static bool isTimestampStale(
    DateTime? timestamp, {
    DateTime? now,
    Duration threshold = const Duration(minutes: 4),
  }) {
    if (timestamp == null) return true;
    final ref = (now ?? DateTime.now()).toUtc();
    return ref.difference(timestamp.toUtc()) > threshold;
  }

  static String formatAgeLabel(DateTime? timestamp, {DateTime? now}) {
    if (timestamp == null) return 'No data yet';
    final ref = (now ?? DateTime.now()).toUtc();
    final diff = ref.difference(timestamp.toUtc());
    if (diff.isNegative || diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ${diff.inMinutes % 60}m ago';
    return '${diff.inDays}d ago';
  }

  /// Single unified activity resolution shared by World & Eyes On You
  /// so both screens always display identical steps, distance, walking time, and trails.
  static ResolvedActivityMetrics resolvePartnerActivity({
    required int? telemetrySteps,
    required int? locationSteps,
    required double gpsJourneyKm,
    required double? telemetryDistanceKm,
    required int? telemetryWalkingSeconds,
    required int? locationActiveMinutes,
    required int? telemetryAppSeconds,
    required String? telemetryActivity,
    required double? speedMps,
    required List<DailyActivitySummary> savedSummaries,
    required String todayDateKey,
  }) {
    // Steps: strictly real hardware/Health Connect count (never invented from km * 1300)
    int? resolvedSteps;
    if (telemetrySteps != null && telemetrySteps >= 0 && locationSteps != null && locationSteps >= 0) {
      resolvedSteps = math.max(telemetrySteps, locationSteps);
    } else if (telemetrySteps != null && telemetrySteps >= 0) {
      resolvedSteps = telemetrySteps;
    } else if (locationSteps != null && locationSteps >= 0) {
      resolvedSteps = locationSteps;
    }

    // Distance: combine verified GPS trail and Health Connect distance without fabricating
    final hcKm = (telemetryDistanceKm != null && telemetryDistanceKm >= 0.0) ? telemetryDistanceKm : 0.0;
    final resolvedDistKm = gpsJourneyKm > hcKm ? gpsJourneyKm : hcKm;

    // Walking Time (physical walking cadence seconds) vs App Time (screen foreground seconds)
    final walkingMin = telemetryWalkingSeconds != null && telemetryWalkingSeconds > 0
        ? (telemetryWalkingSeconds / 60.0).round()
        : (locationActiveMinutes != null && locationActiveMinutes >= 0 ? locationActiveMinutes : 0);
    final appMin = telemetryAppSeconds != null && telemetryAppSeconds > 0
        ? (telemetryAppSeconds / 60.0).round()
        : 0;

    // Classify current movement state
    final String activityState;
    if (speedMps != null && speedMps >= 4.2) {
      activityState = 'vehicle';
    } else if (telemetryActivity == 'walking' || (speedMps != null && speedMps >= 0.6)) {
      activityState = 'walking';
    } else {
      activityState = 'stationary';
    }

    final weekKm = sumTrailKm(
      savedDays: savedSummaries,
      todayDistanceKm: resolvedDistKm,
      todayDateKey: todayDateKey,
      windowDays: 7,
    );
    final monthKm = sumTrailKm(
      savedDays: savedSummaries,
      todayDistanceKm: resolvedDistKm,
      todayDateKey: todayDateKey,
      windowDays: 30,
    );

    final discrepancy = (resolvedSteps != null)
        ? checkStepsVsDistanceDiscrepancy(
            steps: resolvedSteps,
            distanceKm: resolvedDistKm,
          )
        : null;

    return ResolvedActivityMetrics(
      stepsToday: resolvedSteps,
      distanceKmToday: resolvedDistKm,
      walkingMinutesToday: walkingMin,
      appMinutesToday: appMin,
      weekTrailKm: weekKm,
      monthTrailKm: monthKm,
      activityState: activityState,
      discrepancy: discrepancy,
    );
  }
}

class ResolvedActivityMetrics {
  final int? stepsToday;
  final double distanceKmToday;
  final int walkingMinutesToday;
  final int appMinutesToday;
  final double weekTrailKm;
  final double monthTrailKm;
  final String activityState;
  final DiscrepancyReport? discrepancy;

  const ResolvedActivityMetrics({
    required this.stepsToday,
    required this.distanceKmToday,
    required this.walkingMinutesToday,
    required this.appMinutesToday,
    required this.weekTrailKm,
    required this.monthTrailKm,
    required this.activityState,
    this.discrepancy,
  });
}
