import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/stage_provider.dart';
import '../screens/daily_care_screen.dart';

class StageDailyCareCard extends StatelessWidget {
  const StageDailyCareCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;
    final stage = context.watch<StageProvider>();
    final auth = context.watch<AuthProvider>();
    final partner = auth.partner;
    final hasPartner = partner != null;

    final todayKey = DateTime.now().toIso8601String().split('T')[0];
    final items = stage.dailyCareItems;
    final completedCount = items.where((i) => i.isCompletedForDate(todayKey)).length;
    final totalCount = items.length;

    return GestureDetector(
      onTap: () => DailyCareScreen.show(context),
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
        child: Row(
          children: [
            // Left Glowing Icon
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.rose.withOpacity(0.14),
                borderRadius: BorderRadius.circular(13),
              ),
              alignment: Alignment.center,
              child: const Text('💖', style: TextStyle(fontSize: 19)),
            ),
            const SizedBox(width: 12),

            // Middle Text Information
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Daily Care & Checkup',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.rose,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.sage.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.sage.withOpacity(0.25), width: 0.8),
                        ),
                        child: Text(
                          totalCount > 0 ? '$completedCount/$totalCount Done ✦' : 'Daily Routine',
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: AppColors.sage,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    hasPartner
                        ? 'Loving reminders & mutual checkups for each other ✦'
                        : 'Personal self-care & health reminders ✦',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                    ),
                  ),
                ],
              ),
            ),

            // Right Chevron
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
            ),
          ],
        ),
      ),
    );
  }
}
