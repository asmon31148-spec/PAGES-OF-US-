import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'glass_memory_card.dart';
import 'voice_whisper_player_card.dart';
import '../../../widgets/sanctuary_voice_player.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/liquid_glass/liquid_glass_theme.dart';
import '../../../core/widgets/full_screen_video_player.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/memories_provider.dart';
import '../../../providers/audio_provider.dart';
import '../../../data/models/memory_item.dart';

class MemoryStackView extends StatefulWidget {
  final String spaceId;

  const MemoryStackView({super.key, required this.spaceId});

  @override
  State<MemoryStackView> createState() => _MemoryStackViewState();
}

class _MemoryStackViewState extends State<MemoryStackView> {
  bool _isGridView = false;
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;
    final memoriesProvider = context.watch<MemoriesProvider>();
    final audioProvider = context.watch<AudioProvider>();

    final memories = memoriesProvider.filteredMemories;
    final currentFilter = memoriesProvider.mediaFilter;

    return Column(
      children: [
        // 1. Search Bar & Filter Controls
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Column(
            children: [
              TextField(
                onChanged: (val) {
                  _searchDebounce?.cancel();
                  _searchDebounce = Timer(const Duration(milliseconds: 300), () {
                    memoriesProvider.setSearchQuery(val);
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search memories by title or caption...',
                  hintStyle: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                  ),
                  prefixIcon: const Icon(Icons.search, size: 18),
                  filled: true,
                  fillColor: isDark ? Colors.white.withOpacity(0.08) : Colors.white.withOpacity(0.64),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(
                      color: isDark ? Colors.white.withOpacity(0.14) : Colors.white.withOpacity(0.75),
                      width: 0.8,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(
                      color: isDark ? Colors.white.withOpacity(0.14) : Colors.white.withOpacity(0.75),
                      width: 0.8,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(
                      color: AppColors.terra,
                      width: 1.2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Filter Chips + Grid/Feed Switcher
              Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('all', 'All (${memoriesProvider.memories.length})', memoriesProvider, isDark),
                          const SizedBox(width: 8),
                          _buildFilterChip('photos', 'Photos 📷', memoriesProvider, isDark),
                          const SizedBox(width: 8),
                          _buildFilterChip('videos', 'Videos 🎬', memoriesProvider, isDark),
                          const SizedBox(width: 8),
                          _buildFilterChip('audio', 'Voice 🎙️', memoriesProvider, isDark),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Grid / Feed View Switcher Toggle
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _isGridView = !_isGridView);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _isGridView
                            ? AppColors.terra.withOpacity(0.18)
                            : (isDark ? AppColors.darkSurface : AppColors.lightSurface),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _isGridView
                              ? AppColors.terra
                              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isGridView ? Icons.view_agenda_rounded : Icons.grid_view_rounded,
                            size: 15,
                            color: _isGridView
                                ? AppColors.terra
                                : (isDark ? AppColors.darkSoft : AppColors.lightSoft),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _isGridView ? 'Feed' : 'Grid',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _isGridView
                                  ? AppColors.terra
                                  : (isDark ? AppColors.darkInk : AppColors.lightInk),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // 2. Active Sanctuary Audio Indicator Bar
        if (memoriesProvider.playingVoiceId != null)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? AppColors.forest : AppColors.slate,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18), width: 1.0),
            ),
            child: Row(
              children: [
                const Icon(Icons.graphic_eq_rounded, color: AppColors.sageLight, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        'SANCTUARY AUDIO TRACK',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                          color: AppColors.sageLight,
                        ),
                      ),
                      Text(
                        'Playing Voice Message...',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.stop_circle_rounded, color: Colors.white, size: 24),
                  onPressed: () => memoriesProvider.stopVoiceWhisper(ambientAudio: audioProvider),
                ),
              ],
            ),
          ),

        // 3. Content Display: Empty State OR Grid View OR Vertical Feed
        if (memories.isEmpty)
          Padding(
            padding: const EdgeInsets.all(48.0),
            child: Column(
              children: [
                const Text('📷', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 12),
                Text(
                  'No memories match your filter',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkInk : AppColors.lightInk,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Tap the + button to preserve a photo with voice, a video, or an audio whisper.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                  ),
                ),
              ],
            ),
          )
        else if (_isGridView)
          // 4. Multi-Column Grid View for Photos & Videos (Browse 100+ easily)
          _buildGridView(context, memories, memoriesProvider, audioProvider, isDark)
        else
          // 5. Classic Vertical Card Feed
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            itemCount: memories.length,
            itemBuilder: (context, index) {
              final memory = memories[index];
              return RepaintBoundary(
                child: _buildMemoryCard(
                  context,
                  memory,
                  memoriesProvider,
                  audioProvider,
                  isDark,
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildFilterChip(
    String filterKey,
    String label,
    MemoriesProvider provider,
    bool isDark,
  ) {
    final isSelected = provider.mediaFilter == filterKey;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        provider.setFilter(filterKey);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6.5),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.terra
              : (isDark ? Colors.white.withOpacity(0.08) : Colors.white.withOpacity(0.64)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? AppColors.terra
                : (isDark ? Colors.white.withValues(alpha: 0.16) : Colors.black.withValues(alpha: 0.12)),
            width: 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected
                ? Colors.white
                : (isDark ? AppColors.darkInk : AppColors.lightInk),
          ),
        ),
      ),
    );
  }

  /// High-Density Grid View for Photos & Videos (helps find any memory among 100+ items)
  Widget _buildGridView(
    BuildContext context,
    List<MemoryItem> memories,
    MemoriesProvider memoriesProvider,
    AudioProvider audioProvider,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 40),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.80,
        ),
        itemCount: memories.length,
        itemBuilder: (context, index) {
          final memory = memories[index];
          final audioUrl = (memory.voiceUrl != null && memory.voiceUrl!.trim().isNotEmpty)
              ? memory.voiceUrl!.trim()
              : memory.mediaUrl.trim();
          return GlassMemoryCard(
            memory: memory,
            isDark: isDark,
            onTap: memory.mediaType == 'audio' && audioUrl.isNotEmpty
                ? () => memoriesProvider.playVoiceWhisper(
                      memory.id,
                      audioUrl,
                      ambientAudio: audioProvider,
                    )
                : null,
          );
        },
      ),
    );
  }

  /// Full Vertical Memory Card
  Widget _buildMemoryCard(
    BuildContext context,
    MemoryItem memory,
    MemoriesProvider memoriesProvider,
    AudioProvider audioProvider,
    bool isDark,
  ) {
    final isPlayingThisWhisper =
        memoriesProvider.playingVoiceId == memory.id && memoriesProvider.isVoicePlaying;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: LiquidGlassTheme.flatSurface(isDark),
        borderRadius: BorderRadius.circular(22),
        border: LiquidGlassTheme.crispBorder(isDark),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(21),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // 1. Media Area (Photo or Video preview)
          if (memory.mediaType == 'photo' && memory.mediaUrl.isNotEmpty)
            GestureDetector(
              onTap: () => _openLightbox(context, memory.mediaUrl, memory.title),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: CachedNetworkImage(
                  imageUrl: memory.mediaUrl,
                  memCacheWidth: 800,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: isDark ? AppColors.darkCard : AppColors.lightCard,
                    child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                  errorWidget: (context, url, err) => Container(
                    color: isDark ? AppColors.darkCard : AppColors.lightCard,
                    child: const Icon(Icons.broken_image, size: 36),
                  ),
                ),
              ),
            ),

          if (memory.mediaType == 'video' && memory.mediaUrl.isNotEmpty)
            _buildMemoryVideoThumbnail(context, memory, isDark),

          // 2. Interactive WhatsApp / Instagram-style Voice Message Player
          if (memory.mediaType == 'audio')
            VoiceWhisperPlayerCard(
              memory: memory,
              isDark: isDark,
              memoriesProvider: memoriesProvider,
              audioProvider: audioProvider,
            ),

          // 3. Card Details & Captions
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        memory.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.darkInk : AppColors.lightInk,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                      ),
                      onPressed: () async {
                        final ok = await memoriesProvider.deleteMemory(widget.spaceId, memory.id);
                        if (!ok && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Only the creator can delete this memory or server failed.')),
                          );
                        }
                      },
                    ),
                  ],
                ),
                if (memory.caption.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 8),
                    child: Text(
                      memory.caption,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkInk : AppColors.lightInk,
                        height: 1.4,
                      ),
                    ),
                  ),

                // Attached voice whisper player for photo memories
                if (memory.voiceUrl != null &&
                    memory.voiceUrl!.isNotEmpty &&
                    memory.mediaType != 'audio')
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 12),
                    child: SanctuaryVoicePlayer(
                      id: 'whisper_' + memory.id,
                      audioUrl: memory.voiceUrl!,
                      isDark: isDark,
                      ambientAudio: audioProvider,
                    ),
                  ),

                // Footer timestamp
                Text(
                  'Preserved by ${memory.authorName} · ${memory.createdAt.split("T").first}',
                  style: TextStyle(
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                    color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  }

  void _openLightbox(BuildContext context, String imageUrl, String title) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(10),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: CachedNetworkImage(imageUrl: imageUrl, memCacheWidth: 1080, fit: BoxFit.contain),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  /// Cinematic Video Frame with Ambient Blurred Background & Crisp High-Def Foreground
  /// Solves the unnatural zoomed-in crop for vertical/horizontal phone videos
  Widget _buildMemoryVideoThumbnail(BuildContext context, MemoryItem memory, bool isDark) {
    final thumbnailUrl = _getVideoThumbnail(memory.mediaUrl);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FullScreenVideoPlayer(
              videoUrl: memory.mediaUrl,
              title: memory.title.isNotEmpty ? memory.title : 'Our Memory',
              subtitle: memory.caption.isNotEmpty ? memory.caption : 'Preserved Moment',
            ),
          ),
        );
      },
      child: AspectRatio(
        aspectRatio: 4 / 3, // Generous cinematic ratio comfortable for both portrait & landscape
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Stack(
            fit: StackFit.expand,
            alignment: Alignment.center,
            children: [
              // 1. Clean Dark Media Backdrop
              if (thumbnailUrl.isNotEmpty)
                Positioned.fill(
                  child: CachedNetworkImage(
                    imageUrl: thumbnailUrl,
                    memCacheWidth: 200,
                    fit: BoxFit.cover,
                    color: Colors.black.withValues(alpha: 0.55),
                    colorBlendMode: BlendMode.darken,
                    placeholder: (_, __) => _buildFilmFallback(memory, isDark),
                    errorWidget: (_, __, ___) => _buildFilmFallback(memory, isDark),
                  ),
                )
              else
                _buildFilmFallback(memory, isDark),

              // 2. High-Resolution Native Frame (Contain fit: NEVER zoomed in, cropped, or stretched)
              if (thumbnailUrl.isNotEmpty)
                Center(
                  child: CachedNetworkImage(
                    imageUrl: thumbnailUrl,
                    memCacheWidth: 800,
                    fit: BoxFit.contain, // Keeps native aspect ratio completely intact!
                    placeholder: (_, __) => _buildFilmFallback(memory, isDark),
                    errorWidget: (_, __, ___) => _buildFilmFallback(memory, isDark),
                  ),
                ),

              // Soft vignette overlay
              Container(
                color: Colors.black.withValues(alpha: 0.28),
              ),

              // 3. Luxury Centered Play Button
              Center(
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withOpacity(0.55),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.5),
                      width: 1.0,
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
              ),

              // 4. Video Badge
              Positioned(
                bottom: 10,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.65),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white24, width: 0.8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.videocam_rounded, size: 12, color: AppColors.terra),
                      SizedBox(width: 4),
                      Text(
                        'VIDEO 🎬',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// High-resolution video thumbnail generator with Cloudinary & ImageKit support
  String _getVideoThumbnail(String url) {
    if (url.contains('cloudinary.com') || url.contains('/video/upload/')) {
      String thumb = url.replaceAll(RegExp(r'\.(mp4|mov|avi|wmv|webm|mkv)$', caseSensitive: false), '.jpg');
      if (thumb.contains('/video/upload/')) {
        // High quality frame capture at second 1 with 1080p width
        thumb = thumb.replaceAll('/video/upload/', '/video/upload/so_1,f_auto,q_auto:best,w_1080/');
      }
      return thumb;
    } else if (url.contains('ik.imagekit.io')) {
      return '$url/ik-thumbnail.jpg?tr=w-1080,q-85';
    }
    return '';
  }

  Widget _buildAudioGridTile(
    MemoryItem memory,
    bool isDark,
    MemoriesProvider memoriesProvider,
    AudioProvider? audioProvider,
  ) {
    final isPlaying = memoriesProvider.playingVoiceId == memory.id && memoriesProvider.isVoicePlaying;
    final url = memory.voiceUrl != null && memory.voiceUrl!.isNotEmpty
        ? memory.voiceUrl!
        : memory.mediaUrl;

    return Container(
      color: isDark ? const Color(0xFF1A151D) : const Color(0xFFF6EFEA),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background Sound Waveform silhouette
          Center(
            child: Opacity(
              opacity: isDark ? 0.35 : 0.28,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: List.generate(14, (i) {
                  const heights = [10.0, 18.0, 28.0, 42.0, 22.0, 14.0, 32.0, 50.0, 36.0, 20.0, 30.0, 44.0, 18.0, 10.0];
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    width: 3.5,
                    height: heights[i % heights.length],
                    decoration: BoxDecoration(
                      color: AppColors.terra,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }),
              ),
            ),
          ),

          // Central Floating Play/Pause Action Button
          Center(
            child: GestureDetector(
              onTap: () {
                memoriesProvider.playVoiceWhisper(memory.id, url, ambientAudio: audioProvider);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.terra,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.0),
                ),
                child: Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),

          // Bottom Tag
          Positioned(
            left: 10,
            bottom: 10,
            right: 10,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.mic_rounded, size: 12, color: AppColors.terra),
                    const SizedBox(width: 4),
                    Text(
                      isPlaying ? 'Playing...' : 'Voice Note',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.terra,
                      ),
                    ),
                  ],
                ),
                if (isPlaying)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.terra,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilmFallback(MemoryItem memory, bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF131D19) : const Color(0xFF223029),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.movie_creation_outlined,
              size: 40,
              color: Colors.white.withOpacity(0.35),
            ),
            const SizedBox(height: 6),
            Text(
              memory.title.isNotEmpty ? memory.title : 'Memory Film',
              style: TextStyle(
                color: Colors.white.withOpacity(0.75),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
