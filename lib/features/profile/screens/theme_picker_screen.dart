import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/theme_registry.dart';
import '../../../core/theme/models/app_theme_data.dart';
import '../../../core/theme/models/theme_palette.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/liquid_glass/liquid_glass_background.dart';
import '../../../core/widgets/liquid_glass/liquid_glass_card.dart';
import '../../../core/widgets/liquid_glass/liquid_glass_theme.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/auth_provider.dart';

/// Screen allowing couples to select and customize their shared living theme.
/// Any change syncs instantly to the partner's phone in real-time.
class ThemePickerScreen extends StatelessWidget {
  const ThemePickerScreen({super.key});

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

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LiquidGlassBackground(
        child: SafeArea(
          child: Column(
            children: [
              // 1. Top Navigation Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.of(context).pop();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.06),
                        ),
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 18,
                          color: palette.primaryText,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Shared Living Themes',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.3,
                              color: palette.primaryText,
                            ),
                          ),
                          Text(
                            'Synchronized in real-time for both of you',
                            style: TextStyle(
                              fontSize: 11,
                              color: palette.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // 2. Active Theme & Partner Info Card
              _buildPartnerStatusHeader(context, themeProvider, palette, isDark),

              // 3. Brightness Mode Toggle (Light / Dark / System)
              _buildBrightnessSelector(context, themeProvider, palette, isDark, spaceId, userId, userName),

              // 4. Scrollable Content: Theme Grid + Performance Modes
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                        child: Text(
                          'COLLECTION (13 THEMES)',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                            color: palette.accentColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),

                      // Theme Grid
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.88,
                        ),
                        itemCount: ThemeRegistry.allThemes.length,
                        itemBuilder: (context, index) {
                          final theme = ThemeRegistry.allThemes[index];
                          final isSelected = theme.id == themeProvider.themeId;

                          return _buildThemeCard(
                            context,
                            theme: theme,
                            isSelected: isSelected,
                            isDark: isDark,
                            palette: palette,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              themeProvider.updateTheme(
                                theme.id,
                                spaceId: spaceId,
                                userId: userId,
                                userName: userName,
                              );
                            },
                          );
                        },
                      ),

                      const SizedBox(height: 24),

                      // 5. Performance Selector
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                        child: Text(
                          'PERFORMANCE & FLUIDITY',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                            color: palette.accentColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      _buildPerformanceSelector(context, themeProvider, palette, isDark, spaceId, userId, userName),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPartnerStatusHeader(
    BuildContext context,
    ThemeProvider themeProvider,
    ThemePalette palette,
    bool isDark,
  ) {
    final updatedByName = themeProvider.lastUpdatedByName ?? 'Partner';
    final updatedAt = themeProvider.lastUpdatedAt;
    String timeAgo = 'recently';
    if (updatedAt != null) {
      final diff = DateTime.now().toUtc().difference(updatedAt);
      if (diff.inMinutes < 1) {
        timeAgo = 'just now';
      } else if (diff.inMinutes < 60) {
        timeAgo = '${diff.inMinutes}m ago';
      } else if (diff.inHours < 24) {
        timeAgo = '${diff.inHours}h ago';
      } else {
        timeAgo = '${diff.inDays}d ago';
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: LiquidGlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        radius: 18,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: themeProvider.currentPalette.accentColor.withValues(alpha: 0.18),
                border: Border.all(
                  color: themeProvider.currentPalette.accentColor.withValues(alpha: 0.45),
                  width: 1.0,
                ),
              ),
              child: Text(
                themeProvider.currentTheme.emoji,
                style: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Active: ${themeProvider.currentTheme.name}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: palette.primaryText,
                    ),
                  ),
                  Text(
                    'Updated by $updatedByName · $timeAgo',
                    style: TextStyle(
                      fontSize: 11,
                      color: palette.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: palette.accentColor.withOpacity(0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'LIVE SYNC',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.6,
                  color: palette.accentColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrightnessSelector(
    BuildContext context,
    ThemeProvider themeProvider,
    ThemePalette palette,
    bool isDark,
    String spaceId,
    String userId,
    String userName,
  ) {
    final modes = [
      {'id': 'light', 'label': 'Light ☀️'},
      {'id': 'dark', 'label': 'Dark 🌙'},
      {'id': 'system', 'label': 'System ⚙️'},
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
      ),
      child: Row(
        children: modes.map((m) {
          final isSelected = themeProvider.brightnessMode == m['id'];
          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                themeProvider.setBrightnessMode(
                  m['id']!,
                  spaceId: spaceId,
                  userId: userId,
                  userName: userName,
                );
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: isSelected
                      ? (isDark ? Colors.white.withValues(alpha: 0.16) : Colors.white)
                      : Colors.transparent,
                  border: isSelected
                      ? Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.25)
                              : Colors.black.withValues(alpha: 0.12),
                          width: 1.0,
                        )
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  m['label']!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? palette.primaryText : palette.secondaryText,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildThemeCard(
    BuildContext context, {
    required AppThemeData theme,
    required bool isSelected,
    required bool isDark,
    required ThemePalette palette,
    required VoidCallback onTap,
  }) {
    final themePalette = theme.palette(isDark);
    final gradientColors = themePalette.gradientColors;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSelected ? palette.accentColor : (isDark ? Colors.white.withOpacity(0.14) : Colors.black.withOpacity(0.06)),
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Clean Canvas Preview with Swatch Accent Band
              Container(
                color: themePalette.canvasBackground,
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 44,
                child: Container(
                  color: themePalette.accentColor.withValues(alpha: isDark ? 0.26 : 0.18),
                ),
              ),

              // 3. Selection Indicator Badge
              if (isSelected)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: palette.accentColor,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),

              // 4. Content (Emoji, Name, Description)
              Positioned(
                bottom: 10,
                left: 10,
                right: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          theme.emoji,
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            theme.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppColors.lightInk,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      theme.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9.5,
                        height: 1.2,
                        color: isDark ? Colors.white.withOpacity(0.75) : AppColors.lightSoft,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPerformanceSelector(
    BuildContext context,
    ThemeProvider themeProvider,
    ThemePalette palette,
    bool isDark,
    String spaceId,
    String userId,
    String userName,
  ) {
    final levels = [
      ThemePerformanceLevel.full,
      ThemePerformanceLevel.balanced,
      ThemePerformanceLevel.batterySaver,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Live Interactive Fluidity Preview Box
        LivingAtmospherePreview(
          palette: palette,
          performance: themeProvider.performanceLevel,
          isDark: isDark,
        ),
        const SizedBox(height: 12),

        // 2. Selectable Mode Cards
        ...levels.map((level) {
          final isSelected = themeProvider.performanceLevel == level;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            child: LiquidGlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              radius: 18,
              tint: isSelected ? palette.accentColor.withOpacity(0.12) : null,
              onTap: () {
                HapticFeedback.selectionClick();
                themeProvider.setPerformanceLevel(
                  level,
                  spaceId: spaceId,
                  userId: userId,
                  userName: userName,
                );
              },
              child: Row(
                children: [
                  Icon(
                    isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                    color: isSelected ? palette.accentColor : palette.secondaryText,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              level.displayName,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: palette.primaryText,
                              ),
                            ),
                            if (isSelected) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  color: palette.accentColor.withOpacity(0.20),
                                  border: Border.all(
                                    color: palette.accentColor.withOpacity(0.40),
                                    width: 0.8,
                                  ),
                                ),
                                child: Text(
                                  'Active',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: palette.accentColor,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          level == ThemePerformanceLevel.full
                              ? 'Living moving blobs & subtle organic drift at 30 fps'
                              : level == ThemePerformanceLevel.balanced
                                  ? 'Gentle slow ambient pulse with lower GPU cycles'
                                  : 'Static frozen gradient with zero animation overhead',
                          style: TextStyle(
                            fontSize: 11,
                            color: isSelected ? palette.primaryText.withOpacity(0.85) : palette.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
