import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/deleted_ids_store.dart';
import '../../../core/services/device_status_service.dart';
import '../../../core/utils/telemetry_math.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/stage_provider.dart';
import '../../../providers/world_provider.dart';

class TelemetryDebugScreen extends StatefulWidget {
  const TelemetryDebugScreen({super.key});

  @override
  State<TelemetryDebugScreen> createState() => _TelemetryDebugScreenState();
}

class _TelemetryDebugScreenState extends State<TelemetryDebugScreen> {
  Map<String, dynamic>? _snapshot;
  bool _loading = true;
  bool _auditing = false;
  bool _cleaning = false;
  List<OrphanAuditItem>? _auditFindings;
  String? _auditBanner;

  @override
  void initState() {
    super.initState();
    _refreshSnapshot();
  }

  Future<void> _refreshSnapshot() async {
    setState(() => _loading = true);
    final snap = await DeviceStatusService.getDebugTelemetrySnapshot();
    if (!mounted) return;
    setState(() {
      _snapshot = snap;
      _loading = false;
    });
  }

  Future<void> _runOrphanAudit() async {
    final auth = context.read<AuthProvider>();
    final uid = auth.user?.id ?? '';
    final spaceId = auth.space?.id ?? '';
    if (uid.isEmpty || spaceId.isEmpty) {
      setState(() => _auditBanner = 'Not logged into an active space.');
      return;
    }
    setState(() {
      _auditing = true;
      _auditBanner = null;
    });
    final items = await OrphanAuditService.auditActiveSpace(
      spaceId: spaceId,
      myUid: uid,
      partnerUid: auth.partner?.id,
    );
    if (!mounted) return;
    setState(() {
      _auditing = false;
      _auditFindings = items;
      _auditBanner = items.isEmpty
          ? 'No orphaned, legacy test, or foreign rows found.'
          : 'Found ${items.length} item(s). Review below before confirming deletion.';
    });
  }

  Future<void> _confirmDeleteAuditItems() async {
    final items = _auditFindings;
    if (items == null || items.isEmpty) return;
    setState(() => _cleaning = true);
    final deleted = await OrphanAuditService.deleteFindings(items);
    if (!mounted) return;
    setState(() {
      _cleaning = false;
      _auditFindings = [];
      _auditBanner = 'Deleted $deleted item(s) permanently from DB & storage.';
    });
  }

  String _fmtEpochMs(dynamic val) {
    if (val is num && val.toInt() > 0) {
      final dt = DateTime.fromMillisecondsSinceEpoch(val.toInt()).toLocal();
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      final s = dt.second.toString().padLeft(2, '0');
      return '$h:$m:$s (${TelemetryMath.formatAgeLabel(dt)})';
    }
    return 'None';
  }

  @override
  Widget build(BuildContext context) {
    final stage = context.watch<StageProvider>();
    final world = context.watch<WorldProvider>();
    final scheme = Theme.of(context).colorScheme;
    final bg = scheme.surface;
    final cardBg = Theme.of(context).brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.04);
    final borderColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.16)
        : Colors.black.withValues(alpha: 0.14);

    final partnerMetrics = world.resolvePartnerMetrics(
      telemetry: stage.partnerTelemetry,
      savedSummaries: stage.partnerDailySummaries,
    );

    final telemetryMap = (_snapshot?['telemetry'] is Map)
        ? Map<String, dynamic>.from(_snapshot!['telemetry'] as Map)
        : const <String, dynamic>{};

    final syncErrorsRaw = _snapshot?['syncErrorsJson']?.toString() ?? '[]';
    final List<dynamic> syncErrors = () {
      try {
        return jsonDecode(syncErrorsRaw) as List<dynamic>;
      } catch (_) {
        return const <dynamic>[];
      }
    }();

    final eventsRaw = telemetryMap['recentScreenEventsJson']?.toString() ?? '[]';
    final List<dynamic> screenEvents = () {
      try {
        return jsonDecode(eventsRaw) as List<dynamic>;
      } catch (_) {
        return const <dynamic>[];
      }
    }();

    final myDisc = TelemetryMath.checkStepsVsDistanceDiscrepancy(
      steps: telemetryMap['stepsToday'] as int? ?? 0,
      distanceKm: world.myJourneyKmToday,
    );

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Telemetry & Integrity Debug'),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _refreshSnapshot,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh raw snapshot',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _sectionCard(
                  title: 'Permissions & Background Reliability',
                  cardBg: cardBg,
                  borderColor: borderColor,
                  children: [
                    _kv('Battery Optimization Exempt', '${_snapshot?['isIgnoringBatteryOptimizations'] ?? 'unknown'}'),
                    _kv('Health Connect Status', '${_snapshot?['healthConnectStatus'] ?? 'unknown'}'),
                    _kv('Health Connect Permitted', '${_snapshot?['healthConnectPermitted'] ?? false}'),
                    _kv('Activity Recognition Permitted', '${_snapshot?['activityRecognitionPermitted'] ?? false}'),
                    _kv('Hardware Step Sensor Present', '${_snapshot?['hasHardwareStepSensor'] ?? false}'),
                    _kv('Cloud Bg Config Ready', '${_snapshot?['hasCloudConfig'] ?? false}'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () async {
                            await DeviceStatusService.requestHealthConnectPermissions();
                            await _refreshSnapshot();
                          },
                          icon: const Icon(Icons.favorite_border, size: 16),
                          label: const Text('Health Connect Perms'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () async {
                            await DeviceStatusService.requestIgnoreBatteryOptimizations();
                            await _refreshSnapshot();
                          },
                          icon: const Icon(Icons.battery_saver, size: 16),
                          label: const Text('Exempt Battery Opt'),
                        ),
                        FilledButton.icon(
                          onPressed: () async {
                            await stage.refreshPartnerTelemetryNow();
                            await _refreshSnapshot();
                          },
                          icon: const Icon(Icons.sync, size: 16),
                          label: const Text('Force Cloud Sync'),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _sectionCard(
                  title: 'This Device Raw Telemetry',
                  cardBg: cardBg,
                  borderColor: borderColor,
                  children: [
                    _kv('Active Date Key', '${telemetryMap['dateKey'] ?? '-'} (TZ ${telemetryMap['timeZoneOffsetMinutes']}m)'),
                    _kv('Battery', '${telemetryMap['batteryLevel'] ?? -1}% • Charging=${telemetryMap['isCharging']} • ${_fmtEpochMs(telemetryMap['batteryUpdatedAtMs'])}'),
                    _kv('Network', '${telemetryMap['networkType'] ?? 'unknown'} • ${_fmtEpochMs(telemetryMap['networkUpdatedAtMs'])}'),
                    _kv('Unlocks / Locks Today', '${telemetryMap['unlockCountToday'] ?? 0} unlocks / ${telemetryMap['lockCountToday'] ?? 0} locks'),
                    _kv('Last Unlocked / Locked', '${_fmtEpochMs(telemetryMap['lastUnlockedAtMs'])} | ${_fmtEpochMs(telemetryMap['lastLockedAtMs'])}'),
                    _kv('Screen / Walk / App Time', '${telemetryMap['screenTimeSecondsToday'] ?? 0}s screen • ${telemetryMap['walkingTimeSecondsToday'] ?? 0}s walk • ${telemetryMap['appTimeSecondsToday'] ?? 0}s app'),
                    _kv('Step Raw Baseline Last', '${_snapshot?['rawStepLast'] ?? -1}'),
                    _kv('Hardware Sensor Steps Today', '${_snapshot?['sensorStepsToday'] ?? 0}'),
                    _kv('Health Connect Steps / Dist', '${_snapshot?['hcStepsToday'] ?? -1} steps / ${((_snapshot?['hcDistanceKmToday'] as num?)?.toDouble() ?? -1).toStringAsFixed(2)} km'),
                    _kv('Effective Step Source', '${telemetryMap['stepSource'] ?? 'none'}'),
                    _kv('Movement State', '${telemetryMap['movementActivity'] ?? 'stationary'}'),
                    _kv('Last Cloud BG Sync', _fmtEpochMs(_snapshot?['lastCloudSyncAtMs'])),
                  ],
                ),
                const SizedBox(height: 14),
                _sectionCard(
                  title: 'Partner Resolved View (World == Eyes On You)',
                  cardBg: cardBg,
                  borderColor: borderColor,
                  children: [
                    _kv('Partner Telemetry Updated', TelemetryMath.formatAgeLabel(DateTime.tryParse(stage.partnerTelemetry?.updatedAt ?? ''))),
                    _kv('Partner Battery Updated', TelemetryMath.formatAgeLabel(stage.partnerTelemetry?.batteryUpdatedAt)),
                    _kv('Partner Network Updated', TelemetryMath.formatAgeLabel(stage.partnerTelemetry?.networkUpdatedAt)),
                    _kv('Partner Steps / Source', '${partnerMetrics.stepsToday ?? 'Unknown'} (${stage.partnerTelemetry?.stepSource ?? 'none'})'),
                    _kv('Partner Distance / 7d / 30d', '${partnerMetrics.distanceKmToday.toStringAsFixed(2)} km • 7d ${partnerMetrics.weekTrailKm.toStringAsFixed(2)} km • 30d ${partnerMetrics.monthTrailKm.toStringAsFixed(2)} km'),
                    _kv('Partner Walk Min / App Min', '${partnerMetrics.walkingMinutesToday}m walk • ${partnerMetrics.appMinutesToday}m app'),
                    _kv('Partner Activity / Discrepancy', '${partnerMetrics.activityState} • ${partnerMetrics.discrepancy?.note ?? 'OK'}'),
                    _kv('My Discrepancy Check', myDisc.note),
                    _kv('Saved Partner Summaries', '${stage.partnerDailySummaries.length} day rows'),
                    if (stage.lastTelemetrySyncError != null)
                      _kv('Last Provider Sync Error', stage.lastTelemetrySyncError!),
                  ],
                ),
                const SizedBox(height: 14),
                _sectionCard(
                  title: 'Recent Screen Unlock/Lock Log (${screenEvents.length})',
                  cardBg: cardBg,
                  borderColor: borderColor,
                  children: screenEvents.isEmpty
                      ? [const Text('No screen events captured yet today.')]
                      : screenEvents.reversed.take(15).map((raw) {
                          final m = raw is Map ? raw : const {};
                          final type = m['type']?.toString() ?? '';
                          final dur = m['durationSec'];
                          return _kv(
                            type.toUpperCase(),
                            '${_fmtEpochMs(m['tsMs'])}${dur != null ? ' (${dur}s session)' : ''}',
                          );
                        }).toList(),
                ),
                const SizedBox(height: 14),
                _sectionCard(
                  title: 'Cloud Write Errors (${syncErrors.length})',
                  cardBg: cardBg,
                  borderColor: borderColor,
                  children: syncErrors.isEmpty
                      ? [const Text('No failed cloud writes logged.')]
                      : syncErrors.reversed.take(15).map((raw) {
                          final m = raw is Map ? raw : const {};
                          return _kv(
                            m['source']?.toString() ?? 'error',
                            '${_fmtEpochMs(m['tsMs'])} — ${m['message'] ?? ''}',
                          );
                        }).toList(),
                ),
                const SizedBox(height: 14),
                _sectionCard(
                  title: 'Orphaned & Test Data Audit',
                  cardBg: cardBg,
                  borderColor: borderColor,
                  children: [
                    const Text(
                      'Scans active space DB rows for missing owners, test users (e.g. legacy seed accounts), or foreign owners, and reports them before deleting.',
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        OutlinedButton(
                          onPressed: _auditing ? null : _runOrphanAudit,
                          child: Text(_auditing ? 'Scanning...' : 'Scan Database'),
                        ),
                        const SizedBox(width: 10),
                        if (_auditFindings != null && _auditFindings!.isNotEmpty)
                          FilledButton(
                            onPressed: _cleaning ? null : _confirmDeleteAuditItems,
                            child: Text(_cleaning
                                ? 'Deleting...'
                                : 'Confirm Delete (${_auditFindings!.length})'),
                          ),
                      ],
                    ),
                    if (_auditBanner != null) ...[
                      const SizedBox(height: 8),
                      Text(_auditBanner!, style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                    if (_auditFindings != null && _auditFindings!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ..._auditFindings!.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            '• [${item.table}] ${item.title} (${item.id})\n  Owner: "${item.ownerRaw}" — ${item.reason}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
    );
  }

  Widget _sectionCard({
    required String title,
    required Color cardBg,
    required Color borderColor,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 145,
            child: Text(k, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(v, style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
