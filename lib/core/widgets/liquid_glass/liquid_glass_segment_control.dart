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
    final themeProv = context.watch<ThemeProvider>();
    final isDark = themeProv.isDark;
    final palette = themeProv.currentPalette;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: LiquidGlassTheme.flatSurface(isDark, palette: palette),
        borderRadius: BorderRadius.circular(18),
        border: LiquidGlassTheme.crispBorder(isDark, palette: palette),
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
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: isSelected
                      ? (isDark
                          ? Colors.white.withValues(alpha: 0.14)
                          : Colors.white)
                      : Colors.transparent,
                  border: isSelected
                      ? Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.24)
                              : Colors.black.withValues(alpha: 0.10),
                          width: 1.0,
                        )
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  segments[index],
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
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
    );
  }
}
