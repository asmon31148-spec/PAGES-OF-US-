import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/stage_provider.dart';

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

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;
    final authProvider = context.watch<AuthProvider>();
    final stageProvider = context.watch<StageProvider>();
    final user = authProvider.user;
    final partner = authProvider.partner;

    final prompt = stageProvider.dailyPrompt?.prompt ??
        'What was the sweetest little thought you had about us today?';
    final vibeTag = stageProvider.dailyPrompt?.vibeTag ?? 'Gentle Whisper';

    final myAnswer = user != null ? stageProvider.dailyPrompt?.answers[user.id] : null;
    final partnerId = partner?.id;
    final partnerAnswer =
        partnerId != null ? stageProvider.dailyPrompt?.answers[partnerId] : null;

    final bothAnswered = myAnswer != null && partnerAnswer != null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.terra.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  vibeTag.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.terra,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Text(
                'Blind Prompt ✦',
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.sageLight,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Question Prompt
          Text(
            prompt,
            style: TextStyle(
              fontFamily: 'serif',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkInk : AppColors.lightInk,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 16),

          // User's response state
          if (myAnswer == null) ...[
            TextField(
              controller: _answerController,
              maxLines: 2,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.darkInk : AppColors.lightInk,
              ),
              decoration: InputDecoration(
                hintText: 'Whisper your answer here...',
                hintStyle: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                ),
                filled: true,
                fillColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: _isSubmitting || _answerController.text.trim().isEmpty
                    ? null
                    : () async {
                        setState(() => _isSubmitting = true);
                        // Save answer
                        setState(() => _isSubmitting = false);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.sage,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Seal in Envelope 💌', style: TextStyle(fontSize: 12)),
              ),
            ),
          ] else ...[
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
                  const Text('🔒', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      bothAnswered
                          ? (partnerAnswer ?? 'Revealed!')
                          : 'Waiting for ${partner?.nickname ?? "partner"}\'s answer to unseal...',
                      style: TextStyle(
                        fontSize: 12,
                        color: bothAnswered
                            ? (isDark ? AppColors.darkInk : AppColors.lightInk)
                            : (isDark ? AppColors.darkSoft : AppColors.lightSoft),
                        fontStyle: bothAnswered ? FontStyle.italic : FontStyle.normal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
