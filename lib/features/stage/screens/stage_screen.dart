import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/stage_provider.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/stage_atmosphere_card.dart';
import '../widgets/stage_presence_view.dart';
import '../widgets/stage_daily_sync_card.dart';
import '../widgets/stage_pinned_corkboard.dart';
import '../widgets/stage_memory_hero_card.dart';
import '../widgets/stage_daily_care_card.dart';
import '../widgets/mood_aura_modal.dart';
import '../widgets/anniversary_modal.dart';
import '../widgets/profile_modal.dart';
import '../widgets/goal_tracker_modal.dart';
import '../../auth/widgets/pairing_modal.dart';
import '../../../core/services/update_service.dart';

class StageScreen extends StatefulWidget {
  final VoidCallback onGoToMemories;
  final ValueChanged<int>? onSelectTab;

  const StageScreen({
    super.key,
    required this.onGoToMemories,
    this.onSelectTab,
  });

  @override
  State<StageScreen> createState() => _StageScreenState();
}

class _StageScreenState extends State<StageScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.space != null && auth.user != null) {
        context.read<StageProvider>().initSpaceListeners(
              auth.space!.id,
              auth.user!.id,
              auth.partner?.id,
            );
      }

      // Check for App Updates in background
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          UpdateService.checkAndPrompt(context);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;
    final stageProvider = context.watch<StageProvider>();
    final authProvider = context.watch<AuthProvider>();

    final formattedDate =
        DateFormat('EEEE, MMMM d').format(DateTime.now()).toUpperCase();

    final hasAnniversary = stageProvider.anniversaryDate != null &&
        stageProvider.anniversaryDate!.isNotEmpty;
    DateTime? parsedAnniversary;
    if (hasAnniversary) {
      parsedAnniversary = DateTime.tryParse(stageProvider.anniversaryDate!);
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            AppTopBar(
              title: 'Pages of Us',
              showTouch: true,
              showMusic: true,
              onOpenProfile: () => ProfileModal.show(context),
            ),

            // Scrollable Content with Pull-To-Refresh
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  if (authProvider.user != null) {
                    await authProvider.refreshUserData(authProvider.user!.id);
                    final space = authProvider.space;
                    final user = authProvider.user;
                    final partner = authProvider.partner;
                    if (space != null && user != null && context.mounted) {
                      context.read<StageProvider>().initSpaceListeners(
                            space.id,
                            user.id,
                            partner?.id,
                          );
                    }
                  }
                },
                color: AppColors.sage,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Greeting & Anniversary Row
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20.0, vertical: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              formattedDate,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                                color: isDark
                                    ? AppColors.darkSoft
                                    : AppColors.lightSoft,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => AnniversaryModal.show(context),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    hasAnniversary
                                        ? 'Together since ${parsedAnniversary != null ? DateFormat('MMM d, yyyy').format(parsedAnniversary) : stageProvider.anniversaryDate!} ✎'
                                        : 'Together from date ✎',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? AppColors.darkInk
                                          : AppColors.lightInk,
                                    ),
                                  ),
                                  Text(
                                    hasAnniversary
                                        ? 'Day ${stageProvider.daysTogether} together ✦'
                                        : 'Set Date ✦',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.terra,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Section 2: Partner Connection Status (Presence Avatars + Aura + Live Pulse Button)
                      StagePresenceView(
                        onOpenMoodModal: () => MoodAuraModal.show(context),
                        onOpenPairModal: () => PairingModal.show(context),
                        onOpenProfileModal: () => ProfileModal.show(context),
                      ),

                      // Section 1: Weather Status Atmosphere Card
                      const StageAtmosphereCard(),

                      // Section 4: Highlight Screen Section (Memory Spotlight Hero Deck)
                      StageMemoryHeroCard(
                        onGoToMemories: widget.onGoToMemories,
                        onSelectTab: widget.onSelectTab,
                      ),

                      // Section 3: Milestone & Dream Section (Goals & Milestones Teaser Banner)
                      GestureDetector(
                        onTap: () => GoalTrackerModal.show(context),
                        child: Container(
                          margin: EdgeInsets.zero,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkBg
                                : AppColors.lightBg,
                            border: Border(
                              bottom: BorderSide(
                                color: isDark
                                    ? AppColors.darkBorder
                                    : AppColors.lightBorder,
                                width: 0.8,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: AppColors.terra.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                alignment: Alignment.center,
                                child: const Text('🎯',
                                    style: TextStyle(fontSize: 18)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Text(
                                          'MILESTONES & DREAMS',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.terra,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 1),
                                          decoration: BoxDecoration(
                                            color:
                                                AppColors.sage.withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            'Day ${stageProvider.daysTogether}',
                                            style: const TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.sage,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      'Celebrate couple firsts & set new dreams ✦',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark
                                            ? AppColors.darkInk
                                            : AppColors.lightInk,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                size: 18,
                                color: isDark
                                    ? AppColors.darkSoft
                                    : AppColors.lightSoft,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Section 5: Daily Care and Checkup Section
                      const StageDailyCareCard(),

                      // Section 6: Pinned Message Section
                      const StagePinnedCorkboard(),

                      // Section 7: Question & Answer Section
                      const StageDailySyncCard(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
