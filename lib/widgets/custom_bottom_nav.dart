import 'dart:ui';
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
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            color: isVault
                ? const Color(0xFF110D18).withOpacity(0.92)
                : (isDark
                    ? const Color(0xFF101216).withOpacity(0.85)
                    : Colors.white.withOpacity(0.68)),
            border: Border(
              top: BorderSide(
                color: isVault
                    ? const Color(0x55D4AF37)
                    : (isDark ? Colors.white.withOpacity(0.14) : Colors.white.withOpacity(0.80)),
                width: 0.8,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: isDark ? Colors.black.withOpacity(0.30) : const Color(0xFFB89578).withOpacity(0.14),
                blurRadius: 16,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 50,
              child: Row(
                children: List.generate(tabs.length, (index) {
              final isSelected = currentIndex == index;
              final tab = tabs[index];

              Color iconColor;
              Color textColor;

              if (isVault) {
                iconColor = isSelected ? const Color(0xFFD4AF37) : AppColors.romanceSoft.withOpacity(0.7);
                textColor = isSelected ? const Color(0xFFD4AF37) : AppColors.romanceSoft.withOpacity(0.7);
              } else {
                iconColor = isSelected
                    ? palette.accentColor
                    : (isDark ? Colors.white.withOpacity(0.50) : const Color(0xFF8E8E93));
                textColor = isSelected
                    ? (isDark ? Colors.white : palette.accentColor)
                    : (isDark ? Colors.white.withOpacity(0.50) : const Color(0xFF8E8E93));
              }

              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onTabSelected(index);
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        (isSelected ? tab['icon'] : tab['unselectedIcon']) as IconData,
                        size: 23,
                        color: iconColor,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        tab['label'] as String,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: textColor,
                          letterSpacing: 0.1,
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
    ),
    ),
    );
  }
}
