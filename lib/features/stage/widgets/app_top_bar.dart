import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/audio_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/stage_provider.dart';
import 'theme_modal.dart';
import '../../music/screens/music_sanctuary_screen.dart';
import '../screens/touch_sanctuary_screen.dart';

class AppTopBar extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final VoidCallback? onOpenProfile;
  final String? overrideTitle;
  final String? overrideSubtitle;
  final VoidCallback? onAvatarTap;
  final bool showThemeToggle;
  final bool forceDark;
  final bool showTouch;
  final bool showMusic;

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
    this.showTouch = false,
    this.showMusic = true,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final audioProvider = context.watch<AudioProvider>();
    final authProvider = context.watch<AuthProvider>();
    final stageProvider = context.watch<StageProvider>();
    final isPartnerTouching = stageProvider.isPartnerTouching;
    final user = authProvider.user;

    final effectiveTitle = overrideTitle ?? title ?? 'Pages of Us';
    final effectiveSubtitle = overrideSubtitle ?? subtitle;
    final effectiveProfileTap = onOpenProfile ?? onAvatarTap;
    final isDark = forceDark || themeProvider.isDark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Wordmark & Subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    effectiveTitle,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                      color: forceDark
                          ? AppColors.romanceInk
                          : (isDark ? AppColors.darkInk : AppColors.lightInk),
                    ),
                  ),
                ),
                if (effectiveSubtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    effectiveSubtitle,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.1,
                      color: forceDark
                          ? AppColors.romanceSoft
                          : (isDark ? AppColors.darkSoft : AppColors.lightSoft),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Actions Row
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Music & Atmosphere Mute / Unmute Quick Toggle Button
              if (showMusic || audioProvider.isPlaying) ...[
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    audioProvider.toggleMasterMute();
                  },
                  onLongPress: () {
                    HapticFeedback.mediumImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MusicSanctuaryScreen(),
                      ),
                    );
                  },
                  child: Container(
                    height: 32,
                    padding: EdgeInsets.symmetric(horizontal: audioProvider.isPlaying ? 10 : 0),
                    width: audioProvider.isPlaying ? null : 32,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: audioProvider.isPlaying
                            ? [
                                AppColors.terra.withOpacity(0.35),
                                AppColors.terra.withOpacity(0.12),
                              ]
                            : [
                                Colors.white.withOpacity(isDark ? 0.08 : 0.45),
                                Colors.white.withOpacity(isDark ? 0.03 : 0.20),
                              ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: audioProvider.isPlaying
                            ? AppColors.terra.withOpacity(0.7)
                            : (isDark ? Colors.white.withOpacity(0.20) : Colors.black.withOpacity(0.12)),
                        width: 1,
                      ),
                      boxShadow: audioProvider.isPlaying
                          ? [
                              BoxShadow(
                                color: AppColors.terra.withOpacity(0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          audioProvider.isPlaying ? Icons.music_note_rounded : Icons.music_off_rounded,
                          size: 15,
                          color: audioProvider.isPlaying
                              ? Colors.white
                              : (forceDark
                                  ? AppColors.romanceInk
                                  : (isDark ? AppColors.darkInk : AppColors.lightInk)),
                        ),
                        if (audioProvider.isPlaying) ...[
                          const SizedBox(width: 4),
                          const Text(
                            'Playing',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],

              // Light / Dark Theme Switcher
              if (showThemeToggle) ...[
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    themeProvider.toggleDarkLight();
                  },
                  onLongPress: () => ThemeModal.show(context),
                  child: Container(
                    width: 32,
                    height: 32,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.12),
                          Colors.white.withOpacity(0.04),
                        ],
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.22),
                        width: 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      isDark ? Icons.wb_sunny_rounded : Icons.nightlight_round,
                      size: 15,
                      color: isDark ? const Color(0xFFFBBF24) : AppColors.terra,
                    ),
                  ),
                ),
              ],

              // Profile Avatar Pill
              GestureDetector(
                onTap: effectiveProfileTap,
                child: Container(
                  width: 32,
                  height: 32,
                  padding: const EdgeInsets.all(1.5),
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
                    backgroundImage: user?.avatarUrl != null ? CachedNetworkImageProvider(user!.avatarUrl!) : null,
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
