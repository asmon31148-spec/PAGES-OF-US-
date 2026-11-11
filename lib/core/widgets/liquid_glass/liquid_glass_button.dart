import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_colors.dart';

/// Clean, high-contrast action pill with crisp 1px border (zero gradient bleed or glow shadow).
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
    this.radius = 24.0,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onPressed();
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: primaryColor,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.22),
            width: 1.0,
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
    );
  }
}
