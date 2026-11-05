import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
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
    final isVault = currentIndex == 3;

    final tabs = [
      {'label': 'Stage', 'icon': Icons.home_rounded},
      {'label': 'World', 'icon': Icons.public_rounded},
      {'label': 'Memories', 'icon': Icons.photo_library_rounded},
      {'label': 'Vault', 'icon': Icons.lock_rounded},
    ];

    return Container(
      decoration: BoxDecoration(
        color: isVault
            ? const Color(0xFF130F1A).withOpacity(0.88)
            : (isDark
                ? palette.cardBackground.withOpacity(0.82)
                : Colors.white.withOpacity(0.86)),
        border: Border(
          top: BorderSide(
            color: isVault
                ? const Color(0x66E89A8A)
                : (isDark ? Colors.white.withOpacity(0.25) : Colors.black.withOpacity(0.08)),
            width: 1.0,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.35) : Colors.black.withOpacity(0.05),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(tabs.length, (index) {
              final isSelected = currentIndex == index;
              final tab = tabs[index];

              Color iconColor;
              Color textColor;
              Color dotColor;

              if (isVault) {
                iconColor = isSelected ? const Color(0xFFD4AF37) : AppColors.romanceSoft;
                textColor = isSelected ? Colors.white : AppColors.romanceSoft;
                dotColor = isSelected ? const Color(0xFFD4AF37) : Colors.transparent;
              } else {
                iconColor = isSelected
                    ? palette.accentColor
                    : (isDark ? Colors.white.withOpacity(0.65) : const Color(0xFF6B7280));
                textColor = isSelected
                    ? (isDark ? Colors.white : palette.accentColor)
                    : (isDark ? Colors.white.withOpacity(0.65) : const Color(0xFF6B7280));
                dotColor = isSelected ? palette.accentColor : Colors.transparent;
              }

              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onTabSelected(index);
                },
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isVault
                            ? const Color(0xFFD4AF37).withOpacity(0.20)
                            : (isDark
                                ? palette.accentColor.withOpacity(0.24)
                                : palette.accentColor.withOpacity(0.14)))
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: isSelected
                        ? Border.all(
                            color: isVault
                                ? const Color(0xFFD4AF37).withOpacity(0.50)
                                : (isDark
                                    ? palette.accentColor.withOpacity(0.55)
                                    : palette.accentColor.withOpacity(0.40)),
                            width: 1,
                          )
                        : null,
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: isVault
                                  ? const Color(0xFFD4AF37).withOpacity(0.25)
                                  : palette.accentColor.withOpacity(0.20),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        tab['icon'] as IconData,
                        size: 23,
                        color: iconColor,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tab['label'] as String,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: textColor,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: dotColor,
                        ),
                      ),
                    ],
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
