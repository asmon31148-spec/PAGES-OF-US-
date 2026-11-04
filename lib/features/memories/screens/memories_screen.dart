import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../music/widgets/glass/glass_ambient_background.dart';
import '../../music/theme/glass_tokens.dart';

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
    final isDark = context.watch<ThemeProvider>().isDark;
    final authProvider = context.watch<AuthProvider>();
    final memoriesProvider = context.read<MemoriesProvider>();

    final user = authProvider.user;
    final spaceId = authProvider.space?.id ?? 'default_space';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GlassAmbientBackground(
        fallbackColor: const Color(0xFFE07A5F),
        child: SafeArea(
          child: Column(
            children: [
              // Top Bar
              AppTopBar(
                title: 'Our Memories',
                subtitle: 'Moments, letters & keepsakes',
                onOpenProfile: () => ProfileModal.show(context),
              ),

              // Apple Liquid Glass Segmented Switcher (Captured, Letterbox, Timeline)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withOpacity(0.12),
                            Colors.white.withOpacity(0.04),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.22),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.18),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          _buildSegmentButton(0, 'Captured 📷', isDark),
                          _buildSegmentButton(1, 'Letterbox ✉️', isDark),
                          _buildSegmentButton(2, 'Journey 🌿', isDark),
                        ],
                      ),
                    ),
                  ),
                ),
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
      ),
      floatingActionButton: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.terra.withOpacity(0.92),
                  const Color(0xFFD4694E),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.35), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.terra.withOpacity(0.4),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
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
                borderRadius: BorderRadius.circular(24),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded, color: Colors.white, size: 20),
                      SizedBox(width: 6),
                      Text(
                        'Keep Memory',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentButton(int index, String label, bool isDark) {
    final isSelected = _selectedSegment == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedSegment = index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    colors: [
                      AppColors.terra.withOpacity(0.35),
                      AppColors.terra.withOpacity(0.12),
                    ],
                  )
                : null,
            borderRadius: BorderRadius.circular(16),
            border: isSelected
                ? Border.all(
                    color: AppColors.terra.withOpacity(0.55),
                    width: 1,
                  )
                : null,
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.terra.withOpacity(0.2),
                      blurRadius: 8,
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
              color: isSelected ? Colors.white : (isDark ? AppColors.darkSoft : AppColors.lightSoft),
            ),
          ),
        ),
      ),
    );
  }
}
