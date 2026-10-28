import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../core/services/media_upload_service.dart';
import '../../../core/services/update_service.dart';
import '../../../core/widgets/update_dialog.dart';
import '../widgets/policy_dialogs.dart';
import 'support_bot_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _thoughtController;
  bool _isSaving = false;
  bool _isUploadingAvatar = false;
  final ImagePicker _picker = ImagePicker();

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

  Future<void> _pickAndUploadAvatar(ImageSource source) async {
    Navigator.pop(context); // close picker bottom sheet
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked == null) return;

      setState(() => _isUploadingAvatar = true);

      final file = File(picked.path);
      final result = await MediaUploadService.uploadFile(file, folder: 'avatars');

      if (!mounted) return;
      final authProvider = context.read<AuthProvider>();
      await authProvider.updateProfile(avatarUrl: result.url);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile picture updated ✦'),
          backgroundColor: AppColors.sage,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update picture: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
      }
    }
  }

  void _showAvatarPickerSheet(bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Change Profile Photo',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkInk : AppColors.lightInk,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: AppColors.sage),
                title: Text(
                  'Choose from Gallery',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.darkInk : AppColors.lightInk,
                  ),
                ),
                onTap: () => _pickAndUploadAvatar(ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: AppColors.sage),
                title: Text(
                  'Take Photo with Camera',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.darkInk : AppColors.lightInk,
                  ),
                ),
                onTap: () => _pickAndUploadAvatar(ImageSource.camera),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveProfile() async {
    final cleanName = _nameController.text.trim();
    final cleanThought = _thoughtController.text.trim();

    setState(() => _isSaving = true);
    final authProvider = context.read<AuthProvider>();
    await authProvider.updateProfile(
      nickname: cleanName.isEmpty ? 'Partner' : cleanName,
      thought: cleanThought,
    );
    setState(() => _isSaving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile saved successfully ✦'),
          backgroundColor: AppColors.sage,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _confirmLogout(BuildContext context, AuthProvider authProvider) {
    final isDark = context.read<ThemeProvider>().isDark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Log Out of Sanctuary?',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.darkInk : AppColors.lightInk,
          ),
        ),
        content: Text(
          'Your sanctuary will remain secure. You can log back in anytime with your credentials.',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              Navigator.pop(context); // exit profile screen
              await authProvider.signOut();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;
    final partner = authProvider.partner;
    final space = authProvider.space;

    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final ink = isDark ? AppColors.darkInk : AppColors.lightInk;
    final soft = isDark ? AppColors.darkSoft : AppColors.lightSoft;
    final cardBg = isDark ? AppColors.darkCard : AppColors.lightCard;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final avatarUrl = user?.avatarUrl;
    final initial = (user?.nickname.isNotEmpty ?? false)
        ? user!.nickname.substring(0, 1).toUpperCase()
        : '✦';

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 18, color: ink),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Your Sanctuary Profile',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: ink,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => _confirmLogout(context, authProvider),
            child: const Text(
              'Log out',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.redAccent,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Large Profile Avatar with Camera Badge
              Center(
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.sage, width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.sage.withOpacity(0.25),
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: _isUploadingAvatar
                            ? const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: AppColors.sage,
                                ),
                              )
                            : (avatarUrl != null && avatarUrl.isNotEmpty)
                                ? CachedNetworkImage(
                                    imageUrl: avatarUrl,
                                    fit: BoxFit.cover,
                                    placeholder: (_, __) => Container(
                                      color: cardBg,
                                      child: const Center(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppColors.sage,
                                        ),
                                      ),
                                    ),
                                    errorWidget: (_, __, ___) => _buildAvatarFallback(initial),
                                  )
                                : _buildAvatarFallback(initial),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _showAvatarPickerSheet(isDark),
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: AppColors.sage,
                          shape: BoxShape.circle,
                          border: Border.all(color: bg, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          size: 15,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                user?.nickname ?? 'Partner',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: ink,
                ),
              ),
              Text(
                user?.email ?? '',
                style: TextStyle(fontSize: 11, color: soft),
              ),
              const SizedBox(height: 20),

              // 2. Profile Edit Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Nickname',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: soft,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _nameController,
                      style: TextStyle(fontSize: 13, color: ink),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: cardBg,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    Text(
                      'Personal Note / Thought Bubble',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: soft,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _thoughtController,
                      maxLines: 2,
                      style: TextStyle(fontSize: 13, color: ink),
                      decoration: InputDecoration(
                        hintText: 'e.g. Thinking of you 🌿 or on my way...',
                        hintStyle: TextStyle(fontSize: 12, color: soft),
                        filled: true,
                        fillColor: cardBg,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveProfile,
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
                                'Save Profile ✦',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 3. Space Connection Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.link_rounded, color: AppColors.sage, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Shared Sanctuary Space',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: ink,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (partner != null) ...[
                      Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [AppColors.rose, AppColors.terra],
                              ),
                            ),
                            child: ClipOval(
                              child: (partner.avatarUrl != null &&
                                      partner.avatarUrl!.isNotEmpty)
                                  ? CachedNetworkImage(
                                      imageUrl: partner.avatarUrl!,
                                      fit: BoxFit.cover,
                                    )
                                  : Center(
                                      child: Text(
                                        partner.nickname.isNotEmpty
                                            ? partner.nickname[0].toUpperCase()
                                            : 'P',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  partner.nickname,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: ink,
                                  ),
                                ),
                                Text(
                                  'Paired in sanctuary ✦',
                                  style: TextStyle(fontSize: 11, color: AppColors.sage),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      Text(
                        'Not paired with a partner yet. Share your Pair Code to connect.',
                        style: TextStyle(fontSize: 11.5, color: soft),
                      ),
                    ],
                    if (space?.pairCode != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Text(
                              'Pair Code: ',
                              style: TextStyle(fontSize: 11, color: soft),
                            ),
                            Text(
                              space!.pairCode,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                                color: ink,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.copy_rounded, size: 16),
                              color: AppColors.sage,
                              tooltip: 'Copy Pair Code',
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: space.pairCode));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Pair Code copied to clipboard ✦'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 4. Sanctuary Concierge & Support Bot (Help)
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SupportBotScreen()),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [AppColors.darkSurface, AppColors.forest.withOpacity(0.5)]
                          : [AppColors.lightSurface, AppColors.sage.withOpacity(0.12)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.sage.withOpacity(0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.sage,
                        ),
                        child: const Center(
                          child: Text('🌿', style: TextStyle(fontSize: 22)),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Sanctuary Concierge & Help',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: ink,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.sage,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    '24/7',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Chat with our assistant for complaints, bug reports, or feature ideas.',
                              style: TextStyle(fontSize: 11, color: soft),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios_rounded, size: 14, color: soft),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 5. Legal & Policies Section
              Container(
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: border),
                ),
                child: Column(
                  children: [
                    _buildSettingsTile(
                      icon: Icons.shield_outlined,
                      title: 'Privacy Policy',
                      subtitle: 'Couple data ownership & zero tracking guarantee',
                      ink: ink,
                      soft: soft,
                      onTap: () => PolicyDialogs.showPrivacyPolicy(context),
                    ),
                    Divider(height: 1, color: border, indent: 50),
                    _buildSettingsTile(
                      icon: Icons.gavel_outlined,
                      title: 'Terms of Service',
                      subtitle: 'Peaceful sanctuary usage & etiquette',
                      ink: ink,
                      soft: soft,
                      onTap: () => PolicyDialogs.showTermsOfService(context),
                    ),
                    Divider(height: 1, color: border, indent: 50),
                    _buildSettingsTile(
                      icon: Icons.info_outline_rounded,
                      title: 'About Pages of Us',
                      subtitle: 'Version ${UpdateService.currentVersion} (Native Flutter Edition)',
                      ink: ink,
                      soft: soft,
                      onTap: () => PolicyDialogs.showAbout(context),
                    ),
                    Divider(height: 1, color: border, indent: 50),
                    _buildSettingsTile(
                      icon: Icons.system_update_rounded,
                      title: 'Check for Updates',
                      subtitle: 'Get latest features & fixes directly',
                      ink: ink,
                      soft: soft,
                      onTap: () async {
                        final update = await UpdateService.checkLatestRelease();
                        if (!context.mounted) return;
                        if (update != null) {
                          showDialog(
                            context: context,
                            builder: (_) => UpdateDialog(updateInfo: update),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('You are on the latest version of Pages of Us ✨'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarFallback(String initial) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.sage, AppColors.rose],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color ink,
    required Color soft,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.sage, size: 22),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: ink,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 10.5, color: soft),
      ),
      trailing: Icon(Icons.arrow_forward_ios_rounded, size: 12, color: soft),
      onTap: onTap,
    );
  }
}
