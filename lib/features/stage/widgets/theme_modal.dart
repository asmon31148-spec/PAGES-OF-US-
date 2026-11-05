import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_registry.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../profile/screens/theme_picker_screen.dart';

class ThemeModal extends StatelessWidget {
  const ThemeModal({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const ThemeModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final authProvider = context.watch<AuthProvider>();
    final isDark = themeProvider.isDark;
    final palette = themeProvider.currentPalette;

    final user = authProvider.user;
    final space = authProvider.space;
    final spaceId = space?.id ?? user?.spaceId ?? '';
    final userId = user?.id ?? '';
    final userName = user?.nickname ?? 'Partner';

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SHARED LIVING ATMOSPHERE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                        color: AppColors.terra,
                      ),
                    ),
                    Text(
                      'Couples Theme',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkInk : AppColors.lightInk,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Light / Dark / System Switcher
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  _buildBrightnessTab('light', 'Light ☀️', themeProvider, isDark, spaceId, userId, userName),
                  _buildBrightnessTab('dark', 'Dark 🌙', themeProvider, isDark, spaceId, userId, userName),
                  _buildBrightnessTab('system', 'System ⚙️', themeProvider, isDark, spaceId, userId, userName),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Open Full Theme Picker Button
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ThemePickerScreen()),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: palette.accentColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: palette.accentColor.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Text(themeProvider.currentTheme.emoji, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Customize All 13 Shared Themes & Performance ✨',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: palette.accentColor,
                        ),
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios_rounded, size: 14, color: palette.accentColor),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Palette options scrollable list
            Expanded(
              child: ListView.builder(
                itemCount: ThemeRegistry.allThemes.length,
                itemBuilder: (context, index) {
                  final theme = ThemeRegistry.allThemes[index];
                  final isSelected = themeProvider.themeId == theme.id;
                  final themePalette = theme.palette(isDark);

                  return GestureDetector(
                    onTap: () {
                      themeProvider.updateTheme(
                        theme.id,
                        spaceId: spaceId,
                        userId: userId,
                        userName: userName,
                      );
                      Navigator.pop(context);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCard : AppColors.lightCard,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? palette.accentColor
                              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                          width: isSelected ? 1.8 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: themePalette.gradientColors.take(2).toList(),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: isSelected
                                ? const Icon(Icons.check, color: Colors.white, size: 18)
                                : Text(theme.emoji, style: const TextStyle(fontSize: 16)),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  theme.name,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? AppColors.darkInk : AppColors.lightInk,
                                  ),
                                ),
                                Text(
                                  theme.description,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrightnessTab(
    String mode,
    String label,
    ThemeProvider themeProvider,
    bool isDark,
    String spaceId,
    String userId,
    String userName,
  ) {
    final isSelected = themeProvider.brightnessMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          themeProvider.setBrightnessMode(
            mode,
            spaceId: spaceId,
            userId: userId,
            userName: userName,
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? Colors.white.withOpacity(0.20) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected
                  ? (isDark ? AppColors.darkInk : AppColors.lightInk)
                  : (isDark ? AppColors.darkSoft : AppColors.lightSoft),
            ),
          ),
        ),
      ),
    );
  }
}
