import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class TimeLockCountdownWidget extends StatefulWidget {
  final DateTime unlockAt;
  final String title;
  final VoidCallback? onUnlocked;

  const TimeLockCountdownWidget({
    super.key,
    required this.unlockAt,
    required this.title,
    this.onUnlocked,
  });

  @override
  State<TimeLockCountdownWidget> createState() => _TimeLockCountdownWidgetState();
}

class _TimeLockCountdownWidgetState extends State<TimeLockCountdownWidget> {
  late Timer _timer;
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    _remaining = widget.unlockAt.difference(DateTime.now());
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final diff = widget.unlockAt.difference(DateTime.now());
      if (diff.isNegative) {
        _timer.cancel();
        widget.onUnlocked?.call();
      } else {
        setState(() => _remaining = diff);
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final days = _remaining.inDays;
    final hours = _remaining.inHours % 24;
    final minutes = _remaining.inMinutes % 60;
    final seconds = _remaining.inSeconds % 60;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: AppColors.romanceCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.romanceRoseGold.withOpacity(0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppColors.romanceWine.withOpacity(0.3),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Hourglass / Lock Icon with glow
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.romanceWine.withOpacity(0.4),
              border: Border.all(color: AppColors.romanceRoseGold.withOpacity(0.6), width: 1.5),
            ),
            child: const Icon(Icons.lock_clock_rounded, color: AppColors.romanceRoseGold, size: 30),
          ),
          const SizedBox(height: 16),

          Text(
            widget.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.romanceInk,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'TIME-LOCKED SPECIAL CAPSULE',
            style: TextStyle(
              color: AppColors.romanceGold,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 20),

          // Glowing Countdown Digits
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildTimeUnit('$days', 'DAYS'),
              _buildDivider(),
              _buildTimeUnit('${hours.toString().padLeft(2, '0')}', 'HOURS'),
              _buildDivider(),
              _buildTimeUnit('${minutes.toString().padLeft(2, '0')}', 'MIN'),
              _buildDivider(),
              _buildTimeUnit('${seconds.toString().padLeft(2, '0')}', 'SEC'),
            ],
          ),
          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'Patience my love... something magical is waiting for you ✨',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.romanceSoft,
                fontSize: 11.5,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeUnit(String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 52,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.romanceSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.romanceRoseGold.withOpacity(0.2)),
          ),
          child: Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.romanceInk,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.romanceSoft,
            fontSize: 9,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        ':',
        style: TextStyle(
          color: AppColors.romanceRoseGold,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
