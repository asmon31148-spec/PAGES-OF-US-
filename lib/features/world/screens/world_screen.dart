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

class WorldScreen extends StatefulWidget {
  const WorldScreen({super.key});

  @override
  State<WorldScreen> createState() => _WorldScreenState();
}

class _WorldScreenState extends State<WorldScreen> {
  final MapController _mapController = MapController();
  bool _isMapReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.space != null && auth.user != null) {
        context.read<WorldProvider>().initWorldSync(
              spaceId: auth.space!.id,
              currentUserId: auth.user!.id,
              partnerId: auth.partner?.id,
            );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;
    final worldProvider = context.watch<WorldProvider>();
    final authProvider = context.watch<AuthProvider>();

    final user = authProvider.user;
    final partner = authProvider.partner;
    final spaceId = authProvider.space?.id ?? 'default_space';

    final myLoc = user != null ? worldProvider.getUserLocation(user.id) : null;
    final partnerLoc = partner != null ? worldProvider.getUserLocation(partner.id) : null;

    // Calculate distance
    double? distanceKm;
    if (myLoc != null && partnerLoc != null && myLoc.isSharingEnabled && partnerLoc.isSharingEnabled) {
      distanceKm = worldProvider.calculateDistanceKm(
        myLoc.lat,
        myLoc.lng,
        partnerLoc.lat,
        partnerLoc.lng,
      );
    }

    // Default center point: User location, partner location, or romantic default (e.g. Paris or center)
    final defaultCenter = myLoc != null
        ? LatLng(myLoc.lat, myLoc.lng)
        : partnerLoc != null
            ? LatLng(partnerLoc.lat, partnerLoc.lng)
            : const LatLng(48.8566, 2.3522);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            AppTopBar(
              title: 'Our World',
              subtitle: 'Realtime tether & mutual presence',
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
                      height: 380,
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
                              initialZoom: 13.0,
                              onMapReady: () {
                                _isMapReady = true;
                                _fitMapBounds(myLoc, partnerLoc);
                              },
                            ),
                            children: [
                              TileLayer(
                                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.pagesofus.app',
                              ),

                              // Polyline tether between user & partner
                              if (myLoc != null && partnerLoc != null && myLoc.isSharingEnabled && partnerLoc.isSharingEnabled)
                                PolylineLayer(
                                  polylines: [
                                    Polyline(
                                      points: [
                                        LatLng(myLoc.lat, myLoc.lng),
                                        LatLng(partnerLoc.lat, partnerLoc.lng),
                                      ],
                                      color: AppColors.terra.withOpacity(0.8),
                                      strokeWidth: 3.0,
                                    ),
                                  ],
                                ),

                              // Pinned Places Geofence Circles
                              CircleLayer(
                                circles: worldProvider.pinnedPlaces.map((p) {
                                  return CircleMarker(
                                    point: LatLng(p.lat, p.lng),
                                    radius: p.radiusMeters,
                                    useRadiusInMeter: true,
                                    color: AppColors.sage.withOpacity(0.15),
                                    borderColor: AppColors.sage,
                                    borderStrokeWidth: 1.5,
                                  );
                                }).toList(),
                              ),

                              // Markers
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
                                  if (myLoc != null && myLoc.isSharingEnabled)
                                    Marker(
                                      point: LatLng(myLoc.lat, myLoc.lng),
                                      width: 52,
                                      height: 52,
                                      child: _buildAvatarMarker(
                                        name: user?.nickname ?? 'You',
                                        isMe: true,
                                        isDark: isDark,
                                        customLabel: myLoc.customLabel,
                                      ),
                                    ),

                                  // Partner Marker
                                  if (partnerLoc != null && partnerLoc.isSharingEnabled)
                                    Marker(
                                      point: LatLng(partnerLoc.lat, partnerLoc.lng),
                                      width: 52,
                                      height: 52,
                                      child: _buildAvatarMarker(
                                        name: partner?.nickname ?? 'Partner',
                                        isMe: false,
                                        isDark: isDark,
                                        customLabel: partnerLoc.customLabel,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),

                          // Floating Map Controls (Fit bounds & Center me)
                          Positioned(
                            right: 12,
                            bottom: 12,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                FloatingActionButton.small(
                                  heroTag: 'recenter_map',
                                  backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
                                  foregroundColor: isDark ? AppColors.darkInk : AppColors.lightInk,
                                  onPressed: () => _fitMapBounds(myLoc, partnerLoc),
                                  child: const Icon(Icons.crop_free, size: 18),
                                ),
                                const SizedBox(height: 8),
                                FloatingActionButton.small(
                                  heroTag: 'zoom_me',
                                  backgroundColor: AppColors.sage,
                                  foregroundColor: Colors.white,
                                  onPressed: () {
                                    if (myLoc != null) {
                                      _mapController.move(LatLng(myLoc.lat, myLoc.lng), 15.0);
                                    }
                                  },
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
                              label: worldProvider.isLoading ? 'Locating...' : 'Update GPS',
                              color: AppColors.sage,
                              isDark: isDark,
                              onTap: () {
                                if (user != null) {
                                  worldProvider.updateMyPosition(
                                    spaceId: spaceId,
                                    currentUserId: user.id,
                                    nickname: user.nickname,
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
                                  if (user != null) {
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
                            'Your coordinates are shared exclusively with your partner in your private encrypted sanctuary. Turning sharing off hides your location and partner tether simultaneously.',
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
                                onPressed: () => worldProvider.clearLocationHistory(spaceId),
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
      final bounds = LatLngBounds(
        LatLng(myLoc.lat, myLoc.lng),
        LatLng(partnerLoc.lat, partnerLoc.lng),
      );
      _mapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)),
      );
    } else if (myLoc != null) {
      _mapController.move(LatLng(myLoc.lat, myLoc.lng), 14.0);
    } else if (partnerLoc != null) {
      _mapController.move(LatLng(partnerLoc.lat, partnerLoc.lng), 14.0);
    }
  }

  Widget _buildAvatarMarker({
    required String name,
    required bool isMe,
    required bool isDark,
    String? customLabel,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isMe ? AppColors.sage : AppColors.terra,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: (isMe ? AppColors.sage : AppColors.terra).withOpacity(0.4),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '♥',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
        if (customLabel != null && customLabel.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(6),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2)],
            ),
            child: Text(
              customLabel,
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkInk : AppColors.lightInk,
              ),
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
                    Text(
                      userNickname.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: AppColors.sage,
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
                  myLoc?.placeName ?? 'Local Time',
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
                    Text(
                      partnerNickname.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: AppColors.terra,
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
                  partnerLoc?.placeName ?? 'Partner Time',
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

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isTethered
            ? AppColors.terra.withOpacity(0.1)
            : (isDark ? AppColors.darkCard : AppColors.lightCard),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isTethered
              ? AppColors.terra.withOpacity(0.3)
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(isTethered ? '✦' : '○', style: const TextStyle(fontSize: 14, color: AppColors.terra)),
              const SizedBox(width: 8),
              Text(
                isTethered
                    ? '${distanceKm.toStringAsFixed(1)} km apart'
                    : 'Awaiting mutual tether...',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkInk : AppColors.lightInk,
                ),
              ),
            ],
          ),
          Text(
            isTethered ? 'Tether active 🌿' : 'Standby',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isTethered ? AppColors.terra : (isDark ? AppColors.darkSoft : AppColors.lightSoft),
            ),
          ),
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
    if (userId == null) return;
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
              const Text('Where are you right now?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
    if (userId == null) return;
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
                    const Text('Add Pinned Sanctuary Place', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(20),
              height: 400,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  TextField(
                    controller: searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search city, landmark or address...',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.search),
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
                          title: Text(item['display_name'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
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
