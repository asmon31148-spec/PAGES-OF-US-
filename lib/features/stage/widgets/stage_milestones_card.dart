import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/stage_provider.dart';
import 'goal_tracker_modal.dart';

/// Living Milestones & Dreams In-Feed Widget
class StageMilestonesCard extends StatelessWidget {
  const StageMilestonesCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;
    final stageProvider = context.watch<StageProvider>();
    final authProvider = context.watch<AuthProvider>();
    final spaceId = authProvider.space?.id ?? 'default_space';
    final nickname = authProvider.user?.nickname ?? 'You';

    final goals = stageProvider.goals.isNotEmpty
        ? stageProvider.goals
        : StageProvider.defaultPresetGoals;

    final completedCount = goals.where((g) => g.isCompleted).length;
    final totalCount = goals.length;
    final progress = totalCount > 0 ? (completedCount / totalCount).clamp(0.0, 1.0) : 0.0;
    final nextGoal = goals.where((g) => !g.isCompleted).firstOrNull ?? goals.lastOrNull;

    return GestureDetector(
      onTap: () => GoalTrackerModal.show(context),
      behavior: HitTestBehavior.opaque,
      child: Container(
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
            // Top Header: Label + Celebration Day Badge + Action
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: AppColors.terra.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: const Text('🎯', style: TextStyle(fontSize: 16)),
                ),
                const SizedBox(width: 10),
                const Text(
                  'MILESTONES & DREAMS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.terra,
                    letterSpacing: 0.8,
                  ),
                ),
                const Spacer(),
                const Row(
                  children: [
                    Text(
                      'Explore All',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.terra,
                      ),
                    ),
                    SizedBox(width: 2),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: AppColors.terra,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Next Active Goal & Living Progress Sub-Card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1B2520) : const Color(0xFFF3F7F5),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: isDark
                      ? AppColors.darkBorder.withOpacity(0.6)
                      : AppColors.lightBorder.withOpacity(0.8),
                  width: 0.8,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.terra.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          nextGoal?.icon ?? '✨',
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nextGoal?.isCompleted == true
                                  ? 'ALL FIRSTS ACHIEVED! ✦'
                                  : 'NEXT UP ON YOUR BUCKET LIST ✦',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                                color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              nextGoal?.title ?? 'Set a dream together',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppColors.darkInk : AppColors.lightInk,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (nextGoal != null)
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            final willComplete = !nextGoal.isCompleted;
                            stageProvider.toggleGoal(
                              spaceId,
                              nextGoal.id,
                              willComplete,
                              nickname,
                            );
                          },
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: nextGoal.isCompleted
                                  ? AppColors.sage.withOpacity(0.2)
                                  : Colors.transparent,
                              border: Border.all(
                                color: nextGoal.isCompleted
                                    ? AppColors.sage
                                    : (isDark ? AppColors.darkSoft : AppColors.lightSoft),
                                width: 1.5,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: nextGoal.isCompleted
                                ? const Icon(Icons.check, size: 16, color: AppColors.sage)
                                : null,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Progress Bar & Percentage
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$completedCount of $totalCount Firsts & Dreams achieved',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                        ),
                      ),
                      Text(
                        '${(progress * 100).toInt()}%',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.terra,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 5,
                      backgroundColor: isDark
                          ? AppColors.darkBorder
                          : AppColors.lightBorder,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.terra),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
