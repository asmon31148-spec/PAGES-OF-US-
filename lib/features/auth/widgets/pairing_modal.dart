import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/stage_provider.dart';
import '../../../providers/world_provider.dart';
import '../../../providers/vault_provider.dart';
import '../../../providers/memories_provider.dart';

class PairingModal extends StatefulWidget {
  const PairingModal({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const PairingModal(),
    );
  }

  @override
  State<PairingModal> createState() => _PairingModalState();
}

class _PairingModalState extends State<PairingModal> {
  final TextEditingController _codeController = TextEditingController();
  bool _isLinking = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.space == null && auth.user != null) {
        auth.ensureSpace();
      }
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;
    final authProvider = context.watch<AuthProvider>();
    final space = authProvider.space;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(22),
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
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Connect Your Partner',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkInk : AppColors.lightInk,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Share your code or enter their code to link your private sanctuary ✦',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                ),
              ),
              const SizedBox(height: 18),

              // Paired Banner if already linked
              if (authProvider.isPaired && authProvider.partner != null) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.sage.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.sage.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.favorite_rounded, color: AppColors.terra, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Connected with ${authProvider.partner!.nickname} 💕',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.darkInk : AppColors.lightInk,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // 1. Your Code Card
              Text(
                'YOUR INVITE CODE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                  color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                ),
              ),
              const SizedBox(height: 8),

              if (space != null && space.pairCode.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : AppColors.lightCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SelectableText(
                        space.pairCode,
                        style: const TextStyle(
                          fontSize: 24,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          letterSpacing: 4,
                          color: AppColors.terra,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Copy Invite Code',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: space.pairCode));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Invite code ${space.pairCode} copied to clipboard! ✨'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy_rounded, size: 20),
                        color: isDark ? AppColors.darkInk : AppColors.lightInk,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : AppColors.lightCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.terra,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        'Preparing your sanctuary code...',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // 2. Enter Partner's Code
              Text(
                'ENTER PARTNER\'S CODE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                  color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.text,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                  LengthLimitingTextInputFormatter(6),
                ],
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(
                  fontSize: 18,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                ),
                decoration: InputDecoration(
                  hintText: 'e.g. 583921',
                  hintStyle: TextStyle(
                    fontSize: 15,
                    fontFamily: 'monospace',
                    letterSpacing: 2,
                    color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                  ),
                  filled: true,
                  fillColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.terra, width: 1.5),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline, size: 16, color: Colors.redAccent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.redAccent,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLinking
                      ? null
                      : () async {
                          final code = _codeController.text.trim();
                          if (code.isEmpty) {
                            setState(() => _error = 'Please enter your partner\'s 6-digit code.');
                            return;
                          }
                          setState(() {
                            _isLinking = true;
                            _error = null;
                          });
                          final result = await authProvider.joinSpace(code);
                          setState(() => _isLinking = false);
                          if (result.isSuccess && context.mounted) {
                            final space = authProvider.space;
                            final user = authProvider.user;
                            final partner = authProvider.partner;
                            if (space != null && user != null) {
                              context.read<StageProvider>().initSpaceListeners(
                                    space.id,
                                    user.id,
                                    partner?.id,
                                  );
                              context.read<WorldProvider>().initWorldSync(
                                    spaceId: space.id,
                                    currentUserId: user.id,
                                    partnerId: partner?.id,
                                  );
                              context.read<VaultProvider>().initVaultSync(space.id);
                              context.read<MemoriesProvider>().initMemoriesSync(
                                    spaceId: space.id,
                                    currentUserId: user.id,
                                    partnerNickname: partner?.nickname,
                                  );
                            }
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Connected to your partner\'s sanctuary! 💕'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          } else if (mounted) {
                            setState(() => _error = result.errorMessage ?? 'Invalid pair code. Please try again.');
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.terra,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLinking
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Link Together ✦',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
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
