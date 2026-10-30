import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/stage_provider.dart';
import 'blind_prompt_studio_modal.dart';

class StageDailySyncCard extends StatefulWidget {
  const StageDailySyncCard({super.key});

  @override
  State<StageDailySyncCard> createState() => _StageDailySyncCardState();
}

class _StageDailySyncCardState extends State<StageDailySyncCard> {
  final TextEditingController _answerController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  Future<void> _submitAnswer({
    required BuildContext context,
    required AuthProvider authProvider,
    required StageProvider stageProvider,
  }) async {
    final user = authProvider.user;
    final spaceId = authProvider.space?.id ?? user?.spaceId ?? '';
    final userId = user?.id ?? '';
    final text = _answerController.text.trim();
    if (spaceId.isEmpty || userId.isEmpty || text.isEmpty) return;

    HapticFeedback.mediumImpact();
    setState(() => _isSubmitting = true);
    try {
      await stageProvider.saveDailyPromptAnswer(spaceId, userId, text);
      _answerController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Answer submitted & sealed in envelope 💌'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit answer: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;
    final authProvider = context.watch<AuthProvider>();
    final stageProvider = context.watch<StageProvider>();
    final user = authProvider.user;
    final partner = authProvider.partner;
    final partnerNickname = partner?.nickname ?? 'Partner';

    final prompt = stageProvider.dailyPrompt?.prompt ??
        'What was the sweetest little thought you had about us today?';
    final vibeTag = stageProvider.dailyPrompt?.vibeTag ?? 'Gentle Whisper';

    final myAnswer = user != null ? stageProvider.dailyPrompt?.answers[user.id] : null;
    final partnerId = partner?.id;
    String? partnerAnswer;
    if (partnerId != null && stageProvider.dailyPrompt?.answers[partnerId] != null) {
      partnerAnswer = stageProvider.dailyPrompt?.answers[partnerId];
    } else if (user != null && stageProvider.dailyPrompt?.answers != null) {
      final otherEntry = stageProvider.dailyPrompt!.answers.entries.firstWhere(
        (e) => e.key != user.id,
        orElse: () => const MapEntry('', ''),
      );
      if (otherEntry.key.isNotEmpty && otherEntry.value.isNotEmpty) {
        partnerAnswer = otherEntry.value;
      }
    }

    final bothAnswered = myAnswer != null && partnerAnswer != null;
    final canSubmit = !_isSubmitting && _answerController.text.trim().isNotEmpty;

    return Container(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBg : AppColors.lightBg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with Vibe Tag + Studio & History Buttons
          Row(
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.terra.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    vibeTag.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.terra,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Action Buttons: AI Studio, Custom +, History
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. AI Studio Button
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      BlindPromptStudioModal.show(context, initialTab: 0);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.terra.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.terra.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.auto_awesome, size: 11, color: AppColors.terra),
                          SizedBox(width: 3),
                          Text(
                            'Studio ✦',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.terra,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),

                  // 2. Custom Question Button
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      BlindPromptStudioModal.show(context, initialTab: 1);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.add_rounded,
                            size: 13,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            'Custom',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),

                  // 3. History Archive Button
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      BlindPromptStudioModal.show(context, initialTab: 3);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.history_rounded,
                            size: 12,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'History',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Question Prompt (Hero Focal Point of the Home Page)
          Text(
            '“$prompt”',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              fontStyle: FontStyle.italic,
              color: isDark ? AppColors.darkInk : AppColors.lightInk,
              height: 1.35,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 18),

          // User's response state
          if (myAnswer == null) ...[
            TextField(
              controller: _answerController,
              maxLines: 3,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) {
                if (canSubmit) {
                  _submitAnswer(context: context, authProvider: authProvider, stageProvider: stageProvider);
                }
              },
              onChanged: (_) {
                // Instantly re-evaluates button state as user types!
                setState(() {});
              },
              style: TextStyle(
                fontSize: 14.5,
                color: isDark ? AppColors.darkInk : AppColors.lightInk,
              ),
              decoration: InputDecoration(
                hintText: partner != null
                    ? 'Whisper your secret thought to ${partner.nickname}...'
                    : 'Whisper your honest answer here...',
                hintStyle: TextStyle(
                  fontSize: 13.5,
                  fontStyle: FontStyle.italic,
                  color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                ),
                filled: true,
                fillColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                contentPadding: const EdgeInsets.all(16),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    width: 0.8,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: AppColors.terra,
                    width: 1.2,
                  ),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: canSubmit
                    ? () => _submitAnswer(context: context, authProvider: authProvider, stageProvider: stageProvider)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: canSubmit ? AppColors.terra : AppColors.terra.withOpacity(0.3),
                  foregroundColor: Colors.white,
                  elevation: canSubmit ? 3 : 0,
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.send_rounded, size: 15, color: Colors.white),
                          SizedBox(width: 6),
                          Text('Submit Answer 💌', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
                        ],
                      ),
              ),
            ),
          ] else ...[
            // Both Answered: Unsealed Celebration
            if (bothAnswered) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.sage.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text('✨', style: TextStyle(fontSize: 12)),
                    SizedBox(width: 5),
                    Text(
                      'ENVELOPE UNSEALED TOGETHER 💌',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.sage,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // My Answer Card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('✨', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'You answered:',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          myAnswer,
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: isDark ? AppColors.darkInk : AppColors.lightInk,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Partner's Answer (Frosted or Revealed)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Text(bothAnswered ? '💌' : '🔒', style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (bothAnswered) ...[
                          Text(
                            '$partnerNickname answered:',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                            ),
                          ),
                          const SizedBox(height: 2),
                        ],
                        Text(
                          bothAnswered
                              ? partnerAnswer!
                              : 'Waiting for $partnerNickname\'s answer to unseal...',
                          style: TextStyle(
                            fontSize: 12,
                            color: bothAnswered
                                ? (isDark ? AppColors.darkInk : AppColors.lightInk)
                                : (isDark ? AppColors.darkSoft : AppColors.lightSoft),
                            fontStyle: bothAnswered ? FontStyle.italic : FontStyle.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Ask New Question Shortcut if both answered
            if (bothAnswered) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => BlindPromptStudioModal.show(context),
                  icon: const Icon(Icons.auto_awesome, size: 14, color: AppColors.terra),
                  label: const Text(
                    'Ask New Question ✦',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.terra,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
