import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/vault_item.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/vault_provider.dart';
import '../../stage/widgets/app_top_bar.dart';
import '../../stage/widgets/profile_modal.dart';
import '../../music/theme/glass_tokens.dart';
import '../../music/widgets/glass/glass_ambient_background.dart';
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

  void _syncVaults() {
    final auth = context.read<AuthProvider>();
    final spaceId = auth.space?.id ?? auth.user?.spaceId;
    final user = auth.user;
    if (spaceId != null && spaceId.isNotEmpty && user != null) {
      context.read<VaultProvider>().initVaultSync(
        spaceId: spaceId,
        currentUserId: user.id,
        partnerId: auth.partner?.id,
        partnerNickname: auth.partner?.nickname,
      );
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
      isScrollControlled: true,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF1E1A29).withOpacity(0.92),
                  const Color(0xFF0F0D15).withOpacity(0.95),
                ],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(
                color: Colors.white.withOpacity(0.22),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 30,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 22),
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFFD4AF37).withOpacity(0.35),
                        const Color(0xFFD4AF37).withOpacity(0.10),
                      ],
                    ),
                    border: Border.all(
                      color: const Color(0xFFD4AF37).withOpacity(0.6),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD4AF37).withOpacity(0.3),
                        blurRadius: 18,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.hourglass_top_rounded, color: Color(0xFFD4AF37), size: 32),
                ),
                const SizedBox(height: 18),
                Text(
                  vault.title,
                  style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold, letterSpacing: -0.3),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'Sealed by ${vault.creatorName}',
                  style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 13),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFD4AF37).withOpacity(0.3),
                      width: 1.0,
                    ),
                  ),
                  child: Text(
                    days > 0
                        ? 'Unlocks automatically in $days days\n($dateStr)'
                        : 'Unlocks on $dateStr',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFFD4AF37), fontSize: 13.5, height: 1.45, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(25),
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE5C058), Color(0xFFC49A28)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFD4AF37).withOpacity(0.35),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                      ),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(ctx);
                      },
                      child: const Text(
                        'I will wait patiently ✨',
                        style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPinUnlockDialog(VaultItem vault, String spaceId, String currentUserId, String userNickname, String partnerNickname) {
    final pinController = TextEditingController();
    String? errorMessage;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.65),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF221C2F).withOpacity(0.92),
                      const Color(0xFF13101B).withOpacity(0.95),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.24),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.55),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFFD4AF37).withOpacity(0.32),
                            const Color(0xFFD4AF37).withOpacity(0.08),
                          ],
                        ),
                        border: Border.all(
                          color: const Color(0xFFD4AF37).withOpacity(0.6),
                          width: 1.2,
                        ),
                      ),
                      child: const Icon(Icons.lock_outline_rounded, color: Color(0xFFD4AF37), size: 30),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      vault.title,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.2),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Protected with a secret PIN by ${vault.creatorName}',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 13),
                    ),
                    const SizedBox(height: 20),
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
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.25), letterSpacing: 8),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.07),
                        errorText: errorMessage,
                        errorStyle: const TextStyle(color: Color(0xFFFF6B6B)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                            ),
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel', style: TextStyle(color: Colors.white60, fontSize: 14)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              gradient: const LinearGradient(
                                colors: [Color(0xFFE5C058), Color(0xFFC49A28)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFD4AF37).withOpacity(0.35),
                                  blurRadius: 12,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(vertical: 13),
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
                              child: const Text('Unlock', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
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

    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDark;
    final palette = themeProvider.currentPalette;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Top Bar with Frosted Glass Elegance
            AppTopBar(
              onAvatarTap: _openProfileModal,
              overrideTitle: 'Our Vaults',
              overrideSubtitle: '$allCount vaults · $lockedCount locked',
              showThemeToggle: true,
            ),

            // 2. Liquid Glass Filter Chips Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              child: Row(
                children: [
                  _buildFilterChip(
                    label: 'All ($allCount)',
                    isActive: activeFilter == 'all',
                    onTap: () => vaultProvider.setFilter('all'),
                    isDark: isDark,
                    accentColor: palette.accentColor,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    label: 'By You ($mineCount)',
                    isActive: activeFilter == 'mine',
                    onTap: () => vaultProvider.setFilter('mine'),
                    isDark: isDark,
                    accentColor: palette.accentColor,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    label: 'By $partnerNickname ($partnerCount)',
                    isActive: activeFilter == 'partner',
                    onTap: () => vaultProvider.setFilter('partner'),
                    isDark: isDark,
                    accentColor: palette.accentColor,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),

            // 3. 2-Column Liquid Glass Grid
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
                  if (index == filteredVaults.length) {
                    return _buildNewVaultDashedCard(isDark: isDark, accentColor: palette.accentColor);
                  }

                  final vault = filteredVaults[index];
                  final isLocked = vaultProvider.isVaultLocked(vault, currentUserId);
                  return _buildVaultCard(
                    vault: vault,
                    isLocked: isLocked,
                    currentUserId: currentUserId,
                    partnerNickname: partnerNickname,
                    onTap: () => _onVaultTapped(vault, currentUserId, partnerNickname, spaceId, userNickname),
                    onLongPress: () => _confirmDeleteVaultFromGrid(vault, spaceId),
                    isDark: isDark,
                    accentColor: palette.accentColor,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Liquid Glass Filter Chip Pill ---

  Widget _buildFilterChip({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    required bool isDark,
    required Color accentColor,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(GlassTokens.radiusPill),
          gradient: isActive
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    accentColor.withOpacity(isDark ? 0.35 : 0.22),
                    accentColor.withOpacity(isDark ? 0.14 : 0.08),
                  ],
                )
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          Colors.white.withOpacity(0.10),
                          Colors.white.withOpacity(0.04),
                        ]
                      : [
                          Colors.white.withOpacity(0.70),
                          Colors.white.withOpacity(0.40),
                        ],
                ),
          border: Border.all(
            color: isActive
                ? accentColor.withOpacity(0.70)
                : (isDark ? Colors.white.withOpacity(0.20) : Colors.white.withOpacity(0.60)),
            width: isActive ? 1.2 : 0.8,
          ),
          boxShadow: [
            if (isActive)
              BoxShadow(
                color: accentColor.withOpacity(0.25),
                blurRadius: 12,
                offset: const Offset(0, 3),
              )
            else
              BoxShadow(
                color: isDark ? Colors.black.withOpacity(0.18) : const Color(0xFF8C7355).withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isActive) ...[
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentColor,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: isActive
                    ? (isDark ? Colors.white : accentColor)
                    : (isDark ? Colors.white.withOpacity(0.75) : const Color(0xFF52525B)),
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Liquid Glass Delete Confirmation Modal ---

  Future<void> _confirmDeleteVaultFromGrid(VaultItem vault, String spaceId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.65),
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF221C2F).withOpacity(0.92),
                  const Color(0xFF13101B).withOpacity(0.95),
                ],
              ),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: Colors.white.withOpacity(0.24),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.55),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFE57373).withOpacity(0.18),
                    border: Border.all(color: const Color(0xFFE57373).withOpacity(0.4), width: 1.2),
                  ),
                  child: const Icon(Icons.delete_forever_rounded, color: Color(0xFFE57373), size: 28),
                ),
                const SizedBox(height: 14),
                const Text('Delete Vault?', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Text(
                  'Are you sure you want to permanently delete "${vault.title}"? This will remove the vault and its memories for both partners.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withOpacity(0.72), fontSize: 13.5, height: 1.4),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel', style: TextStyle(color: Colors.white60, fontSize: 14)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: const LinearGradient(
                            colors: [Color(0xFFEF5350), Color(0xFFC62828)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFEF5350).withOpacity(0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<VaultProvider>().deleteVault(vault.id, spaceId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${vault.title}" deleted.'),
            backgroundColor: const Color(0xFF1F1B2C),
          ),
        );
      }
    }
  }

  // --- Liquid Glass Vault Grid Card ---

  Widget _buildVaultCard({
    required VaultItem vault,
    required bool isLocked,
    required String currentUserId,
    required String partnerNickname,
    required VoidCallback onTap,
    required VoidCallback onLongPress,
    required bool isDark,
    required Color accentColor,
  }) {
    final isOwner = vault.creatorId.isEmpty || vault.creatorId == currentUserId;
    final creatorLabel = isOwner ? 'By You' : 'By $partnerNickname';

    String? badgeText;
    IconData? badgeIcon;

    if (isLocked && vault.accessMode == 'timer') {
      final days = vault.daysRemaining;
      badgeText = days > 0 ? 'Opens in $days d' : 'Opens today';
      badgeIcon = Icons.hourglass_top_rounded;
    } else if (isLocked && vault.accessMode == 'pin') {
      badgeText = 'PIN locked';
      badgeIcon = Icons.lock_outline_rounded;
    }

    final hasCoverImage = vault.coverImageUrl != null && vault.coverImageUrl!.isNotEmpty;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      onLongPress: () {
        HapticFeedback.mediumImpact();
        onLongPress();
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    Colors.white.withOpacity(0.16),
                    Colors.white.withOpacity(0.04),
                  ]
                : [
                    Colors.white.withOpacity(0.85),
                    Colors.white.withOpacity(0.55),
                  ],
          ),
          border: Border.all(
            color: isLocked
                ? (const Color(0xFFD4AF37).withOpacity(0.45))
                : (isDark ? Colors.white.withOpacity(0.24) : Colors.white.withOpacity(0.80)),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withOpacity(0.32) : const Color(0xFF8C7355).withOpacity(0.10),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Cover Image or Liquid Jewel Vault Base
            if (hasCoverImage)
              CachedNetworkImage(
                imageUrl: vault.coverImageUrl!,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                placeholder: (_, __) => Container(
                  color: Color(vault.colorValue).withOpacity(0.6),
                  child: const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: Color(0xFFD4AF37),
                    ),
                  ),
                ),
                errorWidget: (_, __, ___) => _buildEmblemFallback(vault),
              )
            else
              _buildEmblemFallback(vault),

            // 2. Liquid Glass Dark Scrim
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 110,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.45),
                      Colors.black.withOpacity(0.85),
                    ],
                  ),
                ),
              ),
            ),

            // 3. Frosted Glass Bottom Ribbon (Title & Metadata)
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.18),
                      Colors.white.withOpacity(0.06),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.24),
                    width: 0.8,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      vault.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${DateFormat("dd/MM/yyyy").format(vault.specialDate ?? vault.createdAt)} · $creatorLabel',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.75),
                        fontSize: 10,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 4. Floating Frosted Glass Lock Badge
            if (badgeText != null)
              Positioned(
                top: 9,
                right: 9,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.65),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFD4AF37).withOpacity(0.55),
                      width: 0.9,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD4AF37).withOpacity(0.18),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(badgeIcon, size: 10.5, color: const Color(0xFFD4AF37)),
                      const SizedBox(width: 4),
                      Text(
                        badgeText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmblemFallback(VaultItem vault) {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.2),
          radius: 0.9,
          colors: [
            Color(vault.colorValue).withOpacity(0.85),
            const Color(0xFF0D0B12),
          ],
        ),
      ),
      child: Center(
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.20),
                Colors.white.withOpacity(0.05),
              ],
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.30),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Color(vault.colorValue).withOpacity(0.4),
                blurRadius: 20,
              ),
            ],
          ),
          child: Center(
            child: VaultEmblem(shape: vault.emblemShape, size: 44),
          ),
        ),
      ),
    );
  }

  // --- Liquid Glass "+ New vault" Action Card ---

  Widget _buildNewVaultDashedCard({required bool isDark, required Color accentColor}) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _navigateToNewVault();
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    Colors.white.withOpacity(0.12),
                    Colors.white.withOpacity(0.04),
                  ]
                : [
                    Colors.white.withOpacity(0.80),
                    Colors.white.withOpacity(0.45),
                  ],
          ),
          border: Border.all(
            color: accentColor.withOpacity(0.45),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withOpacity(0.25) : const Color(0xFF8C7355).withOpacity(0.08),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    accentColor.withOpacity(0.30),
                    accentColor.withOpacity(0.08),
                  ],
                ),
                border: Border.all(
                  color: accentColor.withOpacity(0.65),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withOpacity(0.25),
                    blurRadius: 14,
                  ),
                ],
              ),
              child: Icon(Icons.add_rounded, color: accentColor, size: 26),
            ),
            const SizedBox(height: 12),
            Text(
              'New vault',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Lock memories for later',
              style: TextStyle(
                color: isDark ? Colors.white.withOpacity(0.55) : const Color(0xFF71717A),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
