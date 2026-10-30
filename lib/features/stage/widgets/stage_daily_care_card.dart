import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/stage_provider.dart';
import '../screens/daily_care_screen.dart';

/// Living Daily Care & Routine In-Feed Widget
class StageDailyCareCard extends StatelessWidget {
  const StageDailyCareCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;
    final stage = context.watch<StageProvider>();
    final auth = context.watch<AuthProvider>();
    final partner = auth.partner;
    final hasPartner = partner != null;
    final spaceId = auth.space?.id ?? '';
    final currentUserName = auth.user?.nickname ?? 'You';
    final partnerName = partner?.nickname ?? 'Partner';

    final todayKey = DateTime.now().toIso8601String().split('T')[0];
    final items = stage.dailyCareItems.isNotEmpty
        ? stage.dailyCareItems
        : StageProvider.defaultPresetCareItems;
    final completedCount = items.where((i) => i.isCompletedForDate(todayKey)).length;
    final totalCount = items.length;
    final isAllDone = totalCount > 0 && completedCount == totalCount;
    final progress = totalCount > 0 ? (completedCount / totalCount).clamp(0.0, 1.0) : 0.0;

    return Container(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBg : AppColors.lightBg,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 0.8,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header: Icon + Title + Progress Badge + Action
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AppColors.rose.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: const Text('💖', style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(width: 10),
              const Text(
                'DAILY CARE & ROUTINE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.rose,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: isAllDone
                      ? AppColors.gold.withOpacity(0.14)
                      : AppColors.sage.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isAllDone
                        ? AppColors.gold.withOpacity(0.35)
                        : AppColors.sage.withOpacity(0.25),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  isAllDone
                      ? 'All Cared For! 🌸'
                      : (totalCount > 0 ? '$completedCount/$totalCount Done ✦' : 'Daily Routine'),
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: isAllDone ? AppColors.gold : AppColors.sage,
                  ),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => DailyCareScreen.show(context),
                child: const Row(
                  children: [
                    Text(
                      'View All',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.rose,
                      ),
                    ),
                    SizedBox(width: 2),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: AppColors.rose,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 2. Romantic Caring Whisper Note
          Text(
            isAllDone
                ? 'Every loving care checkup completed today! Proud of you both 💖'
                : (hasPartner
                    ? 'Loving mutual checkups for $partnerName & you — tap to check off ✦'
                    : 'Personal daily wellness & health routines — tap to check off ✦'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
            ),
          ),
          const SizedBox(height: 10),

          // 3. Interactive Habit Chips Row (Tap directly on home page to complete!)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                ...items.map((item) {
                  final isDone = item.isCompletedForDate(todayKey);
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        stage.toggleCareItemCompleted(
                          spaceId,
                          item.id,
                          !isDone,
                          currentUserName,
                        );
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                        decoration: BoxDecoration(
                          color: isDone
                              ? (isDark
                                  ? AppColors.sage.withOpacity(0.2)
                                  : AppColors.sage.withOpacity(0.12))
                              : (isDark
                                  ? const Color(0xFF1B2520)
                                  : const Color(0xFFF3F7F5)),
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(
                            color: isDone
                                ? AppColors.sage.withOpacity(0.45)
                                : (isDark
                                    ? AppColors.darkBorder.withOpacity(0.6)
                                    : AppColors.lightBorder.withOpacity(0.8)),
                            width: isDone ? 1.1 : 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isDone ? '✓' : item.icon,
                              style: TextStyle(
                                fontSize: isDone ? 13 : 13,
                                fontWeight: isDone ? FontWeight.bold : FontWeight.normal,
                                color: isDone ? AppColors.sage : null,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              item.title,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: isDone ? FontWeight.w600 : FontWeight.w500,
                                color: isDone
                                    ? AppColors.sage
                                    : (isDark ? AppColors.darkInk : AppColors.lightInk),
                                decoration: isDone ? TextDecoration.lineThrough : null,
                                decorationColor: AppColors.sage,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                // Quick "+ Add" chip
                GestureDetector(
                  onTap: () => DailyCareScreen.show(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                        color: isDark
                            ? AppColors.darkBorder.withOpacity(0.6)
                            : AppColors.lightBorder.withOpacity(0.8),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add_rounded,
                          size: 14,
                          color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          'More',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // 4. Subtle Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 3.5,
              backgroundColor: isDark
                  ? AppColors.darkBorder.withOpacity(0.5)
                  : AppColors.lightBorder.withOpacity(0.6),
              valueColor: AlwaysStoppedAnimation<Color>(
                isAllDone ? AppColors.gold : AppColors.rose,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
