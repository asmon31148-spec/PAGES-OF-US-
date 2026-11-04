import 'dart:ui';
import 'package:flutter/material.dart';
import '../../theme/glass_tokens.dart';

/// Reusable Apple iOS 26 Liquid Glass Card
/// Features stacked BackdropFilter blur, white gradient tint, and bright border rim
class GlassCard extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final Color? tintColor;
  final Color? borderColor;
  final double blurSigma;
  final VoidCallback? onTap;
  final Border? customBorder;

  const GlassCard({
    super.key,
    required this.child,
    this.radius = GlassTokens.radiusCard,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.tintColor,
    this.borderColor,
    this.blurSigma = GlassTokens.blurNormal,
    this.onTap,
    this.customBorder,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [GlassTokens.softShadow],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            padding: padding ?? const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: tintColor != null
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        tintColor!.withOpacity(0.28),
                        tintColor!.withOpacity(0.08),
                      ],
                    )
                  : GlassTokens.glassGradient,
              borderRadius: BorderRadius.circular(radius),
              border: customBorder ??
                  (borderColor != null
                      ? Border.all(color: borderColor!, width: GlassTokens.borderWidth)
                      : Border.all(
                          color: GlassTokens.glassBorder,
                          width: GlassTokens.borderWidth,
                        )),
            ),
            child: child,
          ),
        ),
      ),
    );

    if (onTap != null) {
      return RepaintBoundary(
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: content,
        ),
      );
    }

    return RepaintBoundary(child: content);
  }
}
