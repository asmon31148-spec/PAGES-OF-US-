import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class CustomBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;

  const CustomBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDark;
    final palette = themeProvider.currentPalette;

    final tabs = [
      {
        'label': 'Stage',
        'icon': Icons.home_rounded,
        'unselectedIcon': Icons.home_outlined,
      },
      {
        'label': 'World',
        'icon': Icons.public_rounded,
        'unselectedIcon': Icons.public_outlined,
      },
      {
        'label': 'Memories',
        'icon': Icons.photo_library_rounded,
        'unselectedIcon': Icons.photo_library_outlined,
      },
      {
        'label': 'Vault',
        'icon': Icons.lock_rounded,
        'unselectedIcon': Icons.lock_outline_rounded,
      },
    ];

    final barTopTint = isDark
        ? palette.gradientColors.first.withOpacity(0.22)
        : palette.accentColor.withOpacity(0.06);
    final barBase = isDark
        ? const Color(0xFF101218).withOpacity(0.95)
        : (themeProvider.isEyeComfort
            ? const Color(0xFFFFFBF5).withOpacity(0.97)
            : Colors.white.withOpacity(0.96));

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.alphaBlend(barTopTint, barBase),
            barBase,
          ],
        ),
        border: Border(
          top: BorderSide(
            color: isDark
                ? palette.specularBorderColor.withOpacity(0.22)
                : Colors.black.withOpacity(0.07),
            width: 0.9,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.35)
                : Colors.black.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 58,
          child: Row(
            children: List.generate(tabs.length, (index) {
              final isSelected = currentIndex == index;
              final tab = tabs[index];

              final iconColor = isSelected
                  ? palette.accentColor
                  : (isDark
                      ? Colors.white.withOpacity(0.55)
                      : const Color(0xFF52525B));

              final textColor = isSelected
                  ? (isDark ? Colors.white : palette.accentColor)
                  : (isDark
                      ? Colors.white.withOpacity(0.55)
                      : const Color(0xFF52525B));

              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onTabSelected(index);
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: isSelected
                            ? palette.accentColor.withOpacity(isDark ? 0.20 : 0.12)
                            : Colors.transparent,
                        border: isSelected
                            ? Border.all(
                                color: isDark
                                    ? palette.accentColor.withOpacity(0.45)
                                    : palette.accentColor.withOpacity(0.30),
                                width: 1,
                              )
                            : null,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            (isSelected ? tab['icon'] : tab['unselectedIcon']) as IconData,
                            size: 21,
                            color: iconColor,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            tab['label'] as String,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: textColor,
                              letterSpacing: 0.15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
