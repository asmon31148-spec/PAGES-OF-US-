import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/stage_provider.dart';

class StagePresenceView extends StatelessWidget {
  final VoidCallback onOpenMoodModal;
  final VoidCallback onOpenPairModal;
  final VoidCallback onOpenProfileModal;

  const StagePresenceView({
    super.key,
    required this.onOpenMoodModal,
    required this.onOpenPairModal,
    required this.onOpenProfileModal,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;
    final authProvider = context.watch<AuthProvider>();
    final stageProvider = context.watch<StageProvider>();

    final user = authProvider.user;
    final partner = authProvider.partner;
    final isPaired = authProvider.isPaired;
    final myMood = stageProvider.myMood;
    final partnerMood = stageProvider.partnerMood;
    final isPulsing = stageProvider.isPulsing;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 1. User Avatar + Aura + Thought
          GestureDetector(
            onTap: onOpenMoodModal,
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Mood Aura Glow
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (myMood?.glowColor ?? AppColors.sageLight)
                                .withOpacity(0.45),
                            blurRadius: 18,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    // Avatar Image or Initial
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                      backgroundImage: user?.avatarUrl != null
                          ? NetworkImage(user!.avatarUrl!)
                          : null,
                      child: user?.avatarUrl == null
                          ? Text(
                              user?.nickname.isNotEmpty == true
                                  ? user!.nickname.substring(0, 1).toUpperCase()
                                  : 'Y',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppColors.darkInk : AppColors.lightInk,
                              ),
                            )
                          : null,
                    ),
                    // Mood Badge
                    if (myMood != null)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            myMood.emoji,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  user?.nickname ?? 'You',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkInk : AppColors.lightInk,
                  ),
                ),
                Text(
                  user?.thought ?? (myMood?.label ?? 'Set mood aura ✨'),
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                  ),
                ),
              ],
            ),
          ),

          // 2. Central Live Pulse Button & Tether Line
          GestureDetector(
            onTap: () {
              if (authProvider.space != null && user != null) {
                stageProvider.sendPulse(
                  authProvider.space!.id,
                  user.id,
                  user.nickname,
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      partner != null
                          ? 'A little hello sent to ${partner.nickname} ✨'
                          : 'Connect your partner to send a live hello ✨',
                    ),
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: AnimatedScale(
              scale: isPulsing ? 1.25 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? AppColors.darkCard : AppColors.lightCard,
                  border: Border.all(
                    color: isPulsing
                        ? AppColors.terra
                        : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    width: isPulsing ? 2 : 1,
                  ),
                  boxShadow: isPulsing
                      ? [
                          BoxShadow(
                            color: AppColors.terra.withOpacity(0.5),
                            blurRadius: 20,
                            spreadRadius: 6,
                          )
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  isPulsing ? '💖' : '✦',
                  style: TextStyle(
                    fontSize: isPulsing ? 22 : 16,
                    color: AppColors.terra,
                  ),
                ),
              ),
            ),
          ),

          // 3. Partner Avatar or Connect Button
          isPaired && partner != null
              ? Column(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: (partnerMood?.glowColor ?? AppColors.rose)
                                    .withOpacity(0.45),
                                blurRadius: 18,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                        ),
                        CircleAvatar(
                          radius: 30,
                          backgroundColor:
                              isDark ? AppColors.darkCard : AppColors.lightCard,
                          backgroundImage: partner.avatarUrl != null
                              ? NetworkImage(partner.avatarUrl!)
                              : null,
                          child: partner.avatarUrl == null
                              ? Text(
                                  partner.nickname.isNotEmpty
                                      ? partner.nickname.substring(0, 1).toUpperCase()
                                      : 'P',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        isDark ? AppColors.darkInk : AppColors.lightInk,
                                  ),
                                )
                              : null,
                        ),
                        if (partnerMood != null)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppColors.darkSurface
                                    : AppColors.lightSurface,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                partnerMood.emoji,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      partner.nickname,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkInk : AppColors.lightInk,
                      ),
                    ),
                    Text(
                      partner.thought ?? (partnerMood?.label ?? 'Together'),
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                      ),
                    ),
                  ],
                )
              : GestureDetector(
                  onTap: onOpenPairModal,
                  child: Column(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.sageLight.withOpacity(0.12),
                          border: Border.all(
                            color: AppColors.sageLight,
                            style: BorderStyle.solid,
                            width: 1.5,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.add,
                          color: AppColors.sageLight,
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Connect partner',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.sageLight,
                        ),
                      ),
                      Text(
                        'Tap to pair ＋',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                        ),
                      ),
                    ],
                  ),
                ),
        ],
      ),
    );
  }
}
