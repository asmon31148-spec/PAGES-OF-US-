import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/theme_provider.dart';

class PolicyDialogs {
  static void showPrivacyPolicy(BuildContext context) {
    _showLegalSheet(
      context: context,
      title: 'Privacy Policy',
      icon: Icons.shield_outlined,
      sections: const [
        _PolicySection(
          title: '1. Sanctuary for Two (Couple Privacy First)',
          content:
              'Pages of Us is built from the ground up as a private sanctuary for two partners. '
              'Your letters, voice whispers, photos, vault media, and location coordinates are visible '
              'only to you and your paired partner.',
        ),
        _PolicySection(
          title: '2. Zero Ad Tracking & No Data Selling',
          content:
              'We do not sell, rent, monetize, or broker your personal data or couple moments to any '
              'third party or advertising network. There are zero third-party tracking pixels or ad SDKs in this app.',
        ),
        _PolicySection(
          title: '3. Media Storage & Encryption',
          content:
              'Photos and videos are stored in isolated cloud storage containers (Cloudinary & Supabase) with signed URLs. '
              'Letters, goals, and vault contents remain accessible only within your authenticated shared space.',
        ),
        _PolicySection(
          title: '4. Location & Presence Safeguards',
          content:
              'Location coordinates on the World Map are updated only when you interact with the app. '
              'They are shared strictly with your connected partner for travel estimation and map tethering.',
        ),
        _PolicySection(
          title: '5. Your Right to Delete',
          content:
              'You have full ownership of your data. You may unpair from a space or request full account and '
              'space deletion at any time by contacting our support concierge or through the profile menu.',
        ),
      ],
    );
  }

  static void showTermsOfService(BuildContext context) {
    _showLegalSheet(
      context: context,
      title: 'Terms of Service',
      icon: Icons.gavel_outlined,
      sections: const [
        _PolicySection(
          title: '1. Peaceful Sanctuary Agreement',
          content:
              'By entering Pages of Us, you agree to treat the digital sanctuary with peace, respect, and mutual love. '
              'The application is intended for intimate, consensual couple communication.',
        ),
        _PolicySection(
          title: '2. Content Ownership',
          content:
              'You retain 100% intellectual property ownership over any memories, photos, letters, and voice notes '
              'uploaded to your space.',
        ),
        _PolicySection(
          title: '3. Security & PIN Safeguards',
          content:
              'You are responsible for keeping your account credentials and Vault PIN confidential. '
              'If you suspect any unauthorized access, reset your password immediately.',
        ),
        _PolicySection(
          title: '4. Service Availability & Updates',
          content:
              'We continuously maintain and refine Pages of Us with zero WebView latency and pure native Flutter architecture. '
              'Periodic updates ensure ongoing security, cloud sync stability, and widget functionality.',
        ),
      ],
    );
  }

  static void showAbout(BuildContext context) {
    final isDark = context.read<ThemeProvider>().isDark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [AppColors.sage, AppColors.rose],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Center(
                  child: Text('✦', style: TextStyle(fontSize: 28, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Pages of Us',
                style: TextStyle(
                  fontFamily: 'serif',
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkInk : AppColors.lightInk,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Version 1.0.0 (Native Flutter Edition)',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'A tranquil digital sanctuary crafted exclusively for two lovers to linger, whisper, and remember. '
                'Engineered with zero WebView latency, 0ms instant local cache, pure hardware audio ducking, and interactive couple widgets.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.5,
                  color: isDark ? AppColors.darkInk : AppColors.lightInk,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.sage,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Back to Sanctuary ✦'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static void _showLegalSheet({
    required BuildContext context,
    required String title,
    required IconData icon,
    required List<_PolicySection> sections,
  }) {
    final isDark = context.read<ThemeProvider>().isDark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.92,
        builder: (_, scrollController) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                children: [
                  Icon(icon, color: AppColors.sage, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'serif',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.darkInk : AppColors.lightInk,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                    ),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(height: 20),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  itemCount: sections.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (_, index) {
                    final s = sections[index];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.darkInk : AppColors.lightInk,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          s.content,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.45,
                            color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PolicySection {
  final String title;
  final String content;

  const _PolicySection({required this.title, required this.content});
}
