import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/audio_provider.dart';
import '../../../providers/auth_provider.dart';
import 'theme_modal.dart';
import '../../music/screens/music_sanctuary_screen.dart';

class AppTopBar extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final VoidCallback? onOpenProfile;
  final String? overrideTitle;
  final String? overrideSubtitle;
  final VoidCallback? onAvatarTap;
  final bool showThemeToggle;
  final bool forceDark;

  const AppTopBar({
    super.key,
    this.title,
    this.subtitle,
    this.onOpenProfile,
    this.overrideTitle,
    this.overrideSubtitle,
    this.onAvatarTap,
    this.showThemeToggle = true,
    this.forceDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final audioProvider = context.watch<AudioProvider>();
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;

    final effectiveTitle = overrideTitle ?? title ?? 'Pages of Us';
    final effectiveSubtitle = overrideSubtitle ?? subtitle;
    final effectiveProfileTap = onOpenProfile ?? onAvatarTap;
    final isDark = forceDark || themeProvider.isDark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Wordmark & Subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  effectiveTitle,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: forceDark
                        ? AppColors.romanceInk
                        : (isDark ? AppColors.darkInk : AppColors.lightInk),
                  ),
                ),
                if (effectiveSubtitle != null)
                  Text(
                    effectiveSubtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: forceDark
                          ? AppColors.romanceSoft
                          : (isDark ? AppColors.darkSoft : AppColors.lightSoft),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),

          // Actions Row
          Row(
            children: [
              // Music & Atmosphere Studio Screen
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MusicSanctuaryScreen(),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: forceDark
                        ? AppColors.romanceSurface
                        : (isDark ? AppColors.darkSurface : AppColors.lightSurface),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: audioProvider.isPlaying
                          ? AppColors.terra
                          : (forceDark
                              ? AppColors.romanceBorder
                              : (isDark ? AppColors.darkBorder : AppColors.lightBorder)),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '♫',
                        style: TextStyle(
                          fontSize: 12,
                          color: audioProvider.isPlaying ? AppColors.terra : null,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        audioProvider.isPlaying ? 'Playing ♫' : 'Music',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: forceDark
                              ? AppColors.romanceInk
                              : (isDark ? AppColors.darkInk : AppColors.lightInk),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Light / Dark Theme Switcher (Only shown on Stage, Memories, World - NOT in Vault or Music)
              if (showThemeToggle) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => themeProvider.toggleDarkLight(),
                  onLongPress: () => ThemeModal.show(context),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        width: 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      isDark ? '☀️' : '🌙',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 8),

              // Profile Avatar Pill
              GestureDetector(
                onTap: effectiveProfileTap,
                child: Container(
                  width: 34,
                  height: 34,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: forceDark
                          ? [AppColors.romanceRoseGold, AppColors.romanceWine]
                          : [AppColors.sageLight, AppColors.rose],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: CircleAvatar(
                    backgroundColor: forceDark
                        ? AppColors.romanceCard
                        : (isDark ? AppColors.darkCard : AppColors.lightSurface),
                    backgroundImage: user?.avatarUrl != null ? NetworkImage(user!.avatarUrl!) : null,
                    child: user?.avatarUrl == null
                        ? Text(
                            user?.nickname.isNotEmpty == true
                                ? user!.nickname.substring(0, 1).toUpperCase()
                                : 'Y',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: forceDark
                                  ? AppColors.romanceInk
                                  : (isDark ? AppColors.darkInk : AppColors.lightInk),
                            ),
                          )
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
