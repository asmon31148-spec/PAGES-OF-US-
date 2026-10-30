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
    this.showMusic = false,
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
              // Touch & Draw Studio Isolated Full-Screen Menu Button (Stage / Home)
              if (showTouch) ...[
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TouchSanctuaryScreen(),
                      ),
                    );
                  },
                  child: Container(
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: isPartnerTouching
                          ? const Color(0xFF10B981).withOpacity(0.18)
                          : (forceDark
                              ? AppColors.romanceSurface
                              : (isDark ? AppColors.darkSurface : AppColors.lightSurface)),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isPartnerTouching
                            ? const Color(0xFF10B981)
                            : (forceDark
                                ? AppColors.romanceBorder
                                : (isDark ? AppColors.darkBorder : AppColors.lightBorder)),
                        width: isPartnerTouching ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.fingerprint_rounded,
                          size: 15,
                          color: isPartnerTouching ? const Color(0xFF10B981) : AppColors.terra,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isPartnerTouching ? 'Touching!' : 'Touch',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isPartnerTouching ? FontWeight.bold : FontWeight.w600,
                            color: isPartnerTouching
                                ? const Color(0xFF10B981)
                                : (forceDark
                                    ? AppColors.romanceInk
                                    : (isDark ? AppColors.darkInk : AppColors.lightInk)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // Music & Atmosphere Studio Shortcut
              if (showMusic || audioProvider.isPlaying) ...[
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
                    height: 32,
                    padding: EdgeInsets.symmetric(horizontal: audioProvider.isPlaying ? 8 : 0),
                    width: audioProvider.isPlaying ? null : 32,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: audioProvider.isPlaying
                          ? AppColors.terra.withOpacity(0.15)
                          : (forceDark
                              ? AppColors.romanceSurface
                              : (isDark ? AppColors.darkSurface : AppColors.lightSurface)),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: audioProvider.isPlaying
                            ? AppColors.terra
                            : (forceDark
                                ? AppColors.romanceBorder
                                : (isDark ? AppColors.darkBorder : AppColors.lightBorder)),
                        width: 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.music_note_rounded,
                          size: 15,
                          color: audioProvider.isPlaying
                              ? AppColors.terra
                              : (forceDark
                                  ? AppColors.romanceInk
                                  : (isDark ? AppColors.darkInk : AppColors.lightInk)),
                        ),
                        if (audioProvider.isPlaying) ...[
                          const SizedBox(width: 3),
                          const Text(
                            'Playing',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.terra,
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
                  onTap: () => themeProvider.toggleDarkLight(),
                  onLongPress: () => ThemeModal.show(context),
                  child: Container(
                    width: 32,
                    height: 32,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
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
