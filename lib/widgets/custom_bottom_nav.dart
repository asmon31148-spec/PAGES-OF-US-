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
    final isDark = context.watch<ThemeProvider>().isDark;
    final isVault = currentIndex == 3;

    final tabs = [
      {'label': 'Stage', 'icon': Icons.home_rounded},
      {'label': 'World', 'icon': Icons.public_rounded},
      {'label': 'Memories', 'icon': Icons.photo_library_rounded},
      {'label': 'Vault', 'icon': Icons.lock_rounded},
    ];

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isVault
                      ? [
                          const Color(0xFF1E1428).withOpacity(0.85),
                          const Color(0xFF0F0B14).withOpacity(0.92),
                        ]
                      : (isDark
                          ? [
                              const Color(0xFF181A24).withOpacity(0.85),
                              const Color(0xFF0E1017).withOpacity(0.92),
                            ]
                          : [
                              Colors.white.withOpacity(0.88),
                              Colors.white.withOpacity(0.72),
                            ]),
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: isVault
                      ? const Color(0xFFD4AF37).withOpacity(0.38)
                      : (isDark
                          ? Colors.white.withOpacity(0.18)
                          : Colors.black.withOpacity(0.08)),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isVault
                        ? const Color(0xFFD4AF37).withOpacity(0.15)
                        : Colors.black.withOpacity(0.28),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
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
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onTabSelected(index);
                    },
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: isVault
                                    ? [
                                        const Color(0xFFD4AF37).withOpacity(0.22),
                                        const Color(0xFFD4AF37).withOpacity(0.06),
                                      ]
                                    : [
                                        AppColors.terra.withOpacity(0.20),
                                        AppColors.terra.withOpacity(0.05),
                                      ],
                              )
                            : null,
                        borderRadius: BorderRadius.circular(20),
                        border: isSelected
                            ? Border.all(
                                color: isVault
                                    ? const Color(0xFFD4AF37).withOpacity(0.45)
                                    : AppColors.terra.withOpacity(0.4),
                                width: 1,
                              )
                            : null,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            tab['icon'] as IconData,
                            size: 21,
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
        ),
      ),
    );
  }
}
