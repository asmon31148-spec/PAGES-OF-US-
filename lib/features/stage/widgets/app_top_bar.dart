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
import '../../dossier/screens/obsession_dossier_screen.dart';
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
    final isDarkTheme = context.select<ThemeProvider, bool>((t) => t.isDark);
    final isAudioPlaying = context.select<AudioProvider, bool>((a) => a.isPlaying);
    final user = context.select<AuthProvider, dynamic>((a) => a.user);
    final hasPartner = context.select<AuthProvider, bool>((a) => a.partner != null);
    final partnerBattery = context.select<StageProvider, dynamic>((s) => s.partnerBattery);

    final effectiveTitle = overrideTitle ?? title ?? 'Pages of Us';
    final effectiveSubtitle = overrideSubtitle ?? subtitle;
    final effectiveProfileTap = onOpenProfile ?? onAvatarTap;
    final isDark = forceDark || isDarkTheme;

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
              // Eyes On You / Live Dossier Quick-Access Pill (Home & World Header)
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ObsessionDossierScreen(),
                    ),
                  );
                },
                child: Tooltip(
                  message: 'Eyes On You • Live Dossier',
                  child: Container(
                    height: 30,
                    padding: EdgeInsets.symmetric(
                      horizontal: (hasPartner && partnerBattery != null) ? 8 : 9,
                    ),
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.16)
                            : Colors.black.withValues(alpha: 0.12),
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.visibility_rounded,
                          size: 13.5,
                          color: isDark ? AppColors.darkInk : AppColors.sageDark,
                        ),
                        if (hasPartner && partnerBattery != null) ...[
                          Builder(
                            builder: (context) {
                              final bat = partnerBattery!;
                              final isLow = bat.level <= 15 && !bat.isCharging;
                              final accent = bat.isCharging
                                  ? AppColors.sage
                                  : (isLow
                                      ? const Color(0xFFCC6B5A)
                                      : (isDark ? AppColors.darkInk : AppColors.lightInk));
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(width: 4),
                                  Icon(
                                    bat.isCharging
                                        ? Icons.battery_charging_full_rounded
                                        : Icons.battery_std_rounded,
                                    size: 12.5,
                                    color: accent,
                                  ),
                                  Text(
                                    '${bat.level}%',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: forceDark
                                          ? AppColors.romanceInk
                                          : (isDark ? AppColors.darkInk : AppColors.lightInk),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              // Music & Atmosphere Mute / Unmute Quick Toggle Button
              if (showMusic || isAudioPlaying) ...[
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    context.read<AudioProvider>().toggleMasterMute();
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
                    padding: EdgeInsets.symmetric(horizontal: isAudioPlaying ? 10 : 0),
                    width: isAudioPlaying ? null : 32,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: isAudioPlaying
                          ? AppColors.sage.withValues(alpha: 0.18)
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.05)),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isAudioPlaying
                            ? AppColors.sage.withValues(alpha: 0.65)
                            : (isDark ? Colors.white.withValues(alpha: 0.18) : Colors.black.withValues(alpha: 0.10)),
                        width: 1.0,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isAudioPlaying ? Icons.music_note_rounded : Icons.music_off_rounded,
                          size: 15,
                          color: isAudioPlaying
                              ? Colors.white
                              : (forceDark
                                  ? AppColors.romanceInk
                                  : (isDark ? AppColors.darkInk : AppColors.lightInk)),
                        ),
                        if (isAudioPlaying) ...[
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
                    context.read<ThemeProvider>().toggleDarkLight();
                  },
                  onLongPress: () => ThemeModal.show(context),
                  child: Container(
                    width: 32,
                    height: 32,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.05),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.18)
                            : Colors.black.withValues(alpha: 0.10),
                        width: 1.0,
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
                    border: Border.all(
                      color: forceDark ? AppColors.romanceRoseGold : AppColors.sage,
                      width: 1.0,
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
