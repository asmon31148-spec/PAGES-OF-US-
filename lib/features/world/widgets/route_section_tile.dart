import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/travel_route_service.dart';

/// A reusable section card for one travel mode (train / flight / car / hotel).
class RouteSectionTile extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onTap;
  final bool isDark;
  final Color accentColor;
  final Widget? trailing;

  const RouteSectionTile({
    super.key,
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onTap,
    required this.isDark,
    this.accentColor = AppColors.terra,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Emoji icon container
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(emoji, style: const TextStyle(fontSize: 18)),
                  ),
                ),
                const SizedBox(width: 12),
                // Title + subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.darkInk : AppColors.lightInk,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Action button
                trailing ??
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: accentColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        actionLabel,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Model for a nearby hotel along the route or near midpoint.
class NearbyHotel {
  final String name;
  final int? stars;
  final double distanceKm;

  const NearbyHotel({
    required this.name,
    this.stars,
    this.distanceKm = 0.0,
  });
}

/// Compact hotel card row for the hotels section.
class HotelTile extends StatelessWidget {
  final NearbyHotel hotel;
  final bool isDark;
  final VoidCallback onTap;

  const HotelTile({
    super.key,
    required this.hotel,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final starsStr = hotel.stars != null ? '⭐' * hotel.stars!.clamp(1, 5) : '';
    final distStr = hotel.distanceKm < 1.0
        ? '${(hotel.distanceKm * 1000).round()} m from midpoint'
        : '${hotel.distanceKm.toStringAsFixed(1)} km from midpoint';

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.darkSurface.withOpacity(0.7)
              : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        child: Row(
          children: [
            const Text('🏨', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hotel.name,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkInk : AppColors.lightInk,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      if (starsStr.isNotEmpty) ...[
                        Text(starsStr,
                            style: const TextStyle(fontSize: 9)),
                        const SizedBox(width: 4),
                        Text('· ',
                            style: TextStyle(
                                fontSize: 10,
                                color: isDark
                                    ? AppColors.darkSoft
                                    : AppColors.lightSoft)),
                      ],
                      Expanded(
                        child: Text(
                          distStr,
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark
                                ? AppColors.darkSoft
                                : AppColors.lightSoft,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.open_in_new_rounded, size: 14, color: AppColors.sage),
          ],
        ),
      ),
    );
  }
}
