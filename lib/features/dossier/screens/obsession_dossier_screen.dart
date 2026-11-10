import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/device_status_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/stage_provider.dart';
import '../../../providers/world_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../data/models/secret_whisper.dart';

class ObsessionDossierScreen extends StatefulWidget {
  const ObsessionDossierScreen({super.key});

  @override
  State<ObsessionDossierScreen> createState() => _ObsessionDossierScreenState();
}

class _ObsessionDossierScreenState extends State<ObsessionDossierScreen> {
  final TextEditingController _whisperCtrl = TextEditingController();
  bool _sendingWhisper = false;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<StageProvider>().refreshPartnerTelemetryNow();
      }
    });
  }

  @override
  void dispose() {
    _whisperCtrl.dispose();
    super.dispose();
  }

  String _formatRelativeTime(DateTime? dt) {
    if (dt == null) return 'Unknown';
    final diff = DateTime.now().difference(dt.toLocal());
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ${diff.inMinutes % 60}m ago';
    return DateFormat('MMM d, h:mm a').format(dt.toLocal());
  }

  String _formatIsoTime(String iso) {
    if (iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return DateFormat('h:mm a').format(dt);
    } catch (_) {
      return '';
    }
  }

  String _formatIsoRelative(String iso) {
    if (iso.isEmpty) return '';
    try {
      return _formatRelativeTime(DateTime.parse(iso));
    } catch (_) {
      return '';
    }
  }

  Future<void> _handleRefresh() async {
    setState(() => _refreshing = true);
    HapticFeedback.lightImpact();
    await context.read<StageProvider>().refreshPartnerTelemetryNow();
    if (mounted) setState(() => _refreshing = false);
  }

  Future<void> _sendWhisper() async {
    final text = _whisperCtrl.text.trim();
    if (text.isEmpty) return;
    final auth = context.read<AuthProvider>();
    final spaceId = auth.space?.id ?? '';
    final user = auth.user;
    if (spaceId.isEmpty || user == null) return;

    setState(() => _sendingWhisper = true);
    HapticFeedback.mediumImpact();
    await context.read<StageProvider>().sendSecretWhisper(
          spaceId: spaceId,
          senderId: user.id,
          senderNickname: user.nickname,
          text: text,
        );
    _whisperCtrl.clear();
    if (mounted) {
      setState(() => _sendingWhisper = false);
      FocusScope.of(context).unfocus();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sealed whisper sent — burns after reading 🥀'),
          backgroundColor: Color(0xFF9F1239),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _openAndBurnWhisper(SecretWhisper whisper, String spaceId, String readerId) async {
    if (whisper.isBurned) return;
    final stage = context.read<StageProvider>();
    HapticFeedback.heavyImpact();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: const Color(0xFF14070D),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFF43F5E).withOpacity(0.55), width: 1.4),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF9F1239).withOpacity(0.4),
                blurRadius: 28,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🥀', style: TextStyle(fontSize: 38)),
              const SizedBox(height: 8),
              Text(
                'Whisper from ${whisper.senderNickname}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFDE8EE),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'SINGLE VIEW • BURNS PERMANENTLY ON CLOSE',
                style: TextStyle(
                  fontSize: 9.5,
                  letterSpacing: 1.0,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFF43F5E),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: Text(
                  whisper.text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.45,
                    fontStyle: FontStyle.italic,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.local_fire_department_rounded, size: 17),
                  label: const Text(
                    'Read & Burn Forever',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFBE123C),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (whisper.senderId != readerId) {
      await stage.revealAndBurnWhisper(
        spaceId: spaceId,
        whisperId: whisper.id,
        readerId: readerId,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final stage = context.watch<StageProvider>();
    final world = context.watch<WorldProvider>();
    final themeProv = context.watch<ThemeProvider>();

    final user = auth.user;
    final partner = auth.partner;
    final spaceId = auth.space?.id ?? '';
    final partnerName = partner?.nickname ?? 'Partner';
    final telemetry = stage.partnerTelemetry;
    final pLoc = world.partnerLocation;
    final movementState = world.partnerMovementState;
    final journeyPoints = world.partnerJourneyToday;
    final geoEvents = world.geofenceEvents;
    final stayPoints = world.partnerStayPointsToday;

    const crimson = Color(0xFFF43F5E);
    const wineBg = Color(0xFF0A0408);
    const cardBg = Color(0xFF150910);

    return Scaffold(
      backgroundColor: wineBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 19),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Eyes On You',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFFFDE8EE),
                letterSpacing: -0.2,
              ),
            ),
            Text(
              partner != null
                  ? 'Live Hardware & Route Dossier • $partnerName'
                  : 'Pair with your partner to activate live radar',
              style: const TextStyle(fontSize: 11, color: Color(0xFFB88896)),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Switch to Velvet Noir Theme',
            icon: Icon(
              Icons.auto_awesome_rounded,
              color: themeProv.themeId == 'velvet_noir' ? crimson : Colors.white70,
              size: 20,
            ),
            onPressed: () async {
              HapticFeedback.lightImpact();
              if (spaceId.isNotEmpty && user != null) {
                await themeProv.updateTheme(
                  'velvet_noir',
                  spaceId: spaceId,
                  userId: user.id,
                  userName: user.nickname,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Velvet Noir theme activated 🥀'),
                      backgroundColor: Color(0xFF9F1239),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              }
            },
          ),
          IconButton(
            tooltip: 'Sync Live Signals',
            icon: _refreshing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: crimson),
                  )
                : const Icon(Icons.refresh_rounded, color: Colors.white, size: 21),
            onPressed: _refreshing ? null : _handleRefresh,
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: crimson,
          backgroundColor: cardBg,
          onRefresh: _handleRefresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Partner Presence Hero + Mutual Consent Toggle
                _buildPartnerHeroCard(
                  partner: partner,
                  partnerName: partnerName,
                  telemetry: telemetry,
                  pLoc: pLoc,
                  stage: stage,
                  crimson: crimson,
                  cardBg: cardBg,
                ),

                const SizedBox(height: 14),

                // 2. 100% Real Hardware Telemetry Grid
                _sectionTitle('REAL-TIME HARDWARE RADAR', crimson),
                const SizedBox(height: 8),
                _buildTelemetryGrid(
                  telemetry: telemetry,
                  movementState: movementState,
                  pLoc: pLoc,
                  crimson: crimson,
                  cardBg: cardBg,
                ),

                const SizedBox(height: 16),

                // 3. Today's Real GPS Breadcrumb Trail Map
                _sectionTitle('24H ROUTE BREADCRUMB TRAIL', crimson),
                const SizedBox(height: 8),
                _buildBreadcrumbTrailMap(
                  pLoc: pLoc,
                  journeyPoints: journeyPoints,
                  pinnedPlaces: world.pinnedPlaces,
                  partnerName: partnerName,
                  crimson: crimson,
                  cardBg: cardBg,
                ),

                const SizedBox(height: 16),

                // 4. Geofence Arrival/Departure Radar + Stay Points Log
                _sectionTitle('ARRIVAL, DEPARTURE & STOPS LOG', crimson),
                const SizedBox(height: 8),
                _buildTimelineLog(
                  geoEvents: geoEvents,
                  stayPoints: stayPoints,
                  crimson: crimson,
                  cardBg: cardBg,
                ),

                const SizedBox(height: 16),

                // 5. Burn-After-Reading Secret Whispers
                _sectionTitle('BURN-AFTER-READING WHISPERS', crimson),
                const SizedBox(height: 8),
                _buildWhispersSection(
                  stage: stage,
                  userId: user?.id ?? '',
                  spaceId: spaceId,
                  crimson: crimson,
                  cardBg: cardBg,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text, Color accent) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          color: accent.withOpacity(0.9),
        ),
      ),
    );
  }

  Widget _buildPartnerHeroCard({
    required dynamic partner,
    required String partnerName,
    required DeviceTelemetry? telemetry,
    required dynamic pLoc,
    required StageProvider stage,
    required Color crimson,
    required Color cardBg,
  }) {
    final lastUpdated = telemetry?.updatedAt.isNotEmpty == true
        ? _formatIsoRelative(telemetry!.updatedAt)
        : (pLoc != null ? _formatIsoRelative(pLoc.updatedAt) : 'Awaiting signal');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF280B16), cardBg],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: crimson.withOpacity(0.35)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: crimson.withOpacity(0.2),
                backgroundImage: partner?.avatarUrl != null
                    ? CachedNetworkImageProvider(partner!.avatarUrl!)
                    : null,
                child: partner?.avatarUrl == null
                    ? Text(
                        partnerName.isNotEmpty ? partnerName[0].toUpperCase() : 'P',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            partnerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFFDE8EE),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: telemetry?.isDeviceUnlocked == true
                                ? const Color(0xFF34D399).withOpacity(0.18)
                                : crimson.withOpacity(0.16),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            telemetry == null
                                ? 'STANDBY'
                                : (telemetry.isDeviceUnlocked ? 'ACTIVE NOW' : 'SCREEN OFF'),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: telemetry?.isDeviceUnlocked == true
                                  ? const Color(0xFF34D399)
                                  : crimson,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      pLoc?.placeName?.isNotEmpty == true
                          ? '📍 ${pLoc!.placeName} • Synced $lastUpdated'
                          : 'Synced $lastUpdated',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFFB88896)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Share my live device telemetry with partner',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFFFDE8EE)),
                  ),
                ),
                Switch.adaptive(
                  value: stage.isTelemetrySharingEnabled,
                  activeColor: crimson,
                  onChanged: (val) {
                    HapticFeedback.selectionClick();
                    stage.setTelemetrySharingEnabled(val);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryGrid({
    required DeviceTelemetry? telemetry,
    required String? movementState,
    required dynamic pLoc,
    required Color crimson,
    required Color cardBg,
  }) {
    final screenLabel = telemetry == null
        ? 'Awaiting signal'
        : (telemetry.isDeviceUnlocked
            ? 'Unlocked & Active'
            : (telemetry.isScreenOn ? 'Lockscreen On' : 'Screen Off'));

    final unlockSub = telemetry?.lastUnlockedAt != null
        ? 'Last unlocked ${_formatRelativeTime(telemetry!.lastUnlockedAt)}'
        : (telemetry != null ? 'Real OS screen state' : 'Needs partner app active');

    final netLabel = telemetry == null
        ? 'Awaiting signal'
        : switch (telemetry.networkType) {
            'wifi' => 'Wi-Fi Connected',
            'mobile' => 'Mobile Data',
            'offline' => 'Offline',
            'online' => 'Online',
            _ => 'Unknown',
          };

    final batLabel = telemetry != null && telemetry.batteryLevel >= 0
        ? '${telemetry.batteryLevel}%${telemetry.isCharging ? ' ⚡ Charging' : ''}'
        : 'Awaiting signal';

    final musicLabel = telemetry?.nowPlayingTitle?.isNotEmpty == true
        ? telemetry!.nowPlayingTitle!
        : 'Silent / Idle';
    final musicSub = telemetry?.nowPlayingArtist?.isNotEmpty == true
        ? telemetry!.nowPlayingArtist!
        : 'In-app Music Sanctuary';

    final moveLabel = movementState ?? 'Awaiting GPS speed';
    final gpsAccSub = pLoc?.accuracy != null
        ? 'GPS accuracy ±${pLoc!.accuracy!.round()}m'
        : 'Hardware GPS sensor';

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _metricTile(
                icon: telemetry?.isDeviceUnlocked == true
                    ? Icons.lock_open_rounded
                    : Icons.lock_outline_rounded,
                title: 'PHONE STATE',
                value: screenLabel,
                subtitle: unlockSub,
                accent: telemetry?.isDeviceUnlocked == true ? const Color(0xFF34D399) : crimson,
                cardBg: cardBg,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _metricTile(
                icon: telemetry?.networkType == 'wifi'
                    ? Icons.wifi_rounded
                    : Icons.signal_cellular_alt_rounded,
                title: 'CONNECTION',
                value: netLabel,
                subtitle: 'Live hardware network',
                accent: const Color(0xFF60A5FA),
                cardBg: cardBg,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _metricTile(
                icon: telemetry?.isCharging == true
                    ? Icons.battery_charging_full_rounded
                    : Icons.battery_std_rounded,
                title: 'BATTERY',
                value: batLabel,
                subtitle: telemetry?.isCharging == true ? 'Plugged in' : 'Real battery level',
                accent: telemetry?.isCharging == true ? const Color(0xFF34D399) : Colors.amber,
                cardBg: cardBg,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _metricTile(
                icon: Icons.directions_run_rounded,
                title: 'MOVEMENT',
                value: moveLabel,
                subtitle: gpsAccSub,
                accent: crimson,
                cardBg: cardBg,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _metricTile(
          icon: Icons.headphones_rounded,
          title: 'NOW LISTENING IN SANCTUARY',
          value: musicLabel,
          subtitle: musicSub,
          accent: const Color(0xFFC084FC),
          cardBg: cardBg,
          fullWidth: true,
        ),
      ],
    );
  }

  Widget _metricTile({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required Color accent,
    required Color cardBg,
    bool fullWidth = false,
  }) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withOpacity(0.28)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 17, color: accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
                    color: Color(0xFFB88896),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFDE8EE),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: Color(0xFF8C6370)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreadcrumbTrailMap({
    required dynamic pLoc,
    required List<JourneyPoint> journeyPoints,
    required List<dynamic> pinnedPlaces,
    required String partnerName,
    required Color crimson,
    required Color cardBg,
  }) {
    final trailCoords = journeyPoints
        .where((p) => p.lat != 0.0 && p.lng != 0.0)
        .map((p) => LatLng(p.lat, p.lng))
        .toList();

    final hasPartnerCoord = pLoc != null && (pLoc.lat != 0.0 || pLoc.lng != 0.0);
    if (!hasPartnerCoord && trailCoords.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white12),
        ),
        child: const Text(
          'Awaiting partner live GPS coordinates to render today’s route trail.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Color(0xFFB88896)),
        ),
      );
    }

    final center = hasPartnerCoord ? LatLng(pLoc.lat, pLoc.lng) : trailCoords.last;

    return Container(
      height: 220,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: crimson.withOpacity(0.35)),
      ),
      child: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: center,
              initialZoom: 14.2,
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.pagesofus.app',
              ),
              if (trailCoords.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: trailCoords,
                      color: crimson,
                      strokeWidth: 4.0,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  ...pinnedPlaces.map(
                    (zp) => Marker(
                      point: LatLng(zp.lat, zp.lng),
                      width: 28,
                      height: 28,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.amber, width: 1.5),
                        ),
                        alignment: Alignment.center,
                        child: Text(zp.icon, style: const TextStyle(fontSize: 13)),
                      ),
                    ),
                  ),
                  if (hasPartnerCoord)
                    Marker(
                      point: LatLng(pLoc.lat, pLoc.lng),
                      width: 34,
                      height: 34,
                      child: Container(
                        decoration: BoxDecoration(
                          color: crimson,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(color: crimson.withOpacity(0.7), blurRadius: 12),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          partnerName.isNotEmpty ? partnerName[0].toUpperCase() : 'P',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          Positioned(
            bottom: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.75),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: crimson.withOpacity(0.4)),
              ),
              child: Text(
                '${trailCoords.length} live GPS breadcrumbs today',
                style: const TextStyle(fontSize: 10.5, color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineLog({
    required List<dynamic> geoEvents,
    required List<dynamic> stayPoints,
    required Color crimson,
    required Color cardBg,
  }) {
    if (geoEvents.isEmpty && stayPoints.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white12),
        ),
        child: const Text(
          'No zone arrivals/departures or stops recorded yet today. Save key places on the World Map to trigger live arrival & departure alerts.',
          style: TextStyle(fontSize: 12, height: 1.4, color: Color(0xFFB88896)),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: crimson.withOpacity(0.25)),
      ),
      child: Column(
        children: [
          ...geoEvents.take(10).map((ev) {
            final isArrival = ev.eventType == 'arrived';
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: (isArrival ? const Color(0xFF34D399) : crimson).withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(ev.placeIcon, style: const TextStyle(fontSize: 13)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${isArrival ? 'Arrived at' : 'Left'} ${ev.placeName}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFDE8EE),
                          ),
                        ),
                        Text(
                          _formatIsoTime(ev.timestamp),
                          style: const TextStyle(fontSize: 10.5, color: Color(0xFFB88896)),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: (isArrival ? const Color(0xFF34D399) : crimson).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isArrival ? 'ENTERED' : 'EXITED',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: isArrival ? const Color(0xFF34D399) : crimson,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          ...stayPoints.reversed.take(6).map((sp) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Text(sp.icon, style: const TextStyle(fontSize: 15)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sp.placeName,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFFDE8EE),
                          ),
                        ),
                        Text(
                          '${sp.timeRangeText} • ${sp.durationText}',
                          style: const TextStyle(fontSize: 10.5, color: Color(0xFFB88896)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildWhispersSection({
    required StageProvider stage,
    required String userId,
    required String spaceId,
    required Color crimson,
    required Color cardBg,
  }) {
    final whispers = stage.secretWhispers;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: crimson.withOpacity(0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _whisperCtrl,
                  style: const TextStyle(fontSize: 13, color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Send a secret whisper (burns after reading)...',
                    hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF8C6370)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _sendingWhisper ? null : _sendWhisper,
                child: Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: crimson,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: _sendingWhisper
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.local_fire_department_rounded, size: 18, color: Colors.white),
                ),
              ),
            ],
          ),
          if (whispers.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...whispers.take(6).map((w) {
              final isMine = w.senderId == userId;
              return GestureDetector(
                onTap: () {
                  if (!isMine && !w.isBurned) {
                    _openAndBurnWhisper(w, spaceId, userId);
                  }
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: w.isBurned
                        ? Colors.white.withOpacity(0.03)
                        : crimson.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: w.isBurned ? Colors.white10 : crimson.withOpacity(0.45),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        w.isBurned
                            ? Icons.whatshot_outlined
                            : (isMine ? Icons.lock_clock_rounded : Icons.visibility_rounded),
                        size: 17,
                        color: w.isBurned ? Colors.white38 : crimson,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          w.isBurned
                              ? 'Whisper from ${w.senderNickname} • Burned & sealed 🔥'
                              : (isMine
                                  ? 'Your sealed whisper • Waiting to be read'
                                  : 'Sealed whisper from ${w.senderNickname} • Tap to read once'),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: w.isBurned ? FontWeight.normal : FontWeight.w600,
                            color: w.isBurned ? Colors.white38 : const Color(0xFFFDE8EE),
                          ),
                        ),
                      ),
                      Text(
                        _formatIsoTime(w.createdAt),
                        style: const TextStyle(fontSize: 10, color: Color(0xFF8C6370)),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
