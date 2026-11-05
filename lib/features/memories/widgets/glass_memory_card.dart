import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/liquid_glass/liquid_glass_theme.dart';
import '../../../core/widgets/full_screen_video_player.dart';
import '../../../data/models/memory_item.dart';

/// Reusable Apple iOS 26 Liquid Glass Memory Card.
/// Fulfills Part B specifications:
/// - Full-bleed media with rounded 24px corners
/// - Zero thick outer frames or picture-frame borders
/// - Faint 0.5px specular edge catching light top-left
/// - Soft translucent glass strip at bottom with 14 sigma blur
/// - Warm, low-opacity ambient drop shadow (no dark box)
/// - Reusable across Memories, Vault, and Stage screens
class GlassMemoryCard extends StatelessWidget {
  final MemoryItem memory;
  final bool isDark;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final double radius;
  final double? aspectRatio;

  const GlassMemoryCard({
    super.key,
    required this.memory,
    required this.isDark,
    this.onTap,
    this.onDelete,
    this.radius = 24.0,
    this.aspectRatio,
  });

  String _getVideoThumbnail(String url) {
    if (url.contains('cloudinary.com') && url.contains('/upload/')) {
      final extIdx = url.lastIndexOf('.');
      final baseUrl = extIdx != -1 ? url.substring(0, extIdx) : url;
      return baseUrl.replaceFirst('/upload/', '/upload/so_0,w_600,c_fill,q_auto,f_jpg/') + '.jpg';
    }
    return '';
  }

  void _openLightbox(BuildContext context, String url, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            elevation: 0,
            title: Text(title.isNotEmpty ? title : 'Preserved Moment', style: const TextStyle(fontSize: 16)),
          ),
          body: Center(
            child: InteractiveViewer(
              panEnabled: true,
              boundaryMargin: const EdgeInsets.all(20),
              minScale: 0.5,
              maxScale: 4.0,
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.contain,
                placeholder: (_, __) => const Center(
                  child: CircularProgressIndicator(color: AppColors.terra, strokeWidth: 2),
                ),
                errorWidget: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white54, size: 48),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final videoThumb = _getVideoThumbnail(memory.mediaUrl);
    final isVideo = memory.mediaType == 'video';
    final isAudio = memory.mediaType == 'audio';
    final isPhoto = memory.mediaType == 'photo' || (!isVideo && !isAudio);

    Widget content = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LiquidGlassTheme.faintGlassEdge(isDark),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.24) : const Color(0xFFB89578).withOpacity(0.12),
            blurRadius: 14,
            spreadRadius: -2,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(0.5), // Ultra-fine 0.5px specular edge
      child: ClipRRect(
        borderRadius: BorderRadius.circular((radius - 0.5).clamp(0.0, 999.0)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Full-Bleed Media Surface (zero frame, fills entire card)
            if (isPhoto && memory.mediaUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: memory.mediaUrl,
                memCacheWidth: 600,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  color: isDark ? const Color(0xFF141722) : const Color(0xFFFAF7F2),
                  child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.terra)),
                ),
                errorWidget: (_, __, ___) => Container(
                  color: isDark ? const Color(0xFF141722) : const Color(0xFFFAF7F2),
                  child: const Icon(Icons.broken_image, size: 28, color: Colors.white38),
                ),
              )
            else if (isVideo && memory.mediaUrl.isNotEmpty)
              Stack(
                fit: StackFit.expand,
                children: [
                  if (videoThumb.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: videoThumb,
                      memCacheWidth: 600,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: Colors.black26),
                      errorWidget: (_, __, ___) => Container(color: Colors.black26),
                    )
                  else
                    Container(
                      color: isDark ? const Color(0xFF1A1C24) : const Color(0xFFEDE8E0),
                      alignment: Alignment.center,
                      child: const Icon(Icons.movie_filter_rounded, size: 36, color: Colors.white54),
                    ),
                  // Ambient dark tint for video
                  Container(color: Colors.black.withOpacity(0.25)),
                  // Centered sleek play glass pip
                  Center(
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withOpacity(0.52),
                        border: Border.all(color: Colors.white.withOpacity(0.60), width: 1.0),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.35),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 26),
                      ),
                    ),
                  ),
                ],
              )
            else
              // Audio / Whisper fallback canvas
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [const Color(0xFF261D1A), const Color(0xFF141722)]
                        : [const Color(0xFFFFF5EE), const Color(0xFFF7F2FA)],
                  ),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.mic_none_rounded, size: 40, color: AppColors.terra),
              ),

            // 2. Soft Translucent Bottom Glass Strip (Title, Date & Type Badge)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: ClipRRect(
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular((radius - 0.5).clamp(0.0, 999.0)),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.20),
                          Colors.black.withOpacity(0.72),
                        ],
                      ),
                      border: Border(
                        top: BorderSide(
                          color: Colors.white.withOpacity(0.18),
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                memory.title.isNotEmpty ? memory.title : 'Preserved Moment',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 0.1,
                                  shadows: [
                                    Shadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 1)),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            // Clean media type badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.20),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                memory.mediaType.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          memory.createdAt.split('T').first,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withOpacity(0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (aspectRatio != null) {
      content = AspectRatio(aspectRatio: aspectRatio!, child: content);
    }

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        if (onTap != null) {
          onTap!();
        } else if (isPhoto && memory.mediaUrl.isNotEmpty) {
          _openLightbox(context, memory.mediaUrl, memory.title);
        } else if (isVideo && memory.mediaUrl.isNotEmpty) {
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
        }
      },
      behavior: HitTestBehavior.opaque,
      child: content,
    );
  }
}
