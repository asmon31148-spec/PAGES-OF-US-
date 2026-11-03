import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/world_provider.dart';
import 'paper_plane_painter.dart';

/// Tab options for the journey stats card.
enum _JourneyPeriod { day, week, month }

/// Animated card showing daily / weekly / monthly travel distance,
/// rendered as a paper airplane flying along a curved bezier arc.
class JourneyStatsCard extends StatefulWidget {
  final bool isDark;

  const JourneyStatsCard({super.key, required this.isDark});

  @override
  State<JourneyStatsCard> createState() => _JourneyStatsCardState();
}

class _JourneyStatsCardState extends State<JourneyStatsCard>
    with SingleTickerProviderStateMixin {
  _JourneyPeriod _period = _JourneyPeriod.day;
  late AnimationController _ctrl;
  late Animation<double> _planeAnim;
  Timer? _loopTimer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _planeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    _ctrl.forward();
    // Subtle idle loop: plane flies once then rests at destination
  }

  void _switchPeriod(_JourneyPeriod p) {
    if (_period == p) return;
    setState(() => _period = p);
    _ctrl.reset();
    _ctrl.forward();
  }

  @override
  void dispose() {
    _loopTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final world = context.watch<WorldProvider>();
    final stats = _getStats(world);

    final bool isDark = widget.isDark;
    final Color surfaceColor =
        isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final Color borderColor =
        isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final Color inkColor = isDark ? AppColors.darkInk : AppColors.lightInk;
    final Color softColor = isDark ? AppColors.darkSoft : AppColors.lightSoft;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppColors.terra.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text('✈️', style: TextStyle(fontSize: 16)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Journey',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: inkColor,
                        ),
                      ),
                      Text(
                        'Distance traveled together & apart',
                        style: TextStyle(fontSize: 10, color: softColor),
                      ),
                    ],
                  ),
                ),
                // Period pill switcher
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkCard
                        : AppColors.lightCard,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _periodPill('Day', _JourneyPeriod.day, isDark),
                      _periodPill('Week', _JourneyPeriod.week, isDark),
                      _periodPill('Month', _JourneyPeriod.month, isDark),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Paper plane arc ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: AnimatedBuilder(
              animation: _planeAnim,
              builder: (context, _) {
                return CustomPaint(
                  painter: PaperPlanePainter(
                    progress: _planeAnim.value,
                    lineColor: AppColors.terra,
                    planeColor: Colors.white,
                  ),
                  child: const SizedBox(height: 80, width: double.infinity),
                );
              },
            ),
          ),

          // ── Distance label below arc ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            child: Center(
              child: Text(
                stats.distanceLabel,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.terra,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),

          // ── Stats row ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
            child: Row(
              children: [
                _statChip('👟', '${stats.estimatedSteps}', 'steps', inkColor, softColor),
                _statChip('⏱️', stats.activeHoursLabel, 'active', inkColor, softColor),
                _statChip('📍', '${stats.areasCount}', 'areas', inkColor, softColor),
                _statChip('📅', stats.periodLabel, _periodName, inkColor, softColor),
              ],
            ),
          ),

          // ── Partner compare strip (if partner data available) ─────────────────
          if (world.partnerJourneyKmToday > 0 ||
              world.partnerJourneyKmThisWeek > 0 ||
              world.partnerJourneyKmThisMonth > 0)
            _buildPartnerStrip(world, isDark, softColor, borderColor),
        ],
      ),
    );
  }

  Widget _periodPill(String label, _JourneyPeriod p, bool isDark) {
    final selected = _period == p;
    return GestureDetector(
      onTap: () => _switchPeriod(p),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? AppColors.terra : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: selected
                ? Colors.white
                : (isDark ? AppColors.darkSoft : AppColors.lightSoft),
          ),
        ),
      ),
    );
  }

  Widget _statChip(
      String emoji, String value, String label, Color inkColor, Color softColor) {
    return Expanded(
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: inkColor,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 9, color: softColor),
          ),
        ],
      ),
    );
  }

  Widget _buildPartnerStrip(
    WorldProvider world,
    bool isDark,
    Color softColor,
    Color borderColor,
  ) {
    final partnerKm = switch (_period) {
      _JourneyPeriod.day => world.partnerJourneyKmToday,
      _JourneyPeriod.week => world.partnerJourneyKmThisWeek,
      _JourneyPeriod.month => world.partnerJourneyKmThisMonth,
    };
    final myKm = switch (_period) {
      _JourneyPeriod.day => world.myJourneyKmToday,
      _JourneyPeriod.week => world.myJourneyKmThisWeek,
      _JourneyPeriod.month => world.myJourneyKmThisMonth,
    };
    final partnerLabel = partnerKm < 1
        ? '${(partnerKm * 1000).round()} m'
        : '${partnerKm.toStringAsFixed(1)} km';
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 14),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkCard.withOpacity(0.6)
            : AppColors.lightCard.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          const Text('💑', style: TextStyle(fontSize: 13)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Partner traveled $partnerLabel this $_periodName',
              style: TextStyle(fontSize: 10, color: softColor),
            ),
          ),
          // Simple progress bar comparison
          Container(
            width: 60,
            height: 5,
            decoration: BoxDecoration(
              color: AppColors.sage.withOpacity(0.15),
              borderRadius: BorderRadius.circular(3),
            ),
            child: FractionallySizedBox(
              widthFactor: myKm > 0
                  ? (partnerKm / (myKm + partnerKm)).clamp(0.05, 0.95)
                  : 0.5,
              alignment: Alignment.centerLeft,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.sage,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  _JourneyDisplayStats _getStats(WorldProvider world) {
    final km = switch (_period) {
      _JourneyPeriod.day => world.myJourneyKmToday,
      _JourneyPeriod.week => world.myJourneyKmThisWeek,
      _JourneyPeriod.month => world.myJourneyKmThisMonth,
    };
    final areas = switch (_period) {
      _JourneyPeriod.day => world.myAreasVisitedToday,
      _JourneyPeriod.week => world.myAreasVisitedThisWeek,
      _JourneyPeriod.month => world.myAreasVisitedThisMonth,
    };

    final distanceLabel = km < 0.05
        ? 'No movement'
        : km < 1.0
            ? '${(km * 1000).round()} m'
            : '${km.toStringAsFixed(2)} km';

    final steps = km < 0.05 ? 0 : (km * 1300).round();
    final stepsLabel = steps > 999 ? '${(steps / 1000).toStringAsFixed(1)}k' : '$steps';

    // Active hours: rough estimate (5 km/h walking pace)
    final activeH = (km / 5.0);
    final activeLabel = activeH < 0.1
        ? '< 5 min'
        : activeH < 1.0
            ? '${(activeH * 60).round()} min'
            : '${activeH.toStringAsFixed(1)}h';

    final periodLabels = {
      _JourneyPeriod.day: 'today',
      _JourneyPeriod.week: 'this wk',
      _JourneyPeriod.month: 'this mo',
    };

    return _JourneyDisplayStats(
      distanceLabel: distanceLabel,
      estimatedSteps: stepsLabel,
      activeHoursLabel: activeLabel,
      areasCount: areas,
      periodLabel: periodLabels[_period]!,
    );
  }

  String get _periodName => switch (_period) {
    _JourneyPeriod.day => 'day',
    _JourneyPeriod.week => 'week',
    _JourneyPeriod.month => 'month',
  };
}

class _JourneyDisplayStats {
  final String distanceLabel;
  final String estimatedSteps;
  final String activeHoursLabel;
  final int areasCount;
  final String periodLabel;

  const _JourneyDisplayStats({
    required this.distanceLabel,
    required this.estimatedSteps,
    required this.activeHoursLabel,
    required this.areasCount,
    required this.periodLabel,
  });
}
