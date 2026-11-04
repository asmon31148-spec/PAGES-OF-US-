import 'dart:ui';
import 'package:flutter/material.dart';
import '../../theme/glass_tokens.dart';

/// Reusable Apple iOS 26 Liquid Glass Modal Bottom Sheet
class GlassSheet extends StatelessWidget {
  final Widget child;
  final String? title;
  final Widget? trailing;
  final double maxHeight;

  const GlassSheet({
    super.key,
    required this.child,
    this.title,
    this.trailing,
    this.maxHeight = 0.85,
  });

  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    String? title,
    Widget? trailing,
    double maxHeight = 0.85,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (ctx) => GlassSheet(
        title: title,
        trailing: trailing,
        maxHeight: maxHeight,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final sheetHeight = mediaQuery.size.height * maxHeight;

    return Container(
      constraints: BoxConstraints(maxHeight: sheetHeight),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(GlassTokens.radiusSheet)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 32,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(GlassTokens.radiusSheet)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: GlassTokens.blurStrong, sigmaY: GlassTokens.blurStrong),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF121417).withOpacity(0.85),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(GlassTokens.radiusSheet)),
              border: Border(
                top: BorderSide(color: Colors.white.withOpacity(0.35), width: 1.2),
                left: BorderSide(color: Colors.white.withOpacity(0.15), width: 1),
                right: BorderSide(color: Colors.white.withOpacity(0.15), width: 1),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag Handle Pill
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 10, bottom: 8),
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white38,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Optional Header Title
                  if (title != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              title!,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          if (trailing != null) trailing!,
                        ],
                      ),
                    ),

                  Flexible(child: child),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
