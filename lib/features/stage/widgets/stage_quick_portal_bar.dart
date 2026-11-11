import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/audio_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/stage_provider.dart';
import '../../watch_together/screens/watch_lobby_screen.dart';
import '../screens/touch_sanctuary_screen.dart';
import '../screens/daily_care_screen.dart';
import 'goal_tracker_modal.dart';
import 'stage_presence_view.dart';
import '../../music/screens/music_sanctuary_screen.dart';
import '../../dossier/screens/obsession_dossier_screen.dart';

class StageQuickPortalBar extends StatelessWidget {
  final VoidCallback? onNotesTap;

  const StageQuickPortalBar({
    super.key,
    this.onNotesTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.select<ThemeProvider, bool>((t) => t.isDark);
    final isMusicPlaying = context.select<AudioProvider, bool>((a) => a.isPlaying);
    final isPartnerActive = context.select<StageProvider, bool>((s) => s.partnerTelemetry?.isDeviceUnlocked == true);
    final isGentleMode = context.select<StageProvider, bool>((s) => s.isGentleMode);

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

          // 3b. Eyes On You (Live Hardware & Route Dossier)
          _buildPortalItem(
            icon: Icons.visibility_rounded,
            label: 'Dossier',
            inkColor: inkColor,
            isDark: isDark,
            isActive: isPartnerActive,
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ObsessionDossierScreen(),
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

          const SizedBox(width: 15),

          // 7. Quiet Shell (Stress Relief / Gentle Sanctuary)
          _buildPortalItem(
            icon: Icons.nightlight_round,
            label: 'Quiet Shell',
            inkColor: inkColor,
            isDark: isDark,
            isActive: isGentleMode,
            onTap: () {
              HapticFeedback.lightImpact();
              StagePresenceView.showGentleModeSheet(context);
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
          // Apple Liquid Glass Circular Icon Frame (GPU-optimized without BackdropFilter)
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive
                  ? AppColors.terra.withValues(alpha: 0.22)
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.white.withValues(alpha: 0.85)),
              border: Border.all(
                color: isActive
                    ? AppColors.terra.withValues(alpha: 0.7)
                    : (isDark ? Colors.white.withValues(alpha: 0.20) : Colors.black.withValues(alpha: 0.10)),
                width: 1.0,
              ),
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 24,
              color: isActive ? Colors.white : AppColors.terra,
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
    final authProvider = context.read<AuthProvider>();
    final stageProvider = context.read<StageProvider>();
    final user = authProvider.user;
    final partner = authProvider.partner;
    final space = authProvider.space;

    final myExistingNote = user != null ? stageProvider.pinnedNotes[user.id]?.text : null;
    final otherNotes = stageProvider.pinnedNotes.entries.where((e) => e.key != user?.id);
    final partnerEntry = otherNotes.isNotEmpty ? otherNotes.first : null;
    final partnerExistingNote = (partner != null && stageProvider.pinnedNotes.containsKey(partner.id))
        ? stageProvider.pinnedNotes[partner.id]?.text
        : partnerEntry?.value.text;
    final partnerDisplayName = partner?.nickname ??
        (partnerEntry?.value.authorNickname.isNotEmpty == true
            ? partnerEntry!.value.authorNickname
            : 'Partner');

    final noteController = TextEditingController(text: myExistingNote ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              child: Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF13151B).withValues(alpha: 0.96)
                        : Colors.white.withValues(alpha: 0.96),
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
                    top: 16,
                    bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Drag Handle
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

                        // Title Header
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: AppColors.terra.withOpacity(0.14),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.edit_note_rounded, color: AppColors.terra, size: 22),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Daily Love Notes',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? AppColors.darkInk : AppColors.lightInk,
                                  ),
                                ),
                                Text(
                                  'Pinned on your sanctuary corkboard for each other',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // Partner's Note Card (if available)
                        if (partnerExistingNote?.isNotEmpty == true) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF261D1A) : AppColors.terra.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark ? AppColors.terra.withOpacity(0.35) : Colors.white.withOpacity(0.80),
                                width: 1.0,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text('💌 ', style: TextStyle(fontSize: 12)),
                                    Text(
                                      'From $partnerDisplayName',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.terra,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                SelectableText(
                                  partnerExistingNote!,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    height: 1.45,
                                    color: isDark ? AppColors.darkInk : AppColors.lightInk,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // User's Note Field
                        Row(
                          children: [
                            const Text('✍️ ', style: TextStyle(fontSize: 12)),
                            Text(
                              'Your Note For $partnerDisplayName',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppColors.sageLight : AppColors.sage,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        TextField(
                          controller: noteController,
                          maxLines: 4,
                          minLines: 3,
                          style: TextStyle(
                            fontSize: 13.5,
                            color: isDark ? AppColors.darkInk : AppColors.lightInk,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Leave a sweet whisper or thought for $partnerDisplayName...',
                            hintStyle: TextStyle(
                              fontSize: 12.5,
                              color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                            ),
                            filled: true,
                            fillColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                            contentPadding: const EdgeInsets.all(14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Action Buttons: Pin Note & Clear
                        Row(
                          children: [
                            if (myExistingNote?.isNotEmpty == true)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: TextButton.icon(
                                  onPressed: () async {
                                    HapticFeedback.lightImpact();
                                    if (space != null && user != null) {
                                      await stageProvider.savePinnedNote(space.id, user.id, user.nickname, '');
                                    }
                                    if (modalContext.mounted) {
                                      Navigator.pop(modalContext);
                                    }
                                  },
                                  icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.redAccent),
                                  label: const Text('Clear', style: TextStyle(color: Colors.redAccent, fontSize: 12.5)),
                                ),
                              ),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  HapticFeedback.mediumImpact();
                                  final text = noteController.text.trim();
                                  if (space != null && user != null) {
                                    await stageProvider.savePinnedNote(
                                      space.id,
                                      user.id,
                                      user.nickname,
                                      text,
                                    );
                                  }
                                  if (modalContext.mounted) {
                                    Navigator.pop(modalContext);
                                  }
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        text.isNotEmpty
                                            ? 'Pinned note saved for $partnerDisplayName! 📌'
                                            : 'Note cleared.',
                                      ),
                                      backgroundColor: AppColors.terra,
                                      duration: const Duration(seconds: 2),
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.push_pin_rounded, size: 18),
                                label: const Text(
                                  'Pin Note to Corkboard 📌',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.terra,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size.fromHeight(46),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            );
          },
        );
      },
    );
  }
}
