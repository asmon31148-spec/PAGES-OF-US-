import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/stage_provider.dart';

class StagePresenceView extends StatelessWidget {
  final VoidCallback onOpenMoodModal;
  final VoidCallback onOpenPairModal;
  final VoidCallback onOpenProfileModal;

  const StagePresenceView({
    super.key,
    required this.onOpenMoodModal,
    required this.onOpenPairModal,
    required this.onOpenProfileModal,
  });

  void _sendHello(
    BuildContext context,
    AuthProvider authProvider,
    StageProvider stageProvider,
    bool isDark,
  ) {
    final user = authProvider.user;
    final partner = authProvider.partner;
    final space = authProvider.space;

    if (space != null && user != null) {
      HapticFeedback.lightImpact();
      stageProvider.sendPulse(space.id, user.id, user.nickname);

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                size: 15,
                color: AppColors.terra,
              ),
              const SizedBox(width: 8),
              Text(
                partner != null
                    ? 'A little hello sent to ${partner.nickname} ✨'
                    : 'Connect your partner to send a live hello ✨',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkInk : AppColors.lightInk,
                ),
              ),
            ],
          ),
          backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
          duration: const Duration(milliseconds: 1400),
          behavior: SnackBarBehavior.floating,
          elevation: 6,
          margin: const EdgeInsets.only(bottom: 24, left: 40, right: 40),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: AppColors.terra.withOpacity(0.35),
              width: 1,
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;
    final authProvider = context.watch<AuthProvider>();
    final stageProvider = context.watch<StageProvider>();

    final user = authProvider.user;
    final partner = authProvider.partner;
    final isPaired = authProvider.isPaired;
    final myMood = stageProvider.myMood;
    final partnerMood = stageProvider.partnerMood;
    final isPulsing = stageProvider.isPulsing;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background Tether Line connecting User and Partner
          if (isPaired && partner != null)
            Positioned(
              left: 45,
              right: 45,
              top: 36,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: isPulsing ? 2.5 : 1.0,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isPulsing
                        ? [
                            AppColors.sageLight.withOpacity(0.5),
                            AppColors.terra.withOpacity(0.9),
                            AppColors.rose.withOpacity(0.5),
                          ]
                        : [
                            (isDark ? Colors.white10 : Colors.black12),
                            AppColors.terra.withOpacity(0.2),
                            (isDark ? Colors.white10 : Colors.black12),
                          ],
                  ),
                  boxShadow: isPulsing
                      ? [
                          BoxShadow(
                            color: AppColors.terra.withOpacity(0.6),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
              ),
            ),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 1. User Avatar + Aura + Thought
              GestureDetector(
                onTap: onOpenMoodModal,
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Mood Aura Glow
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: (myMood?.glowColor ?? AppColors.sageLight)
                                    .withOpacity(0.45),
                                blurRadius: 18,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                        ),
                        // Avatar Image or Initial
                        CircleAvatar(
                          radius: 30,
                          backgroundColor:
                              isDark ? AppColors.darkCard : AppColors.lightCard,
                          backgroundImage: user?.avatarUrl != null
                              ? NetworkImage(user!.avatarUrl!)
                              : null,
                          child: user?.avatarUrl == null
                              ? Text(
                                  user?.nickname.isNotEmpty == true
                                      ? user!.nickname.substring(0, 1).toUpperCase()
                                      : 'Y',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? AppColors.darkInk
                                        : AppColors.lightInk,
                                  ),
                                )
                              : null,
                        ),
                        // Mood Badge
                        if (myMood != null)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppColors.darkSurface
                                    : AppColors.lightSurface,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                myMood.emoji,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      user?.nickname ?? 'You',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkInk : AppColors.lightInk,
                      ),
                    ),
                    Text(
                      user?.thought ?? (myMood?.label ?? 'Set mood aura ✨'),
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                      ),
                    ),
                  ],
                ),
              ),

              // 2. Central Live Celestial Pulse Beacon
              StagePulseBeacon(
                isPulsing: isPulsing,
                isDark: isDark,
                onTap: () => _sendHello(
                  context,
                  authProvider,
                  stageProvider,
                  isDark,
                ),
              ),

              // 3. Partner Avatar or Connect Button
              isPaired && partner != null
                  ? Column(
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: (partnerMood?.glowColor ??
                                            AppColors.rose)
                                        .withOpacity(0.45),
                                    blurRadius: 18,
                                    spreadRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                            CircleAvatar(
                              radius: 30,
                              backgroundColor: isDark
                                  ? AppColors.darkCard
                                  : AppColors.lightCard,
                              backgroundImage: partner.avatarUrl != null
                                  ? NetworkImage(partner.avatarUrl!)
                                  : null,
                              child: partner.avatarUrl == null
                                  ? Text(
                                      partner.nickname.isNotEmpty
                                          ? partner.nickname
                                              .substring(0, 1)
                                              .toUpperCase()
                                          : 'P',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? AppColors.darkInk
                                            : AppColors.lightInk,
                                      ),
                                    )
                                  : null,
                            ),
                            if (partnerMood != null)
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? AppColors.darkSurface
                                        : AppColors.lightSurface,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    partnerMood.emoji,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          partner.nickname,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color:
                                isDark ? AppColors.darkInk : AppColors.lightInk,
                          ),
                        ),
                        Text(
                          partner.thought ?? (partnerMood?.label ?? 'Together'),
                          style: TextStyle(
                            fontSize: 10,
                            color:
                                isDark ? AppColors.darkSoft : AppColors.lightSoft,
                          ),
                        ),
                      ],
                    )
                  : GestureDetector(
                      onTap: onOpenPairModal,
                      child: Column(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.sageLight.withOpacity(0.12),
                              border: Border.all(
                                color: AppColors.sageLight,
                                style: BorderStyle.solid,
                                width: 1.5,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.add,
                              color: AppColors.sageLight,
                              size: 24,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Connect partner',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.sageLight,
                            ),
                          ),
                          Text(
                            'Tap to pair ＋',
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark
                                  ? AppColors.darkSoft
                                  : AppColors.lightSoft,
                            ),
                          ),
                        ],
                      ),
                    ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Dynamic Central Celestial Pulse Beacon Widget
/// Features expanding concentric fluid wave ripples, tactile bloom physics,
/// and a luminous starlight sign instead of generic emojis.
class StagePulseBeacon extends StatefulWidget {
  final bool isPulsing;
  final bool isDark;
  final VoidCallback onTap;

  const StagePulseBeacon({
    super.key,
    required this.isPulsing,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<StagePulseBeacon> createState() => _StagePulseBeaconState();
}

class _StagePulseBeaconState extends State<StagePulseBeacon>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.90)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.90, end: 1.22)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.22, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 50,
      ),
    ]).animate(_animController);

    _rotationAnimation = Tween<double>(begin: 0.0, end: 0.125).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
      ),
    );

    if (widget.isPulsing) {
      _animController.forward(from: 0.0);
    }
  }

  @override
  void didUpdateWidget(covariant StagePulseBeacon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPulsing && !oldWidget.isPulsing) {
      _animController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _handleTap() {
    _animController.forward(from: 0.0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;

    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _animController,
        builder: (context, child) {
          final progress = _animController.value;
          final isPulsing = widget.isPulsing || _animController.isAnimating;

          return SizedBox(
            width: 72,
            height: 72,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // 1. Fluid Concentric Expanding Ripple Waves
                if (progress > 0.0 && progress < 1.0)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _PulseRipplePainter(
                        progress: progress,
                        color: AppColors.terra,
                      ),
                    ),
                  ),

                // 2. Ambient Starlight Energy Halo
                if (isPulsing)
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.terra.withOpacity(
                              (0.55 * (1.0 - (progress * 0.5))).clamp(0.0, 1.0)),
                          blurRadius: 22,
                          spreadRadius: 4,
                        ),
                        BoxShadow(
                          color: const Color(0xFFE89A8A).withOpacity(
                              (0.35 * (1.0 - (progress * 0.5))).clamp(0.0, 1.0)),
                          blurRadius: 36,
                          spreadRadius: 8,
                        ),
                      ],
                    ),
                  ),

                // 3. Central Tactile Beacon Button
                Transform.scale(
                  scale: _scaleAnimation.value,
                  child: RotationTransition(
                    turns: _rotationAnimation,
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isPulsing
                              ? [
                                  AppColors.terra.withOpacity(0.35),
                                  const Color(0xFFE89A8A).withOpacity(0.25),
                                ]
                              : [
                                  isDark
                                      ? AppColors.darkCard
                                      : AppColors.lightCard,
                                  isDark
                                      ? AppColors.darkSurface
                                      : AppColors.lightSurface,
                                ],
                        ),
                        border: Border.all(
                          color: isPulsing
                              ? AppColors.terra
                              : (isDark
                                  ? AppColors.darkBorder
                                  : AppColors.lightBorder),
                          width: isPulsing ? 2.0 : 1.2,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: isPulsing
                          ? ShaderMask(
                              shaderCallback: (bounds) => const LinearGradient(
                                colors: [Color(0xFFFFB4A2), Color(0xFFE07A5F)],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ).createShader(bounds),
                              child: const Icon(
                                Icons.auto_awesome_rounded,
                                size: 24,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              Icons.auto_awesome_rounded,
                              size: 19,
                              color: isDark
                                  ? AppColors.darkSoft
                                  : AppColors.lightSoft,
                            ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// CustomPainter that renders organic expanding water-ripple wavefronts
class _PulseRipplePainter extends CustomPainter {
  final double progress;
  final Color color;

  _PulseRipplePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0 || progress >= 1.0) return;

    final center = Offset(size.width / 2, size.height / 2);
    // Expand from inner button radius (26px) up to 68px (136px diameter)
    const minRadius = 26.0;
    const maxRadius = 68.0;

    for (int i = 0; i < 3; i++) {
      final waveDelay = i * 0.16;
      if (progress < waveDelay) continue;

      final waveProgress = (progress - waveDelay) / (1.0 - waveDelay);
      final curved = Curves.easeOutCubic.transform(waveProgress);
      final radius = minRadius + curved * (maxRadius - minRadius);
      final opacity = ((1.0 - curved) * 0.65).clamp(0.0, 1.0);

      final strokePaint = Paint()
        ..color = color.withOpacity(opacity * (1.0 - (i * 0.2)))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2 + (1.0 - curved) * 1.5;

      canvas.drawCircle(center, radius, strokePaint);

      // Delicate soft glow on the primary leading wave
      if (i == 0 && curved < 0.5) {
        final glowPaint = Paint()
          ..color =
              color.withOpacity((0.14 * (1.0 - curved * 2)).clamp(0.0, 1.0))
          ..style = PaintingStyle.fill;
        canvas.drawCircle(center, radius, glowPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PulseRipplePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
