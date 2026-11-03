import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/travel_route_service.dart';
import 'route_section_tile.dart';

/// Full-featured bottom sheet that shows drive, train, flight, and hotel options
/// between the user and their long-distance partner. Opens via [show].
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
  bool _soloMode = false; // false = couple room, true = solo rooms

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final result = await TravelRouteService.instance.fetchAll(
        myLat: widget.myLat,
        myLng: widget.myLng,
        myCity: widget.myCity,
        partnerLat: widget.partnerLat,
        partnerLng: widget.partnerLng,
        partnerCity: widget.partnerCity,
      );
      if (mounted) setState(() { _result = result; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openUrl(String url) {
    // Copy URL to clipboard as fallback (no url_launcher dependency)
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Link copied! Paste in your browser 🔗',
          style: const TextStyle(fontSize: 12),
        ),
        backgroundColor: AppColors.sage,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final bgColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final inkColor = isDark ? AppColors.darkInk : AppColors.lightInk;
    final softColor = isDark ? AppColors.darkSoft : AppColors.lightSoft;
    final distLabel = widget.distanceKm > 1000
        ? '${(widget.distanceKm / 1000).toStringAsFixed(1)}k km apart'
        : '${widget.distanceKm.toStringAsFixed(0)} km apart';

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollCtrl) {
        return Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 24,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              // ── Handle ────────────────────────────────────────────────────
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              // ── Header ────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: AppColors.terra.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('🗺️', style: TextStyle(fontSize: 20)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Plan Your Reunion',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: inkColor,
                            ),
                          ),
                          Text(
                            'You & ${widget.partnerName} · $distLabel',
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
                          color: isDark ? AppColors.darkCard : AppColors.lightCard,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.close_rounded,
                            size: 18,
                            color: isDark ? AppColors.darkSoft : AppColors.lightSoft),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── City photos strip ─────────────────────────────────────────
              if (!_loading && _result != null)
                _buildCityPhotos(_result!, isDark, inkColor, softColor),

              // ── Scrollable content ────────────────────────────────────────
              Expanded(
                child: _loading
                    ? _buildLoader(isDark)
                    : ListView(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                        children: [
                          if (_result != null) ...[
                            // Drive section
                            _sectionLabel('🚗 Drive Route', inkColor),
                            const SizedBox(height: 8),
                            _buildDriveSection(_result!, isDark),

                            const SizedBox(height: 16),

                            // Train section
                            _sectionLabel('🚂 Train / Bus', inkColor),
                            const SizedBox(height: 8),
                            ..._buildTransitSection(_result!, 'train', isDark),

                            const SizedBox(height: 16),

                            // Flight section
                            _sectionLabel('✈️ Flight', inkColor),
                            const SizedBox(height: 8),
                            ..._buildTransitSection(_result!, 'flight', isDark),

                            // Bus section (fallback links also have bus)
                            ..._buildTransitSection(_result!, 'bus', isDark),

                            const SizedBox(height: 16),

                            // Hotels section
                            _sectionLabel('🏨 Hotels Near Midpoint', inkColor),
                            const SizedBox(height: 4),
                            // Solo / couple toggle
                            _buildHotelToggle(isDark, softColor),
                            const SizedBox(height: 8),
                            _buildHotelsSection(_result!, isDark),

                            const SizedBox(height: 12),

                            // Rome2Rio tip if no key
                            if (TravelRouteService.rome2rioKey == null ||
                                TravelRouteService.rome2rioKey!.isEmpty)
                              _buildApiTip(isDark, softColor),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCityPhotos(
    TravelRouteResult result,
    bool isDark,
    Color inkColor,
    Color softColor,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          Expanded(child: _cityPhotoTile(result.myCity, 'You', isDark, inkColor, softColor)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              children: [
                const Text('✈️', style: TextStyle(fontSize: 20)),
                const SizedBox(height: 4),
                Text(
                  '${widget.distanceKm.toStringAsFixed(0)} km',
                  style: TextStyle(
                    fontSize: 9,
                    color: softColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _cityPhotoTile(
              result.partnerCity,
              widget.partnerName,
              isDark,
              inkColor,
              softColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _cityPhotoTile(
    CityPhoto? city,
    String label,
    bool isDark,
    Color inkColor,
    Color softColor,
  ) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (city?.photoUrl != null)
            CachedNetworkImage(
              imageUrl: city!.photoUrl!,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Container(
                color: AppColors.sage.withOpacity(0.2),
                child: const Center(child: Text('🏙️', style: TextStyle(fontSize: 28))),
              ),
            )
          else
            Container(
              color: AppColors.sage.withOpacity(0.15),
              child: const Center(child: Text('🏙️', style: TextStyle(fontSize: 28))),
            ),
          // Gradient overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withOpacity(0.65)],
              ),
            ),
          ),
          // Label
          Positioned(
            bottom: 6,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (city?.city != null && city!.city.isNotEmpty)
                  Text(
                    city.city,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 8,
                      color: Colors.white70,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoader(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.terra,
          ),
          const SizedBox(height: 16),
          Text(
            'Planning your reunion...',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text, Color inkColor) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: inkColor,
      ),
    );
  }

  Widget _buildDriveSection(TravelRouteResult result, bool isDark) {
    final drive = result.drive;
    if (drive == null) {
      return RouteSectionTile(
        emoji: '🚗',
        title: 'Drive Directions',
        subtitle: 'Tap to open in Google Maps',
        actionLabel: 'Navigate',
        isDark: isDark,
        accentColor: AppColors.sage,
        onTap: () => _openUrl(
          'https://www.google.com/maps/dir/${widget.myLat},${widget.myLng}/${widget.partnerLat},${widget.partnerLng}',
        ),
      );
    }

    final distStr = drive.distanceKm > 1000
        ? '${(drive.distanceKm / 1000).toStringAsFixed(1)}k km'
        : '${drive.distanceKm.toStringAsFixed(0)} km';

    final durH = drive.durationMinutes ~/ 60;
    final durM = drive.durationMinutes % 60;
    final durStr = durH > 0 ? '${durH}h ${durM}m drive' : '${durM}m drive';

    return RouteSectionTile(
      emoji: '🚗',
      title: '$distStr · $durStr',
      subtitle: 'Fastest road route via OSRM. Tap to open Google Maps navigation.',
      actionLabel: 'Navigate',
      isDark: isDark,
      accentColor: AppColors.sage,
      onTap: () => _openUrl(drive.googleMapsUrl),
    );
  }

  List<Widget> _buildTransitSection(
      TravelRouteResult result, String type, bool isDark) {
    final options = result.transit.where((t) => t.type == type).toList();
    if (options.isEmpty) return [];

    return options.map((opt) {
      final emoji = type == 'flight' ? '✈️' : (type == 'bus' ? '🚌' : '🚂');
      final accentColor = type == 'flight'
          ? AppColors.slate
          : (type == 'bus' ? AppColors.gold : AppColors.terra);

      final durStr = opt.durationMinutes > 0
          ? '${opt.durationMinutes ~/ 60}h ${opt.durationMinutes % 60}m'
          : '';
      final subtitle = [
        if (durStr.isNotEmpty) durStr,
        if (opt.priceEstimate.isNotEmpty) opt.priceEstimate,
      ].join(' · ');

      return RouteSectionTile(
        emoji: emoji,
        title: opt.name,
        subtitle: subtitle.isNotEmpty ? subtitle : 'Tap to check availability',
        actionLabel: 'Book',
        isDark: isDark,
        accentColor: accentColor,
        onTap: () => _openUrl(opt.deepLink),
      );
    }).toList();
  }

  Widget _buildHotelToggle(bool isDark, Color softColor) {
    return Row(
      children: [
        Text(
          'Room preference:',
          style: TextStyle(fontSize: 11, color: softColor),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _soloMode = false);
          },
          child: _toggleChip('💑 Couple', !_soloMode, isDark),
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _soloMode = true);
          },
          child: _toggleChip('🚶 Solo', _soloMode, isDark),
        ),
      ],
    );
  }

  Widget _toggleChip(String label, bool selected, bool isDark) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: selected
            ? AppColors.terra.withOpacity(0.15)
            : (isDark ? AppColors.darkCard : AppColors.lightCard),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected ? AppColors.terra : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: selected
              ? AppColors.terra
              : (isDark ? AppColors.darkSoft : AppColors.lightSoft),
        ),
      ),
    );
  }

  Widget _buildHotelsSection(TravelRouteResult result, bool isDark) {
    final hotels = result.hotels;
    if (hotels.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        child: Column(
          children: [
            const Text('🏨', style: TextStyle(fontSize: 28)),
            const SizedBox(height: 8),
            Text(
              'Search hotels near the midpoint',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
              ),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () {
                final midLat = (widget.myLat + widget.partnerLat) / 2;
                final midLng = (widget.myLng + widget.partnerLng) / 2;
                final query = _soloMode
                    ? 'Hotels near $midLat,$midLng'
                    : 'Couple hotels near $midLat,$midLng';
                _openUrl(
                  'https://www.google.com/maps/search/${Uri.encodeComponent(query)}',
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.terra,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Search on Google Maps',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: hotels
          .take(6)
          .map((hotel) => HotelTile(
                hotel: hotel,
                isDark: isDark,
                onTap: () => _openUrl(hotel.googleMapsUrl),
              ))
          .toList(),
    );
  }

  Widget _buildApiTip(bool isDark, Color softColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.gold.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('💡', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Add a free Rome2Rio API key in app settings for real-time train & flight prices with departure times.',
              style: TextStyle(fontSize: 10, color: softColor, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
