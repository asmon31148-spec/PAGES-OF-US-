import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'voice_whisper_player_card.dart';
import '../../../core/theme/app_colors.dart';
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
                onChanged: memoriesProvider.setSearchQuery,
                decoration: InputDecoration(
                  hintText: 'Search memories by title or caption...',
                  hintStyle: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                  ),
                  prefixIcon: const Icon(Icons.search, size: 18),
                  filled: true,
                  fillColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
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
              gradient: const LinearGradient(
                colors: [AppColors.slate, AppColors.forest],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
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
              return _buildMemoryCard(
                context,
                memory,
                memoriesProvider,
                audioProvider,
                isDark,
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.terra
              : (isDark ? AppColors.darkSurface : AppColors.lightSurface),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? AppColors.terra
                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.82,
        ),
        itemCount: memories.length,
        itemBuilder: (context, index) {
          final memory = memories[index];
          final videoThumb = _getVideoThumbnail(memory.mediaUrl);

          return GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              if (memory.mediaType == 'photo' && memory.mediaUrl.isNotEmpty) {
                _openLightbox(context, memory.mediaUrl, memory.title);
              } else if (memory.mediaType == 'video' && memory.mediaUrl.isNotEmpty) {
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
              } else if (memory.mediaType == 'audio') {
                final url = memory.voiceUrl != null && memory.voiceUrl!.isNotEmpty
                    ? memory.voiceUrl!
                    : memory.mediaUrl;
                memoriesProvider.playVoiceWhisper(memory.id, url, ambientAudio: audioProvider);
              }
            },
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 1. Media Preview
                  if (memory.mediaType == 'photo' && memory.mediaUrl.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: memory.mediaUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: isDark ? AppColors.darkCard : AppColors.lightCard,
                        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: isDark ? AppColors.darkCard : AppColors.lightCard,
                        child: const Icon(Icons.broken_image, size: 28),
                      ),
                    )
                  else if (memory.mediaType == 'video' && memory.mediaUrl.isNotEmpty)
                    Stack(
                      fit: StackFit.expand,
                      children: [
                        if (videoThumb.isNotEmpty)
                          CachedNetworkImage(
                            imageUrl: videoThumb,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => _buildFilmFallback(memory, isDark),
                            errorWidget: (_, __, ___) => _buildFilmFallback(memory, isDark),
                          )
                        else
                          _buildFilmFallback(memory, isDark),
                        // Dark tint
                        Container(color: Colors.black.withOpacity(0.25)),
                        // Centered Play Pip
                        Center(
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black.withOpacity(0.6),
                              border: Border.all(color: Colors.white38, width: 1),
                            ),
                            child: const Center(
                              child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    // Audio Tile Graphic
                    Container(
                      color: isDark ? const Color(0xFF141C18) : const Color(0xFFEAEFEA),
                      padding: const EdgeInsets.all(12),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            memoriesProvider.playingVoiceId == memory.id && memoriesProvider.isVoicePlaying
                                ? Icons.pause_circle_filled_rounded
                                : Icons.play_circle_fill_rounded,
                            size: 42,
                            color: AppColors.terra,
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'VOICE NOTE',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                              color: AppColors.terra,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // 2. Type Badge in Top-Right
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            memory.mediaType == 'video'
                                ? Icons.videocam_rounded
                                : (memory.mediaType == 'audio' ? Icons.graphic_eq_rounded : Icons.photo_camera_rounded),
                            size: 11,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            memory.mediaType.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 3. Bottom Gradient Info Strip (Title & Date)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(10, 16, 10, 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.8),
                          ],
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            memory.title.isNotEmpty ? memory.title : 'Memory',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            memory.createdAt.split('T').first,
                            style: TextStyle(
                              fontSize: 9.5,
                              color: Colors.white.withOpacity(0.75),
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
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
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
                      onPressed: () => memoriesProvider.deleteMemory(widget.spaceId, memory.id),
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

                // Attached voice whisper button for photo memories
                if (memory.voiceUrl != null &&
                    memory.voiceUrl!.isNotEmpty &&
                    memory.mediaType != 'audio')
                  Padding(
                    padding: const EdgeInsets.only(top: 6, bottom: 10),
                    child: InkWell(
                      onTap: () {
                        memoriesProvider.playVoiceWhisper(
                          memory.id,
                          memory.voiceUrl!,
                          ambientAudio: audioProvider,
                        );
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isPlayingThisWhisper
                              ? AppColors.terra.withOpacity(0.2)
                              : (isDark ? AppColors.darkCard : AppColors.lightCard),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isPlayingThisWhisper
                                ? AppColors.terra
                                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isPlayingThisWhisper ? Icons.pause_circle : Icons.volume_up,
                              size: 18,
                              color: AppColors.terra,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isPlayingThisWhisper
                                  ? 'Playing Voice Note (${memoriesProvider.voicePosition.inSeconds}s)...'
                                  : 'Play Voice Whisper 🎙️',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.terra,
                              ),
                            ),
                          ],
                        ),
                      ),
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
                child: CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.contain),
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
              // 1. Ambient Blurred Backdrop: Fills space with gorgeous colored lighting
              if (thumbnailUrl.isNotEmpty)
                Positioned.fill(
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: CachedNetworkImage(
                      imageUrl: thumbnailUrl,
                      fit: BoxFit.cover,
                      color: Colors.black.withOpacity(0.4),
                      colorBlendMode: BlendMode.darken,
                      placeholder: (_, __) => _buildFilmFallback(memory, isDark),
                      errorWidget: (_, __, ___) => _buildFilmFallback(memory, isDark),
                    ),
                  ),
                )
              else
                _buildFilmFallback(memory, isDark),

              // 2. High-Resolution Native Frame (Contain fit: NEVER zoomed in, cropped, or stretched)
              if (thumbnailUrl.isNotEmpty)
                Center(
                  child: CachedNetworkImage(
                    imageUrl: thumbnailUrl,
                    fit: BoxFit.contain, // Keeps native aspect ratio completely intact!
                    placeholder: (_, __) => _buildFilmFallback(memory, isDark),
                    errorWidget: (_, __, ___) => _buildFilmFallback(memory, isDark),
                  ),
                ),

              // Soft vignette overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.1),
                      Colors.black.withOpacity(0.35),
                    ],
                  ),
                ),
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
                      width: 1.4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
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

  Widget _buildFilmFallback(MemoryItem memory, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF10201B), const Color(0xFF1F382B), const Color(0xFF0D1612)]
              : [const Color(0xFF2C3E35), const Color(0xFF1A2620), const Color(0xFF3B2F25)],
        ),
      ),
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
