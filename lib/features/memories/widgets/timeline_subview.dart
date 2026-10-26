import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/memories_provider.dart';
import '../../../data/models/milestone_item.dart';

class TimelineSubview extends StatelessWidget {
  const TimelineSubview({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;
    final memoriesProvider = context.watch<MemoriesProvider>();
    final authProvider = context.watch<AuthProvider>();
    final spaceId = authProvider.space?.id ?? 'default_space';
    final user = authProvider.user;

    final milestones = memoriesProvider.milestones;

    // Group milestones by year
    final Map<int, List<MilestoneItem>> grouped = {};
    for (final m in milestones) {
      int year = DateTime.now().year;
      final match = RegExp(r'^(\d{4})').firstMatch(m.rawDate);
      if (match != null) {
        year = int.tryParse(match.group(1)!) ?? year;
      }
      grouped.putIfAbsent(year, () => []).add(m);
    }
    final sortedYears = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return Column(
      children: [
        // Top Action Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'JOURNEY TIMELINE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                      color: AppColors.terra,
                    ),
                  ),
                  Text(
                    '${milestones.length} Days You Kept',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.sage,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                icon: const Icon(Icons.add, size: 14),
                label: const Text('Add Milestone', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                onPressed: () => _showAddMilestoneModal(context, spaceId, user?.id),
              ),
            ],
          ),
        ),

        if (milestones.isEmpty)
          Padding(
            padding: const EdgeInsets.all(48.0),
            child: Column(
              children: [
                const Text('🌿', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 12),
                Text(
                  'No milestones recorded yet',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkInk : AppColors.lightInk,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Record anniversaries, first trips, and the small days that mattered to both of you.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                  ),
                ),
              ],
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            itemCount: sortedYears.length,
            itemBuilder: (context, yearIndex) {
              final year = sortedYears[yearIndex];
              final items = grouped[year]!;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      '$year · THE DAYS YOU KEPT',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                        color: AppColors.terra,
                      ),
                    ),
                  ),
                  ...items.map((m) => _buildMilestoneTile(context, m, isDark, spaceId)),
                  const SizedBox(height: 12),
                ],
              );
            },
          ),
      ],
    );
  }

  Widget _buildMilestoneTile(
    BuildContext context,
    MilestoneItem milestone,
    bool isDark,
    String spaceId,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.sage.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              milestone.date.split('-').last,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.sage,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  milestone.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkInk : AppColors.lightInk,
                  ),
                ),
                if (milestone.story.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      milestone.story,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                        height: 1.4,
                      ),
                    ),
                  ),
                Text(
                  'Kept by ${milestone.addedBy}',
                  style: TextStyle(
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                    color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.delete_outline,
              size: 16,
              color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
            ),
            onPressed: () => context.read<MemoriesProvider>().deleteMilestone(spaceId, milestone.id),
          ),
        ],
      ),
    );
  }

  void _showAddMilestoneModal(BuildContext context, String spaceId, String? userId) {
    if (userId == null) return;
    final titleCtrl = TextEditingController();
    final dateCtrl = TextEditingController(text: DateTime.now().toIso8601String().split('T')[0]);
    final storyCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Record a Timeline Milestone',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkInk : AppColors.lightInk,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleCtrl,
                  style: TextStyle(color: isDark ? AppColors.darkInk : AppColors.lightInk),
                  decoration: InputDecoration(
                    labelText: 'Milestone Title (e.g. Moved into our flat)',
                    labelStyle: TextStyle(color: isDark ? AppColors.darkSoft : AppColors.lightSoft),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: dateCtrl,
                  style: TextStyle(color: isDark ? AppColors.darkInk : AppColors.lightInk),
                  decoration: InputDecoration(
                    labelText: 'Date (YYYY-MM-DD)',
                    labelStyle: TextStyle(color: isDark ? AppColors.darkSoft : AppColors.lightSoft),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: storyCtrl,
                  maxLines: 3,
                  style: TextStyle(color: isDark ? AppColors.darkInk : AppColors.lightInk),
                  decoration: InputDecoration(
                    labelText: 'The Story (Optional)',
                    labelStyle: TextStyle(color: isDark ? AppColors.darkSoft : AppColors.lightSoft),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.sage,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () {
                      if (titleCtrl.text.trim().isNotEmpty) {
                        context.read<MemoriesProvider>().addMilestone(
                              spaceId: spaceId,
                              title: titleCtrl.text.trim(),
                              date: dateCtrl.text.trim(),
                              story: storyCtrl.text.trim(),
                              author: userId,
                            );
                        Navigator.pop(ctx);
                      }
                    },
                    child: const Text('Save Milestone ✦', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
