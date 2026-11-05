import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/auth_provider.dart';
import '../services/watch_together_service.dart';
import 'watch_waiting_screen.dart';

class WatchLobbyScreen extends StatefulWidget {
  const WatchLobbyScreen({super.key});

  @override
  State<WatchLobbyScreen> createState() => _WatchLobbyScreenState();
}

class _WatchLobbyScreenState extends State<WatchLobbyScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _handleCreateRoom() async {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null) {
      _showSnackbar('Please ensure you are signed in first.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final code = await WatchTogetherService.instance.createRoom(
        hostUid: user.id,
        hostName: user.nickname.isNotEmpty ? user.nickname : 'Partner',
      );

      if (!mounted) return;
      HapticFeedback.mediumImpact();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WatchWaitingScreen(
            roomCode: code,
            isHost: true,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final errorStr = e.toString();
      String userFriendlyMsg = 'Could not create room: $e';
      if (errorStr.contains('permission-denied')) {
        userFriendlyMsg =
            'Database permission locked. Please update Rules in Firebase Console.';
      }
      setState(() {
        _errorMessage = userFriendlyMsg;
      });
      _showSnackbar(userFriendlyMsg);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleJoinRoom() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.length != 6) {
      setState(() {
        _errorMessage = 'Please enter a valid 6-character room code.';
      });
      return;
    }

    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null) {
      _showSnackbar('Please ensure you are signed in first.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await WatchTogetherService.instance.joinRoom(
        roomCode: code,
        guestUid: user.id,
        guestName: user.nickname.isNotEmpty ? user.nickname : 'Partner',
      );

      if (!mounted) return;
      HapticFeedback.mediumImpact();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WatchWaitingScreen(
            roomCode: code,
            isHost: false,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final errorStr = e.toString();
      String msg = e.toString().replaceAll('Exception: ', '');
      if (errorStr.contains('permission-denied')) {
        msg = 'Database permission locked. Please update Rules in Firebase Console.';
      }
      setState(() {
        _errorMessage = msg;
      });
      _showSnackbar(msg);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.terra,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final ink = isDark ? AppColors.darkInk : AppColors.lightInk;
    final soft = isDark ? AppColors.darkSoft : AppColors.lightSoft;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar with Back Arrow
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: surface,
                        shape: BoxShape.circle,
                        border: Border.all(color: border),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 16,
                        color: ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'Watch Together',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.2,
                      color: ink,
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 16),

                    // Movie Night Hero Icon
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: AppColors.terra.withOpacity(0.12),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.terra.withOpacity(0.3), width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        '🎬',
                        style: TextStyle(fontSize: 36),
                      ),
                    ),

                    const SizedBox(height: 16),

                    Text(
                      'Private Cinema for Two',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                        color: ink,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'Watch any movie on your phone in perfect real-time sync with your partner. Zero uploads — both play your local file.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: soft,
                      ),
                    ),

                    const SizedBox(height: 36),

                    // Button: Create Room
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleCreateRoom,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.terra,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_circle_outline_rounded, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Create Room',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Divider "or join room"
                    Row(
                      children: [
                        Expanded(child: Divider(color: border)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text(
                            'OR JOIN EXISTING',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                              color: soft,
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: border)),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Room Code Input Card
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Enter Partner\'s 6-Digit Code',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: soft,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            height: 52,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.black.withOpacity(0.3) : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: _errorMessage != null
                                    ? Colors.redAccent
                                    : AppColors.terra.withOpacity(0.4),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: TextField(
                              controller: _codeController,
                              textCapitalization: TextCapitalization.characters,
                              maxLength: 6,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 6,
                                color: ink,
                              ),
                              decoration: InputDecoration(
                                counterText: '',
                                hintText: 'ABC123',
                                hintStyle: TextStyle(
                                  letterSpacing: 4,
                                  fontSize: 18,
                                  color: soft.withOpacity(0.4),
                                ),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                              onChanged: (_) {
                                if (_errorMessage != null) {
                                  setState(() {
                                    _errorMessage = null;
                                  });
                                }
                              },
                            ),
                          ),

                          if (_errorMessage != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              _errorMessage!,
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Colors.redAccent,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],

                          const SizedBox(height: 16),

                          // Button: Join Room
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: OutlinedButton(
                              onPressed: _isLoading ? null : _handleJoinRoom,
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.terra, width: 1.5),
                                foregroundColor: AppColors.terra,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text(
                                'Join Room',
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ),
                        ],
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
}
