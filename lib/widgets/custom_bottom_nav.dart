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
    final isDark = context.watch<ThemeProvider>().isDark;
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
            ? const Color(0xFF130F1A)
            : (isDark ? const Color(0xFF10131B) : Colors.white),
        border: Border(
          top: BorderSide(
            color: isVault
                ? const Color(0x66E89A8A)
                : (isDark ? Colors.white.withOpacity(0.24) : Colors.black.withOpacity(0.08)),
            width: 1.2,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.45) : Colors.black.withOpacity(0.06),
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
                    ? AppColors.terra
                    : (isDark ? Colors.white.withOpacity(0.65) : const Color(0xFF6B7280));
                textColor = isSelected
                    ? (isDark ? Colors.white : AppColors.terra)
                    : (isDark ? Colors.white.withOpacity(0.65) : const Color(0xFF6B7280));
                dotColor = isSelected ? AppColors.terra : Colors.transparent;
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
                                ? AppColors.terra.withOpacity(0.24)
                                : AppColors.terra.withOpacity(0.14)))
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: isSelected
                        ? Border.all(
                            color: isVault
                                ? const Color(0xFFD4AF37).withOpacity(0.50)
                                : AppColors.terra.withOpacity(0.45),
                            width: 1.2,
                          )
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
                          fontSize: 10,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: isSelected ? 4 : 0,
                        height: 4,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: dotColor,
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: dotColor.withOpacity(0.6),
                                    blurRadius: 4,
                                  ),
                                ]
                              : null,
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
