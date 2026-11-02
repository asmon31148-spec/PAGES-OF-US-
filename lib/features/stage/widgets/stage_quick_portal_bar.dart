import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../providers/theme_provider.dart';
import '../../../../providers/audio_provider.dart';
import '../../watch_together/screens/watch_lobby_screen.dart';
import '../screens/touch_sanctuary_screen.dart';
import '../screens/daily_care_screen.dart';
import 'goal_tracker_modal.dart';
import '../../music/screens/music_sanctuary_screen.dart';

class StageQuickPortalBar extends StatelessWidget {
  final VoidCallback? onNotesTap;

  const StageQuickPortalBar({
    super.key,
    this.onNotesTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;
    final audioProvider = context.watch<AudioProvider>();
    final isMusicPlaying = audioProvider.isPlaying;

    final inkColor = isDark ? AppColors.darkInk : AppColors.lightInk;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Cinema (Watch Together)
          _buildPortalItem(
            icon: Icons.movie_filter_rounded,
            label: 'Cinema',
            inkColor: inkColor,
            isDark: isDark,
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const WatchLobbyScreen(),
                ),
              );
            },
          ),

          const SizedBox(width: 15),

          // 2. Touch (Touch & Draw Studio)
          _buildPortalItem(
            icon: Icons.front_hand_rounded,
            label: 'Touch',
            inkColor: inkColor,
            isDark: isDark,
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const TouchSanctuaryScreen(),
                ),
              );
            },
          ),

          const SizedBox(width: 15),

          // 3. Listen (Music Sanctuary)
          _buildPortalItem(
            icon: Icons.headphones_rounded,
            label: 'Listen',
            inkColor: inkColor,
            isDark: isDark,
            isActive: isMusicPlaying,
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const MusicSanctuaryScreen(),
                ),
              );
            },
          ),

          const SizedBox(width: 15),

          // 4. Daily Care
          _buildPortalItem(
            icon: Icons.spa_rounded,
            label: 'Daily Care',
            inkColor: inkColor,
            isDark: isDark,
            onTap: () {
              HapticFeedback.lightImpact();
              DailyCareScreen.show(context);
            },
          ),

          const SizedBox(width: 15),

          // 5. Milestones & Dreams
          _buildPortalItem(
            icon: Icons.flag_rounded,
            label: 'Milestones',
            inkColor: inkColor,
            isDark: isDark,
            onTap: () {
              HapticFeedback.lightImpact();
              GoalTrackerModal.show(context);
            },
          ),

          const SizedBox(width: 15),

          // 6. Notes (Pinned Love Notes)
          _buildPortalItem(
            icon: Icons.edit_note_rounded,
            label: 'Notes',
            inkColor: inkColor,
            isDark: isDark,
            onTap: () {
              HapticFeedback.lightImpact();
              if (onNotesTap != null) {
                onNotesTap!();
              } else {
                _showQuickNoteSheet(context, isDark);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPortalItem({
    required IconData icon,
    required String label,
    required Color inkColor,
    required bool isDark,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Circular Glowing Icon Frame
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark
                  ? (isActive
                      ? AppColors.terra.withOpacity(0.2)
                      : const Color(0xFF1F2B24).withOpacity(0.7))
                  : (isActive
                      ? AppColors.terra.withOpacity(0.15)
                      : Colors.white),
              border: Border.all(
                color: isActive
                    ? AppColors.terra
                    : (isDark
                        ? AppColors.terra.withOpacity(0.4)
                        : AppColors.terra.withOpacity(0.35)),
                width: 1.4,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.terra.withOpacity(isActive ? 0.35 : 0.14),
                  blurRadius: 10,
                  spreadRadius: 1,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 24,
              color: AppColors.terra,
            ),
          ),
          const SizedBox(height: 7),
          // Label
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
              color: inkColor,
            ),
          ),
        ],
      ),
    );
  }

  void _showQuickNoteSheet(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Icon(Icons.edit_note_rounded, color: AppColors.terra, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Daily Pinned Notes',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Leave a love note on the corkboard for your partner to see.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.terra,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('View Pinned Notes Below 📌'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
