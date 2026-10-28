import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/vault_item.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/vault_provider.dart';
import '../../stage/widgets/app_top_bar.dart';
import '../../stage/widgets/profile_modal.dart';
import '../widgets/vault_emblem.dart';
import 'new_vault_screen.dart';
import 'vault_detail_screen.dart';

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
      _syncVaults();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncVaults();
  }

  void _syncVaults() {
    final auth = context.read<AuthProvider>();
    final spaceId = auth.space?.id ?? auth.user?.spaceId;
    if (spaceId != null && spaceId.isNotEmpty) {
      context.read<VaultProvider>().initVaultSync(spaceId);
    }
  }

  void _openProfileModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ProfileModal(),
    );
  }

  void _navigateToNewVault() {
    final auth = context.read<AuthProvider>();
    final spaceId = auth.space?.id ?? auth.user?.spaceId;
    final user = auth.user;
    if (spaceId == null || spaceId.isEmpty || user == null) return;

    final partnerNickname = auth.partner?.nickname ?? 'Partner';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NewVaultScreen(
          spaceId: spaceId,
          currentUserId: user.id,
          userNickname: user.nickname,
          partnerNickname: partnerNickname,
        ),
      ),
    );
  }

  void _onVaultTapped(VaultItem vault, String currentUserId, String partnerNickname, String spaceId, String userNickname) {
    final vp = context.read<VaultProvider>();
    final isLocked = vp.isVaultLocked(vault, currentUserId);

    if (!isLocked) {
      _openVaultDetail(vault, spaceId, currentUserId, userNickname, partnerNickname);
      return;
    }

    // Vault is locked for current user
    if (vault.accessMode == 'timer') {
      _showTimerLockedModal(vault);
    } else if (vault.accessMode == 'pin') {
      _showPinUnlockDialog(vault, spaceId, currentUserId, userNickname, partnerNickname);
    }
  }

  void _openVaultDetail(VaultItem vault, String spaceId, String currentUserId, String userNickname, String partnerNickname) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VaultDetailScreen(
          vault: vault,
          spaceId: spaceId,
          currentUserId: currentUserId,
          userNickname: userNickname,
          partnerNickname: partnerNickname,
        ),
      ),
    );
  }

  void _showTimerLockedModal(VaultItem vault) {
    final days = vault.daysRemaining;
    final dateStr = vault.specialDate != null
        ? DateFormat('MMMM d, yyyy').format(vault.specialDate!)
        : 'Special Date';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        decoration: const BoxDecoration(
          color: Color(0xFF16141F),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFFD4AF37).withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.hourglass_top_rounded, color: Color(0xFFD4AF37), size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              vault.title,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Sealed by ${vault.creatorName}',
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black38,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white12),
              ),
              child: Text(
                days > 0
                    ? 'Unlocks automatically in $days days\n($dateStr)'
                    : 'Unlocks on $dateStr',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFD4AF37), fontSize: 13, height: 1.4),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('I will wait patiently ✨', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPinUnlockDialog(VaultItem vault, String spaceId, String currentUserId, String userNickname, String partnerNickname) {
    final pinController = TextEditingController();
    String? errorMessage;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF16141F),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Column(
              children: [
                const Icon(Icons.lock_outline_rounded, color: Color(0xFFD4AF37), size: 36),
                const SizedBox(height: 10),
                Text(
                  vault.title,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Protected with a secret PIN by ${vault.creatorName}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: pinController,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 6,
                  autofocus: true,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 22, letterSpacing: 8),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '••••',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.2), letterSpacing: 8),
                    filled: true,
                    fillColor: Colors.black38,
                    errorText: errorMessage,
                    errorStyle: const TextStyle(color: Color(0xFFE57373)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFD4AF37)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                onPressed: () {
                  final pin = pinController.text.trim();
                  final success = context.read<VaultProvider>().unlockWithPin(vault, pin);
                  if (success) {
                    Navigator.pop(ctx);
                    _openVaultDetail(vault, spaceId, currentUserId, userNickname, partnerNickname);
                  } else {
                    setDialogState(() {
                      errorMessage = 'Incorrect PIN. Try again.';
                      pinController.clear();
                    });
                  }
                },
                child: const Text('Unlock', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vaultProvider = context.watch<VaultProvider>();
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;
    final partner = authProvider.partner;
    final space = authProvider.space;

    final currentUserId = user?.id ?? '';
    final userNickname = user?.nickname ?? 'You';
    final partnerNickname = partner?.nickname ?? 'Partner';
    final spaceId = space?.id ?? user?.spaceId ?? '';

    final vaults = vaultProvider.vaults;
    final filteredVaults = vaultProvider.getFilteredVaults(currentUserId);
    final activeFilter = vaultProvider.activeFilter;

    final allCount = vaults.length;
    final mineCount = vaults.where((v) => v.creatorId == currentUserId || v.creatorId.isEmpty).length;
    final partnerCount = vaults.where((v) => v.creatorId.isNotEmpty && v.creatorId != currentUserId).length;
    final lockedCount = vaults.where((v) => vaultProvider.isVaultLocked(v, currentUserId)).length;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0B12),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Top Bar (Vault has NO day/night mood toggle; permanently luxury dark)
            AppTopBar(
              onAvatarTap: _openProfileModal,
              overrideTitle: 'Our Vaults',
              overrideSubtitle: '$allCount vaults · $lockedCount locked',
              showThemeToggle: false,
              forceDark: true,
            ),

            // 2. Filter Chips Row (Matching Image 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              child: Row(
                children: [
                  _buildFilterChip(
                    label: 'All ($allCount)',
                    isActive: activeFilter == 'all',
                    onTap: () => vaultProvider.setFilter('all'),
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    label: 'By You ($mineCount)',
                    isActive: activeFilter == 'mine',
                    onTap: () => vaultProvider.setFilter('mine'),
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    label: 'By $partnerNickname ($partnerCount)',
                    isActive: activeFilter == 'partner',
                    onTap: () => vaultProvider.setFilter('partner'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),

            // 3. 2-Column Grid (Cards + New Vault Dashed Card)
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 0.74,
                ),
                itemCount: filteredVaults.length + 1, // +1 for "+ New vault" card
                itemBuilder: (context, index) {
                  // Last card is always "+ New vault" dashed card
                  if (index == filteredVaults.length) {
                    return _buildNewVaultDashedCard();
                  }

                  final vault = filteredVaults[index];
                  final isLocked = vaultProvider.isVaultLocked(vault, currentUserId);
                  return _buildVaultCard(
                    vault: vault,
                    isLocked: isLocked,
                    currentUserId: currentUserId,
                    partnerNickname: partnerNickname,
                    onTap: () => _onVaultTapped(vault, currentUserId, partnerNickname, spaceId, userNickname),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Filter Chip Pill ---

  Widget _buildFilterChip({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? Colors.white.withOpacity(0.12) : const Color(0xFF16141F),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isActive ? const Color(0xFFD4AF37) : Colors.white12,
            width: isActive ? 1.2 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.white60,
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // --- Vault Grid Card (Matching Image 1) ---

  Widget _buildVaultCard({
    required VaultItem vault,
    required bool isLocked,
    required String currentUserId,
    required String partnerNickname,
    required VoidCallback onTap,
  }) {
    final isOwner = vault.creatorId.isEmpty || vault.creatorId == currentUserId;
    final creatorLabel = isOwner ? 'By You' : 'By $partnerNickname';

    // Badge styling & content
    String badgeText;
    IconData badgeIcon;

    if (isLocked && vault.accessMode == 'timer') {
      final days = vault.daysRemaining;
      badgeText = days > 0 ? 'Opens in $days d' : 'Opens today';
      badgeIcon = Icons.hourglass_top_rounded;
    } else if (isLocked && vault.accessMode == 'pin') {
      badgeText = 'PIN locked';
      badgeIcon = Icons.lock_outline_rounded;
    } else {
      badgeText = '${vault.totalMemoriesCount} memories';
      badgeIcon = Icons.photo_library_outlined;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Color(vault.colorValue),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFD4AF37).withOpacity(0.35),
            width: 1.1,
          ),
          boxShadow: [
            BoxShadow(
              color: Color(vault.colorValue).withOpacity(0.4),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Top Right Badge
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.45),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(badgeIcon, size: 9.5, color: const Color(0xFFD4AF37)),
                    const SizedBox(width: 3.5),
                    Text(
                      badgeText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Center Visual (Emblem OR Cover Image OR Video Thumbnail)
            Center(
              child: () {
                String? imageToShow = vault.coverImageUrl;
                if ((imageToShow == null || imageToShow.isEmpty) && vault.videoUrl != null && vault.videoUrl!.isNotEmpty) {
                  if (vault.videoUrl!.contains('cloudinary.com') || vault.videoUrl!.contains('/video/upload/')) {
                    imageToShow = vault.videoUrl!.replaceAll(RegExp(r'\.(mp4|mov|avi|wmv|webm|mkv)$', caseSensitive: false), '.jpg');
                    if (imageToShow.contains('/video/upload/')) {
                      imageToShow = imageToShow.replaceAll('/video/upload/', '/video/upload/so_1,f_auto,q_auto/');
                    }
                  }
                }

                if (imageToShow != null && imageToShow.isNotEmpty) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: CachedNetworkImage(
                      imageUrl: imageToShow,
                      width: 76,
                      height: 76,
                      fit: BoxFit.cover,
                    ),
                  );
                }
                return VaultEmblem(shape: vault.emblemShape, size: 56);
              }(),
            ),

            // Bottom Text: Title & Creator/Memories
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    vault.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.1,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$creatorLabel · ${vault.totalMemoriesCount} memories',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.65),
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- "+ New vault" Dashed Card (Matching Image 1) ---

  Widget _buildNewVaultDashedCard() {
    return GestureDetector(
      onTap: _navigateToNewVault,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF14121B),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withOpacity(0.25),
            width: 1.2,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFD4AF37), width: 1.2),
              ),
              child: const Icon(Icons.add_rounded, color: Color(0xFFD4AF37), size: 24),
            ),
            const SizedBox(height: 12),
            const Text(
              'New vault',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'Lock memories for later',
              style: TextStyle(
                color: Colors.white.withOpacity(0.45),
                fontSize: 10.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
