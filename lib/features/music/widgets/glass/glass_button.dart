import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/glass_tokens.dart';

/// Reusable Apple iOS 26 Liquid Glass Button with spring touch scale animation
class GlassButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final Color? tint;
  final bool isCircle;

  const GlassButton({
    super.key,
    required this.child,
    required this.onTap,
    this.padding,
    this.radius = GlassTokens.radiusPill,
    this.tint,
    this.isCircle = false,
  });

  @override
  State<GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<GlassButton> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    _animController.forward();
  }

  void _onTapUp(TapUpDetails _) {
    _animController.reverse();
    HapticFeedback.lightImpact();
    widget.onTap();
  }

  void _onTapCancel() {
    _animController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        behavior: HitTestBehavior.opaque,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) => Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.radius),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: GlassTokens.blurNormal, sigmaY: GlassTokens.blurNormal),
              child: Container(
                padding: widget.padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  gradient: widget.tint != null
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            widget.tint!.withOpacity(0.35),
                            widget.tint!.withOpacity(0.15),
                          ],
                        )
                      : GlassTokens.glassGradient,
                  borderRadius: BorderRadius.circular(widget.radius),
                  border: Border.all(
                    color: GlassTokens.glassBorder,
                    width: GlassTokens.borderWidth,
                  ),
                  shape: widget.isCircle ? BoxShape.circle : BoxShape.rectangle,
                ),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
