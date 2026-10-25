import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/full_screen_video_player.dart';
import '../../../data/models/event_capsule.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/vault_provider.dart';
import '../../stage/widgets/app_top_bar.dart';
import '../../stage/widgets/profile_modal.dart';
import '../widgets/vault_video_thumbnail.dart';
import '../widgets/scratch_card_reveal.dart';
import '../widgets/time_lock_countdown.dart';
import '../widgets/romance_keypad.dart';
import '../widgets/romance_confetti.dart';
import '../widgets/add_event_capsule_dialog.dart';

class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key});

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 4));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final spaceId = context.read<AuthProvider>().space?.id;
      if (spaceId != null) {
        context.read<VaultProvider>().initVaultSync(spaceId);
      }
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  void _openProfileModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ProfileModal(),
    );
  }

  void _showAddCapsuleModal(BuildContext context, {EventCapsule? existing}) {
    final auth = context.read<AuthProvider>();
    final space = auth.space;
    final user = auth.user;
    if (space == null || user == null) return;

    showDialog(
      context: context,
      builder: (_) => AddEventCapsuleDialog(
        spaceId: space.id,
        userId: user.id,
        userName: user.nickname,
        initialCapsule: existing,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vaultProvider = context.watch<VaultProvider>();
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;
    final space = authProvider.space;

    // Check if we should trigger confetti burst
    if (vaultProvider.shouldTriggerConfetti) {
      _confettiController.play();
      vaultProvider.resetConfettiTrigger();
    }

    final capsule = vaultProvider.selectedCapsule;
    final isOwner = capsule != null && user != null && (capsule.creatorId.isEmpty || capsule.creatorId == user.id);

    return Scaffold(
      backgroundColor: AppColors.romanceBg,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // 1. Top Bar
                AppTopBar(
                  onAvatarTap: _openProfileModal,
                  overrideTitle: 'Our Vault',
                  overrideSubtitle: 'Confidential event capsules & secrets...',
                ),

                // 2. Event Capsules Timeline Selector
                _buildCapsuleTimeline(vaultProvider, space?.id ?? '', user?.id ?? ''),

                // 3. Main Content (Locked vs Unlocked)
                Expanded(
                  child: capsule == null
                      ? const Center(
                          child: CircularProgressIndicator(color: AppColors.romanceRoseGold),
                        )
                      : vaultProvider.isUnlocked
                          ? _buildUnlockedCapsule(context, capsule, isOwner, vaultProvider)
                          : _buildLockedCapsule(context, capsule, vaultProvider),
                ),
              ],
            ),

            // Confetti Petal & Gold Burst Overlay
            RomanceConfettiOverlay(controller: _confettiController),
          ],
        ),
      ),
    );
  }

  Widget _buildCapsuleTimeline(VaultProvider vaultProvider, String spaceId, String userId) {
    return Container(
      height: 48,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          // Create New Capsule Button
          GestureDetector(
            onTap: () => _showAddCapsuleModal(context),
            child: Container(
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.romanceWine,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.romanceRoseGold.withOpacity(0.5)),
                boxShadow: [
                  BoxShadow(color: AppColors.romanceWine.withOpacity(0.3), blurRadius: 8),
                ],
              ),
              child: const Row(
                children: [
                  Icon(Icons.add_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'New Capsule ✦',
                    style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),

          // Capsule Chips
          ...vaultProvider.capsules.map((c) {
            final isSelected = vaultProvider.selectedCapsule?.id == c.id;
            return GestureDetector(
              onTap: () => vaultProvider.selectCapsule(c),
              child: Container(
                margin: const EdgeInsets.only(right: 10),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.romanceCard : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? AppColors.romanceRoseGold : AppColors.romanceBorder,
                    width: isSelected ? 1.5 : 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      c.isTimeLocked ? Icons.lock_clock_rounded : Icons.lock_rounded,
                      size: 13,
                      color: isSelected ? AppColors.romanceRoseGold : AppColors.romanceSoft,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      c.title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? AppColors.romanceInk : AppColors.romanceSoft,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildLockedCapsule(BuildContext context, EventCapsule capsule, VaultProvider vaultProvider) {
    if (capsule.isTimeLocked) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: TimeLockCountdownWidget(
            unlockAt: capsule.unlockAt!,
            title: capsule.title,
            onUnlocked: () => setState(() {}),
          ),
        ),
      );
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: RomanceKeypad(
          title: capsule.title,
          subtitle: 'Enter 6-digit secret key to unlock this special capsule',
          hint: capsule.passcodeHint,
          enteredPin: vaultProvider.enteredPin,
          isError: vaultProvider.isError,
          pinLength: 6,
          onDigit: (d) => vaultProvider.appendPinDigit(d),
          onDelete: () => vaultProvider.deletePinDigit(),
          onClear: () => vaultProvider.clearPin(),
        ),
      ),
    );
  }

  Widget _buildUnlockedCapsule(
    BuildContext context,
    EventCapsule capsule,
    bool isOwner,
    VaultProvider vaultProvider,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Unlocked Header with Status & Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.romanceWine.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.romanceRoseGold.withOpacity(0.5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lock_open_rounded, size: 13, color: AppColors.romanceRoseGold),
                        const SizedBox(width: 5),
                        Text(
                          isOwner ? 'YOUR CAPSULE ✦' : 'SECRET FOR YOU 🎁',
                          style: const TextStyle(
                            color: AppColors.romanceRoseGold,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  if (isOwner)
                    IconButton(
                      icon: const Icon(Icons.edit_note_rounded, color: AppColors.romanceRoseGold, size: 24),
                      onPressed: () => _showAddCapsuleModal(context, existing: capsule),
                    ),
                  IconButton(
                    icon: const Icon(Icons.lock_rounded, color: AppColors.romanceSoft, size: 20),
                    onPressed: () => vaultProvider.lockVault(),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 1. Dedicated Event Video
          if (capsule.videoUrl != null && capsule.videoUrl!.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.romanceRoseGold.withOpacity(0.35)),
              ),
              clipBehavior: Clip.antiAlias,
              child: VaultVideoThumbnail(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FullScreenVideoPlayer(
                        videoUrl: capsule.videoUrl!,
                        title: capsule.title,
                        subtitle: 'Confidential Event Film',
                      ),
                    ),
                  );
                },
              ),
            ),

          // 2. Secret Sealed Love Letter Card
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: AppColors.romanceCard,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.romanceBorder),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      capsule.title,
                      style: const TextStyle(
                        color: AppColors.romanceInk,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.romanceWine,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        capsule.eventType,
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(color: AppColors.romanceBorder, height: 1),
                const SizedBox(height: 14),
                Text(
                  capsule.personalNote,
                  style: const TextStyle(
                    color: AppColors.romanceInk,
                    fontSize: 14,
                    height: 1.6,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'With all my heart, ${capsule.creatorName}',
                    style: const TextStyle(
                      color: AppColors.romanceRoseGold,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 3. Interactive Scratch-to-Reveal Secret Card
          if (capsule.scratchSecret != null && capsule.scratchSecret!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: ScratchCardReveal(
                secretMessage: capsule.scratchSecret!,
              ),
            ),

          // 4. Lock Capsule Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.lock_rounded, size: 16, color: AppColors.romanceRoseGold),
              label: const Text('Lock Capsule & Return', style: TextStyle(color: AppColors.romanceRoseGold, fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                side: Border.all(color: AppColors.romanceRoseGold.withOpacity(0.5)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () => vaultProvider.lockVault(),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
