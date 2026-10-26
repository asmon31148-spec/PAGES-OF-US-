import 'package:flutter/material.dart';
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isVault
            ? const Color(0xFF130F1A)
            : (isDark ? AppColors.darkSurface : AppColors.lightSurface),
        border: Border(
          top: BorderSide(
            color: isVault
                ? const Color(0x33E89A8A)
                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
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
                  : (isDark ? AppColors.darkSoft : AppColors.lightSoft);
              textColor = isSelected
                  ? (isDark ? AppColors.darkInk : AppColors.lightInk)
                  : (isDark ? AppColors.darkSoft : AppColors.lightSoft);
              dotColor = isSelected ? AppColors.terra : Colors.transparent;
            }

            return GestureDetector(
              onTap: () => onTabSelected(index),
              behavior: HitTestBehavior.opaque,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    tab['icon'] as IconData,
                    size: 22,
                    color: iconColor,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    tab['label'] as String,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 3),
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
            );
          }),
        ),
      ),
    );
  }
}
