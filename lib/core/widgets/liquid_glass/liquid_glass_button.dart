import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_colors.dart';
import 'liquid_glass_theme.dart';

/// Luminous Apple Liquid Glass Button / Pill with specular rim light & glowing elevation
class LiquidGlassButton extends StatelessWidget {
  final VoidCallback onPressed;
  final Widget child;
  final IconData? icon;
  final String? label;
  final Color primaryColor;
  final EdgeInsetsGeometry padding;
  final double radius;

  const LiquidGlassButton({
    super.key,
    required this.onPressed,
    this.child = const SizedBox.shrink(),
    this.icon,
    this.label,
    this.primaryColor = AppColors.terra,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    this.radius = 28.0,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    final innerRadius = BorderRadius.circular((radius - 1.2).clamp(0.0, 999.0));

    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onPressed();
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.65),
              Colors.white.withOpacity(0.20),
              primaryColor.withOpacity(0.30),
            ],
          ),
          boxShadow: LiquidGlassTheme.glowShadow(primaryColor),
        ),
        padding: const EdgeInsets.all(1.2), // Specular rim reflection
        child: ClipRRect(
          borderRadius: innerRadius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              padding: padding,
              decoration: BoxDecoration(
                borderRadius: innerRadius,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    primaryColor.withOpacity(0.92),
                    primaryColor.withOpacity(0.82),
                  ],
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 19, color: Colors.white),
                    if (label != null) const SizedBox(width: 8),
                  ],
                  if (label != null)
                    Text(
                      label!,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: Colors.white,
                      ),
                    ),
                  if (label == null && icon == null) child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
