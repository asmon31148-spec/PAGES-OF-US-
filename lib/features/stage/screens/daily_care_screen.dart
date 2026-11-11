import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:confetti/confetti.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/liquid_glass/liquid_glass_background.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/stage_provider.dart';
import '../../../data/models/daily_care_item.dart';
import '../../../core/services/notification_service.dart';

/// Full-Screen Daily Care Schedule & Partner Checkup Screen
class DailyCareScreen extends StatefulWidget {
  const DailyCareScreen({super.key});

  static void show(BuildContext context) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const DailyCareScreen(),
      ),
    );
  }

  @override
  State<DailyCareScreen> createState() => _DailyCareScreenState();
}

class _DailyCareScreenState extends State<DailyCareScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late ConfettiController _confettiController;
  final String _todayKey = DateTime.now().toIso8601String().split('T')[0];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _confettiController = ConfettiController(duration: const Duration(milliseconds: 1500));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;
    final auth = context.watch<AuthProvider>();
    final stage = context.watch<StageProvider>();
    final user = auth.user;
    final partner = auth.partner;
    final spaceId = auth.space?.id ?? '';

    final hasPartner = partner != null;
    final partnerName = partner?.nickname ?? 'Partner';
    final userName = user?.nickname ?? 'You';

    // Filter items
    final allItems = stage.dailyCareItems;

    // Items meant for partner (scheduled by user or targeted at partner)
    final forPartnerItems = allItems.where((item) {
      if (!hasPartner) return false;
      return item.targetUserId == partner.id || (item.targetUserId.isEmpty && item.createdById == user?.id);
    }).toList();

    // Items meant for user (scheduled by partner or targeted at user)
    final forMeItems = allItems.where((item) {
      if (!hasPartner) return true; // Solo user sees their items here
      return item.targetUserId == user?.id || (item.targetUserId.isEmpty && item.createdById == partner.id);
    }).toList();

    // Completed counts
    final completedCount = allItems.where((i) => i.isCompletedForDate(_todayKey)).length;
    final totalCount = allItems.length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LiquidGlassBackground(
        child: SafeArea(
          child: Stack(
          children: [
            Column(
              children: [
                // 1. Top Navigation Bar
                _buildTopBar(context, isDark, spaceId, user?.id, userName, partner?.id, partnerName),

                // 2. Today's Care Summary Card
                _buildSummaryBanner(isDark, completedCount, totalCount, hasPartner, partnerName),

                // 3. Segmented Tab Selector
                _buildTabBar(isDark, partnerName, hasPartner),

                // 4. Tab Content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Tab 1: For Partner
                      _buildCareList(
                        items: forPartnerItems,
                        isDark: isDark,
                        spaceId: spaceId,
                        currentUserId: user?.id ?? '',
                        currentUserName: userName,
                        partnerName: partnerName,
                        isManagingForPartner: true,
                        hasPartner: hasPartner,
                      ),

                      // Tab 2: For You (Check off list)
                      _buildCareList(
                        items: forMeItems,
                        isDark: isDark,
                        spaceId: spaceId,
                        currentUserId: user?.id ?? '',
                        currentUserName: userName,
                        partnerName: partnerName,
                        isManagingForPartner: false,
                        hasPartner: hasPartner,
                      ),

                      // Tab 3: Daily Rhythm (All grouped by TimeSlot)
                      _buildTimelineView(
                        items: allItems,
                        isDark: isDark,
                        spaceId: spaceId,
                        currentUserId: user?.id ?? '',
                        currentUserName: userName,
                        partnerName: partnerName,
                        hasPartner: hasPartner,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Confetti Cannon for when an item is completed
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                colors: const [
                  Color(0xFFE57373),
                  Color(0xFF81C784),
                  Color(0xFF64B5F6),
                  Color(0xFFFFD54F),
                  Color(0xFFBA68C8),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.sage,
        foregroundColor: Colors.white,
        elevation: 4,
        onPressed: () => _showAddCareModal(
          context,
          spaceId,
          user?.id ?? '',
          userName,
          partner?.id,
          partnerName,
          hasPartner,
        ),
        icon: const Icon(Icons.add_task_rounded, size: 20),
        label: const Text(
          'Add Care Checkup',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildTopBar(
    BuildContext context,
    bool isDark,
    String spaceId,
    String? currentUserId,
    String currentUserName,
    String? partnerId,
    String partnerName,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                color: isDark ? AppColors.darkInk : AppColors.lightInk,
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 4),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Daily Care Routine',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.rose.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'DAILY SYNC',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: AppColors.rose,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Loving reminders & mutual checkups',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBanner(
    bool isDark,
    int completed,
    int total,
    bool hasPartner,
    String partnerName,
  ) {
    final progress = total > 0 ? (completed / total).clamp(0.0, 1.0) : 0.0;
    final percent = (progress * 100).round();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A221D) : const Color(0xFFEAF2EC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.sage.withValues(alpha: isDark ? 0.35 : 0.45),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.sage.withOpacity(0.18),
                    ),
                    alignment: Alignment.center,
                    child: const Text('🌿', style: TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mutual Care Progress',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.lightInk,
                        ),
                      ),
                      Text(
                        hasPartner
                            ? '$completed of $total caring checkups done today'
                            : '$completed of $total personal care checkups done',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white70 : AppColors.lightSoft,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.sage.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.sage.withOpacity(0.4)),
                ),
                child: Text(
                  '$percent%',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.sage,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: isDark ? Colors.white12 : Colors.black12,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.sage),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(bool isDark, String partnerName, bool hasPartner) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.08) : Colors.white.withOpacity(0.60),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.06),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: AppColors.sage.withOpacity(0.18),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.sage.withOpacity(0.45)),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: AppColors.sage,
        unselectedLabelColor: isDark ? AppColors.darkSoft : AppColors.lightSoft,
        labelStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(fontSize: 11.5),
        tabs: [
          Tab(text: hasPartner ? 'For $partnerName' : 'For Partner'),
          const Tab(text: 'For You'),
          const Tab(text: 'Timeline ⏳'),
        ],
      ),
    );
  }

  Widget _buildCareList({
    required List<DailyCareItem> items,
    required bool isDark,
    required String spaceId,
    required String currentUserId,
    required String currentUserName,
    required String partnerName,
    required bool isManagingForPartner,
    required bool hasPartner,
  }) {
    if (!hasPartner && isManagingForPartner) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.terra.withOpacity(0.12),
                ),
                alignment: Alignment.center,
                child: const Text('💌', style: TextStyle(fontSize: 26)),
              ),
              const SizedBox(height: 16),
              const Text(
                'Waiting for Partner',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Once your partner pairs their account, you can schedule personalized daily checkups, morning reminders, and gentle nudges for them here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('✨', style: TextStyle(fontSize: 32)),
              const SizedBox(height: 12),
              Text(
                isManagingForPartner
                    ? 'No checkups scheduled for $partnerName yet'
                    : 'No care checkups scheduled for you yet',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                isManagingForPartner
                    ? 'Tap the button below to add sweet daily reminders (e.g. hydrate, take vitamins, sleep early) for $partnerName.'
                    : 'Items scheduled by $partnerName or your personal self-care routine will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _buildCareCard(
          item: item,
          isDark: isDark,
          spaceId: spaceId,
          currentUserId: currentUserId,
          currentUserName: currentUserName,
          partnerName: partnerName,
          isManagingForPartner: isManagingForPartner,
        );
      },
    );
  }

  Widget _buildCareCard({
    required DailyCareItem item,
    required bool isDark,
    required String spaceId,
    required String currentUserId,
    required String currentUserName,
    required String partnerName,
    required bool isManagingForPartner,
  }) {
    final isDone = item.isCompletedForDate(_todayKey);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.08) : Colors.white.withOpacity(0.75),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDone
              ? AppColors.sage.withOpacity(0.4)
              : (isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.06)),
          width: 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Icon + Title + TimeSlot Pill + Checkbox/Action
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon Container
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isDone
                        ? AppColors.sage.withOpacity(0.18)
                        : (isDark ? const Color(0xFF231C18) : const Color(0xFFFFF4EE)),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDone ? AppColors.sage.withOpacity(0.5) : AppColors.terra.withOpacity(0.2),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(item.icon, style: const TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 12),

                // Title & Time info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                decoration: isDone ? TextDecoration.lineThrough : null,
                                color: isDone
                                    ? (isDark ? Colors.white54 : Colors.black45)
                                    : (isDark ? AppColors.darkInk : AppColors.lightInk),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.access_time_rounded, size: 11, color: AppColors.slate),
                                const SizedBox(width: 4),
                                Text(
                                  NotificationService.formatWithAmPm(item.scheduledTime),
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.slate,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: item.scheduledTime.toUpperCase().contains('PM')
                                        ? Colors.purple.withOpacity(0.18)
                                        : Colors.amber.withOpacity(0.20),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    item.scheduledTime.toUpperCase().contains('PM') ? 'PM' : 'AM',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: item.scheduledTime.toUpperCase().contains('PM')
                                          ? (isDark ? Colors.purpleAccent : Colors.purple[700])
                                          : (isDark ? Colors.amberAccent : Colors.orange[900]),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '· ${_capitalize(item.timeSlot)}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.slate,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Interactive Checkbox / Status
                if (!isManagingForPartner) ...[
                  // For You: Can check off!
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      final stage = context.read<StageProvider>();
                      stage.toggleCareItemCompleted(spaceId, item.id, !isDone, currentUserName);
                      if (!isDone) {
                        _confettiController.play();
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Completed "${item.title}" for today! 💖'),
                            duration: const Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDone ? AppColors.sage : Colors.transparent,
                        border: Border.all(
                          color: isDone ? AppColors.sage : (isDark ? Colors.white24 : Colors.black26),
                          width: 2,
                        ),
                      ),
                      child: isDone
                          ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                          : null,
                    ),
                  ),
                ] else ...[
                  // For Partner: View their live completion status & Nudge option!
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDone
                          ? AppColors.sage.withOpacity(0.15)
                          : Colors.orange.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      isDone ? 'Completed ✨' : 'Pending',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isDone ? AppColors.sage : Colors.orangeAccent,
                      ),
                    ),
                  ),
                ],
              ],
            ),

            // Caring Note from Partner
            if (item.caringNote.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1714) : const Color(0xFFFFF9F5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.terra.withOpacity(0.18),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('“', style: TextStyle(color: AppColors.terra, fontSize: 16, height: 1.1)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        item.caringNote,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontStyle: FontStyle.italic,
                          color: isDark ? Colors.white70 : Colors.black87,
                          height: 1.3,
                        ),
                      ),
                    ),
                    const Text('”', style: TextStyle(color: AppColors.terra, fontSize: 16, height: 1.1)),
                  ],
                ),
              ),
            ],

            // Action footer for partner routine (Care Nudge & Delete)
            if (isManagingForPartner) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Gentle Care Nudge Button
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.terra.withOpacity(0.14),
                      foregroundColor: AppColors.terra,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.favorite_rounded, size: 13),
                    label: Text(
                      item.reminderNudgeCount > 0
                          ? 'Send Nudge (${item.reminderNudgeCount})'
                          : 'Send Care Nudge 💌',
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      final stage = context.read<StageProvider>();
                      stage.sendCareNudge(
                        spaceId,
                        item.id,
                        currentUserName,
                        partnerName,
                        currentUserId: currentUserId,
                      );
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Sent gentle care nudge to $partnerName! 💌'),
                          duration: const Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),

                  // Delete / remove option
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 16),
                    color: Colors.redAccent.withOpacity(0.7),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Delete Checkup',
                    onPressed: () => _confirmDelete(context, spaceId, item),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineView({
    required List<DailyCareItem> items,
    required bool isDark,
    required String spaceId,
    required String currentUserId,
    required String currentUserName,
    required String partnerName,
    required bool hasPartner,
  }) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          'No care items scheduled',
          style: TextStyle(color: isDark ? AppColors.darkSoft : AppColors.lightSoft),
        ),
      );
    }

    final morningItems = items.where((i) => i.timeSlot == 'morning').toList();
    final afternoonItems = items.where((i) => i.timeSlot == 'afternoon').toList();
    final eveningItems = items.where((i) => i.timeSlot == 'evening').toList();
    final nightItems = items.where((i) => i.timeSlot == 'night').toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
      children: [
        if (morningItems.isNotEmpty)
          _buildTimeSlotSection('🌅 Morning Care', morningItems, isDark, spaceId, currentUserId, currentUserName, partnerName),
        if (afternoonItems.isNotEmpty)
          _buildTimeSlotSection('☀️ Afternoon Care', afternoonItems, isDark, spaceId, currentUserId, currentUserName, partnerName),
        if (eveningItems.isNotEmpty)
          _buildTimeSlotSection('🌆 Evening Wind Down', eveningItems, isDark, spaceId, currentUserId, currentUserName, partnerName),
        if (nightItems.isNotEmpty)
          _buildTimeSlotSection('🌙 Nighttime Rest', nightItems, isDark, spaceId, currentUserId, currentUserName, partnerName),
      ],
    );
  }

  Widget _buildTimeSlotSection(
    String title,
    List<DailyCareItem> slotItems,
    bool isDark,
    String spaceId,
    String currentUserId,
    String currentUserName,
    String partnerName,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, top: 12, bottom: 6),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.sageLight : AppColors.sage,
            ),
          ),
        ),
        ...slotItems.map(
          (item) => _buildCareCard(
            item: item,
            isDark: isDark,
            spaceId: spaceId,
            currentUserId: currentUserId,
            currentUserName: currentUserName,
            partnerName: partnerName,
            isManagingForPartner: item.targetUserId != currentUserId && item.createdById == currentUserId,
          ),
        ),
      ],
    );
  }

  void _confirmDelete(BuildContext context, String spaceId, DailyCareItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Care Checkup?'),
        content: Text('Remove "${item.title}" from the daily care schedule?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            onPressed: () async {
              final ok = await context.read<StageProvider>().deleteCareItem(spaceId, item.id);
              if (context.mounted) {
                Navigator.pop(ctx);
                if (!ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Only the creator can delete this care item or server unavailable.')),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showAddCareModal(
    BuildContext context,
    String spaceId,
    String currentUserId,
    String currentUserName,
    String? partnerId,
    String partnerName,
    bool hasPartner,
  ) {
    final titleController = TextEditingController();
    final noteController = TextEditingController();
    String selectedIcon = '💧';
    String selectedTimeSlot = 'morning';
    String scheduledTime = '08:30 AM';
    String target = hasPartner ? 'partner' : 'me'; // 'partner' or 'me'

    final presets = [
      {'title': 'Drink 500ml Water', 'icon': '💧', 'slot': 'morning', 'time': '08:30 AM'},
      {'title': 'Take Vitamins', 'icon': '💊', 'slot': 'morning', 'time': '09:00 AM'},
      {'title': 'Healthy Lunch', 'icon': '🥗', 'slot': 'afternoon', 'time': '01:00 PM'},
      {'title': 'Mindful Walk', 'icon': '🚶‍♂️', 'slot': 'afternoon', 'time': '04:30 PM'},
      {'title': 'Evening Warm Tea', 'icon': '🍵', 'slot': 'evening', 'time': '08:00 PM'},
      {'title': 'Night Skincare', 'icon': '🧴', 'slot': 'night', 'time': '10:00 PM'},
      {'title': 'Sleep Early', 'icon': '🌙', 'slot': 'night', 'time': '10:30 PM'},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final isDark = Theme.of(ctx).brightness == Brightness.dark;

            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                top: 20,
                left: 20,
                right: 20,
              ),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Schedule Care Checkup',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(modalCtx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Quick Inspiration Chips
                    const Text('Quick Suggestions:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: presets.map((p) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ActionChip(
                              avatar: Text(p['icon']!),
                              label: Text(p['title']!, style: const TextStyle(fontSize: 11)),
                              backgroundColor: isDark ? Colors.white10 : Colors.black.withOpacity(0.04),
                              onPressed: () {
                                setModalState(() {
                                  titleController.text = p['title']!;
                                  selectedIcon = p['icon']!;
                                  selectedTimeSlot = p['slot']!;
                                  scheduledTime = p['time']!;
                                });
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Checkup Title Input
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: 'Checkup Title',
                        hintText: 'e.g. Drink warm water, take medicine',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Text(selectedIcon, style: const TextStyle(fontSize: 20)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Time Slot Dropdown
                    DropdownButtonFormField<String>(
                      value: selectedTimeSlot,
                      decoration: InputDecoration(
                        labelText: 'Time Slot Category',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'morning', child: Text('🌅 Morning (5 AM - 12 PM)')),
                        DropdownMenuItem(value: 'afternoon', child: Text('☀️ Afternoon (12 PM - 5 PM)')),
                        DropdownMenuItem(value: 'evening', child: Text('🌆 Evening (5 PM - 9 PM)')),
                        DropdownMenuItem(value: 'night', child: Text('🌙 Night (9 PM - 5 AM)')),
                      ],
                      onChanged: (val) {
                        if (val != null) setModalState(() => selectedTimeSlot = val);
                      },
                    ),
                    const SizedBox(height: 12),

                    // Scheduled Exact Time & AM/PM Dual Selector
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Exact Notification Time & AM/PM',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            // 1. Clock Picker Card (Tap to pick hour:min on clock)
                            Expanded(
                              child: GestureDetector(
                                onTap: () async {
                                  HapticFeedback.selectionClick();
                                  final tod = NotificationService.parseTimeString(scheduledTime) ??
                                      const TimeOfDay(hour: 8, minute: 30);
                                  final picked = await showTimePicker(
                                    context: ctx,
                                    initialTime: tod,
                                    builder: (context, child) {
                                      return Theme(
                                        data: isDark ? ThemeData.dark() : ThemeData.light(),
                                        child: child!,
                                      );
                                    },
                                  );
                                  if (picked != null) {
                                    setModalState(() {
                                      final hour = picked.hourOfPeriod == 0 ? 12 : picked.hourOfPeriod;
                                      final minute = picked.minute.toString().padLeft(2, '0');
                                      final period = picked.period == DayPeriod.am ? 'AM' : 'PM';
                                      scheduledTime = '${hour.toString().padLeft(2, '0')}:$minute $period';
                                      if (picked.hour >= 5 && picked.hour < 12) {
                                        selectedTimeSlot = 'morning';
                                      } else if (picked.hour >= 12 && picked.hour < 17) {
                                        selectedTimeSlot = 'afternoon';
                                      } else if (picked.hour >= 17 && picked.hour < 21) {
                                        selectedTimeSlot = 'evening';
                                      } else {
                                        selectedTimeSlot = 'night';
                                      }
                                    });
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.04),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isDark ? Colors.white.withOpacity(0.15) : Colors.black.withOpacity(0.12),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.access_time_filled_rounded, size: 18, color: AppColors.sage),
                                      const SizedBox(width: 8),
                                      Text(
                                        NotificationService.formatWithAmPm(scheduledTime),
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.2,
                                          color: isDark ? AppColors.darkInk : AppColors.lightInk,
                                        ),
                                      ),
                                      const Spacer(),
                                      const Icon(Icons.touch_app_rounded, size: 14, color: AppColors.slate),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // 2. Clear AM / PM Quick Switcher Chips
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    final tod = NotificationService.parseTimeString(scheduledTime) ??
                                        const TimeOfDay(hour: 8, minute: 30);
                                    final hour12 = tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod;
                                    final minute = tod.minute.toString().padLeft(2, '0');
                                    setModalState(() {
                                      scheduledTime = '${hour12.toString().padLeft(2, '0')}:$minute AM';
                                      selectedTimeSlot = (hour12 >= 5 && hour12 < 12) ? 'morning' : 'night';
                                    });
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: scheduledTime.toUpperCase().contains('AM')
                                          ? AppColors.gold.withOpacity(0.25)
                                          : (isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.03)),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: scheduledTime.toUpperCase().contains('AM')
                                            ? AppColors.gold
                                            : Colors.transparent,
                                        width: 1.2,
                                      ),
                                    ),
                                    child: Text(
                                      '☀️ AM',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                        color: scheduledTime.toUpperCase().contains('AM')
                                            ? (isDark ? Colors.amberAccent : Colors.orange[900])
                                            : (isDark ? AppColors.darkSoft : AppColors.lightSoft),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 5),
                                GestureDetector(
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    final tod = NotificationService.parseTimeString(scheduledTime) ??
                                        const TimeOfDay(hour: 8, minute: 30);
                                    final hour12 = tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod;
                                    final minute = tod.minute.toString().padLeft(2, '0');
                                    setModalState(() {
                                      scheduledTime = '${hour12.toString().padLeft(2, '0')}:$minute PM';
                                      selectedTimeSlot = (hour12 < 5 || hour12 == 12) ? 'afternoon' : (hour12 < 9 ? 'evening' : 'night');
                                    });
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: scheduledTime.toUpperCase().contains('PM')
                                          ? Colors.purple.withOpacity(0.25)
                                          : (isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.03)),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: scheduledTime.toUpperCase().contains('PM')
                                            ? Colors.purpleAccent
                                            : Colors.transparent,
                                        width: 1.2,
                                      ),
                                    ),
                                    child: Text(
                                      '🌙 PM',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                        color: scheduledTime.toUpperCase().contains('PM')
                                            ? (isDark ? Colors.purpleAccent : Colors.purple[800])
                                            : (isDark ? AppColors.darkSoft : AppColors.lightSoft),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Caring Note for Partner
                    TextField(
                      controller: noteController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Sweet Caring Note (Optional)',
                        hintText: 'e.g. Stay hydrated and don’t overwork today! 💕',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Who is this for?
                    if (hasPartner) ...[
                      const Text('Schedule for:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          ChoiceChip(
                            label: Text('For $partnerName 💖'),
                            selected: target == 'partner',
                            onSelected: (_) => setModalState(() => target = 'partner'),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('For Me 🤍'),
                            selected: target == 'me',
                            onSelected: (_) => setModalState(() => target = 'me'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                    ],

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.sage,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () {
                          final title = titleController.text.trim();
                          if (title.isEmpty) return;

                          final targetUserId = target == 'partner' ? (partnerId ?? '') : currentUserId;
                          final targetUserName = target == 'partner' ? partnerName : currentUserName;

                          final newItem = DailyCareItem(
                            id: 'care_${DateTime.now().millisecondsSinceEpoch}',
                            title: title,
                            icon: selectedIcon,
                            scheduledTime: scheduledTime,
                            timeSlot: selectedTimeSlot,
                            caringNote: noteController.text.trim(),
                            targetUserId: targetUserId,
                            targetUserName: targetUserName,
                            createdById: currentUserId,
                            createdByName: currentUserName,
                          );

                          context.read<StageProvider>().addCareItem(
                            spaceId,
                            newItem,
                            currentUserId: currentUserId,
                            partnerName: partnerName,
                          );
                          Navigator.pop(modalCtx);
                          HapticFeedback.lightImpact();

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Scheduled care checkup: "$title" ✨'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        child: const Text(
                          'Save Care Checkup',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  static String _capitalize(String str) {
    if (str.isEmpty) return '';
    return str[0].toUpperCase() + str.substring(1);
  }
}
