import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/stage_provider.dart';

class StageLiveTouchPad extends StatelessWidget {
  const StageLiveTouchPad({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;
    final authProvider = context.watch<AuthProvider>();
    final stageProvider = context.watch<StageProvider>();
    final user = authProvider.user;
    final space = authProvider.space;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: 180,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: GestureDetector(
          onPanDown: (details) {
            final box = context.findRenderObject() as RenderBox?;
            if (box != null && space != null && user != null) {
              final local = details.localPosition;
              final nx = local.dx / box.size.width;
              final ny = local.dy / box.size.height;
              HapticFeedback.lightImpact();
              stageProvider.sendTouchPadEvent(space.id, user.id, nx, ny);
            }
          },
          onPanUpdate: (details) {
            final box = context.findRenderObject() as RenderBox?;
            if (box != null && space != null && user != null) {
              final local = details.localPosition;
              final nx = local.dx / box.size.width;
              final ny = local.dy / box.size.height;
              stageProvider.sendTouchPadEvent(space.id, user.id, nx, ny);
            }
          },
          child: Stack(
            children: [
              // Subtle background grid or glow
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.fingerprint,
                      size: 40,
                      color: AppColors.sageLight,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Synchronized Touch Pad',
                      style: TextStyle(
                        fontFamily: 'serif',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkInk : AppColors.lightInk,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Hold your thumb here to feel your partner\'s presence ✦',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                      ),
                    ),
                  ],
                ),
              ),

              // Dynamic Ripples
              ...stageProvider.touchPoints.map((pt) {
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final px = pt.x * constraints.maxWidth;
                    final py = pt.y * constraints.maxHeight;
                    return Positioned(
                      left: px - 30,
                      top: py - 30,
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.terra.withOpacity(0.3),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.terra.withOpacity(0.5),
                              blurRadius: 16,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
