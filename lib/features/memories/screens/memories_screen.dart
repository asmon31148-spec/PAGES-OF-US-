import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/memories_provider.dart';
import '../../../core/widgets/liquid_glass/liquid_glass_segment_control.dart';
import '../../../core/widgets/liquid_glass/liquid_glass_button.dart';
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
              partnerId: auth.partner?.id,
              partnerNickname: auth.partner?.nickname,
            );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final memoriesProvider = context.read<MemoriesProvider>();

    final user = authProvider.user;
    final spaceId = authProvider.space?.id ?? 'default_space';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
          child: Column(
            children: [
              // Top Bar
              AppTopBar(
                title: 'Our Memories',
                subtitle: 'Moments, letters & keepsakes',
                onOpenProfile: () => ProfileModal.show(context),
              ),

              // True Apple Liquid Glass Segment Control
              LiquidGlassSegmentControl(
                selectedIndex: _selectedSegment,
                segments: const ['Captured 📷', 'Letterbox ✉️', 'Journey 🌿'],
                onSegmentSelected: (index) {
                  setState(() => _selectedSegment = index);
                },
              ),

              // Scrollable Content
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.terra,
                  onRefresh: () async {
                    if (authProvider.space != null && user != null) {
                      await memoriesProvider.initMemoriesSync(
                        spaceId: spaceId,
                        currentUserId: user.id,
                        partnerId: authProvider.partner?.id,
                        partnerNickname: authProvider.partner?.nickname,
                      );
                    }
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 120),
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
      floatingActionButton: LiquidGlassButton(
        icon: Icons.add_rounded,
        label: 'Keep Memory',
        primaryColor: AppColors.terra,
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
}
