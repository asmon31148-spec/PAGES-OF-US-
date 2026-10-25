import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/auth_provider.dart';

class ProfileModal extends StatefulWidget {
  const ProfileModal({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ProfileModal(),
    );
  }

  @override
  State<ProfileModal> createState() => _ProfileModalState();
}

class _ProfileModalState extends State<ProfileModal> {
  late TextEditingController _nameController;
  late TextEditingController _thoughtController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _nameController = TextEditingController(text: user?.nickname ?? '');
    _thoughtController = TextEditingController(text: user?.thought ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _thoughtController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.bottom(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Your Sanctuary Profile',
                    style: TextStyle(
                      fontFamily: 'serif',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.darkInk : AppColors.lightInk,
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      await authProvider.signOut();
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: const Text(
                      'Log out',
                      style: TextStyle(fontSize: 12, color: Colors.redAccent),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Nickname Field
              Text(
                'Your Nickname',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _nameController,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.darkInk : AppColors.lightInk,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Thought Note Field
              Text(
                'Personal Note / Thought Bubble',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _thoughtController,
                maxLines: 2,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.darkInk : AppColors.lightInk,
                ),
                decoration: InputDecoration(
                  hintText: 'e.g. Thinking of you, or on my way...',
                  hintStyle: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                  ),
                  filled: true,
                  fillColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 18),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving
                      ? null
                      : () async {
                          setState(() => _isSaving = true);
                          await authProvider.updateProfile(
                            nickname: _nameController.text.trim(),
                            thought: _thoughtController.text.trim(),
                          );
                          setState(() => _isSaving = false);
                          if (context.mounted) Navigator.pop(context);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.sage,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Save Profile',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
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
