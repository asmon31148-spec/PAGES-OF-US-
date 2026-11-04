import 'dart:ui';
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
          // Apple Liquid Glass Circular Icon Frame
          ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isActive
                        ? [
                            AppColors.terra.withOpacity(0.35),
                            AppColors.terra.withOpacity(0.12),
                          ]
                        : [
                            Colors.white.withOpacity(0.14),
                            Colors.white.withOpacity(0.04),
                          ],
                  ),
                  border: Border.all(
                    color: isActive
                        ? AppColors.terra.withOpacity(0.7)
                        : Colors.white.withOpacity(0.24),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isActive
                          ? AppColors.terra.withOpacity(0.35)
                          : Colors.black.withOpacity(0.18),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  size: 24,
                  color: isActive ? Colors.white : AppColors.terra,
                ),
              ),
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
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF13151B).withOpacity(0.88)
                    : Colors.white.withOpacity(0.88),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border(
                  top: BorderSide(
                    color: isDark ? Colors.white.withOpacity(0.25) : Colors.black.withOpacity(0.1),
                    width: 1.2,
                  ),
                ),
              ),
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
        ),
      ),
    ),
  );
};
}
}
