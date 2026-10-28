import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/stage_provider.dart';
import '../screens/touch_sanctuary_screen.dart';

class StageTouchSanctuaryCard extends StatefulWidget {
  const StageTouchSanctuaryCard({super.key});

  @override
  State<StageTouchSanctuaryCard> createState() => _StageTouchSanctuaryCardState();
}

class _StageTouchSanctuaryCardState extends State<StageTouchSanctuaryCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _openFullScreen(BuildContext context, [TouchSanctuaryMode mode = TouchSanctuaryMode.thumbKiss]) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => TouchSanctuaryScreen(
          initialMode: mode,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 280),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;
    final auth = context.watch<AuthProvider>();
    final stage = context.watch<StageProvider>();
    final partner = auth.partner;
    final partnerName = partner?.nickname?.isNotEmpty == true ? partner!.nickname! : 'Partner';
    final isPartnerTouching = stage.isPartnerTouching;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16151A) : const Color(0xFFFAF7F5),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isPartnerTouching
              ? AppColors.terra.withOpacity(0.5)
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          width: isPartnerTouching ? 1.5 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isPartnerTouching
                ? AppColors.terra.withOpacity(0.2)
                : Colors.black.withOpacity(isDark ? 0.35 : 0.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _openFullScreen(context),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Category Tag + Partner Presence Pill
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.terra,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.terra.withOpacity(0.6),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'TOUCH & DRAW SANCTUARY',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                              color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isPartnerTouching
                              ? const Color(0xFF10B981).withOpacity(0.15)
                              : (isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04)),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isPartnerTouching
                                ? const Color(0xFF10B981).withOpacity(0.3)
                                : Colors.transparent,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isPartnerTouching ? const Color(0xFF10B981) : Colors.grey,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isPartnerTouching ? '$partnerName is touching!' : partnerName,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isPartnerTouching
                                    ? const Color(0xFF10B981)
                                    : (isDark ? AppColors.darkSoft : AppColors.lightSoft),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Center Visual Display
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F0E13) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05),
                      ),
                    ),
                    child: AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, _) {
                        return Column(
                          children: [
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                // Pulsing Ambient Glow Ring
                                Container(
                                  width: 72 + (_pulseController.value * 14),
                                  height: 72 + (_pulseController.value * 14),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.terra.withOpacity(0.12 * (1.0 - _pulseController.value)),
                                    border: Border.all(
                                      color: AppColors.terra.withOpacity(0.35 * (1.0 - _pulseController.value)),
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                                // Center Core Icon
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.terra.withOpacity(0.15),
                                    border: Border.all(
                                      color: AppColors.terra.withOpacity(0.4),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.fingerprint_rounded,
                                    size: 32,
                                    color: AppColors.terra,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Full Screen Touch & Glow Studio',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : AppColors.lightInk,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tap to enter edge-to-edge isolated canvas ✦',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Bottom Mode Action Pills (Tap any to open directly in that mode)
                  Row(
                    children: [
                      _buildQuickPill(
                        label: 'Thumb-Kiss',
                        icon: Icons.fingerprint_rounded,
                        isDark: isDark,
                        onTap: () => _openFullScreen(context, TouchSanctuaryMode.thumbKiss),
                      ),
                      const SizedBox(width: 8),
                      _buildQuickPill(
                        label: 'Glow Trace',
                        icon: Icons.brush_rounded,
                        isDark: isDark,
                        onTap: () => _openFullScreen(context, TouchSanctuaryMode.glowTrace),
                      ),
                      const SizedBox(width: 8),
                      _buildQuickPill(
                        label: 'Miss U (${stage.myDailyTouches + stage.partnerDailyTouches})',
                        icon: Icons.favorite_rounded,
                        isDark: isDark,
                        onTap: () => _openFullScreen(context, TouchSanctuaryMode.heartPulse),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Primary Full-Screen Launch Button
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: () => _openFullScreen(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.terra,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(23),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.fullscreen_rounded, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Open Full Screen Studio',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickPill({
    required String label,
    required IconData icon,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 13,
                color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkInk : AppColors.lightInk,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
