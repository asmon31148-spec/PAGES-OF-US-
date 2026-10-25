import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import '../../../core/theme/app_colors.dart';
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
                    fontFamily: 'serif',
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
            GestureDetector(
              onTap: () => _openVideoPlayer(context, memory.mediaUrl, memory.title),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  color: Colors.black87,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(Icons.videocam, size: 48, color: Colors.white24),
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.terra.withOpacity(0.85),
                          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 8)],
                        ),
                        child: const Icon(Icons.play_arrow, color: Colors.white, size: 32),
                      ),
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('VIDEO 🎬', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 2. Pure Voice Note Area (if no photo/video)
          if (memory.mediaType == 'audio')
            Container(
              padding: const EdgeInsets.all(20),
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (memory.voiceUrl != null) {
                        memoriesProvider.playVoiceWhisper(
                          memory.id,
                          memory.voiceUrl!,
                          ambientAudio: audioProvider,
                        );
                      }
                    },
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.sage,
                      ),
                      child: Icon(
                        isPlayingThisWhisper ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'VOICE WHISPER MESSAGE',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                            color: AppColors.terra,
                          ),
                        ),
                        Text(
                          memory.title,
                          style: TextStyle(
                            fontFamily: 'serif',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.darkInk : AppColors.lightInk,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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
                          fontFamily: 'serif',
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
                                ? 'Playing Voice Whisper...'
                                : 'Listen Voice Whisper 🎙️',
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

  void _openVideoPlayer(BuildContext context, String videoUrl, String title) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (_) => _VideoPlayerModal(videoUrl: videoUrl, title: title),
    );
  }
}

class _VideoPlayerModal extends StatefulWidget {
  final String videoUrl;
  final String title;

  const _VideoPlayerModal({required this.videoUrl, required this.title});

  @override
  State<_VideoPlayerModal> createState() => _VideoPlayerModalState();
}

class _VideoPlayerModalState extends State<_VideoPlayerModal> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        setState(() => _isInitialized = true);
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(widget.title, style: const TextStyle(color: Colors.white, fontSize: 16, fontFamily: 'serif')),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Expanded(
              child: Center(
                child: _isInitialized
                    ? AspectRatio(
                        aspectRatio: _controller.value.aspectRatio,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            VideoPlayer(_controller),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _controller.value.isPlaying
                                      ? _controller.pause()
                                      : _controller.play();
                                });
                              },
                              child: AnimatedOpacity(
                                opacity: _controller.value.isPlaying ? 0.0 : 1.0,
                                duration: const Duration(milliseconds: 200),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.play_arrow, color: Colors.white, size: 40),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : const CircularProgressIndicator(color: AppColors.terra),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
