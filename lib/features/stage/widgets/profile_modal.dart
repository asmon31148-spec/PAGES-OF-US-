import 'package:flutter/material.dart';
import '../../profile/screens/profile_screen.dart';

class ProfileModal extends StatelessWidget {
  const ProfileModal({super.key});

  static void show(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const ProfileScreen();
  }
}
