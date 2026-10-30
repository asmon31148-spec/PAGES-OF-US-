import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/full_screen_video_player.dart';
import '../../../data/models/memory_item.dart';
import '../../../data/models/vault_item.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/stage_provider.dart';
import '../../../providers/vault_provider.dart';
import '../../../providers/memories_provider.dart';
import '../../../providers/world_provider.dart';
import '../widgets/goal_tracker_modal.dart';

class SpotlightItem {
  final String tag;
  final IconData tagIcon;
  final Color tagColor;
  final String title;
  final String subtitle;
  final String badgeText;
  final String? imageUrl;
  final Widget? customVisual;
  final VoidCallback onTap;

  SpotlightItem({
    required this.tag,
    required this.tagIcon,
    required this.tagColor,
    required this.title,
    required this.subtitle,
    required this.badgeText,
    this.imageUrl,
    this.customVisual,
    required this.onTap,
  });
}

class StageMemoryHeroCard extends StatefulWidget {
  final VoidCallback onGoToMemories;
  final ValueChanged<int>? onSelectTab;

  const StageMemoryHeroCard({
    super.key,
    required this.onGoToMemories,
    this.onSelectTab,
  });

  @override
  State<StageMemoryHeroCard> createState() => _StageMemoryHeroCardState();
}

class _StageMemoryHeroCardState extends State<StageMemoryHeroCard> {
  late PageController _pageController;
  Timer? _autoTransitionTimer;
  int _currentIndex = 0;
  bool _isUserHolding = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startAutoTransition();
  }

  void _startAutoTransition() {
    _autoTransitionTimer?.cancel();
    // Non-stop, smooth 6.5s interval transition across app features
    _autoTransitionTimer = Timer.periodic(const Duration(milliseconds: 6500), (timer) {
      if (!_isUserHolding && mounted && _pageController.hasClients) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _autoTransitionTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  List<SpotlightItem> _buildSpotlightFeed({
    required BuildContext context,
    required AuthProvider auth,
    required StageProvider stage,
    required VaultProvider vault,
    required MemoriesProvider memories,
    required WorldProvider world,
  }) {
    final List<SpotlightItem> items = [];
    final partner = auth.partner;
    final partnerName = partner?.nickname ?? 'Partner';

    // 1. VAULT UPDATE / TIMER (From Vaults)
    final timerVaults = vault.vaults.where((v) => v.accessMode == 'timer' && v.specialDate != null).toList();
    if (timerVaults.isNotEmpty) {
      final v = timerVaults.first;
      final days = v.daysRemaining;
      items.add(SpotlightItem(
        tag: 'VAULT COUNTDOWN',
        tagIcon: Icons.hourglass_top_rounded,
        tagColor: const Color(0xFFD4AF37),
        title: v.title,
        subtitle: days > 0
            ? 'Sealed by ${v.creatorName} · Opens automatically in $days days 🗝️'
            : 'Unlocks today in Our Vaults!',
        badgeText: 'Tap to view Vault ✦',
        imageUrl: v.coverImageUrl,
        onTap: () => widget.onSelectTab?.call(3), // Switch to Vault tab
      ));
    } else if (vault.vaults.isNotEmpty) {
      final v = vault.vaults.first;
      items.add(SpotlightItem(
        tag: 'OUR VAULTS',
        tagIcon: Icons.lock_outline_rounded,
        tagColor: const Color(0xFFD4AF37),
        title: v.title,
        subtitle: 'Preserved by ${v.creatorName} · ${v.totalMemoriesCount} memories sealed inside',
        badgeText: 'Open Vault 🗝️',
        imageUrl: v.coverImageUrl,
        onTap: () => widget.onSelectTab?.call(3),
      ));
    }

    // 2. VIDEO SPOTLIGHT (From Memories)
    final videoMems = memories.memories.where((m) => m.mediaType == 'video' && m.mediaUrl.isNotEmpty).toList();
    if (videoMems.isNotEmpty) {
      final vid = videoMems.first;
      String thumb = vid.mediaUrl.replaceAll(RegExp(r'\.(mp4|mov|avi|wmv|webm|mkv)$', caseSensitive: false), '.jpg');
      if (thumb.contains('/video/upload/')) {
        thumb = thumb.replaceAll('/video/upload/', '/video/upload/so_1,f_auto,q_auto/');
      }

      items.add(SpotlightItem(
        tag: 'VIDEO MEMORY REEL',
        tagIcon: Icons.videocam_rounded,
        tagColor: const Color(0xFFE57373),
        title: vid.title.isNotEmpty ? vid.title : 'Our Cinema Moment',
        subtitle: vid.caption.isNotEmpty ? vid.caption : 'A moving memory preserved together in time',
        badgeText: 'Watch Video ▶',
        imageUrl: thumb,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FullScreenVideoPlayer(
                videoUrl: vid.mediaUrl,
                title: vid.title.isNotEmpty ? vid.title : 'Our Memory',
                subtitle: vid.caption,
              ),
            ),
          );
        },
      ));
    }

    // 3. PHOTO MEMORY SLIDE (From Memories)
    final photoMems = memories.memories.where((m) => m.mediaType == 'photo' && m.mediaUrl.isNotEmpty).toList();
    if (photoMems.isNotEmpty) {
      final photo = photoMems.first;
      items.add(SpotlightItem(
        tag: 'CAPTURED MOMENT',
        tagIcon: Icons.photo_camera_back_rounded,
        tagColor: AppColors.rose,
        title: photo.title.isNotEmpty ? photo.title : 'Treasured Memory',
        subtitle: photo.caption.isNotEmpty ? photo.caption : '“Every little memory with you is my favorite view.”',
        badgeText: 'Open Gallery ✦',
        imageUrl: photo.mediaUrl,
        onTap: widget.onGoToMemories,
      ));
    }

    // 4. VOICE WHISPER HIGHLIGHT (From Memories)
    final voiceMems = memories.memories.where((m) => m.mediaType == 'audio' || (m.voiceUrl != null && m.voiceUrl!.isNotEmpty)).toList();
    if (voiceMems.isNotEmpty) {
      final voice = voiceMems.first;
      items.add(SpotlightItem(
        tag: 'VOICE WHISPER',
        tagIcon: Icons.graphic_eq_rounded,
        tagColor: const Color(0xFF81C784),
        title: voice.title.isNotEmpty ? voice.title : 'Audio Whisper',
        subtitle: 'Listen to the voice note preserved by ${voice.authorName}',
        badgeText: 'Listen Now 🎙️',
        onTap: widget.onGoToMemories,
      ));
    }

    // 5. LIVE TETHER & LOCATION UPDATE (From World)
    final partnerWeather = world.partnerWeather;
    final partnerLocation = world.getUserLocation(partner?.id);
    final cityName = partnerLocation?.city ?? partnerLocation?.placeName ?? 'Distance';
    if (partnerWeather != null) {
      items.add(SpotlightItem(
        tag: 'LIVE TETHER',
        tagIcon: Icons.location_on_rounded,
        tagColor: const Color(0xFF64B5F6),
        title: '$partnerName in $cityName',
        subtitle: '${partnerWeather.temperature.round()}°C · ${partnerWeather.condition} · Connected together across distance',
        badgeText: 'Open World Map ✦',
        onTap: () => widget.onSelectTab?.call(1), // Switch to World tab
      ));
    } else if (partner != null && partner.thought != null && partner.thought!.isNotEmpty) {
      items.add(SpotlightItem(
        tag: 'PARTNER THOUGHT',
        tagIcon: Icons.auto_awesome,
        tagColor: const Color(0xFF64B5F6),
        title: partnerName,
        subtitle: '“${partner.thought}” · Connected in sanctuary',
        badgeText: 'Tethered ✦',
        onTap: () => widget.onSelectTab?.call(1),
      ));
    }

    // 6. PINNED NOTE (From Stage Corkboard)
    final notes = stage.pinnedNotes.values.where((n) => n.text.isNotEmpty).toList();
    if (notes.isNotEmpty) {
      final note = notes.first;
      items.add(SpotlightItem(
        tag: 'PINNED CORKBOARD NOTE',
        tagIcon: Icons.push_pin_rounded,
        tagColor: const Color(0xFFFFB74D),
        title: '“${note.text}”',
        subtitle: 'A sweet reminder pinned on the sanctuary corkboard',
        badgeText: 'Read Note 📌',
        onTap: () {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: isDark ? const Color(0xFF241B15) : const Color(0xFFFFF9F5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.push_pin_rounded, color: Color(0xFFFFB74D), size: 22),
                  SizedBox(width: 8),
                  Text('Sanctuary Note 📌', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              content: Text(
                '“${note.text}”',
                style: const TextStyle(fontSize: 15, fontStyle: FontStyle.italic, height: 1.4),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
              ],
            ),
          );
        },
      ));
    }

    // 7. GOAL & DREAM IN PROGRESS (From Goals)
    if (stage.goals.isNotEmpty) {
      final goal = stage.goals.first;
      items.add(SpotlightItem(
        tag: 'DREAM IN PROGRESS',
        tagIcon: Icons.stars_rounded,
        tagColor: const Color(0xFFBA68C8),
        title: goal.title,
        subtitle: goal.category.isNotEmpty ? '${goal.category} · A future we are building together' : 'A special milestone dream for two',
        badgeText: 'View Goals 🎯',
        onTap: () => GoalTrackerModal.show(context),
      ));
    }

    // 8. Fallback / Default Romance Slides if empty
    if (items.isEmpty) {
      items.add(SpotlightItem(
        tag: 'SANCTUARY REEL',
        tagIcon: Icons.favorite_rounded,
        tagColor: AppColors.rose,
        title: '“No matter how many places we go, this is still my favorite view.”',
        subtitle: 'A living diary of your photos, vaults, voice notes & milestones',
        badgeText: 'Add Moments ✦',
        onTap: widget.onGoToMemories,
      ));
      items.add(SpotlightItem(
        tag: 'VAULT TIMER',
        tagIcon: Icons.hourglass_top_rounded,
        tagColor: const Color(0xFFD4AF37),
        title: 'Our First Milestone Vault',
        subtitle: 'Lock confidential films, letters & secrets for special dates',
        badgeText: 'Create Vault 🗝️',
        onTap: () => widget.onSelectTab?.call(3),
      ));
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;
    final auth = context.watch<AuthProvider>();
    final stage = context.watch<StageProvider>();
    final vault = context.watch<VaultProvider>();
    final memories = context.watch<MemoriesProvider>();
    final world = context.watch<WorldProvider>();

    final feed = _buildSpotlightFeed(
      context: context,
      auth: auth,
      stage: stage,
      vault: vault,
      memories: memories,
      world: world,
    );

    return Container(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBg : AppColors.lightBg,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 0.8,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Active Category Tag & "All Memories →"
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: (feed.isNotEmpty ? feed[_currentIndex % feed.length].tagColor : AppColors.rose).withOpacity(0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      feed.isNotEmpty ? feed[_currentIndex % feed.length].tagIcon : Icons.auto_awesome_rounded,
                      size: 11,
                      color: feed.isNotEmpty ? feed[_currentIndex % feed.length].tagColor : AppColors.rose,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      feed.isNotEmpty ? feed[_currentIndex % feed.length].tag : 'SANCTUARY REEL',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: feed.isNotEmpty ? feed[_currentIndex % feed.length].tagColor : AppColors.rose,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: widget.onGoToMemories,
                child: const Text(
                  'Explore All →',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.sageLight,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Story-style mini progress ticks at top of the card
          if (feed.length > 1) ...[
            Row(
              children: List.generate(feed.length, (idx) {
                final isCurrent = (_currentIndex % feed.length) == idx;
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    height: 2.5,
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? (feed[idx].tagColor)
                          : (isDark ? Colors.white12 : Colors.black12),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 10),
          ],

          // Living Reel Card Carousel (Hold to Pause, Tap to Action)
          GestureDetector(
            onLongPressStart: (_) => setState(() => _isUserHolding = true),
            onLongPressEnd: (_) => setState(() => _isUserHolding = false),
            child: SizedBox(
              height: 165,
              child: PageView.builder(
                controller: _pageController,
                itemCount: 10000, // Infinite smooth loop
                onPageChanged: (page) {
                  setState(() => _currentIndex = page % feed.length);
                },
                itemBuilder: (context, rawIndex) {
                  final item = feed[rawIndex % feed.length];
                  return _buildSpotlightCard(item, isDark);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpotlightCard(SpotlightItem item, bool isDark) {
    final hasImage = item.imageUrl != null && item.imageUrl!.isNotEmpty;

    return GestureDetector(
      onTap: item.onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: isDark ? const Color(0xFF161F1A) : const Color(0xFFEBE6DC),
          border: Border.all(
            color: item.tagColor.withOpacity(0.40),
            width: 1.1,
          ),
          boxShadow: [
            BoxShadow(
              color: item.tagColor.withOpacity(0.16),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. If photo/video has an imageUrl, render image with vignette
            if (hasImage) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(17),
                child: CachedNetworkImage(
                  imageUrl: item.imageUrl!,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: Colors.black26),
                  errorWidget: (_, __, ___) => _buildArtisticBackdrop(item, isDark),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(17),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.25),
                      Colors.black.withOpacity(0.72),
                    ],
                  ),
                ),
              ),
            ] else ...[
              // 2. Beautiful category-specific artistic backdrop (Voice, Tether, Dreams, etc.)
              _buildArtisticBackdrop(item, isDark),
            ],

            // Text & Action Content
            Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 220),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Colors.white.withOpacity(0.85),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Bottom Action Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                        decoration: BoxDecoration(
                          color: item.tagColor.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: item.tagColor.withOpacity(0.35), width: 0.9),
                        ),
                        child: Text(
                          item.badgeText,
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: item.tagColor,
                          boxShadow: [
                            BoxShadow(
                              color: item.tagColor.withOpacity(0.45),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.black87,
                          size: 17,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArtisticBackdrop(SpotlightItem item, bool isDark) {
    List<Color> gradientColors;
    Widget graphic;

    switch (item.tag) {
      case 'VOICE WHISPER':
        gradientColors = const [
          Color(0xFF0C2417),
          Color(0xFF163E27),
          Color(0xFF0A1B11),
        ];
        graphic = _buildVoiceWhisperGraphic(item.tagColor);
        break;

      case 'LIVE TETHER':
      case 'PARTNER THOUGHT':
        gradientColors = const [
          Color(0xFF0A1B2E),
          Color(0xFF12345A),
          Color(0xFF071424),
        ];
        graphic = _buildLiveTetherGraphic(item.tagColor);
        break;

      case 'DREAM IN PROGRESS':
        gradientColors = const [
          Color(0xFF220D2F),
          Color(0xFF3B1652),
          Color(0xFF160820),
        ];
        graphic = _buildDreamGraphic(item.tagColor);
        break;

      case 'PINNED CORKBOARD NOTE':
        gradientColors = const [
          Color(0xFF2A1C12),
          Color(0xFF422819),
          Color(0xFF1B110B),
        ];
        graphic = _buildPinnedNoteGraphic(item.tagColor);
        break;

      case 'VAULT COUNTDOWN':
      case 'OUR VAULTS':
      case 'VAULT TIMER':
        gradientColors = const [
          Color(0xFF221C11),
          Color(0xFF382D18),
          Color(0xFF15110B),
        ];
        graphic = _buildVaultGraphic(item.tagColor);
        break;

      default:
        gradientColors = const [
          Color(0xFF241019),
          Color(0xFF3C182A),
          Color(0xFF180A11),
        ];
        graphic = _buildSanctuaryGraphic(item.tagColor);
        break;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(17),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Rich Thematic Gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradientColors,
              ),
            ),
          ),

          // 2. Ambient Radial Lighting Flare from Top-Right
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    item.tagColor.withOpacity(0.30),
                    item.tagColor.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),

          // 3. Category-specific artistic graphic
          graphic,

          // 4. Directional shadow vignette to guarantee text legibility
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                stops: const [0.0, 0.65, 1.0],
                colors: [
                  Colors.black.withOpacity(0.50),
                  Colors.black.withOpacity(0.18),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceWhisperGraphic(Color accentColor) {
    const barHeights = [14.0, 26.0, 42.0, 68.0, 50.0, 84.0, 58.0, 96.0, 72.0, 46.0, 28.0, 16.0];
    return Positioned(
      right: 14,
      top: 12,
      bottom: 12,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (int i = 0; i < barHeights.length; i++) ...[
            Container(
              width: 3.5,
              height: barHeights[i],
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.30 + (barHeights[i] / 96.0) * 0.65),
                borderRadius: BorderRadius.circular(3),
                boxShadow: [
                  if (barHeights[i] > 50)
                    BoxShadow(
                      color: accentColor.withOpacity(0.45),
                      blurRadius: 6,
                      spreadRadius: 0.5,
                    ),
                ],
              ),
            ),
            if (i < barHeights.length - 1) const SizedBox(width: 3.5),
          ],
        ],
      ),
    );
  }

  Widget _buildLiveTetherGraphic(Color accentColor) {
    return Positioned(
      right: -10,
      top: -10,
      bottom: -10,
      width: 140,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Concentric radar rings
          Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: accentColor.withOpacity(0.14), width: 1.2),
            ),
          ),
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: accentColor.withOpacity(0.22), width: 1.2),
            ),
          ),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: accentColor.withOpacity(0.38), width: 1.2),
              color: accentColor.withOpacity(0.08),
            ),
          ),
          // Central tether pulse beacon
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accentColor,
              boxShadow: [
                BoxShadow(
                  color: accentColor.withOpacity(0.65),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          // Watermark compass
          Positioned(
            right: 25,
            child: Icon(
              Icons.explore_rounded,
              size: 72,
              color: accentColor.withOpacity(0.14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDreamGraphic(Color accentColor) {
    return Positioned(
      right: -5,
      top: -10,
      bottom: -10,
      width: 135,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Dream halo rings
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: accentColor.withOpacity(0.16), width: 1.2),
            ),
          ),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: accentColor.withOpacity(0.28), width: 1.2),
            ),
          ),
          // Star icon
          Icon(
            Icons.stars_rounded,
            size: 64,
            color: accentColor.withOpacity(0.42),
          ),
          // Sparkle elements
          Positioned(
            top: 25,
            right: 20,
            child: Text(
              '✦',
              style: TextStyle(
                color: const Color(0xFFFFD54F).withOpacity(0.85),
                fontSize: 18,
              ),
            ),
          ),
          Positioned(
            bottom: 25,
            right: 35,
            child: Text(
              '✨',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withOpacity(0.75),
              ),
            ),
          ),
          Positioned(
            top: 50,
            right: 85,
            child: Text(
              '⋆',
              style: TextStyle(
                color: accentColor.withOpacity(0.75),
                fontSize: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPinnedNoteGraphic(Color accentColor) {
    return Positioned(
      right: 14,
      top: 22,
      child: Icon(
        Icons.push_pin_rounded,
        size: 72,
        color: accentColor.withOpacity(0.16),
      ),
    );
  }

  Widget _buildVaultGraphic(Color accentColor) {
    return Positioned(
      right: 14,
      top: 18,
      child: Icon(
        Icons.hourglass_top_rounded,
        size: 72,
        color: accentColor.withOpacity(0.16),
      ),
    );
  }

  Widget _buildSanctuaryGraphic(Color accentColor) {
    return Positioned(
      right: 14,
      top: 20,
      child: Icon(
        Icons.favorite_rounded,
        size: 72,
        color: accentColor.withOpacity(0.16),
      ),
    );
  }
}
