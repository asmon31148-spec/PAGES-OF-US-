import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../main.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _startTransitionTimer();
  }

  void _startTransitionTimer() {
    Timer(const Duration(milliseconds: 1400), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const AuthGate(),
            transitionsBuilder: (_, animation, __, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 350),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFECB92),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Adorable Couple Polaroid Artwork
              Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset(
                  'assets/icon.png',
                  fit: BoxFit.cover,
                ),
              )
                  .animate()
                  .scale(
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutBack,
                  )
                  .fadeIn(duration: const Duration(milliseconds: 500)),

              const SizedBox(height: 28),

              // Title
              const Text(
                'Pages of Us',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: Color(0xFF4A3428),
                ),
              )
                  .animate()
                  .fadeIn(delay: const Duration(milliseconds: 250), duration: const Duration(milliseconds: 500))
                  .slideY(begin: 0.2, end: 0, curve: Curves.easeOutQuad),

              const SizedBox(height: 8),

              // Subtitle
              Text(
                'A sanctuary for two ✦',
                style: TextStyle(
                  fontSize: 13.5,
                  fontStyle: FontStyle.italic,
                  letterSpacing: 0.2,
                  color: const Color(0xFF4A3428).withOpacity(0.7),
                ),
              )
                  .animate()
                  .fadeIn(delay: const Duration(milliseconds: 400), duration: const Duration(milliseconds: 500)),
            ],
          ),
        ),
      ),
    );
  }
}
