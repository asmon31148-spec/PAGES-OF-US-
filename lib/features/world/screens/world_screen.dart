import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/theme_provider.dart';
import '../../stage/widgets/app_top_bar.dart';
import '../../stage/widgets/profile_modal.dart';

class WorldScreen extends StatelessWidget {
  const WorldScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      body: SafeArea(
        child: Column(
          children: [
            AppTopBar(
              title: 'Our World',
              subtitle: 'Realtime tether, distance & live mutual presence',
              onOpenProfile: () => ProfileModal.show(context),
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.public_rounded, size: 48, color: AppColors.sageLight),
                    const SizedBox(height: 12),
                    Text(
                      'World & Dual Tether',
                      style: TextStyle(
                        fontFamily: 'serif',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkInk : AppColors.lightInk,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Ready for Phase 2 (Leaflet & Dual World Clocks migration)',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
