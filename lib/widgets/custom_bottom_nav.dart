import 'dart:ui';
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

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                palette.gradientColors.first.withOpacity(isDark ? 0.32 : 0.40),
                (isDark ? const Color(0xFF101216) : Colors.white).withOpacity(isDark ? 0.85 : 0.88),
              ],
            ),
            border: Border(
              top: BorderSide(
                color: palette.specularBorderColor.withOpacity(isDark ? 0.28 : 0.45),
                width: 1.0,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withOpacity(0.35)
                    : palette.accentColor.withOpacity(0.08),
                blurRadius: 18,
                offset: const Offset(0, -4),
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
                          ? Colors.white.withOpacity(0.48)
                          : const Color(0xFF71717A));

                  final textColor = isSelected
                      ? (isDark ? Colors.white : palette.accentColor)
                      : (isDark
                          ? Colors.white.withOpacity(0.48)
                          : const Color(0xFF71717A));

                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onTabSelected(index);
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Center(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 4),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: isSelected
                                ? palette.accentColor.withOpacity(isDark ? 0.20 : 0.14)
                                : Colors.transparent,
                            border: isSelected
                                ? Border.all(
                                    color: isDark
                                        ? palette.accentColor.withOpacity(0.45)
                                        : palette.accentColor.withOpacity(0.35),
                                    width: 1,
                                  )
                                : null,
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: palette.accentColor.withOpacity(0.20),
                                      blurRadius: 10,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AnimatedScale(
                                scale: isSelected ? 1.08 : 1.0,
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeOutBack,
                                child: Icon(
                                  (isSelected ? tab['icon'] : tab['unselectedIcon'])
                                      as IconData,
                                  size: 21,
                                  color: iconColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                tab['label'] as String,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
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
        ),
      ),
    );
  }
}
