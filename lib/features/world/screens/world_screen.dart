import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/world_provider.dart';
import '../../stage/widgets/app_top_bar.dart';
import '../../stage/widgets/profile_modal.dart';
import '../../../data/models/user_location_model.dart';
import '../../../data/models/pinned_place.dart';

enum MapBasemapStyle {
  dark,
  streets,
  satellite,
}

class WorldScreen extends StatefulWidget {
  const WorldScreen({super.key});

  @override
  State<WorldScreen> createState() => _WorldScreenState();
}

class _WorldScreenState extends State<WorldScreen> {
  final MapController _mapController = MapController();
  bool _isMapReady = false;
  MapBasemapStyle _mapStyle = MapBasemapStyle.dark;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startLiveWorldTracking();
    });
  }

  void _startLiveWorldTracking() {
    final auth = context.read<AuthProvider>();
    final world = context.read<WorldProvider>();
    final spaceId = auth.space?.id ?? auth.user?.spaceId ?? '';
    final user = auth.user;
    final partner = auth.partner;

    if (spaceId.isNotEmpty && user != null) {
      world.initWorldSync(
        spaceId: spaceId,
        currentUserId: user.id,
        partnerId: partner?.id,
      );

      // Automatically acquire GPS and begin continuous real-time movement streaming
      world.startLiveTracking(
        spaceId: spaceId,
        currentUserId: user.id,
        nickname: user.nickname,
        avatarUrl: user.avatarUrl,
      );
    }
  }

  String _getTileUrl(MapBasemapStyle style) {
    switch (style) {
      case MapBasemapStyle.dark:
        // Esri World Dark Gray Canvas: 100% free, zero watermark, zero key
        return 'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Dark_Gray_Base/MapServer/tile/{z}/{y}/{x}';
      case MapBasemapStyle.satellite:
        // Esri World Imagery: 100% free high-res satellite tiles
        return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
      case MapBasemapStyle.streets:
      default:
        // OpenStreetMap Standard: 100% free worldwide street map
        return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
    }
  }

  int _getMaxNativeZoom(MapBasemapStyle style) {
    switch (style) {
      case MapBasemapStyle.satellite:
        return 17; // Esri Imagery max native tile zoom worldwide (prevents white "not available" tiles)
      case MapBasemapStyle.dark:
        return 16;
      case MapBasemapStyle.streets:
      default:
        return 18;
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

    // Auto-start live GPS tracking & cloud sync as soon as credentials become available
    if (spaceId.isNotEmpty && user != null && !worldProvider.isLiveTrackingActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !worldProvider.isLiveTrackingActive) {
          worldProvider.initWorldSync(
            spaceId: spaceId,
            currentUserId: user.id,
            partnerId: partner?.id,
          );
          worldProvider.startLiveTracking(
            spaceId: spaceId,
            currentUserId: user.id,
            nickname: user.nickname,
            avatarUrl: user.avatarUrl,
          );
        }
      });
    }

    final myLoc = (user != null ? worldProvider.getUserLocation(user.id) : null) ?? worldProvider.myLocation;
    final partnerLoc = (partner != null ? worldProvider.getUserLocation(partner.id) : null) ?? worldProvider.partnerLocation;

    // Automatic real-time distance calculation between two partners
    double? distanceKm;
    if (myLoc != null && partnerLoc != null) {
      if ((myLoc.lat != 0.0 || myLoc.lng != 0.0) && (partnerLoc.lat != 0.0 || partnerLoc.lng != 0.0)) {
        distanceKm = worldProvider.calculateDistanceKm(
          myLoc.lat,
          myLoc.lng,
          partnerLoc.lat,
          partnerLoc.lng,
        );
      }
    }
    distanceKm ??= worldProvider.liveDistanceKm;

    // Default center point: User location, partner location, or romantic default
    final defaultCenter = myLoc != null
        ? LatLng(myLoc.lat, myLoc.lng)
        : partnerLoc != null
            ? LatLng(partnerLoc.lat, partnerLoc.lng)
            : const LatLng(22.5726, 88.3639);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      body: SafeArea(
        child: Column(
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
                    // 1. Dual World Clocks Header Card
                    _buildDualClocksCard(
                      isDark: isDark,
                      userNickname: user?.nickname ?? 'You',
                      partnerNickname: partner?.nickname ?? 'Partner',
                      myLoc: myLoc,
                      partnerLoc: partnerLoc,
                      now: worldProvider.now,
                    ),

                    // 2. Live Tether Distance Banner
                    _buildDistanceBanner(
                      isDark: isDark,
                      distanceKm: distanceKm,
                      myLoc: myLoc,
                      partnerLoc: partnerLoc,
                      partnerNickname: partner?.nickname ?? 'Partner',
                    ),

                    // 3. Interactive FlutterMap Card
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      height: 390,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        ),
                        boxShadow: [
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
                              initialZoom: 14.0,
                              maxZoom: 18.0,
                              minZoom: 3.0,
                              onMapReady: () {
                                _isMapReady = true;
                                _fitMapBounds(myLoc, partnerLoc);
                              },
                            ),
                            children: [
                              // Clean, verified tile layer without watermark
                              TileLayer(
                                urlTemplate: _getTileUrl(_mapStyle),
                                userAgentPackageName: 'com.pagesofus.app',
                                maxZoom: 18.0,
                                maxNativeZoom: _getMaxNativeZoom(_mapStyle),
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

                              // Floating Midpoint Distance Badge along the Tether Line
                              if (myLoc != null &&
                                  partnerLoc != null &&
                                  distanceKm != null &&
                                  (myLoc.lat != 0.0 || myLoc.lng != 0.0) &&
                                  (partnerLoc.lat != 0.0 || partnerLoc.lng != 0.0))
                                MarkerLayer(
                                  markers: [
                                    Marker(
                                      point: LatLng(
                                        (myLoc.lat + partnerLoc.lat) / 2,
                                        (myLoc.lng + partnerLoc.lng) / 2,
                                      ),
                                      width: 140,
                                      height: 32,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: (isDark ? const Color(0xFF191823) : Colors.white).withOpacity(0.92),
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(color: AppColors.terra, width: 1.2),
                                          boxShadow: const [
                                            BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Text('♥ ', style: TextStyle(color: AppColors.terra, fontSize: 10)),
                                            Text(
                                              distanceKm < 1.0
                                                  ? '${(distanceKm * 1000).round()} m'
                                                  : '${distanceKm.toStringAsFixed(1)} km',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: isDark ? Colors.white : AppColors.lightInk,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                              // Accuracy circles (Meter-precise GPS rings)
                              CircleLayer(
                                circles: [
                                  // My accuracy ring
                                  if (myLoc != null &&
                                      myLoc.isSharingEnabled &&
                                      myLoc.accuracy != null &&
                                      myLoc.accuracy! > 0)
                                    CircleMarker(
                                      point: LatLng(myLoc.lat, myLoc.lng),
                                      radius: myLoc.accuracy!.clamp(5.0, 150.0),
                                      useRadiusInMeter: true,
                                      color: AppColors.sage.withOpacity(0.12),
                                      borderColor: AppColors.sage.withOpacity(0.45),
                                      borderStrokeWidth: 1.2,
                                    ),

                                  // Partner accuracy ring
                                  if (partnerLoc != null &&
                                      partnerLoc.isSharingEnabled &&
                                      partnerLoc.accuracy != null &&
                                      partnerLoc.accuracy! > 0)
                                    CircleMarker(
                                      point: LatLng(partnerLoc.lat, partnerLoc.lng),
                                      radius: partnerLoc.accuracy!.clamp(5.0, 150.0),
                                      useRadiusInMeter: true,
                                      color: AppColors.terra.withOpacity(0.12),
                                      borderColor: AppColors.terra.withOpacity(0.45),
                                      borderStrokeWidth: 1.2,
                                    ),

                                  // Pinned Places Geofence Circles
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
                                ],
                              ),
                            ],
                          ),

                          // Top-Left Live Status Pill
                          Positioned(
                            top: 12,
                            left: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: worldProvider.gpsStatus.contains('Live')
                                          ? AppColors.sage
                                          : (worldProvider.isLoading ? Colors.orangeAccent : Colors.grey),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    worldProvider.gpsStatus,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white70 : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Top-Right Basemap Style Switcher
                          Positioned(
                            top: 12,
                            right: 12,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  if (_mapStyle == MapBasemapStyle.dark) {
                                    _mapStyle = MapBasemapStyle.streets;
                                  } else if (_mapStyle == MapBasemapStyle.streets) {
                                    _mapStyle = MapBasemapStyle.satellite;
                                  } else {
                                    _mapStyle = MapBasemapStyle.dark;
                                  }
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                                    Text(
                                      _mapStyle == MapBasemapStyle.dark
                                          ? '🌙 Dark'
                                          : (_mapStyle == MapBasemapStyle.streets ? '🗺️ Street' : '🛰️ Satellite'),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white70 : Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // Floating Map Controls (Fit bounds & Center me / partner)
                          Positioned(
                            right: 12,
                            bottom: 12,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Fit Both
                                FloatingActionButton.small(
                                  heroTag: 'recenter_map',
                                  backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
                                  foregroundColor: isDark ? AppColors.darkInk : AppColors.lightInk,
                                  onPressed: () => _fitMapBounds(myLoc, partnerLoc),
                                  tooltip: 'Fit Both',
                                  child: const Icon(Icons.crop_free, size: 18),
                                ),
                                const SizedBox(height: 8),

                                // Center Partner
                                if (partnerLoc != null) ...[
                                  FloatingActionButton.small(
                                    heroTag: 'zoom_partner',
                                    backgroundColor: AppColors.terra,
                                    foregroundColor: Colors.white,
                                    onPressed: () {
                                      _mapController.move(LatLng(partnerLoc.lat, partnerLoc.lng), 15.5);
                                    },
                                    tooltip: 'Center Partner',
                                    child: const Icon(Icons.favorite, size: 16),
                                  ),
                                  const SizedBox(height: 8),
                                ],

                                // Center Me
                                FloatingActionButton.small(
                                  heroTag: 'zoom_me',
                                  backgroundColor: AppColors.sage,
                                  foregroundColor: Colors.white,
                                  onPressed: () {
                                    if (myLoc != null) {
                                      _mapController.move(LatLng(myLoc.lat, myLoc.lng), 15.5);
                                    } else {
                                      _startLiveWorldTracking();
                                    }
                                  },
                                  tooltip: 'Center Me',
                                  child: const Icon(Icons.my_location, size: 18),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 4. Quick Action Grid
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
                                if (user != null && spaceId.isNotEmpty) {
                                  worldProvider.updateMyPosition(
                                    spaceId: spaceId,
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

                    // 5. Privacy & History Options Card
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
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
                          const SizedBox(height: 6),
                          Text(
                            'Your coordinates stream continuously and privately between your two paired phones. Turning sharing off hides your location and partner tether simultaneously.',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  foregroundColor: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                                ),
                                icon: const Icon(Icons.search, size: 14),
                                label: const Text('Search Coordinates', style: TextStyle(fontSize: 11)),
                                onPressed: () => _showSearchModal(context),
                              ),
                              TextButton(
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  foregroundColor: Colors.redAccent,
                                ),
                                onPressed: () {
                                  if (spaceId.isNotEmpty) {
                                    worldProvider.clearLocationHistory(spaceId);
                                  }
                                },
                                child: const Text('Clear History', style: TextStyle(fontSize: 11)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _fitMapBounds(UserLocationData? myLoc, UserLocationData? partnerLoc) {
    if (!_isMapReady) return;

    if (myLoc != null && partnerLoc != null) {
      final latDiff = (myLoc.lat - partnerLoc.lat).abs();
      final lngDiff = (myLoc.lng - partnerLoc.lng).abs();

      // If both are very close (same building/room), zoom comfortably
      if (latDiff < 0.0003 && lngDiff < 0.0003) {
        _mapController.move(LatLng(myLoc.lat, myLoc.lng), 16.0);
      } else {
        final bounds = LatLngBounds(
          LatLng(myLoc.lat, myLoc.lng),
          LatLng(partnerLoc.lat, partnerLoc.lng),
        );
        _mapController.fitCamera(
          CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(55)),
        );
      }
    } else if (myLoc != null) {
      _mapController.move(LatLng(myLoc.lat, myLoc.lng), 15.0);
    } else if (partnerLoc != null) {
      _mapController.move(LatLng(partnerLoc.lat, partnerLoc.lng), 15.0);
    }
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
  }) {
    final myTimeStr = DateFormat('h:mm a').format(now);
    final partnerTimeStr = DateFormat('h:mm a').format(now);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
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
                    const Text('☀️', style: TextStyle(fontSize: 12)),
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
                  myLoc?.placeName ?? 'Locating...',
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

          // Partner Clock
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('🌙', style: TextStyle(fontSize: 12)),
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
                Text(
                  partnerTimeStr,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkInk : AppColors.lightInk,
                  ),
                ),
                Text(
                  partnerLoc?.placeName ?? (partnerLoc != null ? 'Nearby' : 'Awaiting signal...'),
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
  }) {
    final isTethered = distanceKm != null;

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
        color: isTethered
            ? (isDark ? const Color(0xFF221A1A) : const Color(0xFFFFF6F0))
            : (isDark ? AppColors.darkCard : AppColors.lightCard),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isTethered
              ? AppColors.terra.withOpacity(0.4)
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          width: 1.2,
        ),
        boxShadow: [
          if (isTethered)
            BoxShadow(
              color: AppColors.terra.withOpacity(0.08),
              blurRadius: 12,
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
                          'You: ${myLoc?.placeName ?? "Locating..."}',
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
                          '$partnerNickname: ${partnerLoc?.placeName ?? "Awaiting signal"}',
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = ctx.watch<ThemeProvider>().isDark;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(20),
              height: 400,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  TextField(
                    controller: searchCtrl,
                    style: TextStyle(color: isDark ? AppColors.darkInk : AppColors.lightInk),
                    decoration: InputDecoration(
                      hintText: 'Search city, landmark or address...',
                      hintStyle: TextStyle(color: isDark ? AppColors.darkSoft : AppColors.lightSoft),
                      suffixIcon: IconButton(
                        icon: Icon(Icons.search, color: isDark ? AppColors.darkSoft : AppColors.lightSoft),
                        onPressed: () async {
                          setModalState(() => isSearching = true);
                          final res = await context.read<WorldProvider>().searchPlaces(searchCtrl.text);
                          setModalState(() {
                            results = res;
                            isSearching = false;
                          });
                        },
                      ),
                    ),
                  ),
                  if (isSearching) const LinearProgressIndicator(),
                  Expanded(
                    child: ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (context, idx) {
                        final item = results[idx];
                        return ListTile(
                          title: Text(
                            item['display_name'] ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppColors.darkInk : AppColors.lightInk,
                            ),
                          ),
                          onTap: () {
                            final lat = double.tryParse(item['lat'] ?? '');
                            final lon = double.tryParse(item['lon'] ?? '');
                            if (lat != null && lon != null) {
                              _mapController.move(LatLng(lat, lon), 15.0);
                              Navigator.pop(ctx);
                            }
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
