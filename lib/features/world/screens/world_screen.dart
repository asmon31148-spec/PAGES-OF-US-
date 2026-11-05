import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/liquid_glass/liquid_glass_background.dart';
import '../../../core/widgets/liquid_glass/liquid_glass_theme.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/world_provider.dart';
import '../../stage/widgets/app_top_bar.dart';
import '../../stage/widgets/profile_modal.dart';
import '../../../data/models/user_location_model.dart';
import '../../../data/models/pinned_place.dart';
import '../widgets/journey_stats_card.dart';
import '../widgets/date_planner_card.dart';
import '../../music/widgets/glass/glass_ambient_background.dart';
import '../../music/widgets/glass/glass_card.dart';
import '../../music/theme/glass_tokens.dart';

enum MapBasemapStyle {
  streets,
  satellite,
  dark,
  terrain,
}

class WorldScreen extends StatefulWidget {
  const WorldScreen({super.key});

  @override
  State<WorldScreen> createState() => _WorldScreenState();
}

class _WorldScreenState extends State<WorldScreen> with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  AnimationController? _mapAnimationController;
  bool _isMapReady = false;
  bool _hasInitialMapCentered = false;
  String? _lastFittedCoordKey;
  bool _isFullScreenMap = false;
  MapBasemapStyle _mapStyle = MapBasemapStyle.streets;
  LatLng? _selectedDatePlacePos;
  String? _selectedDatePlaceName;
  String? _selectedDatePlaceCategory;

  String _cleanDisplayAddress(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 'Locating...';
    final parts = raw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    if (parts.length >= 2 && parts[0].toLowerCase() == parts[1].toLowerCase()) {
      return parts[0];
    }
    return raw;
  }

  @override
  void initState() {
    super.initState();
    _loadSavedMapStyle();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startLiveWorldTracking();
    });
  }

  Future<void> _loadSavedMapStyle() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('world_map_style_pref');
      if (saved != null) {
        final match = MapBasemapStyle.values.where((s) => s.name == saved).firstOrNull;
        if (match != null && mounted) {
          setState(() => _mapStyle = match);
        }
      }
    } catch (_) {}
  }

  Future<void> _changeMapStyle(MapBasemapStyle newStyle) async {
    setState(() => _mapStyle = newStyle);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('world_map_style_pref', newStyle.name);
    } catch (_) {}
  }

  void _cycleMapStyle() {
    HapticFeedback.selectionClick();
    final nextIndex = (_mapStyle.index + 1) % MapBasemapStyle.values.length;
    _changeMapStyle(MapBasemapStyle.values[nextIndex]);
  }

  String _getStyleLabel(MapBasemapStyle style) {
    switch (style) {
      case MapBasemapStyle.streets:
        return '🗺️ Street';
      case MapBasemapStyle.satellite:
        return '🛰️ Satellite';
      case MapBasemapStyle.dark:
        return '🌙 Dark';
      case MapBasemapStyle.terrain:
        return '🏔️ Terrain';
    }
  }

  @override
  void dispose() {
    _mapAnimationController?.dispose();
    super.dispose();
  }

  void _startLiveWorldTracking() {
    final auth = context.read<AuthProvider>();
    final world = context.read<WorldProvider>();
    final spaceId = auth.space?.id ?? auth.user?.spaceId ?? '';
    final user = auth.user;
    final partner = auth.partner;

    if (user != null) {
      final effectiveSpaceId = spaceId.isNotEmpty ? spaceId : 'solo_${user.id}';
      if (world.spaceId != effectiveSpaceId || world.partnerId != partner?.id) {
        world.initWorldSync(
          spaceId: effectiveSpaceId,
          currentUserId: user.id,
          partnerId: partner?.id,
        );
      }

      if (!world.isLiveTrackingActive) {
        // Automatically acquire GPS and begin continuous real-time movement streaming
        world.startLiveTracking(
          spaceId: effectiveSpaceId,
          currentUserId: user.id,
          nickname: user.nickname,
          avatarUrl: user.avatarUrl,
        );
      }
    }
  }

  // Native dark mode matrix that inverts Google Maps standard tiles into a sleek obsidian dark theme
  // while preserving crisp white road names, shops, and building contrast with ZERO watermarks!
  static const List<double> _darkMapMatrix = <double>[
    -0.20, -0.65, -0.07, 0, 215,
    -0.18, -0.60, -0.06, 0, 225,
    -0.20, -0.65, -0.07, 0, 220,
    0,      0,      0,    1, 0,
  ];

  String _getTileUrl(MapBasemapStyle style) {
    switch (style) {
      case MapBasemapStyle.satellite:
        // Google Maps Hybrid: Ultra high-resolution satellite WITH all place names and road networks
        return 'https://mt{s}.google.com/vt/lyrs=y&x={x}&y={y}&z={z}';
      case MapBasemapStyle.dark:
        // Google Maps Dark: 100% full detail roads, shops & places with native dark styling (Zero Watermark!)
        return 'https://mt{s}.google.com/vt/lyrs=m&x={x}&y={y}&z={z}';
      case MapBasemapStyle.terrain:
        // Google Maps Terrain: Physical relief with complete place names & roads
        return 'https://mt{s}.google.com/vt/lyrs=p&x={x}&y={y}&z={z}';
      case MapBasemapStyle.streets:
      default:
        // Google Maps Standard: 100% full detail, shops, restaurants, buildings, local landmarks, lanes
        return 'https://mt{s}.google.com/vt/lyrs=m&x={x}&y={y}&z={z}';
    }
  }

  List<String> _getSubdomains(MapBasemapStyle style) {
    return const ['0', '1', '2', '3'];
  }

  int _getMaxNativeZoom(MapBasemapStyle style) {
    switch (style) {
      case MapBasemapStyle.satellite:
        return 20;
      case MapBasemapStyle.dark:
        return 20;
      case MapBasemapStyle.terrain:
        return 18;
      case MapBasemapStyle.streets:
      default:
        return 20;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;
    final worldProvider = context.watch<WorldProvider>();
    final authProvider = context.watch<AuthProvider>();

    final user = authProvider.user;
    final partner = authProvider.partner;
    final spaceId = authProvider.space?.id ?? authProvider.user?.spaceId ?? '';

    final hasPartner = (partner != null && partner.id.isNotEmpty) ||
        authProvider.isPaired ||
        (worldProvider.partnerLocation != null) ||
        (worldProvider.partnerId != null && worldProvider.partnerId!.isNotEmpty);
    final effectivePartnerId = partner?.id ?? worldProvider.partnerId ?? '';
    final myLoc = (user != null ? worldProvider.getUserLocation(user.id) : null) ?? worldProvider.myLocation;
    final partnerLoc = hasPartner
        ? ((effectivePartnerId.isNotEmpty ? worldProvider.getUserLocation(effectivePartnerId) : null) ?? worldProvider.partnerLocation)
        : null;

    // Automatic real-time distance calculation between two partners (only in paired mode)
    double? distanceKm;
    if (hasPartner && myLoc != null && partnerLoc != null) {
      if ((myLoc.lat != 0.0 || myLoc.lng != 0.0) && (partnerLoc.lat != 0.0 || partnerLoc.lng != 0.0)) {
        distanceKm = worldProvider.calculateDistanceKm(
          myLoc.lat,
          myLoc.lng,
          partnerLoc.lat,
          partnerLoc.lng,
        );
      }
    }
    if (hasPartner) {
      distanceKm ??= worldProvider.liveDistanceKm;
    }

    final hasMyValid = myLoc != null && (myLoc.lat != 0.0 || myLoc.lng != 0.0);
    final hasPartnerValid = hasPartner && partnerLoc != null && (partnerLoc.lat != 0.0 || partnerLoc.lng != 0.0);

    // Default center point: Midpoint between both partners, or user/partner location
    final defaultCenter = (hasMyValid && hasPartnerValid)
        ? LatLng((myLoc.lat + partnerLoc.lat) / 2, (myLoc.lng + partnerLoc.lng) / 2)
        : (hasMyValid
            ? LatLng(myLoc.lat, myLoc.lng)
            : (hasPartnerValid
                ? LatLng(partnerLoc.lat, partnerLoc.lng)
                : const LatLng(22.365, 88.432)));

    // Smart initial zoom calculation so FlutterMap immediately requests the correct tiles on boot
    double smartInitialZoom = 15.0;
    if (hasMyValid && hasPartnerValid) {
      final distKm = _calculateDistanceKm(myLoc.lat, myLoc.lng, partnerLoc.lat, partnerLoc.lng);
      if (distKm > 800) {
        smartInitialZoom = 4.8;
      } else if (distKm > 300) {
        smartInitialZoom = 5.8;
      } else if (distKm > 100) {
        smartInitialZoom = 7.2;
      } else if (distKm > 20) {
        smartInitialZoom = 10.5;
      } else if (distKm > 2) {
        smartInitialZoom = 13.5;
      } else if (distKm > 0.2) {
        smartInitialZoom = 16.0;
      } else {
        smartInitialZoom = 18.0;
      }
    } else if (hasMyValid || hasPartnerValid) {
      smartInitialZoom = 16.5;
    }

    // Initial camera centering: only trigger on first map load, NOT on every continuous GPS jitter
    if (_isMapReady && !_hasInitialMapCentered && (hasMyValid || hasPartnerValid)) {
      _hasInitialMapCentered = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _isMapReady) {
          _fitMapBounds(myLoc, partnerLoc);
        }
      });
    }

    return PopScope(
      canPop: !_isFullScreenMap,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_isFullScreenMap) {
          setState(() => _isFullScreenMap = false);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: LiquidGlassBackground(
          child: SafeArea(
          child: _isFullScreenMap
              ? _buildMapCard(
                  isDark: isDark,
                  myLoc: myLoc,
                  partnerLoc: partnerLoc,
                  distanceKm: distanceKm,
                  user: user,
                  partner: partner,
                  worldProvider: worldProvider,
                  defaultCenter: defaultCenter,
                  isFullScreen: true,
                  now: worldProvider.now,
                )
              : Column(
                  children: [
                    // Top Bar
                    AppTopBar(
                      title: 'Our World',
                      subtitle: 'Realtime tether & presence',
                      onOpenProfile: () => ProfileModal.show(context),
                    ),

                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: Column(
                          children: [
                            // 1. World Clocks Header Card (Dual if paired, Solo if single)
                            _buildDualClocksCard(
                              isDark: isDark,
                              userNickname: user?.nickname ?? 'You',
                              partnerNickname: partner?.nickname ?? 'Partner',
                              myLoc: myLoc,
                              partnerLoc: partnerLoc,
                              now: worldProvider.now,
                              hasPartner: hasPartner,
                            ),

                            // 2. Live Tether Distance Banner (Only shown when paired with partner)
                            if (hasPartner && distanceKm != null)
                              _buildDistanceBanner(
                                isDark: isDark,
                                distanceKm: distanceKm,
                                myLoc: myLoc,
                                partnerLoc: partnerLoc,
                                partnerNickname: partner?.nickname ?? 'Partner',
                                now: worldProvider.now,
                              ),

                            // 3. Interactive FlutterMap Card (Full-screen toggleable, no big accuracy circles)
                            _buildMapCard(
                              isDark: isDark,
                              myLoc: myLoc,
                              partnerLoc: partnerLoc,
                              distanceKm: distanceKm,
                              user: user,
                              partner: partner,
                              worldProvider: worldProvider,
                              defaultCenter: defaultCenter,
                              isFullScreen: false,
                              now: worldProvider.now,
                            ),

                            // 4. Journey Stats Card — partner daily activity & animated paper plane flight route
                            JourneyStatsCard(
                              isDark: isDark,
                              partnerNickname: partner?.nickname ?? 'Partner',
                              partnerAvatarUrl: partner?.avatarUrl,
                              userNickname: user?.nickname ?? 'You',
                              userAvatarUrl: user?.avatarUrl,
                            ),

                            // 5. Quick Action Grid
                            Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildActionButton(
                              icon: Icons.gps_fixed,
                              label: worldProvider.isLoading ? 'Locating...' : 'Refresh GPS',
                              color: AppColors.sage,
                              isDark: isDark,
                              onTap: () {
                                if (user != null) {
                                  final effectiveSpaceId = spaceId.isNotEmpty ? spaceId : 'solo_${user.id}';
                                  worldProvider.updateMyPosition(
                                    spaceId: effectiveSpaceId,
                                    currentUserId: user.id,
                                    nickname: user.nickname,
                                    avatarUrl: user.avatarUrl,
                                  );
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildActionButton(
                              icon: Icons.label_outline,
                              label: myLoc?.customLabel ?? 'Set Status',
                              color: AppColors.terra,
                              isDark: isDark,
                              onTap: () => _showLocationTagModal(context, spaceId, user?.id),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildActionButton(
                              icon: Icons.add_location_alt_outlined,
                              label: 'Add Place',
                              color: AppColors.slate,
                              isDark: isDark,
                              onTap: () => _showAddPlaceModal(context, spaceId, user?.id, defaultCenter),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 7. Mutual Location Tether Card (Clean & Compact)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF141722).withOpacity(0.78) : Colors.white.withOpacity(0.66),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isDark ? Colors.white.withOpacity(0.16) : Colors.white.withOpacity(0.78),
                          width: 1.0,
                        ),
                        boxShadow: LiquidGlassTheme.cardShadow(isDark),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.security, size: 16, color: AppColors.sage),
                              const SizedBox(width: 8),
                              Text(
                                'Mutual Location Tether',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? AppColors.darkInk : AppColors.lightInk,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  foregroundColor: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                                ),
                                onPressed: () {
                                  if (spaceId.isNotEmpty) {
                                    worldProvider.clearLocationHistory(spaceId);
                                  }
                                },
                                child: const Text('Clear History', style: TextStyle(fontSize: 10.5)),
                              ),
                              const SizedBox(width: 4),
                              Switch(
                                value: worldProvider.isSharing,
                                activeColor: AppColors.sage,
                                onChanged: (val) {
                                  if (user != null && spaceId.isNotEmpty) {
                                    worldProvider.toggleSharing(
                                      spaceId: spaceId,
                                      currentUserId: user.id,
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // 8. Date Planner AI (Part C)
                    DatePlannerCard(
                      isTetherOn: worldProvider.isSharing,
                      isDark: isDark,
                      userLat: myLoc?.lat ?? 0.0,
                      userLng: myLoc?.lng ?? 0.0,
                      userCity: myLoc?.placeName ?? 'Your Location',
                      partnerLat: worldProvider.isSharing ? (partnerLoc?.lat ?? 0.0) : 0.0,
                      partnerLng: worldProvider.isSharing ? (partnerLoc?.lng ?? 0.0) : 0.0,
                      partnerCity: worldProvider.isSharing ? (partnerLoc?.placeName ?? 'Partner Location') : '',
                      partnerNickname: partner?.nickname ?? 'Partner',
                      onPlaceSelected: (pLat, pLng, [pName, pCat]) {
                        HapticFeedback.lightImpact();
                        setState(() {
                          _selectedDatePlacePos = LatLng(pLat, pLng);
                          _selectedDatePlaceName = pName;
                          _selectedDatePlaceCategory = pCat;
                          _isFullScreenMap = true;
                        });
                        _mapController.move(LatLng(pLat, pLng), 15.5);
                      },
                    ),
                  ],
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

  Widget _buildMapCard({
    required bool isDark,
    required UserLocationData? myLoc,
    required UserLocationData? partnerLoc,
    required double? distanceKm,
    required dynamic user,
    required dynamic partner,
    required WorldProvider worldProvider,
    required LatLng defaultCenter,
    required bool isFullScreen,
    required DateTime now,
  }) {
    // Partner live / recency calculation
    bool isPartnerLive = false;
    String partnerActiveStatus = 'Standby';
    if (partnerLoc != null) {
      try {
        final updatedUtc = DateTime.parse(partnerLoc.updatedAt).toUtc();
        final rawDiff = DateTime.now().toUtc().difference(updatedUtc);
        final diff = rawDiff.isNegative ? Duration.zero : rawDiff;
        if (diff.inMinutes < 3) {
          isPartnerLive = true;
          partnerActiveStatus = 'Live';
        } else if (diff.inMinutes < 60) {
          partnerActiveStatus = '${diff.inMinutes}m ago';
        } else if (diff.inHours < 24) {
          partnerActiveStatus = '${diff.inHours}h ago';
        } else {
          partnerActiveStatus = DateFormat('d MMM').format(updatedUtc.toLocal());
        }
      } catch (_) {}
    }

    final pNick = partner?.nickname ?? 'Partner';
    final mapStatusText = partnerLoc != null
        ? (isPartnerLive ? '● Both Live' : '$pNick: $partnerActiveStatus')
        : worldProvider.gpsStatus;
    final mapStatusColor = partnerLoc != null
        ? (isPartnerLive ? AppColors.sage : Colors.orangeAccent)
        : (worldProvider.gpsStatus.contains('Live') ? AppColors.sage : (worldProvider.isLoading ? Colors.orangeAccent : Colors.grey));

    // Smart initial zoom calculation so FlutterMap immediately requests the correct tiles on boot
    final dist = distanceKm ?? (myLoc != null && partnerLoc != null && (myLoc.lat != 0.0 || myLoc.lng != 0.0) && (partnerLoc.lat != 0.0 || partnerLoc.lng != 0.0)
        ? _calculateDistanceKm(myLoc.lat, myLoc.lng, partnerLoc.lat, partnerLoc.lng)
        : null);
    double smartInitialZoom = 15.0;
    if (dist != null) {
      if (dist > 800) {
        smartInitialZoom = 4.8;
      } else if (dist > 300) {
        smartInitialZoom = 5.8;
      } else if (dist > 100) {
        smartInitialZoom = 7.2;
      } else if (dist > 20) {
        smartInitialZoom = 10.5;
      } else if (dist > 2) {
        smartInitialZoom = 13.5;
      } else if (dist > 0.2) {
        smartInitialZoom = 16.0;
      } else {
        smartInitialZoom = 18.0;
      }
    } else if (myLoc != null || partnerLoc != null) {
      smartInitialZoom = 16.5;
    }

    return Container(
      margin: isFullScreen
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: isFullScreen ? double.infinity : 390,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: isFullScreen ? BorderRadius.zero : BorderRadius.circular(28),
        border: isFullScreen
            ? null
            : Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
        boxShadow: isFullScreen
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: defaultCenter,
              initialZoom: smartInitialZoom,
              maxZoom: 21.0,
              minZoom: 3.0,
              onMapReady: () {
                _isMapReady = true;
                if (!_hasInitialMapCentered) {
                  _hasInitialMapCentered = true;
                  _fitMapBounds(myLoc, partnerLoc);
                }
              },
            ),
            children: [
              // Clean verified high-detail tile layer with Google Maps engine
              TileLayer(
                key: ValueKey('tile_layer_${_mapStyle.name}'),
                urlTemplate: _getTileUrl(_mapStyle),
                subdomains: _getSubdomains(_mapStyle),
                userAgentPackageName: 'com.pagesofus.app',
                maxZoom: 21.0,
                maxNativeZoom: _getMaxNativeZoom(_mapStyle),
                tileBuilder: _mapStyle == MapBasemapStyle.dark
                    ? (context, tileWidget, tile) => ColorFiltered(
                          colorFilter: const ColorFilter.matrix(_darkMapMatrix),
                          child: tileWidget,
                        )
                    : null,
              ),

              // Polyline tether between user & partner
              if (myLoc != null &&
                  partnerLoc != null &&
                  (myLoc.lat != 0.0 || myLoc.lng != 0.0) &&
                  (partnerLoc.lat != 0.0 || partnerLoc.lng != 0.0))
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [
                        LatLng(myLoc.lat, myLoc.lng),
                        LatLng(partnerLoc.lat, partnerLoc.lng),
                      ],
                      color: AppColors.terra.withOpacity(0.85),
                      strokeWidth: 3.5,
                    ),
                  ],
                ),

              // Pinned Places Geofence Circles only (NO huge accuracy circles)
              if (worldProvider.pinnedPlaces.isNotEmpty)
                CircleLayer(
                  circles: [
                    ...worldProvider.pinnedPlaces.map((p) {
                      return CircleMarker(
                        point: LatLng(p.lat, p.lng),
                        radius: p.radiusMeters,
                        useRadiusInMeter: true,
                        color: AppColors.sage.withOpacity(0.15),
                        borderColor: AppColors.sage,
                        borderStrokeWidth: 1.5,
                      );
                    }),
                  ],
                ),

              // Markers Layer
              MarkerLayer(
                markers: [
                  // Pinned Places
                  ...worldProvider.pinnedPlaces.map((p) {
                    return Marker(
                      point: LatLng(p.lat, p.lng),
                      width: 40,
                      height: 40,
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurface : Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 4),
                          ],
                          border: Border.all(color: AppColors.sage, width: 2),
                        ),
                        alignment: Alignment.center,
                        child: Text(p.icon, style: const TextStyle(fontSize: 18)),
                      ),
                    );
                  }),

                  // User Marker
                  if (myLoc != null && (myLoc.lat != 0.0 || myLoc.lng != 0.0))
                    Marker(
                      point: LatLng(myLoc.lat, myLoc.lng),
                      width: 60,
                      height: 60,
                      child: _buildAvatarMarker(
                        name: user?.nickname ?? 'You',
                        avatarUrl: myLoc.avatarUrl ?? user?.avatarUrl,
                        isMe: true,
                        isDark: isDark,
                        customLabel: myLoc.customLabel,
                      ),
                    ),

                  // Partner Marker
                  if (partnerLoc != null && (partnerLoc.lat != 0.0 || partnerLoc.lng != 0.0))
                    Marker(
                      point: LatLng(partnerLoc.lat, partnerLoc.lng),
                      width: 60,
                      height: 60,
                      child: _buildAvatarMarker(
                        name: partner?.nickname ?? 'Partner',
                        avatarUrl: partnerLoc.avatarUrl ?? partner?.avatarUrl,
                        isMe: false,
                        isDark: isDark,
                        customLabel: partnerLoc.customLabel,
                      ),
                    ),
                  // Selected Date Place Marker
                  if (_selectedDatePlacePos != null)
                    Marker(
                      point: _selectedDatePlacePos!,
                      width: 170,
                      height: 76,
                      alignment: Alignment.topCenter,
                      child: _buildDatePlaceMarker(
                        name: _selectedDatePlaceName ?? 'Date Spot',
                        category: _selectedDatePlaceCategory ?? 'Spot',
                        isDark: isDark,
                      ),
                    ),
                ],
              ),
            ],
          ),

          // Unified Top Controls Row: Status Pill on Left, Basemap Switcher on Right
          Positioned(
            top: 14,
            left: 14,
            right: 14,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Left Cluster: Exit Fullscreen (if active) + Compact Live Status Pill
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isFullScreen) ...[
                      Material(
                        color: (isDark ? const Color(0xFF191823) : Colors.white).withOpacity(0.92),
                        shape: const CircleBorder(),
                        elevation: 4,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() => _isFullScreenMap = false);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(9),
                            child: Icon(
                              Icons.arrow_back_rounded,
                              size: 19,
                              color: isDark ? AppColors.darkInk : AppColors.lightInk,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],

                    // Compact Live Status Pill: Hugs content neatly without giant empty black bar
                    Container(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.54,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: (isDark ? const Color(0xFF191823) : Colors.white).withOpacity(0.92),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? Colors.white12 : Colors.black12,
                        ),
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 4),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: mapStatusColor,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              mapStatusText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Top-Right Basemap Style Switcher
                GestureDetector(
                  onTap: _cycleMapStyle,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: (isDark ? const Color(0xFF191823) : Colors.white).withOpacity(0.95),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? Colors.white12 : Colors.black12,
                      ),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 4),
                      ],
                    ),
                    child: Text(
                      _getStyleLabel(_mapStyle),
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Floating Map Controls (Right side: Fullscreen toggle, Partner locator, Me locator)
          Positioned(
            right: 12,
            bottom: isFullScreen ? 24 : 12,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Full Screen Toggle Button
                FloatingActionButton.small(
                  heroTag: 'map_fullscreen_toggle',
                  backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
                  foregroundColor: isDark ? AppColors.darkInk : AppColors.lightInk,
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    setState(() => _isFullScreenMap = !_isFullScreenMap);
                  },
                  tooltip: isFullScreen ? 'Exit Full Screen' : 'Full Screen Map',
                  child: Icon(
                    isFullScreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                    size: 20,
                  ),
                ),
                const SizedBox(height: 8),

                // 2. Locate Partner Button (Only shown when paired with partner)
                if (partner != null && partnerLoc != null) ...[
                  FloatingActionButton.small(
                    heroTag: 'zoom_partner',
                    backgroundColor: AppColors.terra,
                    foregroundColor: Colors.white,
                    onPressed: () {
                      if (partnerLoc != null && (partnerLoc.lat != 0.0 || partnerLoc.lng != 0.0)) {
                        _animatedMapMove(LatLng(partnerLoc.lat, partnerLoc.lng), 16.0);
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Centered on ${partner?.nickname ?? "Partner"}'),
                            duration: const Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                    tooltip: 'Locate ${partner?.nickname ?? "Partner"}',
                    child: const Icon(Icons.person_pin_circle_rounded, size: 20),
                  ),
                  const SizedBox(height: 8),
                ],

                // 3. Locate Me Button
                FloatingActionButton.small(
                  heroTag: 'zoom_me',
                  backgroundColor: AppColors.sage,
                  foregroundColor: Colors.white,
                  onPressed: () {
                    if (myLoc != null && (myLoc.lat != 0.0 || myLoc.lng != 0.0)) {
                      _animatedMapMove(LatLng(myLoc.lat, myLoc.lng), 16.0);
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Centered on your location'),
                          duration: Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    } else {
                      _startLiveWorldTracking();
                      if (user != null) {
                        final auth = context.read<AuthProvider>();
                        final currSpaceId = auth.space?.id ?? auth.user?.spaceId ?? '';
                        final effectiveSpaceId = currSpaceId.isNotEmpty ? currSpaceId : 'solo_${user.id}';
                        worldProvider.updateMyPosition(
                          spaceId: effectiveSpaceId,
                          currentUserId: user.id,
                          nickname: user.nickname,
                          avatarUrl: user.avatarUrl,
                        );
                      }
                    }
                  },
                  tooltip: 'Center on Me',
                  child: const Icon(Icons.my_location_rounded, size: 18),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _animatedMapMove(LatLng destLocation, double destZoom) {
    if (!_isMapReady) return;
    HapticFeedback.lightImpact();

    _mapAnimationController?.stop();
    _mapAnimationController?.dispose();

    final latTween = Tween<double>(
      begin: _mapController.camera.center.latitude,
      end: destLocation.latitude,
    );
    final lngTween = Tween<double>(
      begin: _mapController.camera.center.longitude,
      end: destLocation.longitude,
    );
    final zoomTween = Tween<double>(
      begin: _mapController.camera.zoom,
      end: destZoom,
    );

    _mapAnimationController = AnimationController(
      duration: const Duration(milliseconds: 650),
      vsync: this,
    );

    final animation = CurvedAnimation(
      parent: _mapAnimationController!,
      curve: Curves.easeInOutCubic,
    );

    _mapAnimationController!.addListener(() {
      _mapController.move(
        LatLng(latTween.evaluate(animation), lngTween.evaluate(animation)),
        zoomTween.evaluate(animation),
      );
    });

    _mapAnimationController!.forward();
  }

  double _calculateDistanceKm(double lat1, double lng1, double lat2, double lng2) {
    try {
      return context.read<WorldProvider>().calculateDistanceKm(lat1, lng1, lat2, lng2);
    } catch (_) {
      const Distance dist = Distance();
      return dist.as(LengthUnit.Kilometer, LatLng(lat1, lng1), LatLng(lat2, lng2));
    }
  }

  void _fitMapBounds(UserLocationData? myLoc, UserLocationData? partnerLoc) {
    if (!_isMapReady) return;

    final hasMy = myLoc != null && (myLoc.lat != 0.0 || myLoc.lng != 0.0);
    final hasPartner = partnerLoc != null && (partnerLoc.lat != 0.0 || partnerLoc.lng != 0.0);

    if (hasMy && hasPartner) {
      final distanceKm = _calculateDistanceKm(myLoc.lat, myLoc.lng, partnerLoc.lat, partnerLoc.lng);
      final centerLat = (myLoc.lat + partnerLoc.lat) / 2;
      final centerLng = (myLoc.lng + partnerLoc.lng) / 2;
      final center = LatLng(centerLat, centerLng);

      if (distanceKm < 0.08) {
        // Under the same roof or same building/room (< 80 meters):
        // Zoom to maximum high-detail building/street view (18.2) so both avatars are prominently visible!
        _animatedMapMove(center, 18.2);
      } else if (distanceKm < 0.35) {
        // Within walking distance / neighborhood:
        _animatedMapMove(center, 17.2);
      } else {
        // Maximum zoom fitting both pins with comfortable padding:
        final bounds = LatLngBounds(
          LatLng(myLoc.lat, myLoc.lng),
          LatLng(partnerLoc.lat, partnerLoc.lng),
        );
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.symmetric(horizontal: 45, vertical: 40),
            maxZoom: 18.0,
          ),
        );
      }
    } else if (hasMy) {
      _animatedMapMove(LatLng(myLoc.lat, myLoc.lng), 17.5);
    } else if (hasPartner) {
      _animatedMapMove(LatLng(partnerLoc.lat, partnerLoc.lng), 17.5);
    }
  }

  Widget _buildDatePlaceMarker({
    required String name,
    required String category,
    required bool isDark,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Name Callout Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
          decoration: BoxDecoration(
            color: (isDark ? const Color(0xFF191823) : Colors.white).withOpacity(0.96),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.terra, width: 1.2),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('✨', style: TextStyle(fontSize: 10)),
              const SizedBox(width: 4),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 120),
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _selectedDatePlacePos = null;
                    _selectedDatePlaceName = null;
                  });
                },
                child: const Icon(Icons.close_rounded, size: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        // Pin Icon
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.terra,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.terra.withOpacity(0.5),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: const Icon(
            Icons.place_rounded,
            color: Colors.white,
            size: 18,
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarMarker({
    required String name,
    String? avatarUrl,
    required bool isMe,
    required bool isDark,
    String? customLabel,
  }) {
    final color = isMe ? AppColors.sage : AppColors.terra;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            // Outer Halo
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.22),
              ),
            ),

            // Inner Avatar
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.45),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: avatarUrl != null && avatarUrl.isNotEmpty
                  ? ClipOval(
                      child: Image.network(
                        avatarUrl,
                        width: 30,
                        height: 30,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Text(
                          name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '♥',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    )
                  : Text(
                      name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '♥',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
            ),
          ],
        ),

        // Custom Status Tag or Name
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1D2A) : Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2)],
          ),
          child: Text(
            customLabel?.isNotEmpty == true ? customLabel! : name,
            style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildDualClocksCard({
    required bool isDark,
    required String userNickname,
    required String partnerNickname,
    required UserLocationData? myLoc,
    required UserLocationData? partnerLoc,
    required DateTime now,
    required bool hasPartner,
  }) {
    final myTimeStr = DateFormat('h:mm a').format(now);
    final myIsDay = now.hour >= 6 && now.hour < 19;

    // 1. Partner civil/clock time
    DateTime partnerDateTime = now;
    int solarDiffMinutes = 0;
    bool isPartnerLive = false;
    String partnerActiveStatus = 'Standby';

    if (partnerLoc != null && (partnerLoc.lat != 0.0 || partnerLoc.lng != 0.0)) {
      // Estimate or retrieve partner's exact civil clock using device timezone offset
      final partnerOffset = _estimatePartnerOffset(
        partnerLoc.lat,
        partnerLoc.lng,
        exactOffsetMinutes: partnerLoc.timeZoneOffsetMinutes,
      );
      partnerDateTime = now.toUtc().add(partnerOffset);

      // Solar astronomical time difference (the sun's position: 4 mins per longitude degree)
      final myLng = (myLoc != null && myLoc.lng != 0.0) ? myLoc.lng : partnerLoc.lng;
      solarDiffMinutes = ((partnerLoc.lng - myLng) * 4).round();

      // Activity recency
      try {
        final updatedUtc = DateTime.parse(partnerLoc.updatedAt).toUtc();
        final rawDiff = DateTime.now().toUtc().difference(updatedUtc);
        final diff = rawDiff.isNegative ? Duration.zero : rawDiff;
        if (diff.inMinutes < 3) {
          isPartnerLive = true;
          partnerActiveStatus = 'Live';
        } else if (diff.inMinutes < 60) {
          partnerActiveStatus = '${diff.inMinutes}m ago';
        } else if (diff.inHours < 24) {
          partnerActiveStatus = '${diff.inHours}h ago';
        } else {
          partnerActiveStatus = DateFormat('d MMM').format(updatedUtc.toLocal());
        }
      } catch (_) {}
    }

    final partnerTimeStr = DateFormat('h:mm a').format(partnerDateTime);

    // Partner day/night icon based on astronomical solar position at their longitude
    bool partnerIsDay;
    if (partnerLoc != null && (partnerLoc.lat != 0.0 || partnerLoc.lng != 0.0)) {
      final approxUtcOffsetMinutes = (partnerLoc.lng * 4).round();
      final partnerSolarTime = now.toUtc().add(Duration(minutes: approxUtcOffsetMinutes));
      partnerIsDay = partnerSolarTime.hour >= 6 && partnerSolarTime.hour < 18;
    } else {
      partnerIsDay = partnerDateTime.hour >= 6 && partnerDateTime.hour < 19;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141722).withOpacity(0.78) : Colors.white.withOpacity(0.66),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.16) : Colors.white.withOpacity(0.78),
          width: 1.0,
        ),
        boxShadow: LiquidGlassTheme.cardShadow(isDark),
      ),
      child: Row(
        children: [
          // User Clock
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(myIsDay ? '☀️' : '🌙', style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        userNickname.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          color: AppColors.sage,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                Text(
                  myTimeStr,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkInk : AppColors.lightInk,
                  ),
                ),
                Text(
                  _cleanDisplayAddress(myLoc?.placeName),
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Divider
          Container(
            height: 36,
            width: 1,
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            margin: const EdgeInsets.symmetric(horizontal: 12),
          ),

          // Partner Clock (if paired) OR Solo Status
          if (hasPartner && partnerLoc != null)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(partnerIsDay ? '☀️' : '🌙', style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          partnerNickname.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            color: AppColors.terra,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: isPartnerLive
                              ? AppColors.sage.withOpacity(0.18)
                              : (isDark ? Colors.white10 : Colors.black.withOpacity(0.06)),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isPartnerLive ? AppColors.sage : Colors.orangeAccent,
                              ),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              partnerActiveStatus,
                              style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.bold,
                                color: isPartnerLive
                                    ? AppColors.sage
                                    : (isDark ? Colors.white60 : Colors.black54),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Text(
                    partnerTimeStr,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.darkInk : AppColors.lightInk,
                    ),
                  ),
                  Text(
                    _cleanDisplayAddress(partnerLoc.placeName),
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (solarDiffMinutes.abs() >= 10)
                    Text(
                      solarDiffMinutes < 0
                          ? '☀️ Sun sets ~${-solarDiffMinutes}m later'
                          : '☀️ Sun sets ~${solarDiffMinutes}m earlier',
                      style: TextStyle(
                        fontSize: 8.5,
                        fontStyle: FontStyle.italic,
                        color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            )
          else if (hasPartner)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      const Text('📡', style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          partnerNickname.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            color: AppColors.terra,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Awaiting partner signal 🛰️',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            )
          else
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: const [
                      Text('✨', style: TextStyle(fontSize: 12)),
                      SizedBox(width: 4),
                      Text(
                        'SOLO PRESENCE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          color: AppColors.sageLight,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Connect partner for mutual live tether',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                      height: 1.25,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDistanceBanner({
    required bool isDark,
    required double? distanceKm,
    required UserLocationData? myLoc,
    required UserLocationData? partnerLoc,
    required String partnerNickname,
    required DateTime now,
  }) {
    final isTethered = distanceKm != null;

    String partnerActiveStatus = 'Standby';
    if (partnerLoc != null) {
      try {
        final updatedUtc = DateTime.parse(partnerLoc.updatedAt).toUtc();
        final rawDiff = DateTime.now().toUtc().difference(updatedUtc);
        final diff = rawDiff.isNegative ? Duration.zero : rawDiff;
        if (diff.inMinutes < 3) {
          partnerActiveStatus = 'Live now';
        } else if (diff.inMinutes < 60) {
          partnerActiveStatus = '${diff.inMinutes}m ago';
        } else if (diff.inHours < 24) {
          partnerActiveStatus = '${diff.inHours}h ago';
        } else {
          partnerActiveStatus = DateFormat('d MMM').format(updatedUtc.toLocal());
        }
      } catch (_) {}
    }

    String primaryDistance;
    String secondaryInfo;
    String proximityTag;

    if (isTethered) {
      if (distanceKm < 0.05) {
        primaryDistance = 'Side by side ♥';
        secondaryInfo = 'Under the same roof';
        proximityTag = 'Together';
      } else if (distanceKm < 1.0) {
        final meters = (distanceKm * 1000).round();
        primaryDistance = '$meters m apart';
        secondaryInfo = '~${(meters / 80).clamp(1, 15).round()} min walk';
        proximityTag = 'Walking Distance 🚶';
      } else if (distanceKm < 25.0) {
        final miles = (distanceKm * 0.621371).toStringAsFixed(1);
        primaryDistance = '${distanceKm.toStringAsFixed(1)} km';
        secondaryInfo = '$miles miles · Same city';
        proximityTag = 'Short Drive 🚗';
      } else {
        final miles = (distanceKm * 0.621371).toStringAsFixed(1);
        primaryDistance = '${distanceKm.toStringAsFixed(1)} km';
        secondaryInfo = '$miles miles · Long distance';
        proximityTag = 'Under Same Sky ☁️';
      }
    } else {
      if (myLoc != null && partnerLoc == null) {
        primaryDistance = 'Waiting for partner...';
        secondaryInfo = 'Awaiting $partnerNickname\'s signal';
        proximityTag = 'Standby';
      } else {
        primaryDistance = 'Connecting Tether...';
        secondaryInfo = 'Acquiring mutual GPS coordinates';
        proximityTag = 'Locating';
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  AppColors.terra.withOpacity(0.18),
                  const Color(0xFF141722).withOpacity(0.92),
                ]
              : [
                  AppColors.terra.withOpacity(0.08),
                  Colors.white.withOpacity(0.95),
                ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.terra.withOpacity(0.40) : AppColors.terra.withOpacity(0.25),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.35) : const Color(0x1A2B2D38),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Status badge & Recenter action
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isTethered ? AppColors.sage : Colors.orangeAccent,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isTethered ? 'REAL-TIME LIVE DISTANCE' : 'MUTUAL GPS TETHER',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: isTethered ? AppColors.sage : Colors.orangeAccent,
                    ),
                  ),
                ],
              ),
              if (isTethered)
                GestureDetector(
                  onTap: () => _fitMapBounds(myLoc, partnerLoc),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.terra.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.crop_free, size: 12, color: AppColors.terra),
                        SizedBox(width: 4),
                        Text(
                          'Fit Map',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: AppColors.terra,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Middle: Big Distance readout + Proximity Tag
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                primaryDistance,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: isTethered
                      ? AppColors.terra
                      : (isDark ? AppColors.darkInk : AppColors.lightInk),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  proximityTag,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Subtitle info
          Text(
            secondaryInfo,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
            ),
          ),

          // Bottom Row: Location tags if available
          if (myLoc != null || partnerLoc != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.location_on, size: 12, color: AppColors.sage),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'You: ${_cleanDisplayAddress(myLoc?.placeName)}',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.location_on, size: 12, color: AppColors.terra),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          partnerLoc != null
                              ? '$partnerNickname: ${_cleanDisplayAddress(partnerLoc.placeName)} ($partnerActiveStatus)'
                              : '$partnerNickname: Awaiting signal',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkInk : AppColors.lightInk,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _showLocationTagModal(BuildContext context, String spaceId, String? userId) {
    if (userId == null || spaceId.isEmpty) return;
    final tags = ['Home 🏡', 'Work 💼', 'Cafe ☕', 'Transit 🚇', 'Gym 🏋️', 'Out Exploring ✨'];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = ctx.watch<ThemeProvider>().isDark;
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Where are you right now?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkInk : AppColors.lightInk,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: tags.map((t) {
                  return ActionChip(
                    label: Text(t),
                    onPressed: () {
                      context.read<WorldProvider>().updateMyPosition(
                            spaceId: spaceId,
                            currentUserId: userId,
                            nickname: 'You',
                            customTag: t,
                          );
                      Navigator.pop(ctx);
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddPlaceModal(BuildContext context, String spaceId, String? userId, LatLng center) {
    if (userId == null || spaceId.isEmpty) return;
    final nameCtrl = TextEditingController();
    String icon = '🏡';
    double radius = 150;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = ctx.watch<ThemeProvider>().isDark;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Add Pinned Sanctuary Place',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkInk : AppColors.lightInk,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Place Name (e.g. Our Cozy Apartment)'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: ['🏡', '☕', '💼', '🌳', '🏋️', '✨'].map((emoji) {
                        return IconButton(
                          icon: Text(emoji, style: TextStyle(fontSize: icon == emoji ? 24 : 18)),
                          onPressed: () => setModalState(() => icon = emoji),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.sage,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(44),
                      ),
                      onPressed: () {
                        if (nameCtrl.text.trim().isNotEmpty) {
                          context.read<WorldProvider>().addPinnedPlace(
                                spaceId: spaceId,
                                name: nameCtrl.text.trim(),
                                icon: icon,
                                lat: center.latitude,
                                lng: center.longitude,
                                radiusMeters: radius,
                                currentUserId: userId,
                              );
                          Navigator.pop(ctx);
                        }
                      },
                      child: const Text('Pin to Map'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showSearchModal(BuildContext context) {
    final searchCtrl = TextEditingController();
    List<Map<String, dynamic>> results = [];
    bool isSearching = false;
    String? statusMessage;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = ctx.watch<ThemeProvider>().isDark;
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> doSearch() async {
              final q = searchCtrl.text.trim();
              if (q.isEmpty) return;
              setModalState(() {
                isSearching = true;
                statusMessage = null;
              });
              try {
                final res = await context.read<WorldProvider>().searchPlaces(q);
                setModalState(() {
                  results = res;
                  isSearching = false;
                  if (res.isEmpty) {
                    statusMessage = 'No matching places found. Try another city or landmark.';
                  }
                });
              } catch (_) {
                setModalState(() {
                  isSearching = false;
                  statusMessage = 'Search request timed out. Please try again.';
                });
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                height: 480,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  boxShadow: const [
                    BoxShadow(color: Colors.black38, blurRadius: 20),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Drag Handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.black12,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Icon(Icons.explore_outlined, color: AppColors.terra, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Search Places & Coordinates',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.darkInk : AppColors.lightInk,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: searchCtrl,
                      autofocus: true,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => doSearch(),
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? AppColors.darkInk : AppColors.lightInk,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search city, landmark or coordinates...',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                        ),
                        prefixIcon: const Icon(Icons.search, color: AppColors.terra, size: 20),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (searchCtrl.text.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                                onPressed: () {
                                  searchCtrl.clear();
                                  setModalState(() {
                                    results = [];
                                    statusMessage = null;
                                  });
                                },
                              ),
                            IconButton(
                              icon: const Icon(Icons.arrow_forward_rounded, color: AppColors.terra),
                              onPressed: doSearch,
                            ),
                          ],
                        ),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1E1D2A) : const Color(0xFFF3F4F6),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (isSearching)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: CircularProgressIndicator(color: AppColors.terra, strokeWidth: 2.5),
                        ),
                      ),
                    if (!isSearching && statusMessage != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            statusMessage!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                            ),
                          ),
                        ),
                      ),
                    if (!isSearching && results.isNotEmpty)
                      Expanded(
                        child: ListView.separated(
                          itemCount: results.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            color: isDark ? Colors.white10 : Colors.black12,
                          ),
                          itemBuilder: (context, idx) {
                            final item = results[idx];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.terra.withOpacity(0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.location_on, size: 18, color: AppColors.terra),
                              ),
                              title: Text(
                                item['display_name'] ?? item['name'] ?? '',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? AppColors.darkInk : AppColors.lightInk,
                                ),
                              ),
                              onTap: () {
                                final lat = double.tryParse(item['lat']?.toString() ?? '');
                                final lon = double.tryParse(item['lon']?.toString() ?? '');
                                if (lat != null && lon != null) {
                                  _mapController.move(LatLng(lat, lon), 14.5);
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Centered map on ${item['name'] ?? 'location'}'),
                                      duration: const Duration(seconds: 2),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              },
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Estimates or retrieves the exact UTC offset for a geographic coordinate,
  /// preferring exact civil telemetry offset if reported by the partner device,
  /// and correctly handling countries with fractional-hour timezones (Nepal, Iran, Afghanistan, Myanmar, etc.).
  /// Falls back to the nearest whole-hour zone for all other locations.
  Duration _estimatePartnerOffset(double lat, double lng, {int? exactOffsetMinutes}) {
    if (exactOffsetMinutes != null) {
      return Duration(minutes: exactOffsetMinutes);
    }
    // India (IST UTC+5:30) — excludes Nepal and Sri Lanka sub-regions below
    if (lat >= 6.0 && lat <= 38.0 && lng >= 68.0 && lng <= 98.0) {
      final isNepal = lat >= 26.0 && lat <= 31.0 && lng >= 80.0 && lng <= 89.0;
      final isSriLanka = lat >= 5.5 && lat <= 10.0 && lng >= 79.5 && lng <= 82.0;
      if (!isNepal && !isSriLanka) return const Duration(hours: 5, minutes: 30);
    }
    // Nepal (NPT UTC+5:45)
    if (lat >= 26.0 && lat <= 31.0 && lng >= 80.0 && lng <= 89.0) {
      return const Duration(hours: 5, minutes: 45);
    }
    // Sri Lanka (SLST UTC+5:30)
    if (lat >= 5.5 && lat <= 10.0 && lng >= 79.5 && lng <= 82.0) {
      return const Duration(hours: 5, minutes: 30);
    }
    // Afghanistan (AFT UTC+4:30)
    if (lat >= 29.0 && lat <= 39.0 && lng >= 60.0 && lng <= 75.0) {
      return const Duration(hours: 4, minutes: 30);
    }
    // Iran (IRST UTC+3:30 standard)
    if (lat >= 25.0 && lat <= 40.0 && lng >= 44.0 && lng <= 64.0) {
      return const Duration(hours: 3, minutes: 30);
    }
    // Myanmar (MMT UTC+6:30)
    if (lat >= 10.0 && lat <= 29.0 && lng >= 92.0 && lng <= 102.0) {
      return const Duration(hours: 6, minutes: 30);
    }
    // Northern Territory / South Australia (ACST UTC+9:30)
    if (lat >= -38.0 && lat <= -10.0 && lng >= 129.0 && lng <= 141.0) {
      return const Duration(hours: 9, minutes: 30);
    }
    // Chatham Islands, NZ (CHAST UTC+12:45)
    if (lat >= -44.5 && lat <= -43.5 && lng >= -177.0 && lng <= -175.0) {
      return const Duration(hours: 12, minutes: 45);
    }
    // Marquesas Islands (MART UTC−9:30)
    if (lat >= -11.0 && lat <= -7.0 && lng >= -141.0 && lng <= -135.0) {
      return const Duration(hours: -9, minutes: -30);
    }
    // General case: round to nearest whole-hour zone (15° per hour), clamped to valid range
    final tzOffsetHours = (lng / 15.0).round().clamp(-12, 14);
    return Duration(hours: tzOffsetHours);
  }
}

