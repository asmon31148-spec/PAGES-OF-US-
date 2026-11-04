import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../providers/theme_provider.dart';
import '../../theme/app_colors.dart';
import 'liquid_glass_theme.dart';

class LiquidGlassSegmentControl extends StatelessWidget {
  final int selectedIndex;
  final List<String> segments;
  final ValueChanged<int> onSegmentSelected;

  const LiquidGlassSegmentControl({
    super.key,
    required this.selectedIndex,
    required this.segments,
    required this.onSegmentSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LiquidGlassTheme.specularBorder(isDark),
        boxShadow: LiquidGlassTheme.cardShadow(isDark),
      ),
      padding: const EdgeInsets.all(1.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(21),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(21),
              gradient: LiquidGlassTheme.cardGloss(isDark),
            ),
            child: Row(
              children: List.generate(segments.length, (index) {
                final isSelected = selectedIndex == index;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onSegmentSelected(index);
                    },
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: isSelected
                            ? (isDark
                                ? LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Colors.white.withOpacity(0.24),
                                      Colors.white.withOpacity(0.10),
                                    ],
                                  )
                                : LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Colors.white,
                                      Colors.white.withOpacity(0.90),
                                    ],
                                  ))
                            : null,
                        border: isSelected
                            ? Border.all(
                                color: isDark
                                    ? Colors.white.withOpacity(0.35)
                                    : Colors.black.withOpacity(0.06),
                                width: 1,
                              )
                            : null,
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: isDark
                                      ? Colors.black.withOpacity(0.35)
                                      : Colors.black.withOpacity(0.08),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        segments[index],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected
                              ? (isDark ? Colors.white : AppColors.lightInk)
                              : (isDark ? Colors.white60 : AppColors.lightSoft),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
