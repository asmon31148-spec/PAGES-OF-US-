import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/liquid_glass/liquid_glass_card.dart';
import '../../../core/widgets/liquid_glass/liquid_glass_theme.dart';
import '../../../core/services/date_planner_service.dart';
import '../../../providers/world_provider.dart';
import '../../../providers/auth_provider.dart';

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
  final Function(double lat, double lng, [String? name, String? category])? onPlaceSelected;

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

  Future<void> _openGoogleMaps(String url, {double? lat, double? lng, String? name}) async {
    HapticFeedback.selectionClick();

    // 1. First priority: Direct native Google Maps app intent via geo: URI
    if (lat != null && lng != null && lat != 0.0 && lng != 0.0) {
      final queryParam = name != null && name.isNotEmpty ? Uri.encodeComponent('$name ($lat,$lng)') : '$lat,$lng';
      final geoUri = Uri.parse('geo:$lat,$lng?q=$queryParam');
      try {
        final launched = await launchUrl(geoUri, mode: LaunchMode.externalApplication);
        if (launched) return;
      } catch (_) {}
    }

    // 2. Second priority: Standard Google Maps navigation URL
    if (url.isNotEmpty) {
      final uri = Uri.parse(url);
      try {
        if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
      } catch (_) {
        try {
          if (await launchUrl(uri, mode: LaunchMode.platformDefault)) return;
        } catch (_) {}
      }
    }

    // 3. Fallback direct web search
    if (lat != null && lng != null) {
      final fallbackUri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
      try {
        await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
      } catch (_) {
        try {
          await launchUrl(fallbackUri, mode: LaunchMode.platformDefault);
        } catch (_) {}
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;

    // Disabled state only if tether is OFF AND user has no live coordinates yet
    if (!widget.isTetherOn && widget.userLat == 0.0) {
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
                _buildQuickChip('Cafe around me ☕', isDark),
                const SizedBox(width: 6),
                _buildQuickChip('Cozy library 📚', isDark),
                const SizedBox(width: 6),
                _buildQuickChip('Quiet park near her 🌿', isDark),
                const SizedBox(width: 6),
                _buildQuickChip('Halfway date 📍', isDark),
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
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.04) : Colors.white.withOpacity(0.60),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.white.withOpacity(0.10) : Colors.white.withOpacity(0.65),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(Icons.location_searching_rounded, size: 28, color: isDark ? AppColors.darkSoft : AppColors.lightSoft),
                    const SizedBox(height: 8),
                    Text(
                      _result!.error ?? 'No registered spots found nearby in local registry.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () {
                        final searchUrl = _result!.googleMapsSearchUrl ??
                            'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent('${_queryController.text} near me')}';
                        _openGoogleMaps(searchUrl);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.terra,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.map_rounded, size: 14, color: Colors.white),
                            SizedBox(width: 6),
                            Text(
                              'Search Live on Google Maps ↗',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _result!.places.length,
                itemBuilder: (context, idx) {
                  final place = _result!.places[idx];
                  return _buildPlaceCard(place, isDark);
                },
              ),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () {
                  final searchUrl = _result!.googleMapsSearchUrl ??
                      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent('${_queryController.text} near me')}';
                  _openGoogleMaps(searchUrl);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.explore_outlined, size: 13, color: isDark ? AppColors.darkSoft : AppColors.lightSoft),
                        const SizedBox(width: 4),
                        Text(
                          'Search more live spots on Google Maps ↗',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
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
    final userDistStr = place.distanceKmUser < 1.0
        ? '${(place.distanceKmUser * 1000).round()}m'
        : '${place.distanceKmUser.toStringAsFixed(1)} km';
    final partnerDistStr = place.distanceKmPartner < 1.0
        ? '${(place.distanceKmPartner * 1000).round()}m'
        : '${place.distanceKmPartner.toStringAsFixed(1)} km';

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _showPlaceDetailsModal(context, place, isDark);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(13),
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
            // Top Row: Recommended Badge & Category + Live Map Action
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
                else if (place.isGoogleVerified)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E8E3E).withOpacity(0.18),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF1E8E3E).withOpacity(0.50)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_rounded, size: 10, color: Color(0xFF34A853)),
                        SizedBox(width: 3),
                        Text(
                          'GOOGLE MAPS',
                          style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF34A853),
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
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

                // Action Pills: Save to Bucket List + View on Map
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Builder(
                      builder: (ctx) {
                        final worldProv = ctx.watch<WorldProvider>();
                        final authProv = ctx.read<AuthProvider>();
                        final saved = worldProv.isInBucketList(place.name, place.lat, place.lng);
                        return GestureDetector(
                          onTap: () async {
                            HapticFeedback.lightImpact();
                            final spaceId = authProv.space?.id ?? '';
                            final user = authProv.user;
                            if (spaceId.isEmpty || user == null) return;
                            if (!saved) {
                              await worldProv.addToBucketList(
                                spaceId: spaceId,
                                name: place.name,
                                category: place.category,
                                icon: place.categoryIcon,
                                address: place.address,
                                lat: place.lat,
                                lng: place.lng,
                                googleMapsUrl: place.googleMapsUrl,
                                addedById: user.id,
                                addedByNickname: user.nickname,
                              );
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Saved "${place.name}" to Date Bucket List ⭐'),
                                    backgroundColor: AppColors.sage,
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: saved
                                  ? AppColors.sage.withOpacity(0.18)
                                  : Colors.amber.withOpacity(0.14),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: saved
                                    ? AppColors.sage.withOpacity(0.5)
                                    : Colors.amber.withOpacity(0.4),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  saved ? Icons.check_rounded : Icons.star_rounded,
                                  size: 11,
                                  color: saved ? AppColors.sageLight : Colors.amber,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  saved ? 'Saved' : 'Bucket',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: saved ? AppColors.sageLight : Colors.amber.shade400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        if (widget.onPlaceSelected != null) {
                          widget.onPlaceSelected!(place.lat, place.lng, place.name, place.category);
                        } else {
                          _openGoogleMaps(
                            place.googleMapsUrl,
                            lat: place.lat,
                            lng: place.lng,
                            name: place.name,
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.terra.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Map',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.terra,
                              ),
                            ),
                            SizedBox(width: 3),
                            Icon(Icons.map_rounded, size: 11, color: AppColors.terra),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 7),

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
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            // Metrics row: Rating, Price, Status
            const SizedBox(height: 5),
            Row(
              children: [
                if (place.rating != null) ...[
                  Text(
                    '★ ${place.rating!.toStringAsFixed(1)}',
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
                ] else ...[
                  Text(
                    place.isGoogleVerified ? 'Google Verified' : 'Mapped Location',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: place.isGoogleVerified ? const Color(0xFF34A853) : (isDark ? AppColors.darkSoft : AppColors.lightSoft),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('•', style: TextStyle(color: isDark ? AppColors.darkSoft : AppColors.lightSoft)),
                  const SizedBox(width: 8),
                ],
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

            const SizedBox(height: 8),

            // Distances for BOTH partners (two clean rows so text is NEVER cut off)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: (isDark ? Colors.black : Colors.white).withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person_pin_circle_rounded, size: 13, color: AppColors.sage),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'You: $userDistStr (${place.userTravelTime})',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.darkInk : AppColors.lightInk,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.favorite_rounded, size: 12, color: AppColors.terra),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${widget.partnerNickname}: $partnerDistStr (${place.partnerTravelTime})',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.darkInk : AppColors.lightInk,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Recommendation Reason line if recommended
            if (place.isRecommended && place.recommendationReason.isNotEmpty) ...[
              const SizedBox(height: 7),
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

  void _showPlaceDetailsModal(BuildContext context, DatePlaceOption place, bool isDark) {
    final userDistStr = place.distanceKmUser < 1.0
        ? '${(place.distanceKmUser * 1000).round()}m'
        : '${place.distanceKmUser.toStringAsFixed(1)} km';
    final partnerDistStr = place.distanceKmPartner < 1.0
        ? '${(place.distanceKmPartner * 1000).round()}m'
        : '${place.distanceKmPartner.toStringAsFixed(1)} km';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF13151B).withOpacity(0.94) : Colors.white.withOpacity(0.95),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border(
                  top: BorderSide(
                    color: isDark ? Colors.white.withOpacity(0.25) : Colors.black.withOpacity(0.1),
                    width: 1.2,
                  ),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Header with category icon, name, and close
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.terra.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(place.categoryIcon, style: const TextStyle(fontSize: 24)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              place.name,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppColors.darkInk : AppColors.lightInk,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${place.category.toUpperCase()} • ${place.address.isNotEmpty ? place.address : "Exact Spot"}',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: Icon(Icons.close_rounded, color: isDark ? AppColors.darkSoft : AppColors.lightSoft),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Metrics Pill Row
                  Row(
                    children: [
                      if (place.rating != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.star_rounded, size: 15, color: Colors.amber),
                              const SizedBox(width: 4),
                              Text(
                                '${place.rating!.toStringAsFixed(1)}${place.userRatingsTotal != null ? " (${place.userRatingsTotal})" : ""}',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: (place.isGoogleVerified ? const Color(0xFF1E8E3E) : AppColors.sage).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(place.isGoogleVerified ? Icons.check_circle_rounded : Icons.location_on_rounded,
                                  size: 14, color: place.isGoogleVerified ? const Color(0xFF34A853) : AppColors.sage),
                              const SizedBox(width: 4),
                              Text(
                                place.isGoogleVerified ? 'Google Maps Verified' : 'Mapped Location',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: place.isGoogleVerified ? const Color(0xFF34A853) : AppColors.sage,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: (place.isOpenNow ? AppColors.sage : Colors.orangeAccent).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          place.openStatusText,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: place.isOpenNow ? AppColors.sage : Colors.orangeAccent,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Distance breakdown for both
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.black : Colors.white).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.08),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'COUPLE TRAVEL BREAKDOWN',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            color: AppColors.terra,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(Icons.person_pin_circle_rounded, color: AppColors.sage, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              'You: $userDistStr away',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            const Spacer(),
                            Text(
                              place.userTravelTime,
                              style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkSoft : AppColors.lightSoft),
                            ),
                          ],
                        ),
                        const Divider(height: 16),
                        Row(
                          children: [
                            const Icon(Icons.favorite_rounded, color: AppColors.terra, size: 15),
                            const SizedBox(width: 8),
                            Text(
                              '${widget.partnerNickname}: $partnerDistStr away',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            const Spacer(),
                            Text(
                              place.partnerTravelTime,
                              style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkSoft : AppColors.lightSoft),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  if (place.recommendationReason.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.terra.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.auto_awesome_rounded, color: AppColors.terra, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              place.recommendationReason,
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.4,
                                fontStyle: FontStyle.italic,
                                color: isDark ? AppColors.darkInk : AppColors.lightInk,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Actions: View on Map & Open Google Maps
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _openGoogleMaps(
                              place.googleMapsUrl,
                              lat: place.lat,
                              lng: place.lng,
                              name: place.name,
                            );
                          },
                          icon: const Icon(Icons.directions_rounded, size: 18),
                          label: const Text('Google Maps ↗'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: isDark ? AppColors.darkInk : AppColors.lightInk,
                            minimumSize: const Size.fromHeight(46),
                            side: BorderSide(
                              color: isDark ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.15),
                            ),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            if (widget.onPlaceSelected != null) {
                              widget.onPlaceSelected!(place.lat, place.lng, place.name, place.category);
                            }
                          },
                          icon: const Icon(Icons.pin_drop_rounded, size: 18),
                          label: const Text('Show on Map 🗺️', style: TextStyle(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.terra,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(46),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
