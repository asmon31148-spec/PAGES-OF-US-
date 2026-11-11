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

    final barBase = isDark
        ? const Color(0xFF101218).withValues(alpha: 0.96)
        : (themeProvider.isEyeComfort
            ? const Color(0xFFFFFBF5).withValues(alpha: 0.97)
            : Colors.white.withValues(alpha: 0.96));

    return Container(
      decoration: BoxDecoration(
        color: barBase,
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.14)
                : Colors.black.withValues(alpha: 0.08),
            width: 1.0,
          ),
        ),
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
