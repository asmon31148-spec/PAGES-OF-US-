import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import '../../../core/theme/app_colors.dart';

class RomanceConfettiOverlay extends StatelessWidget {
  final ConfettiController controller;

  const RomanceConfettiOverlay({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConfettiWidget(
        confettiController: controller,
        blastDirectionality: BlastDirectionality.explosive,
        shouldLoop: false,
        emissionFrequency: 0.06,
        numberOfParticles: 35,
        maxBlastForce: 25,
        minBlastForce: 10,
        gravity: 0.25,
        colors: const [
          AppColors.romanceRoseGold,
          AppColors.romanceWine,
          AppColors.romanceGold,
          Color(0xFFF472B6), // Soft Rose Petal Pink
          Color(0xFFFDE047), // Golden shimmer
          Colors.white,
        ],
      ),
    );
  }
}
