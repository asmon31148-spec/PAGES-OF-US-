import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/telemetry_math.dart';
import '../../../providers/stage_provider.dart';
import '../../../providers/world_provider.dart';
import '../../../data/models/stay_point_model.dart';
import 'paper_plane_painter.dart';

/// Animated card showing live travel journey & activity status:
/// - Prominently displays the Partner's footsteps, travel distance, and active time on your phone
/// - Displays an animated paper plane traveling along the route from departure to current spot
/// - Allows switching between Partner and You with a clean toggle pill
class JourneyStatsCard extends StatefulWidget {
  final bool isDark;
  final String? partnerNickname;
  final String? partnerAvatarUrl;
  final String? userNickname;
  final String? userAvatarUrl;

  const JourneyStatsCard({
    super.key,
    required this.isDark,
    this.partnerNickname,
    this.partnerAvatarUrl,
    this.userNickname,
    this.userAvatarUrl,
  });

  @override
  State<JourneyStatsCard> createState() => _JourneyStatsCardState();
}

class _JourneyStatsCardState extends State<JourneyStatsCard>
    with SingleTickerProviderStateMixin {
  bool _showPartner = true;
  bool _showTimeline = true;
  late AnimationController _ctrl;
  late Animation<double> _planeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _planeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutCubic);
    _ctrl.repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _cleanPlace(String? raw) {
    if (raw == null || raw.trim().isEmpty || raw.trim().toLowerCase() == 'nearby') {
      return 'Starting Point';
    }
    final parts = raw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return 'Starting Point';
    if (parts.length >= 2 && parts[0].toLowerCase() == parts[1].toLowerCase()) {
      return parts[0];
    }
    // Return primary neighborhood or city (max 20 chars)
    final text = parts[0];
    if (text.length > 20) {
      return '${text.substring(0, 18)}...';
    }
    return text;
  }

  @override
  Widget build(BuildContext context) {
    final world = context.watch<WorldProvider>();
    final stage = context.watch<StageProvider>();
    final partnerLoc = world.partnerLocation;
    final myLoc = world.myLocation;

    final hasPartner = widget.partnerNickname != null &&
        widget.partnerNickname!.isNotEmpty &&
        widget.partnerNickname!.toLowerCase() != 'partner';

    final effectiveShowPartner = hasPartner ? _showPartner : false;
    final partnerName = widget.partnerNickname ?? 'Partner';
    final userName = widget.userNickname ?? 'You';

    final currentTargetName = effectiveShowPartner ? partnerName : userName;
    final currentAvatarUrl = effectiveShowPartner ? widget.partnerAvatarUrl : widget.userAvatarUrl;

    // Unified distance, real steps & walking time shared with Eyes On You
    final ResolvedActivityMetrics resolved = effectiveShowPartner
        ? world.resolvePartnerMetrics(
            telemetry: stage.partnerTelemetry,
            savedSummaries: stage.partnerDailySummaries,
          )
        : TelemetryMath.resolvePartnerActivity(
            telemetrySteps: stage.myTelemetry?.stepsToday,
            locationSteps: world.myStepsTodayOrNull,
            gpsJourneyKm: world.myJourneyKmToday,
            telemetryDistanceKm: stage.myTelemetry?.distanceKmToday,
            telemetryWalkingSeconds: stage.myTelemetry?.walkingTimeSecondsToday,
            locationActiveMinutes: world.myActiveMinutesToday,
            telemetryAppSeconds: stage.myTelemetry?.appTimeSecondsToday,
            telemetryActivity: stage.myTelemetry?.movementActivity,
            speedMps: myLoc?.speedMps,
            savedSummaries: stage.myDailySummaries,
            todayDateKey: stage.myTelemetry?.dateKey ??
                TelemetryMath.localDateKeyFor(DateTime.now()),
          );

    final double km = resolved.distanceKmToday;
    final int? steps = resolved.stepsToday;
    final int activeMinutes = resolved.walkingMinutesToday;

    // A person is actively traveling if currently moving
    final bool isMovingNow = effectiveShowPartner ? world.isPartnerMoving : world.isMyMoving;
    final bool isStationary = !isMovingNow;

    // Origin and destination place names
    final String rawOrigin = effectiveShowPartner
        ? world.effectivePartnerDeparturePlace
        : world.myDeparturePlace;

    final String rawDest = effectiveShowPartner
        ? (partnerLoc?.placeName ?? 'Locating...')
        : (myLoc?.placeName ?? 'Locating...');

    final String originLabel = _cleanPlace(rawOrigin);
    final String destLabel = _cleanPlace(rawDest);

    // Stay points / visited stops for current selected user for TODAY
    final List<StayPoint> stayPoints = effectiveShowPartner
        ? world.partnerStayPointsToday
        : world.myStayPointsToday;

    final bool isDark = widget.isDark;
    final Color surfaceColor =
        isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final Color borderColor =
        isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final Color inkColor = isDark ? AppColors.darkInk : AppColors.lightInk;
    final Color softColor = isDark ? AppColors.darkSoft : AppColors.lightSoft;

    final distanceLabel = km < 0.01
        ? '0 m'
        : km < 1.0
            ? '${(km * 1000).round()} m'
            : '${km.toStringAsFixed(2)} km';

    final stepsLabel = steps == null
        ? 'Unknown'
        : steps <= 0
            ? '0'
            : steps > 999
                ? '${(steps / 1000).toStringAsFixed(1)}k'
                : '$steps';

    final activeLabel = activeMinutes < 1
        ? 'Resting'
        : activeMinutes < 60
            ? '$activeMinutes min'
            : '${(activeMinutes / 60).toStringAsFixed(1)}h';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: Partner Avatar, Name & Toggle Pill ────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Row(
              children: [
                // Avatar / Emoji
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: effectiveShowPartner ? AppColors.terra : AppColors.sage,
                      width: 1.5,
                    ),
                  ),
                  child: ClipOval(
                    child: currentAvatarUrl != null && currentAvatarUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: currentAvatarUrl,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => _avatarFallback(currentTargetName, effectiveShowPartner),
                          )
                        : _avatarFallback(currentTargetName, effectiveShowPartner),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$currentTargetName\'s Journey & Activity',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: inkColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        effectiveShowPartner
                            ? 'Live activity synced from partner'
                            : 'Your live movement & footsteps today',
                        style: TextStyle(fontSize: 10, color: softColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Toggle pill between Partner and User
                if (hasPartner)
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : AppColors.lightCard,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _togglePill(
                          label: partnerName,
                          isSelected: _showPartner,
                          isDark: isDark,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _showPartner = true);
                          },
                        ),
                        _togglePill(
                          label: 'You',
                          isSelected: !_showPartner,
                          isDark: isDark,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _showPartner = false);
                          },
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // ── Departure & Destination Route Info ───────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: isStationary
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.sage,
                            ),
                          ),
                          const SizedBox(width: 6),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 180),
                            child: Text(
                              'Resting at $destLabel',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: inkColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.sage.withOpacity(0.16),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          '🏡 Stationary · Indoors',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: AppColors.sage,
                          ),
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Departure / Origin
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.terra.withOpacity(0.6),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                originLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: inkColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Live status badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isMovingNow
                              ? AppColors.terra.withOpacity(0.16)
                              : AppColors.sage.withOpacity(0.16),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isMovingNow ? '✈️ Moving' : '🏡 Resting',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: isMovingNow ? AppColors.terra : AppColors.sage,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '· $distanceLabel',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: isMovingNow ? AppColors.terra : AppColors.sage,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Destination
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Flexible(
                              child: Text(
                                destLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: inkColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 5),
                            const Icon(
                              Icons.location_on_rounded,
                              size: 13,
                              color: AppColors.terra,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),

          // ── Animated Paper Plane Bezier Arc ──────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: AnimatedBuilder(
              animation: _planeAnim,
              builder: (context, _) {
                return CustomPaint(
                  painter: PaperPlanePainter(
                    progress: _planeAnim.value,
                    lineColor: AppColors.terra,
                    planeColor: Colors.white,
                    isStationary: isStationary,
                  ),
                  child: const SizedBox(height: 72, width: double.infinity),
                );
              },
            ),
          ),

          // ── 3 Core Stats Row: Footsteps, Distance, Active Time & Status ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 2, 14, 12),
            child: Row(
              children: [
                _statChip('👟', stepsLabel, 'footsteps', inkColor, softColor),
                _statChip('📏', distanceLabel, 'traveled', inkColor, softColor),
                _statChip('⏱️', activeLabel, 'active', inkColor, softColor),
                _statChip(
                  isMovingNow ? '📍' : '🏡',
                  isMovingNow ? 'On Move' : 'Resting',
                  'status',
                  inkColor,
                  softColor,
                ),
              ],
            ),
          ),

          // ── Today's Places Visited (Stops Timeline) ────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (isDark ? Colors.black : Colors.white).withOpacity(0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.timeline_rounded, size: 14, color: AppColors.terra),
                          const SizedBox(width: 6),
                          Text(
                            'Places Visited Today (${stayPoints.isNotEmpty ? stayPoints.length : 1})',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.2,
                              color: inkColor,
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() => _showTimeline = !_showTimeline);
                        },
                        child: Text(
                          _showTimeline ? 'Hide' : 'Show',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: AppColors.terra,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_showTimeline) ...[
                    const SizedBox(height: 10),
                    if (stayPoints.isEmpty)
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.sage.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Text('🏡', style: TextStyle(fontSize: 13)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  destLabel,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: inkColor,
                                  ),
                                ),
                                Text(
                                  'Primary stay point today · Resting indoors',
                                  style: TextStyle(fontSize: 10, color: softColor),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    else
                      Column(
                        children: List.generate(stayPoints.length, (index) {
                          final stop = stayPoints[index];
                          final isLast = index == stayPoints.length - 1;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // If user traveled (>= 100m) to reach this stop, show trip leg:
                                if (stop.hasTripLeg) ...[
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Column(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: AppColors.terra.withOpacity(0.12),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.directions_walk_rounded,
                                              size: 11,
                                              color: AppColors.terra,
                                            ),
                                          ),
                                          Container(
                                            width: 1.5,
                                            height: 14,
                                            color: AppColors.terra.withOpacity(0.35),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.only(top: 2),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Traveled ${stop.tripDistanceText} (${stop.tripTimeRangeText})',
                                                style: const TextStyle(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.terra,
                                                ),
                                              ),
                                              Text(
                                                stop.fromPlaceName!.toLowerCase() == stop.placeName.toLowerCase()
                                                    ? 'Within ${stop.placeName} (Local transit)'
                                                    : '${stop.fromPlaceName} → ${stop.placeName}',
                                                style: TextStyle(
                                                  fontSize: 9.5,
                                                  fontStyle: FontStyle.italic,
                                                  color: softColor,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 6),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],

                                // The Stop / Destination Spot:
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Column(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(5),
                                          decoration: BoxDecoration(
                                            color: (stop.isCurrent ? AppColors.terra : AppColors.sage)
                                                .withOpacity(0.18),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Text(stop.icon, style: const TextStyle(fontSize: 11)),
                                        ),
                                        if (!isLast)
                                          Container(
                                            width: 1.5,
                                            height: 16,
                                            color: isDark ? Colors.white12 : Colors.black12,
                                          ),
                                      ],
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  stop.placeName,
                                                  style: TextStyle(
                                                    fontSize: 11.5,
                                                    fontWeight: FontWeight.bold,
                                                    color: inkColor,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (stop.isCurrent)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.terra.withOpacity(0.18),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: const Text(
                                                    'Current Spot',
                                                    style: TextStyle(
                                                      fontSize: 8.5,
                                                      fontWeight: FontWeight.bold,
                                                      color: AppColors.terra,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          Text(
                                            '${stop.timeRangeText}  •  ${stop.durationText}',
                                            style: TextStyle(fontSize: 9.5, color: softColor),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarFallback(String name, bool isPartner) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'P';
    return Container(
      color: isPartner
          ? AppColors.terra.withOpacity(0.2)
          : AppColors.sage.withOpacity(0.2),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isPartner ? AppColors.terra : AppColors.sage,
          ),
        ),
      ),
    );
  }

  Widget _togglePill({
    required String label,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.terra : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: isSelected
                ? Colors.white
                : (isDark ? AppColors.darkSoft : AppColors.lightSoft),
          ),
        ),
      ),
    );
  }

  Widget _statChip(
    String emoji,
    String value,
    String label,
    Color inkColor,
    Color softColor,
  ) {
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: TextStyle(fontSize: 9.5, color: softColor),
          ),
        ],
      ),
    );
  }
}
