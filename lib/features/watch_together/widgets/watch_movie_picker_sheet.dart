import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_colors.dart';
import '../models/watch_room_model.dart';
import '../services/watch_video_service.dart';

class WatchMoviePickerSheet extends StatefulWidget {
  final bool isDark;
  final Function(WatchVideoSource source, String? localFilePath) onVideoSelected;

  const WatchMoviePickerSheet({
    super.key,
    required this.isDark,
    required this.onVideoSelected,
  });

  @override
  State<WatchMoviePickerSheet> createState() => _WatchMoviePickerSheetState();
}

class _WatchMoviePickerSheetState extends State<WatchMoviePickerSheet> {
  int _selectedTab = 0; // 0 = YouTube, 1 = Web Link, 2 = Local File

  // YouTube search state
  final TextEditingController _ytSearchController = TextEditingController();
  List<WatchVideoItem> _ytResults = [];
  bool _isSearchingYt = false;
  String? _ytError;
  Timer? _debounceTimer;

  // Web Link state
  final TextEditingController _webUrlController = TextEditingController();
  final TextEditingController _webTitleController = TextEditingController();

  // Local file state
  bool _isPickingLocal = false;

  @override
  void initState() {
    super.initState();
    _loadDefaultYouTubeRecommendations();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _ytSearchController.dispose();
    _webUrlController.dispose();
    _webTitleController.dispose();
    super.dispose();
  }

  void _loadDefaultYouTubeRecommendations() {
    _performYouTubeSearch('romantic movies full free');
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    if (query.trim().isEmpty) return;

    // Check if it's a direct YouTube link pasted
    if (query.contains('youtu.be') || query.contains('youtube.com')) {
      _performYouTubeSearch(query.trim());
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 600), () {
      _performYouTubeSearch(query.trim());
    });
  }

  Future<void> _performYouTubeSearch(String query) async {
    if (query.trim().isEmpty) return;
    setState(() {
      _isSearchingYt = true;
      _ytError = null;
    });

    try {
      final results = await WatchVideoService.instance.searchYouTube(query);
      if (mounted) {
        setState(() {
          _ytResults = results;
          _isSearchingYt = false;
          if (results.isEmpty) {
            _ytError = 'No videos found. Try a different title or paste a YouTube link.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearchingYt = false;
          _ytError = 'Search failed. Please check internet connection.';
        });
      }
    }
  }

  void _selectYouTubeVideo(WatchVideoItem item) {
    HapticFeedback.mediumImpact();
    final source = WatchVideoSource(
      type: 'youtube',
      title: item.title,
      youtubeId: item.id,
      thumbnailUrl: item.thumbnailUrl,
      durationMs: item.durationMs,
    );
    widget.onVideoSelected(source, null);
    Navigator.pop(context);
  }

  void _submitWebUrl() {
    final url = _webUrlController.text.trim();
    if (url.isEmpty || !url.startsWith('http')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid video link starting with http/https'),
          backgroundColor: AppColors.terra,
        ),
      );
      return;
    }

    String title = _webTitleController.text.trim();
    if (title.isEmpty) {
      final uri = Uri.tryParse(url);
      title = uri?.pathSegments.isNotEmpty == true ? uri!.pathSegments.last : 'Web Stream Movie';
    }

    HapticFeedback.mediumImpact();
    final source = WatchVideoSource(
      type: 'web_url',
      title: title,
      webUrl: url,
    );
    widget.onVideoSelected(source, null);
    Navigator.pop(context);
  }

  Future<void> _pickLocalFile() async {
    setState(() {
      _isPickingLocal = true;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        final name = result.files.single.name;

        // Read duration from local file
        final controller = VideoPlayerController.file(File(path));
        await controller.initialize();
        final durationMs = controller.value.duration.inMilliseconds;
        await controller.dispose();

        final source = WatchVideoSource(
          type: 'local',
          title: name,
          durationMs: durationMs,
        );

        if (mounted) {
          HapticFeedback.mediumImpact();
          widget.onVideoSelected(source, path);
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open video file: $e'),
            backgroundColor: AppColors.terra,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPickingLocal = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final bg = isDark ? const Color(0xFF161922) : Colors.white;
    final surface = isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04);
    final border = isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.08);
    final ink = isDark ? AppColors.darkInk : AppColors.lightInk;
    final soft = isDark ? AppColors.darkSoft : AppColors.lightSoft;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black26,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text('🎬', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    Text(
                      'Choose Cinema Movie',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: ink,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, size: 22, color: soft),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Segmented Tabs: YouTube, Web Link, Local File
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: border),
              ),
              child: Row(
                children: [
                  _buildTabItem(0, 'YouTube 🔴', Icons.play_circle_fill_rounded),
                  _buildTabItem(1, 'Web Link 🌐', Icons.link_rounded),
                  _buildTabItem(2, 'Local File 📁', Icons.folder_rounded),
                ],
              ),
            ),
          ),

          const SizedBox(height: 6),

          // Tab Content
          Expanded(
            child: _selectedTab == 0
                ? _buildYouTubeTab(isDark, surface, border, ink, soft)
                : (_selectedTab == 1
                    ? _buildWebLinkTab(isDark, surface, border, ink, soft)
                    : _buildLocalFileTab(isDark, surface, border, ink, soft)),
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem(int index, String title, IconData icon) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() {
            _selectedTab = index;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.terra : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected ? Colors.white : (widget.isDark ? AppColors.darkSoft : AppColors.lightSoft),
              ),
              const SizedBox(width: 5),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : (widget.isDark ? AppColors.darkSoft : AppColors.lightSoft),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildYouTubeTab(bool isDark, Color surface, Color border, Color ink, Color soft) {
    return Column(
      children: [
        // Search Input
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Container(
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border),
            ),
            child: Row(
              children: [
                const SizedBox(width: 14),
                const Icon(Icons.search_rounded, size: 20, color: AppColors.terra),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _ytSearchController,
                    onChanged: _onSearchChanged,
                    onSubmitted: _performYouTubeSearch,
                    style: TextStyle(fontSize: 13.5, color: ink),
                    decoration: InputDecoration(
                      hintText: 'Search movie or paste YouTube link...',
                      hintStyle: TextStyle(fontSize: 12.5, color: soft),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                if (_ytSearchController.text.isNotEmpty)
                  IconButton(
                    icon: Icon(Icons.clear_rounded, size: 18, color: soft),
                    onPressed: () {
                      _ytSearchController.clear();
                      setState(() {
                        _ytResults = [];
                      });
                    },
                  ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18, color: AppColors.terra),
                  onPressed: () => _performYouTubeSearch(_ytSearchController.text),
                ),
              ],
            ),
          ),
        ),

        // Quick Category Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              _buildCategoryChip('Romantic Movies 🎬', 'romantic movies full'),
              const SizedBox(width: 6),
              _buildCategoryChip('Anime 🌸', 'anime full episode'),
              const SizedBox(width: 6),
              _buildCategoryChip('Lo-Fi Beats 🎧', 'lofi hip hop radio'),
              const SizedBox(width: 6),
              _buildCategoryChip('Short Film 🍿', 'award winning short film'),
              const SizedBox(width: 6),
              _buildCategoryChip('Nature 4K 🌿', 'nature relaxation 4k'),
            ],
          ),
        ),

        const SizedBox(height: 4),

        // Video Results List
        Expanded(
          child: _isSearchingYt
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: AppColors.terra),
                      SizedBox(height: 12),
                      Text('Finding video streams...', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                )
              : (_ytError != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Text(_ytError!, textAlign: TextAlign.center, style: TextStyle(color: soft, fontSize: 13)),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: _ytResults.length,
                      itemBuilder: (context, idx) {
                        final video = _ytResults[idx];
                        return _buildYouTubeVideoCard(video, isDark, surface, border, ink, soft);
                      },
                    )),
        ),
      ],
    );
  }

  Widget _buildCategoryChip(String label, String query) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        _ytSearchController.text = query;
        _performYouTubeSearch(query);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: widget.isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: widget.isDark ? Colors.white.withOpacity(0.10) : Colors.black.withOpacity(0.06),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: widget.isDark ? AppColors.darkInk : AppColors.lightInk,
          ),
        ),
      ),
    );
  }

  Widget _buildYouTubeVideoCard(
    WatchVideoItem video,
    bool isDark,
    Color surface,
    Color border,
    Color ink,
    Color soft,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _selectYouTubeVideo(video),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 16:9 Thumbnail with Duration Badge
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    CachedNetworkImage(
                      imageUrl: video.thumbnailUrl,
                      width: 120,
                      height: 72,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        width: 120,
                        height: 72,
                        color: Colors.black26,
                        child: const Icon(Icons.movie_rounded, color: Colors.white38),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        width: 120,
                        height: 72,
                        color: Colors.black26,
                        child: const Icon(Icons.broken_image_rounded, color: Colors.white38),
                      ),
                    ),
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.75),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          video.durationFormatted,
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Title and Channel
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: ink,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      video.channel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: soft,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF0000).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'YouTube Stream',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFFF0000),
                            ),
                          ),
                        ),
                        const Spacer(),
                        const Text(
                          'Select 🍿',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.terra,
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
      ),
    );
  }

  Widget _buildWebLinkTab(bool isDark, Color surface, Color border, Color ink, Color soft) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Stream Any Web Video Link',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: ink),
          ),
          const SizedBox(height: 6),
          Text(
            'Paste any direct streaming link (.mp4, .m3u8, MKV, cloud link). Neither of you needs to download it.',
            style: TextStyle(fontSize: 12, color: soft, height: 1.3),
          ),
          const SizedBox(height: 18),

          // URL Field
          Text('Video Link (URL)*', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: soft)),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: border),
            ),
            child: TextField(
              controller: _webUrlController,
              style: TextStyle(fontSize: 13, color: ink),
              decoration: InputDecoration(
                hintText: 'https://example.com/movie.mp4',
                hintStyle: TextStyle(fontSize: 12, color: soft),
                prefixIcon: const Icon(Icons.link_rounded, size: 20, color: AppColors.terra),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Optional Title Field
          Text('Movie Title (Optional)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: soft)),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: border),
            ),
            child: TextField(
              controller: _webTitleController,
              style: TextStyle(fontSize: 13, color: ink),
              decoration: InputDecoration(
                hintText: 'e.g. Our Summer Vacation Movie',
                hintStyle: TextStyle(fontSize: 12, color: soft),
                prefixIcon: const Icon(Icons.movie_outlined, size: 20, color: AppColors.terra),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
              ),
            ),
          ),

          const Spacer(),

          // Submit Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _submitWebUrl,
              icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
              label: const Text(
                'Set Cinema Stream 🎬',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.terra,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildLocalFileTab(bool isDark, Color surface, Color border, Color ink, Color soft) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Play Offline Video from Phone Storage',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: ink),
          ),
          const SizedBox(height: 6),
          Text(
            'Use this if you already have the exact same movie file downloaded on both your and your partner’s phones.',
            style: TextStyle(fontSize: 12, color: soft, height: 1.3),
          ),
          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: border),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.terra.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.video_collection_rounded, size: 28, color: AppColors.terra),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Offline Mode',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ink),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Requires matching movie duration on both phones.',
                        style: TextStyle(fontSize: 11, color: soft),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isPickingLocal ? null : _pickLocalFile,
              icon: _isPickingLocal
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.folder_open_rounded, color: Colors.white),
              label: Text(
                _isPickingLocal ? 'Opening Storage...' : 'Browse Local Video 📁',
                style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.terra,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
