import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/memories_provider.dart';
import '../../stage/widgets/app_top_bar.dart';
import '../../stage/widgets/profile_modal.dart';
import '../widgets/memory_stack_view.dart';
import '../widgets/letterbox_subview.dart';
import '../widgets/timeline_subview.dart';
import '../widgets/add_memory_dialog.dart';

class MemoriesScreen extends StatefulWidget {
  const MemoriesScreen({super.key});

  @override
  State<MemoriesScreen> createState() => _MemoriesScreenState();
}

class _MemoriesScreenState extends State<MemoriesScreen> {
  int _selectedSegment = 0; // 0: Captured, 1: Letterbox, 2: Timeline

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.space != null && auth.user != null) {
        context.read<MemoriesProvider>().initMemoriesSync(
              spaceId: auth.space!.id,
              currentUserId: auth.user!.id,
              partnerNickname: auth.partner?.nickname,
            );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;
    final authProvider = context.watch<AuthProvider>();
    final memoriesProvider = context.watch<MemoriesProvider>();

    final user = authProvider.user;
    final spaceId = authProvider.space?.id ?? 'default_space';

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            AppTopBar(
              title: 'Our Memories',
              subtitle: 'Captured moments, letters & journey',
              onOpenProfile: () => ProfileModal.show(context),
            ),

            // Segmented Switcher (Captured, Letterbox, Timeline)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Row(
                children: [
                  _buildSegmentButton(0, 'Captured 📷', isDark),
                  _buildSegmentButton(1, 'Letterbox ✉️', isDark),
                  _buildSegmentButton(2, 'Journey 🌿', isDark),
                ],
              ),
            ),

            // Scrollable Content
            Expanded(
              child: RefreshIndicator(
                color: AppColors.sage,
                onRefresh: () async {
                  if (authProvider.space != null && user != null) {
                    await memoriesProvider.initMemoriesSync(
                      spaceId: spaceId,
                      currentUserId: user.id,
                      partnerNickname: authProvider.partner?.nickname,
                    );
                  }
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 80),
                  child: _selectedSegment == 0
                      ? MemoryStackView(spaceId: spaceId)
                      : _selectedSegment == 1
                          ? const LetterboxSubview()
                          : const TimelineSubview(),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.terra,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add, size: 20),
        label: const Text(
          'Keep Memory',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        onPressed: () {
          if (user != null) {
            AddMemoryDialog.show(
              context,
              spaceId: spaceId,
              currentUserId: user.id,
              userNickname: user.nickname,
              memoriesProvider: memoriesProvider,
            );
          }
        },
      ),
    );
  }

  Widget _buildSegmentButton(int index, String label, bool isDark) {
    final isSelected = _selectedSegment == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedSegment = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? AppColors.darkCard : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected
                  ? (isDark ? AppColors.darkInk : AppColors.lightInk)
                  : (isDark ? AppColors.darkSoft : AppColors.lightSoft),
            ),
          ),
        ),
      ),
    );
  }
}
