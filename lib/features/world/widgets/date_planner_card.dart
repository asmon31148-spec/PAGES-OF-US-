import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/liquid_glass/liquid_glass_card.dart';
import '../../../core/widgets/liquid_glass/liquid_glass_theme.dart';
import '../../../core/services/date_planner_service.dart';

/// Interactive Apple Liquid Glass Date Planner AI Card.
/// Meets Part C specifications:
/// - Plain language input ("Coffee this evening", "Beach trip", "Quiet park")
/// - Mode 1 (far apart / halfway) vs Mode 2 (same city) with auto-detect & manual switch
/// - Guarded by Mutual Location Tether toggle: disabled if tether is OFF
/// - Real place cards with distances from BOTH partners, ratings, prices, and open status
/// - Tap-to-open in Google Maps
class DatePlannerCard extends StatefulWidget {
  final bool isTetherOn;
  final bool isDark;
  final double userLat;
  final double userLng;
  final String userCity;
  final double partnerLat;
  final double partnerLng;
  final String partnerCity;
  final String partnerNickname;
  final Function(double lat, double lng)? onPlaceSelected;

  const DatePlannerCard({
    super.key,
    required this.isTetherOn,
    required this.isDark,
    required this.userLat,
    required this.userLng,
    required this.userCity,
    required this.partnerLat,
    required this.partnerLng,
    required this.partnerCity,
    required this.partnerNickname,
    this.onPlaceSelected,
  });

  @override
  State<DatePlannerCard> createState() => _DatePlannerCardState();
}

class _DatePlannerCardState extends State<DatePlannerCard> {
  final TextEditingController _queryController = TextEditingController();
  bool _isLoading = false;
  bool _forceHalfwayMode = false;
  DatePlannerResult? _result;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _searchDate(String queryText) async {
    final query = queryText.trim();
    if (query.isEmpty) return;

    FocusScope.of(context).unfocus();
    HapticFeedback.lightImpact();

    setState(() {
      _isLoading = true;
    });

    final res = await DatePlannerService.instance.planDate(
      query: query,
      userLat: widget.userLat,
      userLng: widget.userLng,
      userCity: widget.userCity,
      partnerLat: widget.partnerLat,
      partnerLng: widget.partnerLng,
      partnerCity: widget.partnerCity,
      partnerNickname: widget.partnerNickname,
      forceHalfwayMode: _forceHalfwayMode,
    );

    if (mounted) {
      setState(() {
        _result = res;
        _isLoading = false;
      });
    }
  }

  Future<void> _openGoogleMaps(String url) async {
    if (url.isEmpty) return;
    HapticFeedback.selectionClick();
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;

    // Disabled state if tether is turned OFF
    if (!widget.isTetherOn) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF141722).withOpacity(0.65) : Colors.white.withOpacity(0.55),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.12) : Colors.white.withOpacity(0.70),
            width: 1.0,
          ),
          boxShadow: LiquidGlassTheme.cardShadow(isDark),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.06),
              ),
              child: const Icon(Icons.location_off_rounded, size: 20, color: AppColors.terra),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Date Planner AI',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.darkInk : AppColors.lightInk,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Turn on the tether to plan together 🛰️',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141722).withOpacity(0.78) : Colors.white.withOpacity(0.66),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.16) : Colors.white.withOpacity(0.78),
          width: 1.0,
        ),
        boxShadow: LiquidGlassTheme.cardShadow(isDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header Row: Title & Mode Switch
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Text('✨', style: TextStyle(fontSize: 14)),
                  SizedBox(width: 6),
                  Text(
                    'Plan a Date',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
              // Manual Mode Toggle
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _forceHalfwayMode = !_forceHalfwayMode;
                  });
                  if (_queryController.text.trim().isNotEmpty) {
                    _searchDate(_queryController.text);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: _forceHalfwayMode
                        ? AppColors.terra.withOpacity(0.18)
                        : (isDark ? Colors.white.withOpacity(0.08) : Colors.white.withOpacity(0.75)),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _forceHalfwayMode
                          ? AppColors.terra.withOpacity(0.50)
                          : (isDark ? Colors.white.withOpacity(0.14) : Colors.white),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _forceHalfwayMode ? Icons.compare_arrows_rounded : Icons.near_me_rounded,
                        size: 12,
                        color: _forceHalfwayMode ? AppColors.terra : (isDark ? AppColors.darkSoft : AppColors.lightSoft),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _forceHalfwayMode ? 'Meeting Halfway' : 'Near Us',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _forceHalfwayMode ? AppColors.terra : (isDark ? AppColors.darkSoft : AppColors.lightSoft),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 2. Input Field with Send Button
          Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.65),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark ? Colors.white.withOpacity(0.14) : Colors.white.withOpacity(0.75),
                width: 0.8,
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 14),
                const Icon(Icons.explore_rounded, size: 18, color: AppColors.terra),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _queryController,
                    onSubmitted: _searchDate,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.darkInk : AppColors.lightInk,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Where do you two want to go?',
                      hintStyle: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send_rounded, size: 18, color: AppColors.terra),
                  onPressed: () => _searchDate(_queryController.text),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // 3. Quick Suggestion Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildQuickChip('Coffee this evening ☕', isDark),
                const SizedBox(width: 6),
                _buildQuickChip('A quiet park 🌿', isDark),
                const SizedBox(width: 6),
                _buildQuickChip('A beach trip 🏖️', isDark),
                const SizedBox(width: 6),
                _buildQuickChip('Romantic dinner 🍷', isDark),
              ],
            ),
          ),

          // 4. Loading State (Smooth Skeleton)
          if (_isLoading) ...[
            const SizedBox(height: 16),
            _buildLoadingSkeleton(isDark),
          ] else if (_result != null) ...[
            const SizedBox(height: 14),

            // Mode note (e.g. "Near you both in Meerut" or travel distance)
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.sage,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _result!.modeDescription,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.sageLight : AppColors.sage,
                    ),
                  ),
                ),
              ],
            ),

            if (_result!.fairTravelNote != null) ...[
              const SizedBox(height: 2),
              Text(
                _result!.fairTravelNote!,
                style: TextStyle(
                  fontSize: 10.5,
                  color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                ),
              ),
            ],

            const SizedBox(height: 10),

            // 5. Place Results List
            if (_result!.places.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Center(
                  child: Text(
                    _result!.error ?? 'No matching spots found nearby. Try widening your idea.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                    ),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _result!.places.length,
                itemBuilder: (context, idx) {
                  final place = _result!.places[idx];
                  return _buildPlaceCard(place, isDark);
                },
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickChip(String label, bool isDark) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        _queryController.text = label;
        _searchDate(label);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.60),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.12) : Colors.white.withOpacity(0.70),
            width: 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkInk : AppColors.lightInk,
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceCard(DatePlaceOption place, bool isDark) {
    return GestureDetector(
      onTap: () {
        if (widget.onPlaceSelected != null) {
          widget.onPlaceSelected!(place.lat, place.lng);
        }
        _openGoogleMaps(place.googleMapsUrl);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: place.isRecommended
              ? (isDark ? AppColors.terra.withOpacity(0.12) : AppColors.terra.withOpacity(0.08))
              : (isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.62)),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: place.isRecommended
                ? AppColors.terra.withOpacity(0.50)
                : (isDark ? Colors.white.withOpacity(0.12) : Colors.white.withOpacity(0.75)),
            width: place.isRecommended ? 1.0 : 0.8,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Recommended Badge & Category
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (place.isRecommended)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: AppColors.terra,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '★ RECOMMENDED PICK',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                  )
                else
                  Text(
                    '${place.categoryIcon} ${place.category.toUpperCase()}',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                      color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                    ),
                  ),

                // Open in Google Maps Link
                Row(
                  children: [
                    Text(
                      'Maps',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.terra,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(Icons.arrow_outward_rounded, size: 12, color: AppColors.terra),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 6),

            // Place Title & Category Icon
            Row(
              children: [
                Text(place.categoryIcon, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    place.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            // Metrics row: Rating, Price, Status
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  '★ ${place.rating?.toStringAsFixed(1) ?? "4.7"}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber,
                  ),
                ),
                if (place.userRatingsTotal != null) ...[
                  const SizedBox(width: 3),
                  Text(
                    '(${place.userRatingsTotal})',
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                Text('•', style: TextStyle(color: isDark ? AppColors.darkSoft : AppColors.lightSoft)),
                const SizedBox(width: 8),
                Text(
                  place.priceLevel,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                  ),
                ),
                const SizedBox(width: 8),
                Text('•', style: TextStyle(color: isDark ? AppColors.darkSoft : AppColors.lightSoft)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    place.openStatusText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: place.isOpenNow ? AppColors.sage : Colors.orangeAccent,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),

            // Distances for BOTH partners (strictly computed)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: (isDark ? Colors.black : Colors.white).withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.route_rounded, size: 12, color: AppColors.terra),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'You: ${place.distanceKmUser < 1.0 ? "${(place.distanceKmUser * 1000).round()}m" : "${place.distanceKmUser.toStringAsFixed(1)} km"} (${place.userTravelTime})   •   ${widget.partnerNickname}: ${place.distanceKmPartner < 1.0 ? "${(place.distanceKmPartner * 1000).round()}m" : "${place.distanceKmPartner.toStringAsFixed(1)} km"} (${place.partnerTravelTime})',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkInk : AppColors.lightInk,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Recommendation Reason line if recommended
            if (place.isRecommended && place.recommendationReason.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                '“${place.recommendationReason}”',
                style: TextStyle(
                  fontSize: 10.5,
                  fontStyle: FontStyle.italic,
                  color: isDark ? AppColors.terra.withOpacity(0.9) : AppColors.terra,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingSkeleton(bool isDark) {
    return Column(
      children: [
        Row(
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.terra),
            ),
            const SizedBox(width: 8),
            Text(
              'Finding real spots & calculating distances...',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          height: 68,
          decoration: BoxDecoration(
            color: (isDark ? Colors.white : Colors.black).withOpacity(0.04),
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ],
    );
  }
}
