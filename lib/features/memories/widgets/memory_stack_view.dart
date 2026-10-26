import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'voice_whisper_player_card.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/full_screen_video_player.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/memories_provider.dart';
import '../../../providers/audio_provider.dart';
import '../../../data/models/memory_item.dart';

class MemoryStackView extends StatelessWidget {
  final String spaceId;

  const MemoryStackView({super.key, required this.spaceId});

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;
    final memoriesProvider = context.watch<MemoriesProvider>();
    final audioProvider = context.watch<AudioProvider>();

    final memories = memoriesProvider.filteredMemories;

    return Column(
      children: [
        // 1. Search Bar & Filter Chips
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
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('all', 'All Memories (${memoriesProvider.memories.length})', memoriesProvider, isDark),
                    const SizedBox(width: 8),
                    _buildFilterChip('photos', 'Photos 📷', memoriesProvider, isDark),
                    const SizedBox(width: 8),
                    _buildFilterChip('videos', 'Videos 🎬', memoriesProvider, isDark),
                    const SizedBox(width: 8),
                    _buildFilterChip('audio', 'Voice Whispers 🎙️', memoriesProvider, isDark),
                  ],
                ),
              ),
            ],
          ),
        ),

        // 2. Upper Audio Track: Plays pure Voice Messages isolates
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
                const Icon(Icons.graphic_eq, color: AppColors.sageLight, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
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
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.stop_circle, color: Colors.white, size: 24),
                  onPressed: () => memoriesProvider.stopVoiceWhisper(ambientAudio: audioProvider),
                ),
              ],
            ),
          ),

        // 3. Memory Cards Feed
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
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
      onTap: () => provider.setFilter(filterKey),
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
                      onPressed: () => memoriesProvider.deleteMemory(spaceId, memory.id),
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

                // 4. Attached 30-sec Voice Whisper Pill (Below photo memory)
                if (memory.voiceUrl != null && memory.mediaType == 'photo')
                  GestureDetector(
                    onTap: () {
                      memoriesProvider.playVoiceWhisper(
                        memory.id,
                        memory.voiceUrl!,
                        ambientAudio: audioProvider,
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.only(top: 6, bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isPlayingThisWhisper
                            ? AppColors.terra.withOpacity(0.15)
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
                                ? 'Playing Voice Note (${memoriesProvider.voicePosition.inSeconds}s / ${memoriesProvider.voiceDuration.inSeconds > 0 ? memoriesProvider.voiceDuration.inSeconds : 30}s)...'
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
        aspectRatio: 16 / 9,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Stack(
            fit: StackFit.expand,
            alignment: Alignment.center,
            children: [
              // 1. If Cloudinary video thumbnail available
              if (thumbnailUrl.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: thumbnailUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => _buildFilmFallback(memory, isDark),
                  errorWidget: (_, __, ___) => _buildFilmFallback(memory, isDark),
                )
              else
                _buildFilmFallback(memory, isDark),

              // Soft vignette overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.15),
                      Colors.black.withOpacity(0.4),
                    ],
                  ),
                ),
              ),

              // Sleek, Luxury Play Button (properly centered, not stretched by Stack)
              Center(
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withOpacity(0.55),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.4),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.45),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ),

              // Video Badge
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

  String _getVideoThumbnail(String url) {
    if (url.contains('cloudinary.com') || url.contains('/video/upload/')) {
      String thumb = url.replaceAll(RegExp(r'\.(mp4|mov|avi|wmv|webm|mkv)$', caseSensitive: false), '.jpg');
      if (thumb.contains('/video/upload/')) {
        thumb = thumb.replaceAll('/video/upload/', '/video/upload/so_1,f_auto,q_auto/');
      }
      return thumb;
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
