import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/mood_aura.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/stage_provider.dart';

class MoodAuraModal extends StatelessWidget {
  const MoodAuraModal({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const MoodAuraModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDark;
    final palette = themeProvider.currentPalette;
    final authProvider = context.watch<AuthProvider>();
    final stageProvider = context.watch<StageProvider>();
    final user = authProvider.user;
    final space = authProvider.space;
    final currentMood = stageProvider.myMood;
    final isGentle = stageProvider.isGentleMode;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF14171E).withOpacity(0.92)
                : Colors.white.withOpacity(0.92),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(
                color: isDark
                    ? Colors.white.withOpacity(0.18)
                    : Colors.white.withOpacity(0.85),
                width: 1.2,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withOpacity(0.40)
                    : const Color(0xFF8C7355).withOpacity(0.12),
                blurRadius: 24,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // 1. Quiet Shell / Stress Relief Banner
                Container(
                  margin: const EdgeInsets.only(bottom: 18),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isGentle
                          ? [
                              const Color(0xFF4338CA).withOpacity(0.35),
                              const Color(0xFF312E81).withOpacity(0.45),
                            ]
                          : [
                              (isDark ? const Color(0xFF1E2230) : const Color(0xFFF1F3FB))
                                  .withOpacity(0.85),
                              (isDark ? const Color(0xFF191C28) : const Color(0xFFE8EBF8))
                                  .withOpacity(0.85),
                            ],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isGentle
                          ? const Color(0xFF818CF8).withOpacity(0.75)
                          : (isDark ? Colors.white12 : Colors.black12),
                      width: isGentle ? 1.5 : 1.0,
                    ),
                    boxShadow: isGentle
                        ? [
                            BoxShadow(
                              color: const Color(0xFF6366F1).withOpacity(0.25),
                              blurRadius: 16,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isGentle
                              ? const Color(0xFF6366F1)
                              : (isDark
                                  ? Colors.white.withOpacity(0.08)
                                  : Colors.black.withOpacity(0.06)),
                        ),
                        child: Icon(
                          Icons.nightlight_round,
                          size: 22,
                          color: isGentle ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Quiet Shell Sanctuary',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                if (isGentle) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF6366F1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'ACTIVE',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isGentle
                                  ? 'Push alerts muted. Partner sees you resting in quiet shell 🌙'
                                  : 'Feeling pressure? Mute alert vibrations and rest with zero guilt.',
                              style: TextStyle(
                                fontSize: 11,
                                height: 1.3,
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: () {
                          if (space != null && user != null) {
                            stageProvider.toggleGentleMode(space.id, user.id);
                            HapticFeedback.mediumImpact();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isGentle ? const Color(0xFF6366F1) : const Color(0xFFE07A5F),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          isGentle ? 'Exit' : 'Enter 🌙',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),

                // 2. Mood Header
                Text(
                  'How are you feeling right now?',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkInk : AppColors.lightInk,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Your partner will softly see your aura glowing around your avatar ✦',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                  ),
                ),
                const SizedBox(height: 14),

                // 3. Grid of Mood Auras
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.95,
                  ),
                  itemCount: moodAuraOptions.length,
                  itemBuilder: (context, index) {
                    final aura = moodAuraOptions[index];
                    final isSelected = currentMood?.id == aura.id;

                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        if (space != null && user != null) {
                          stageProvider.setMyMood(space.id, user.id, aura);
                        }
                        Navigator.pop(context);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withOpacity(isSelected ? 0.12 : 0.05)
                              : Colors.white.withOpacity(isSelected ? 0.90 : 0.60),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? aura.glowColor
                                : (isDark ? Colors.white12 : Colors.black12),
                            width: isSelected ? 2 : 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: aura.glowColor.withOpacity(0.35),
                                    blurRadius: 10,
                                  ),
                                ]
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(aura.emoji, style: const TextStyle(fontSize: 22)),
                            const SizedBox(height: 4),
                            Text(
                              aura.label,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isDark ? AppColors.darkInk : AppColors.lightInk,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),

                Center(
                  child: TextButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      if (space != null && user != null) {
                        stageProvider.setMyMood(space.id, user.id, null);
                      }
                      Navigator.pop(context);
                    },
                    child: Text(
                      'Clear Aura',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
