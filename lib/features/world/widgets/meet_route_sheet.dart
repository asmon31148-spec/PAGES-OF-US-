import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/travel_route_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/stage_provider.dart';

/// Full-featured AI Date & Reunion Planner bottom sheet.
/// Generates personalized, live romantic itineraries via Groq AI (qwen/qwen3.8-27b),
/// live OSRM driving duration, live Open-Meteo weather, and real midpoint spots.
class MeetRouteSheet extends StatefulWidget {
  final bool isDark;
  final double myLat;
  final double myLng;
  final String myCity;
  final double partnerLat;
  final double partnerLng;
  final String partnerCity;
  final String partnerName;
  final double distanceKm;

  const MeetRouteSheet({
    super.key,
    required this.isDark,
    required this.myLat,
    required this.myLng,
    required this.myCity,
    required this.partnerLat,
    required this.partnerLng,
    required this.partnerCity,
    required this.partnerName,
    required this.distanceKm,
  });

  static Future<void> show(
    BuildContext context, {
    required bool isDark,
    required double myLat,
    required double myLng,
    required String myCity,
    required double partnerLat,
    required double partnerLng,
    required String partnerCity,
    required String partnerName,
    required double distanceKm,
  }) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MeetRouteSheet(
        isDark: isDark,
        myLat: myLat,
        myLng: myLng,
        myCity: myCity,
        partnerLat: partnerLat,
        partnerLng: partnerLng,
        partnerCity: partnerCity,
        partnerName: partnerName,
        distanceKm: distanceKm,
      ),
    );
  }

  @override
  State<MeetRouteSheet> createState() => _MeetRouteSheetState();
}

class _MeetRouteSheetState extends State<MeetRouteSheet> {
  TravelRouteResult? _result;
  bool _loading = true;
  bool _regeneratingAi = false;
  String _selectedVibe = 'Cozy & Romantic';

  final List<String> _vibes = [
    'Cozy & Romantic',
    'Adventure & Fun',
    'Sunset & Chill',
    'Foodie Feast',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final auth = context.read<AuthProvider>();
    final myName = auth.user?.nickname ?? 'You';

    try {
      final res = await TravelRouteService.instance.fetchAll(
        myLat: widget.myLat,
        myLng: widget.myLng,
        myCity: widget.myCity,
        partnerLat: widget.partnerLat,
        partnerLng: widget.partnerLng,
        partnerCity: widget.partnerCity,
        myName: myName,
        partnerName: widget.partnerName,
        distanceKm: widget.distanceKm,
        vibe: _selectedVibe,
      );
      if (mounted) {
        setState(() {
          _result = res;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _changeVibe(String vibe) async {
    if (_selectedVibe == vibe || _result == null) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selectedVibe = vibe;
      _regeneratingAi = true;
    });

    final auth = context.read<AuthProvider>();
    final myName = auth.user?.nickname ?? 'You';

    try {
      final newItinerary = await TravelRouteService.instance.generateAiItinerary(
        myName: myName,
        partnerName: widget.partnerName,
        myCity: widget.myCity,
        partnerCity: widget.partnerCity,
        distanceKm: widget.distanceKm,
        midpointCity: _result!.midCity,
        vibe: vibe,
      );

      if (mounted) {
        setState(() {
          _result = TravelRouteResult(
            drive: _result!.drive,
            itinerary: newItinerary,
            weather: _result!.weather,
            nearbySpots: _result!.nearbySpots,
            transitEstimates: _result!.transitEstimates,
            midLat: _result!.midLat,
            midLng: _result!.midLng,
            midCity: _result!.midCity,
            distanceKm: _result!.distanceKm,
          );
          _regeneratingAi = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _regeneratingAi = false);
    }
  }

  String _formatFullPlanText(ReunionItinerary itinerary) {
    final sb = StringBuffer();
    sb.writeln('💖 ${itinerary.title}');
    sb.writeln('📍 Meeting Location: ${itinerary.meetupCity}');
    sb.writeln('✨ Vibe: ${itinerary.romanticVibe}');
    sb.writeln('📏 Distance Apart: ${widget.distanceKm.toStringAsFixed(1)} km');
    sb.writeln('');
    sb.writeln('── ITINERARY ──');
    for (final stop in itinerary.stops) {
      sb.writeln('${stop.icon} ${stop.time}: ${stop.title}');
      sb.writeln('   Location: ${stop.location}');
      sb.writeln('   ${stop.description}');
      sb.writeln('');
    }
    sb.writeln('🎒 Packing Tip: ${itinerary.packingTip}');
    sb.writeln('🎁 Sweet Surprise: ${itinerary.surpriseIdea}');
    return sb.toString();
  }

  Future<void> _saveToCorkboard(ReunionItinerary itinerary) async {
    HapticFeedback.mediumImpact();
    final auth = context.read<AuthProvider>();
    final stage = context.read<StageProvider>();
    final user = auth.user;
    final spaceId = auth.space?.id ?? user?.spaceId ?? '';

    if (user != null && spaceId.isNotEmpty) {
      final summaryText = '🗺️ REUNION PLAN: ${itinerary.title}\n📍 In ${itinerary.meetupCity}\n' +
          itinerary.stops.map((s) => '${s.icon} ${s.title} (${s.time})').join('\n') +
          '\n🎁 Surprise: ${itinerary.surpriseIdea}';

      await stage.savePinnedNote(spaceId, user.id, user.nickname, summaryText);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Pinned to your couple corkboard! 📌 Both can see it on Stage.'),
            backgroundColor: AppColors.sage,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _copyPlan(ReunionItinerary itinerary) {
    HapticFeedback.lightImpact();
    final text = _formatFullPlanText(itinerary);
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Itinerary copied to clipboard! 📋 Share with your partner.'),
        backgroundColor: AppColors.terra,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final bgColor = isDark ? const Color(0xFF13151D) : Colors.white;
    final cardColor = isDark ? const Color(0xFF1C1F2B) : const Color(0xFFF8F9FA);
    final borderColor = isDark ? const Color(0xFF282C3D) : const Color(0xFFE2E8F0);
    final inkColor = isDark ? AppColors.darkInk : AppColors.lightInk;
    final softColor = isDark ? AppColors.darkSoft : AppColors.lightSoft;

    final distLabel = widget.distanceKm > 1000
        ? '${(widget.distanceKm / 1000).toStringAsFixed(1)}k km'
        : '${widget.distanceKm.toStringAsFixed(0)} km';

    return DraggableScrollableSheet(
      initialChildSize: 0.90,
      minChildSize: 0.55,
      maxChildSize: 0.96,
      builder: (context, scrollCtrl) {
        return Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              // ── Drag Handle ────────────────────────────────────────────────
              const SizedBox(height: 12),
              Container(
                width: 44,
                height: 4.5,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 14),

              // ── Top Header ─────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: AppColors.terra.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text('✨', style: TextStyle(fontSize: 20)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Reunion & Date Planner',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: inkColor,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Text(
                            'AI-tailored romantic itinerary for you & ${widget.partnerName}',
                            style: TextStyle(fontSize: 11, color: softColor),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.close_rounded, size: 18, color: softColor),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // ── Vibe Selector Chips ───────────────────────────────────────
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _vibes.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final vibe = _vibes[index];
                    final isSelected = _selectedVibe == vibe;
                    return GestureDetector(
                      onTap: () => _changeVibe(vibe),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.terra
                              : (isDark ? const Color(0xFF1E2230) : const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.terra
                                : (isDark ? const Color(0xFF2E344A) : const Color(0xFFE2E8F0)),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            vibe,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                              color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),

              // ── Content ───────────────────────────────────────────────────
              Expanded(
                child: _loading
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(color: AppColors.terra, strokeWidth: 2.5),
                            const SizedBox(height: 16),
                            Text(
                              'Designing your romantic reunion...',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: inkColor),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Connecting AI planner, live routes & weather',
                              style: TextStyle(fontSize: 11, color: softColor),
                            ),
                          ],
                        ),
                      )
                    : _buildLoadedBody(scrollCtrl, cardColor, borderColor, inkColor, softColor, distLabel),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoadedBody(
    ScrollController scrollCtrl,
    Color cardColor,
    Color borderColor,
    Color inkColor,
    Color softColor,
    String distLabel,
  ) {
    final res = _result!;
    final itinerary = res.itinerary;
    final weather = res.weather;
    final drive = res.drive;
    final spots = res.nearbySpots;

    return Stack(
      children: [
        ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
          children: [
            // ── Halfway Meeting Summary Card ──────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: AppColors.terra.withValues(alpha: 0.14),
                border: Border.all(color: AppColors.terra.withValues(alpha: 0.35), width: 1.0),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.terra.withOpacity(0.25),
                    ),
                    child: const Center(child: Text('📍', style: TextStyle(fontSize: 22))),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Destination: ${res.midCity}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: inkColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$distLabel apart · Halfway rendezvous spot',
                          style: TextStyle(fontSize: 11, color: softColor),
                        ),
                      ],
                    ),
                  ),
                  if (weather != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Text(weather.icon, style: const TextStyle(fontSize: 16)),
                          const SizedBox(height: 2),
                          Text(
                            '${weather.temperature.round()}°C',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: inkColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // ── AI Itinerary Title & Quick Action Buttons ──────────────────
            if (itinerary != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('✨', style: TextStyle(fontSize: 13)),
                            const SizedBox(width: 4),
                            Text(
                              itinerary.title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: inkColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                        Text(
                          '${itinerary.romanticVibe} · 1-Day Schedule',
                          style: TextStyle(fontSize: 11, color: softColor),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Copy Plan',
                        icon: Icon(Icons.copy_rounded, size: 20, color: softColor),
                        onPressed: () => _copyPlan(itinerary),
                      ),
                      IconButton(
                        tooltip: 'Pin to Corkboard',
                        icon: const Icon(Icons.push_pin_rounded, size: 20, color: AppColors.terra),
                        onPressed: () => _saveToCorkboard(itinerary),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // ── Itinerary Timeline Cards ──────────────────────────────────
              ...itinerary.stops.asMap().entries.map((entry) {
                final idx = entry.key;
                final stop = entry.value;
                final isLast = idx == itinerary.stops.length - 1;

                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Timeline indicator
                      Column(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.terra.withOpacity(0.18),
                              border: Border.all(color: AppColors.terra, width: 1.5),
                            ),
                            child: Center(
                              child: Text(stop.icon, style: const TextStyle(fontSize: 14)),
                            ),
                          ),
                          if (!isLast)
                            Expanded(
                              child: Container(
                                width: 2,
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                color: AppColors.terra.withOpacity(0.3),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 14),

                      // Stop detail card
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: borderColor),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      stop.title,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.bold,
                                        color: inkColor,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.terra.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      stop.time,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.terra,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (stop.location.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.location_on_rounded, size: 12, color: AppColors.terra),
                                    const SizedBox(width: 3),
                                    Expanded(
                                      child: Text(
                                        stop.location,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: inkColor.withOpacity(0.85),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 6),
                              Text(
                                stop.description,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: softColor,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 10),

              // ── Sweet Surprise & Packing Advice ───────────────────────────
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.rose.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.rose.withOpacity(0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('🎁', style: TextStyle(fontSize: 22)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cute Surprise Idea for ${widget.partnerName}',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: inkColor,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            itinerary.surpriseIdea,
                            style: TextStyle(fontSize: 11, color: softColor, height: 1.3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('🎒', style: TextStyle(fontSize: 22)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'What to Pack & Wear',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: inkColor,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            itinerary.packingTip,
                            style: TextStyle(fontSize: 11, color: softColor, height: 1.3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // ── Real Live Travel Breakdown ──────────────────────────────────
            Row(
              children: [
                const Icon(Icons.directions_car_rounded, size: 16, color: AppColors.terra),
                const SizedBox(width: 6),
                Text(
                  'Live Travel & Route Time',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: inkColor),
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (drive != null)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.terra.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.drive_eta_rounded, color: AppColors.terra, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'By Road (Car / Cab)',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: inkColor),
                          ),
                          Text(
                            '${drive.durationString} · ${drive.distanceKm.toStringAsFixed(1)} km total',
                            style: TextStyle(fontSize: 11, color: softColor),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: drive.googleMapsUrl));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Google Maps navigation link copied! 🚗'),
                            backgroundColor: AppColors.sage,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.terra,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Maps',
                              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(width: 2),
                            Icon(Icons.open_in_new_rounded, size: 12, color: Colors.white),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 10),

            // Transit Estimates
            ...res.transitEstimates.map((transit) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Text(transit.icon, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                transit.mode,
                                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: inkColor),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '· ${transit.duration}',
                                style: TextStyle(fontSize: 11, color: softColor),
                              ),
                            ],
                          ),
                          Text(
                            '${transit.priceEstimate} — ${transit.tip}',
                            style: TextStyle(fontSize: 10.5, color: softColor),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 16),

            // ── Real Cafes & Spots Around Midpoint ─────────────────────────
            if (spots.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.explore_rounded, size: 16, color: AppColors.terra),
                  const SizedBox(width: 6),
                  Text(
                    'Real Spots Near ${res.midCity}',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: inkColor),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 100,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: spots.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, idx) {
                    final sp = spots[idx];
                    return Container(
                      width: 160,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(sp.icon, style: const TextStyle(fontSize: 18)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  sp.category,
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.terra,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Text(
                            sp.name,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: inkColor),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '~${sp.distanceKm.toStringAsFixed(1)} km from center',
                            style: TextStyle(fontSize: 10, color: softColor),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
            ],

            // ── Bottom Action Buttons ──────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _regeneratingAi ? null : () => _changeVibe(_selectedVibe),
                    icon: _regeneratingAi
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.auto_awesome, size: 16, color: Colors.white),
                    label: Text(
                      _regeneratingAi ? 'Creating...' : 'Regenerate Plan',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.terra,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                if (itinerary != null) ...[
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: () => _saveToCorkboard(itinerary),
                    icon: const Icon(Icons.push_pin_rounded, size: 16, color: AppColors.terra),
                    label: const Text(
                      'Pin to Stage',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.terra),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cardColor,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      side: const BorderSide(color: AppColors.terra),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),

        // Floating subtle overlay when regenerating
        if (_regeneratingAi)
          Positioned(
            top: 10,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.terra,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'AI is crafting a fresh romantic plan...',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
