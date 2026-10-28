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
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          border: Border(
            top: BorderSide(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
            bottom: BorderSide(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
        ),
        child: Row(
          children: [
            // Left Glowing Icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.rose.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: const Text('💖', style: TextStyle(fontSize: 18)),
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
                        'DAILY CARE & CHECKUP',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.rose,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.sage.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          totalCount > 0 ? '$completedCount/$totalCount Done ✦' : 'Daily Routine',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: AppColors.sage,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasPartner
                        ? 'Loving reminders & mutual checkups for each other ✦'
                        : 'Personal self-care & health reminders ✦',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.darkInk : AppColors.lightInk,
                    ),
                  ),
                ],
              ),
            ),

            // Right Chevron
            Icon(
              Icons.chevron_right,
              size: 18,
              color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
            ),
          ],
        ),
      ),
    );
  }
}
