import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/glass_tokens.dart';

/// Dynamic blurred album-art / ambient gradient background for Liquid Glass UI.
/// Creates the depth and refraction surface that liquid glass widgets blur over.
class GlassAmbientBackground extends StatelessWidget {
  final String? imageUrl;
  final Color fallbackColor;
  final Widget child;

  const GlassAmbientBackground({
    super.key,
    this.imageUrl,
    this.fallbackColor = const Color(0xFFD97706),
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. Base dark background
        Positioned.fill(
          child: Container(
            color: GlassTokens.surfaceDark,
          ),
        ),

        // 2. Ambient glowing art or radial mesh
        Positioned.fill(
          child: RepaintBoundary(
            child: AnimatedSwitcher(
              duration: GlassTokens.animNormal,
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: SizedBox.expand(
                key: ValueKey<String>(imageUrl ?? fallbackColor.value.toString()),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (imageUrl != null && imageUrl!.isNotEmpty)
                      CachedNetworkImage(
                        imageUrl: imageUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _buildFallbackMesh(),
                      )
                    else
                      _buildFallbackMesh(),

                    // Deep blur layer across whole background to create liquid ambient glow
                    BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                      child: Container(
                        color: Colors.black.withOpacity(0.42),
                      ),
                    ),

                    // Top and bottom dark gradient overlays for maximum text contrast
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            GlassTokens.surfaceDark.withOpacity(0.75),
                            Colors.transparent,
                            GlassTokens.surfaceDark.withOpacity(0.92),
                          ],
                          stops: const [0.0, 0.45, 0.95],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // 3. Foreground content
        child,
      ],
    );
  }

  Widget _buildFallbackMesh() {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0.4, -0.6),
          radius: 1.2,
          colors: [
            fallbackColor.withOpacity(0.45),
            const Color(0xFF1B2A20),
            GlassTokens.surfaceDark,
          ],
        ),
      ),
    );
  }
}
