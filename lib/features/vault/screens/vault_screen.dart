import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/media_upload_service.dart';
import '../../../core/widgets/full_screen_video_player.dart';
import '../widgets/vault_video_thumbnail.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/vault_provider.dart';
import '../../stage/widgets/app_top_bar.dart';
import '../../stage/widgets/profile_modal.dart';

class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key});

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.space != null) {
        context.read<VaultProvider>().initVaultSync(auth.space!.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;
    final vaultProvider = context.watch<VaultProvider>();
    final authProvider = context.watch<AuthProvider>();
    final spaceId = authProvider.space?.id ?? 'default_space';

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      body: SafeArea(
        child: Column(
          children: [
            AppTopBar(
              title: 'Our Vault',
              subtitle: 'Confidential time capsule & secret note',
              onOpenProfile: () => ProfileModal.show(context),
            ),
            Expanded(
              child: vaultProvider.isUnlocked
                  ? _buildUnlockedVault(context, vaultProvider, isDark, spaceId)
                  : _buildLockedKeypad(context, vaultProvider, isDark),
            ),
          ],
        ),
      ),
    );
  }

  // --- LOCKED KEYPAD ---
  Widget _buildLockedKeypad(
    BuildContext context,
    VaultProvider vaultProvider,
    bool isDark,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.terra.withOpacity(0.12),
              border: Border.all(color: AppColors.terra.withOpacity(0.3)),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.lock_outline, size: 36, color: AppColors.terra),
          ),
          const SizedBox(height: 16),
          Text(
            'Sanctuary Vault',
            style: TextStyle(
              fontFamily: 'serif',
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.darkInk : AppColors.lightInk,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Enter your 4-digit couple passcode to unseal',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
            ),
          ),
          const SizedBox(height: 24),

          // 4-Digit PIN Indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (index) {
              final isFilled = index < vaultProvider.enteredPin.length;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 10),
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: vaultProvider.isError
                      ? Colors.redAccent
                      : isFilled
                          ? AppColors.terra
                          : (isDark ? AppColors.darkCard : AppColors.lightBorder),
                  border: Border.all(
                    color: vaultProvider.isError
                        ? Colors.redAccent
                        : (isFilled ? AppColors.terra : AppColors.lightBorder),
                  ),
                ),
              );
            }),
          ),
          if (vaultProvider.isError)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Incorrect passcode. Please try again.',
                style: const TextStyle(fontSize: 11, color: Colors.redAccent, fontWeight: FontWeight.bold),
              ),
            ),
          const SizedBox(height: 32),

          // Numerical Keypad Grid
          SizedBox(
            width: 260,
            child: Column(
              children: [
                _buildKeypadRow(['1', '2', '3'], vaultProvider, isDark),
                const SizedBox(height: 14),
                _buildKeypadRow(['4', '5', '6'], vaultProvider, isDark),
                const SizedBox(height: 14),
                _buildKeypadRow(['7', '8', '9'], vaultProvider, isDark),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildKeypadButton('C', isDark, onTap: () {
                      HapticFeedback.lightImpact();
                      vaultProvider.clearPin();
                    }),
                    _buildKeypadButton('0', isDark, onTap: () {
                      HapticFeedback.lightImpact();
                      vaultProvider.appendPinDigit('0');
                    }),
                    _buildKeypadButton('⌫', isDark, onTap: () {
                      HapticFeedback.lightImpact();
                      vaultProvider.deletePinDigit();
                    }),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Default couple PIN: 2512',
            style: TextStyle(
              fontSize: 10,
              fontStyle: FontStyle.italic,
              color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeypadRow(
    List<String> digits,
    VaultProvider provider,
    bool isDark,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: digits.map((d) {
        return _buildKeypadButton(d, isDark, onTap: () {
          HapticFeedback.lightImpact();
          provider.appendPinDigit(d);
        });
      }).toList(),
    );
  }

  Widget _buildKeypadButton(
    String label,
    bool isDark, {
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          shape: BoxShape.circle,
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.darkInk : AppColors.lightInk,
          ),
        ),
      ),
    );
  }

  // --- UNLOCKED CAPSULE ---
  Widget _buildUnlockedVault(
    BuildContext context,
    VaultProvider vaultProvider,
    bool isDark,
    String spaceId,
  ) {
    final vault = vaultProvider.vault;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('🔓', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Text(
                    'VAULT UNLOCKED',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                      color: AppColors.sage,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    onPressed: () => _showEditVaultModal(context, vaultProvider, spaceId),
                    tooltip: 'Edit Capsule',
                  ),
                  IconButton(
                    icon: const Icon(Icons.lock, size: 20, color: AppColors.terra),
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      vaultProvider.lockVault();
                    },
                    tooltip: 'Lock Vault',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Confidential Media Area
          if (vault.videoUrl != null && vault.videoUrl!.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: _buildVaultMediaPreview(vault.videoUrl!, vault.title, isDark),
            ),

          // Secret Note Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vault.title,
                  style: TextStyle(
                    fontFamily: 'serif',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkInk : AppColors.lightInk,
                  ),
                ),
                Text(
                  vault.subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                  ),
                ),
                const Divider(height: 24),
                Text(
                  vault.personalNote,
                  style: TextStyle(
                    fontFamily: 'serif',
                    fontSize: 15,
                    fontStyle: FontStyle.italic,
                    height: 1.6,
                    color: isDark ? AppColors.darkInk : AppColors.lightInk,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Lock Button
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                side: BorderSide(color: AppColors.terra.withOpacity(0.5)),
              ),
              icon: const Icon(Icons.lock, size: 16, color: AppColors.terra),
              label: const Text(
                'Lock Vault & Return',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.terra),
              ),
              onPressed: () {
                HapticFeedback.mediumImpact();
                vaultProvider.lockVault();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVaultMediaPreview(String mediaUrl, String title, bool isDark) {
    final isVideo = mediaUrl.contains('.mp4') || mediaUrl.contains('.mov') || mediaUrl.contains('video/');

    if (isVideo) {
      return VaultVideoThumbnail(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FullScreenVideoPlayer(
                videoUrl: mediaUrl,
                title: title,
                subtitle: 'Confidential Vault Film',
              ),
            ),
          );
        },
      );
    }

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: CachedNetworkImage(imageUrl: mediaUrl, fit: BoxFit.cover),
    );
  }

  void _showEditVaultModal(
    BuildContext context,
    VaultProvider vaultProvider,
    String spaceId,
  ) {
    final titleCtrl = TextEditingController(text: vaultProvider.vault.title);
    final subtitleCtrl = TextEditingController(text: vaultProvider.vault.subtitle);
    final noteCtrl = TextEditingController(text: vaultProvider.vault.personalNote);
    final pinCtrl = TextEditingController(text: vaultProvider.vault.passcode);
    String? mediaUrl = vaultProvider.vault.videoUrl;
    bool isUploading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Edit Sanctuary Capsule', style: TextStyle(fontFamily: 'serif', fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Capsule Title')),
                      const SizedBox(height: 10),
                      TextField(controller: subtitleCtrl, decoration: const InputDecoration(labelText: 'Subtitle')),
                      const SizedBox(height: 10),
                      TextField(controller: noteCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Secret Note / Message')),
                      const SizedBox(height: 10),
                      TextField(controller: pinCtrl, maxLength: 4, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '4-Digit Passcode PIN')),
                      const SizedBox(height: 10),

                      // Media attachment button
                      OutlinedButton.icon(
                        icon: isUploading
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.attach_file, size: 16),
                        label: Text(mediaUrl != null && mediaUrl!.isNotEmpty ? 'Change Video / Photo 🎬' : 'Attach Video or Photo 🎬'),
                        onPressed: () async {
                          final picker = ImagePicker();
                          final XFile? file = await picker.pickMedia();
                          if (file != null) {
                            setModalState(() => isUploading = true);
                            try {
                              final res = await MediaUploadService.uploadFile(File(file.path), folder: 'vault');
                              setModalState(() {
                                mediaUrl = res.url;
                                isUploading = false;
                              });
                            } catch (_) {
                              setModalState(() => isUploading = false);
                            }
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.sage,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: () {
                            vaultProvider.updateVaultConfig(
                              spaceId: spaceId,
                              title: titleCtrl.text.trim(),
                              subtitle: subtitleCtrl.text.trim(),
                              passcode: pinCtrl.text.trim().isNotEmpty ? pinCtrl.text.trim() : '2512',
                              videoUrl: mediaUrl,
                              personalNote: noteCtrl.text.trim(),
                            );
                            Navigator.pop(ctx);
                          },
                          child: const Text('Save Capsule ✦', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

