import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/device_status_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/stage_provider.dart';
import '../../../providers/world_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../data/models/secret_whisper.dart';

class _DossierPalette {
  final Color bg;
  final Color card;
  final Color heroStart;
  final Color subtleFill;
  final Color accent;
  final Color primaryInk;
  final Color mutedInk;
  final Color softBorder;
  final Color softGreen;
  final Color softBlue;
  final Color softAmber;
  final Color softViolet;
  final Color softBlush;

  const _DossierPalette({
    required this.bg,
    required this.card,
    required this.heroStart,
    required this.subtleFill,
    required this.accent,
    required this.primaryInk,
    required this.mutedInk,
    required this.softBorder,
    required this.softGreen,
    required this.softBlue,
    required this.softAmber,
    required this.softViolet,
    required this.softBlush,
  });

  factory _DossierPalette.fromBrightness(bool isDark) {
    if (isDark) {
      return const _DossierPalette(
        bg: Color(0xFF1B1418), // Warm matte dusk plum — soft on OLED eyes
        card: Color(0xFF251C21), // Cozy smoked mauve card
        heroStart: Color(0xFF30222A), // Gentle velvet rose dusk
        subtleFill: Color(0xFF2E2329),
        accent: Color(0xFFD28799), // Muted dusty rosewood (zero neon glare)
        primaryInk: Color(0xFFF2E4E9), // Warm cream-rose ink
        mutedInk: Color(0xFFB398A2), // Gentle dusty mauve
        softBorder: Color(0x22D28799),
        softGreen: Color(0xFF7CB89E), // Calm sage mint
        softBlue: Color(0xFF8AAED6), // Soft slate sky
        softAmber: Color(0xFFD4B27D), // Warm chamomile honey
        softViolet: Color(0xFFB498C8), // Muted lavender mist
        softBlush: Color(0xFFE4B4C1),
      );
    }
    return const _DossierPalette(
      bg: Color(0xFFFAF3F5), // Warm rose-oat paper
      card: Color(0xFFFFFAFA), // Soft silk cream card
      heroStart: Color(0xFFF3E4E9), // Airy cashmere blush
      subtleFill: Color(0xFFF2E6EA),
      accent: Color(0xFFB46578), // Calm dusty rosewood
      primaryInk: Color(0xFF33262B), // Gentle espresso-plum ink
      mutedInk: Color(0xFF7C666F), // Soft mauve taupe
      softBorder: Color(0x22B46578),
      softGreen: Color(0xFF4B8B70),
      softBlue: Color(0xFF537AA6),
      softAmber: Color(0xFFA67C46),
      softViolet: Color(0xFF7E6599),
      softBlush: Color(0xFFA35D70),
    );
  }
}

class ObsessionDossierScreen extends StatefulWidget {
  const ObsessionDossierScreen({super.key});

  @override
  State<ObsessionDossierScreen> createState() => _ObsessionDossierScreenState();
}

class _ObsessionDossierScreenState extends State<ObsessionDossierScreen> {
  final TextEditingController _whisperCtrl = TextEditingController();
  final MapController _mapController = MapController();
  bool _sendingWhisper = false;
  bool _refreshing = false;
  bool _isSatelliteMap = false;

  static const List<double> _darkMapMatrix = <double>[
    -0.20, -0.65, -0.07, 0, 215,
    -0.18, -0.60, -0.06, 0, 225,
    -0.20, -0.65, -0.07, 0, 220,
    0,      0,      0,    1, 0,
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<StageProvider>().refreshPartnerTelemetryNow();
        context.read<WorldProvider>().refreshPartnerJourneyTrail();
      }
    });
  }

  @override
  void dispose() {
    _whisperCtrl.dispose();
    _mapController.dispose();
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

  String _formatExactAndRelative(DateTime? dt) {
    if (dt == null) return 'Not recorded yet';
    final local = dt.toLocal();
    return '${DateFormat('h:mm a').format(local)} (${_formatRelativeTime(local)})';
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
    await Future.wait([
      context.read<StageProvider>().refreshPartnerTelemetryNow(),
      context.read<WorldProvider>().refreshPartnerJourneyTrail(),
    ]);
    if (mounted) setState(() => _refreshing = false);
  }

  Future<void> _openInGoogleMaps(double lat, double lng, String name) async {
    final geoUri = Uri.parse('geo:$lat,$lng?q=$lat,$lng(${Uri.encodeComponent(name)})');
    try {
      if (await launchUrl(geoUri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {}
    final webUri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    try {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    } catch (_) {}
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
          backgroundColor: Color(0xFF8F5262),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _openAndBurnWhisper(SecretWhisper whisper, String spaceId, String readerId, _DossierPalette pal) async {
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
            color: pal.card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: pal.accent.withOpacity(0.4), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: pal.accent.withOpacity(0.22),
                blurRadius: 24,
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
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: pal.primaryInk,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'SINGLE VIEW • BURNS PERMANENTLY ON CLOSE',
                style: TextStyle(
                  fontSize: 9.5,
                  letterSpacing: 1.0,
                  fontWeight: FontWeight.w700,
                  color: pal.accent,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: pal.subtleFill,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: pal.softBorder),
                ),
                child: Text(
                  whisper.text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.45,
                    fontStyle: FontStyle.italic,
                    color: pal.primaryInk,
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
                    backgroundColor: pal.accent,
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
    final weather = world.partnerWeather;

    final pal = _DossierPalette.fromBrightness(themeProv.isDark);
    final crimson = pal.accent;
    final cardBg = pal.card;

    return Scaffold(
      backgroundColor: pal.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: pal.primaryInk, size: 19),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Eyes On You',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: pal.primaryInk,
                letterSpacing: -0.2,
              ),
            ),
            Text(
              partner != null ? 'Live Dossier • $partnerName' : 'Pair to activate radar',
              style: TextStyle(fontSize: 11, color: pal.mutedInk),
            ),
          ],
        ),
        actions: [
          GestureDetector(
            onTap: () async {
              HapticFeedback.lightImpact();
              if (spaceId.isNotEmpty && user != null) {
                final activated = await themeProv.toggleVelvetNoir(
                  spaceId: spaceId,
                  userId: user.id,
                  userName: user.nickname,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        activated
                            ? 'Velvet Noir theme activated 🥀 (tap again to turn off)'
                            : 'Velvet Noir deactivated — restored ${themeProv.currentTheme.name} ✨',
                      ),
                      backgroundColor: activated ? pal.accent : AppColors.sage,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              }
            },
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 11),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: themeProv.themeId == 'velvet_noir'
                    ? crimson.withOpacity(0.18)
                    : pal.subtleFill,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: themeProv.themeId == 'velvet_noir' ? crimson.withOpacity(0.55) : pal.softBorder,
                ),
              ),
              child: Text(
                themeProv.themeId == 'velvet_noir' ? '🥀 Velvet ON' : '🥀 Velvet OFF',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: themeProv.themeId == 'velvet_noir' ? pal.primaryInk : pal.mutedInk,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Sync Live Signals',
            icon: _refreshing
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: crimson),
                  )
                : Icon(Icons.refresh_rounded, color: pal.primaryInk, size: 21),
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
                  world: world,
                  pal: pal,
                ),

                const SizedBox(height: 16),

                // 2. 100% Real Hardware Telemetry Cards (Zero Cut-off Text)
                _sectionTitle('REAL-TIME HARDWARE & DEVICE PULSE', pal),
                const SizedBox(height: 8),
                _buildTelemetrySection(
                  telemetry: telemetry,
                  movementState: movementState,
                  pLoc: pLoc,
                  pal: pal,
                ),

                const SizedBox(height: 16),

                // 3. Detailed Movement & Distance Analytics (100% Real GPS Metrics)
                _sectionTitle('MOVEMENT & ACTIVITY ANALYTICS', pal),
                const SizedBox(height: 8),
                _buildMovementAnalyticsSection(
                  world: world,
                  stage: stage,
                  weather: weather,
                  partnerName: partnerName,
                  stayPointCount: stayPoints.length,
                  pal: pal,
                ),

                const SizedBox(height: 16),

                // 4. Interactive Full-Detail Route Breadcrumb Map (Google Dark / Satellite — Zero Watermark)
                _sectionTitle('LIVE ROUTE & ZONE RADAR MAP', pal),
                const SizedBox(height: 8),
                _buildBreadcrumbTrailMap(
                  pLoc: pLoc,
                  journeyPoints: journeyPoints,
                  pinnedPlaces: world.pinnedPlaces,
                  partnerName: partnerName,
                  isDark: themeProv.isDark,
                  pal: pal,
                ),

                const SizedBox(height: 16),

                // 5. Geofence Arrival/Departure Radar + Stay Points Log
                _sectionTitle('ARRIVAL, DEPARTURE & STOPS LOG', pal),
                const SizedBox(height: 8),
                _buildTimelineLog(
                  geoEvents: geoEvents,
                  stayPoints: stayPoints,
                  pal: pal,
                ),

                const SizedBox(height: 16),

                // 6. Burn-After-Reading Secret Whispers
                _sectionTitle('BURN-AFTER-READING WHISPERS', pal),
                const SizedBox(height: 8),
                _buildWhispersSection(
                  stage: stage,
                  userId: user?.id ?? '',
                  spaceId: spaceId,
                  pal: pal,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text, _DossierPalette pal) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
          color: pal.mutedInk,
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
    required WorldProvider world,
    required _DossierPalette pal,
  }) {
    final lastUpdated = telemetry?.updatedAt.isNotEmpty == true
        ? _formatIsoRelative(telemetry!.updatedAt)
        : (pLoc != null ? _formatIsoRelative(pLoc.updatedAt) : 'Awaiting signal');

    final placeLabel = (pLoc?.placeName != null && pLoc!.placeName!.isNotEmpty)
        ? pLoc.placeName!
        : 'Location pending';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [pal.heroStart, pal.card],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: pal.softBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: pal.accent.withOpacity(0.18),
                backgroundImage: partner?.avatarUrl != null
                    ? CachedNetworkImageProvider(partner!.avatarUrl!)
                    : null,
                child: partner?.avatarUrl == null
                    ? Text(
                        partnerName.isNotEmpty ? partnerName[0].toUpperCase() : 'P',
                        style: TextStyle(color: pal.primaryInk, fontWeight: FontWeight.bold, fontSize: 18),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          partnerName,
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.bold,
                            color: pal.primaryInk,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: telemetry?.isDeviceUnlocked == true
                                ? pal.softGreen.withOpacity(0.16)
                                : pal.accent.withOpacity(0.15),
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
                                  ? pal.softGreen
                                  : pal.accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '📍 $placeLabel • Synced $lastUpdated',
                      style: TextStyle(fontSize: 12, color: pal.mutedInk),
                    ),
                    if (world.liveDistanceKm != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Distance from you: ${world.formattedLiveDistance}',
                        style: TextStyle(fontSize: 11.5, color: pal.softBlush, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: pal.subtleFill,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Share my live device telemetry with partner',
                    style: TextStyle(fontSize: 11.5, color: pal.primaryInk),
                  ),
                ),
                Switch.adaptive(
                  value: stage.isTelemetrySharingEnabled,
                  activeColor: pal.accent,
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

  Widget _buildTelemetrySection({
    required DeviceTelemetry? telemetry,
    required String? movementState,
    required dynamic pLoc,
    required _DossierPalette pal,
  }) {
    final screenLabel = telemetry == null
        ? 'Awaiting signal'
        : (telemetry.isDeviceUnlocked
            ? 'Unlocked & Active'
            : (telemetry.isScreenOn ? 'Lockscreen On' : 'Screen Off'));

    final unlockSub = telemetry == null
        ? 'Needs partner app active'
        : 'Last unlocked: ${_formatExactAndRelative(telemetry.lastUnlockedAt)}'
          '${telemetry.unlockCountToday != null ? ' • ${telemetry.unlockCountToday} unlocks today' : ''}';

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
        ? 'By ${telemetry!.nowPlayingArtist!} • Playing in Sanctuary'
        : 'Sanctuary Music Player';

    final moveLabel = movementState ?? 'Awaiting GPS speed';
    final gpsAccSub = pLoc?.accuracy != null
        ? 'GPS accuracy ±${pLoc!.accuracy!.round()} meters'
        : 'Waiting for GPS fix';

    return Column(
      children: [
        _metricTile(
          icon: telemetry?.isDeviceUnlocked == true
              ? Icons.lock_open_rounded
              : Icons.lock_outline_rounded,
          title: 'PHONE STATE & UNLOCK ACTIVITY',
          value: screenLabel,
          subtitle: unlockSub,
          accent: telemetry?.isDeviceUnlocked == true ? pal.softGreen : pal.accent,
          pal: pal,
          fullWidth: true,
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _metricTile(
                icon: telemetry?.networkType == 'wifi'
                    ? Icons.wifi_rounded
                    : Icons.signal_cellular_alt_rounded,
                title: 'NETWORK',
                value: netLabel,
                subtitle: 'Live OS connection',
                accent: pal.softBlue,
                pal: pal,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _metricTile(
                icon: telemetry?.isCharging == true
                    ? Icons.battery_charging_full_rounded
                    : Icons.battery_std_rounded,
                title: 'BATTERY',
                value: batLabel,
                subtitle: telemetry?.isCharging == true ? 'Plugged in' : 'Hardware level',
                accent: telemetry?.isCharging == true ? pal.softGreen : pal.softAmber,
                pal: pal,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _metricTile(
          icon: Icons.directions_run_rounded,
          title: 'MOVEMENT & GPS PRECISION',
          value: moveLabel,
          subtitle: gpsAccSub,
          accent: pal.accent,
          pal: pal,
          fullWidth: true,
        ),
        const SizedBox(height: 10),
        _metricTile(
          icon: Icons.headphones_rounded,
          title: 'NOW LISTENING IN SANCTUARY',
          value: musicLabel,
          subtitle: musicSub,
          accent: pal.softViolet,
          pal: pal,
          fullWidth: true,
        ),
      ],
    );
  }

  Widget _buildMovementAnalyticsSection({
    required WorldProvider world,
    required StageProvider stage,
    required dynamic weather,
    required String partnerName,
    required int stayPointCount,
    required _DossierPalette pal,
  }) {
    final todayKm = world.effectivePartnerJourneyKm;
    final weekKm = world.partnerJourneyKmThisWeek;
    final monthKm = world.partnerJourneyKmThisMonth;
    final locSteps = world.effectivePartnerSteps;
    final telemetrySteps = stage.partnerTelemetry?.stepsToday ?? 0;
    final steps = telemetrySteps > locSteps ? telemetrySteps : locSteps;
    final activeMins = world.effectivePartnerActiveMinutes;
    final origin = world.effectivePartnerDeparturePlace;
    final mood = stage.partnerMood;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: pal.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: pal.softBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _statBox('TODAY DISTANCE', '${todayKm.toStringAsFixed(2)} km', pal.accent, pal),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statBox('STEPS TODAY', '$steps', pal.softGreen, pal),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statBox('ACTIVE TIME', '$activeMins min', pal.softAmber, pal),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _statBox('7-DAY TRAIL', '${weekKm.toStringAsFixed(1)} km', pal.softBlue, pal),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statBox('30-DAY TRAIL', '${monthKm.toStringAsFixed(1)} km', pal.softViolet, pal),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statBox('STOPS TODAY', '$stayPointCount', pal.softBlush, pal),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: pal.softBorder, height: 1),
          const SizedBox(height: 10),
          _detailRow(Icons.flag_outlined, 'Started Today At', origin, pal),
          const SizedBox(height: 6),
          _detailRow(
            Icons.wb_cloudy_outlined,
            'Local Weather ($partnerName)',
            weather != null
                ? '${weather.temperature.round()}°C • ${weather.condition} (Feels like ${weather.apparentTemperature.round()}°C, Wind ${weather.windSpeed.round()} km/h)'
                : 'Awaiting live weather sync',
            pal,
          ),
          const SizedBox(height: 6),
          _detailRow(
            Icons.favorite_border_rounded,
            'Mood Aura & Touches',
            '${mood != null ? '${mood.emoji} ${mood.label}' : 'No mood set'} • ${stage.partnerDailyTouches} touches today (${stage.weeklyTouches} weekly)',
            pal,
          ),
        ],
      ),
    );
  }

  Widget _statBox(String label, String value, Color accent, _DossierPalette pal) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: pal.subtleFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: pal.mutedInk,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value, _DossierPalette pal) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: pal.mutedInk),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 11.5, height: 1.35, color: pal.primaryInk),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: TextStyle(color: pal.mutedInk, fontWeight: FontWeight.w600),
                ),
                TextSpan(text: value),
              ],
            ),
          ),
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
    required _DossierPalette pal,
    bool fullWidth = false,
  }) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: pal.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: pal.softBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
                    color: pal.mutedInk,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  softWrap: true,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: pal.primaryInk,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  softWrap: true,
                  style: TextStyle(fontSize: 10.5, height: 1.3, color: pal.mutedInk),
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
    required bool isDark,
    required _DossierPalette pal,
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
          color: pal.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: pal.softBorder),
        ),
        child: Text(
          'Awaiting partner live GPS coordinates to render today’s route trail & map.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: pal.mutedInk),
        ),
      );
    }

    final center = hasPartnerCoord ? LatLng(pLoc.lat, pLoc.lng) : trailCoords.last;
    final tileUrl = _isSatelliteMap
        ? 'https://mt{s}.google.com/vt/lyrs=y&x={x}&y={y}&z={z}'
        : 'https://mt{s}.google.com/vt/lyrs=m&x={x}&y={y}&z={z}';

    return Container(
      decoration: BoxDecoration(
        color: pal.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: pal.softBorder),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 260,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: center,
                      initialZoom: 15.0,
                      interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
                    ),
                    children: [
                      TileLayer(
                        key: ValueKey('dossier_map_${_isSatelliteMap ? 'sat' : (isDark ? 'dark' : 'light')}'),
                        urlTemplate: tileUrl,
                        subdomains: const ['0', '1', '2', '3'],
                        userAgentPackageName: 'com.pagesofus.app',
                        maxZoom: 20,
                        tileBuilder: (!_isSatelliteMap && isDark)
                            ? (context, tileWidget, tile) => ColorFiltered(
                                  colorFilter: const ColorFilter.matrix(_darkMapMatrix),
                                  child: tileWidget,
                                )
                            : null,
                      ),
                      if (trailCoords.length >= 2)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: trailCoords,
                              color: pal.accent,
                              strokeWidth: 4.5,
                            ),
                          ],
                        ),
                      MarkerLayer(
                        markers: [
                          ...pinnedPlaces.map(
                            (zp) => Marker(
                              point: LatLng(zp.lat, zp.lng),
                              width: 30,
                              height: 30,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: pal.card.withOpacity(0.92),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: pal.softAmber, width: 1.5),
                                ),
                                alignment: Alignment.center,
                                child: Text(zp.icon, style: const TextStyle(fontSize: 13)),
                              ),
                            ),
                          ),
                          if (hasPartnerCoord)
                            Marker(
                              point: LatLng(pLoc.lat, pLoc.lng),
                              width: 38,
                              height: 38,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: pal.accent,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2.2),
                                  boxShadow: [
                                    BoxShadow(color: pal.accent.withOpacity(0.45), blurRadius: 12),
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  partnerName.isNotEmpty ? partnerName[0].toUpperCase() : 'P',
                                  style: const TextStyle(
                                      color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  // Top-right Map Style & Center Controls
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Column(
                      children: [
                        _mapControlChip(
                          icon: _isSatelliteMap ? Icons.map_rounded : Icons.satellite_alt_rounded,
                          label: _isSatelliteMap ? 'Street' : 'Satellite',
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _isSatelliteMap = !_isSatelliteMap);
                          },
                        ),
                        const SizedBox(height: 6),
                        _mapControlChip(
                          icon: Icons.my_location_rounded,
                          label: 'Center',
                          onTap: () {
                            HapticFeedback.lightImpact();
                            _mapController.move(center, 15.5);
                          },
                        ),
                      ],
                    ),
                  ),
                  // Bottom-left Trail Counter Pill
                  Positioned(
                    bottom: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1F161B).withOpacity(0.84),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: pal.accent.withOpacity(0.35)),
                      ),
                      child: Text(
                        '${trailCoords.length} GPS points today • ${pinnedPlaces.length} zones',
                        style: const TextStyle(
                            fontSize: 10.5, color: Color(0xFFF2E4E9), fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Map Explanation & Exact Coordinates Bar
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pLoc?.placeName?.isNotEmpty == true ? '📍 ${pLoc!.placeName}' : '📍 Live Coordinates',
                        style: TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.bold, color: pal.primaryInk),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Lat ${center.latitude.toStringAsFixed(5)}, Lng ${center.longitude.toStringAsFixed(5)} • Rose line shows today’s real route',
                        style: TextStyle(fontSize: 10.5, color: pal.mutedInk),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _openInGoogleMaps(
                    center.latitude,
                    center.longitude,
                    pLoc?.placeName ?? partnerName,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: pal.accent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: pal.accent.withOpacity(0.38)),
                    ),
                    child: Text(
                      'Maps ↗',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: pal.primaryInk),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mapControlChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF1F161B).withOpacity(0.84),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: const Color(0xFFF2E4E9)),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFFF2E4E9)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineLog({
    required List<dynamic> geoEvents,
    required List<dynamic> stayPoints,
    required _DossierPalette pal,
  }) {
    if (geoEvents.isEmpty && stayPoints.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: pal.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: pal.softBorder),
        ),
        child: Text(
          'No zone arrivals/departures or stops recorded yet today. Save key places on the World Map to trigger live arrival & departure alerts.',
          style: TextStyle(fontSize: 12, height: 1.4, color: pal.mutedInk),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: pal.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: pal.softBorder),
      ),
      child: Column(
        children: [
          ...geoEvents.take(10).map((ev) {
            final isArrival = ev.eventType == 'arrived';
            final badgeColor = isArrival ? pal.softGreen : pal.accent;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: badgeColor.withOpacity(0.14),
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
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: pal.primaryInk,
                          ),
                        ),
                        Text(
                          _formatIsoTime(ev.timestamp),
                          style: TextStyle(fontSize: 10.5, color: pal.mutedInk),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: badgeColor.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isArrival ? 'ENTERED' : 'EXITED',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: badgeColor,
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
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: pal.primaryInk,
                          ),
                        ),
                        Text(
                          '${sp.timeRangeText} • ${sp.durationText}',
                          style: TextStyle(fontSize: 10.5, color: pal.mutedInk),
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
    required _DossierPalette pal,
  }) {
    final whispers = stage.secretWhispers;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: pal.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: pal.softBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _whisperCtrl,
                  style: TextStyle(fontSize: 13, color: pal.primaryInk),
                  decoration: InputDecoration(
                    hintText: 'Send a secret whisper (burns after reading)...',
                    hintStyle: TextStyle(fontSize: 12, color: pal.mutedInk),
                    filled: true,
                    fillColor: pal.subtleFill,
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
                    color: pal.accent,
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
                    _openAndBurnWhisper(w, spaceId, userId, pal);
                  }
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: w.isBurned
                        ? pal.subtleFill
                        : pal.accent.withOpacity(0.11),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: w.isBurned ? pal.softBorder : pal.accent.withOpacity(0.32),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        w.isBurned
                            ? Icons.whatshot_outlined
                            : (isMine ? Icons.lock_clock_rounded : Icons.visibility_rounded),
                        size: 17,
                        color: w.isBurned ? pal.mutedInk : pal.accent,
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
                            color: w.isBurned ? pal.mutedInk : pal.primaryInk,
                          ),
                        ),
                      ),
                      Text(
                        _formatIsoTime(w.createdAt),
                        style: TextStyle(fontSize: 10, color: pal.mutedInk),
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
