import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/letter_item.dart';
import '../../../widgets/sanctuary_voice_player.dart';

class LetterBookScreen extends StatefulWidget {
  final List<LetterItem> letters;
  final int initialIndex;
  final String spaceId;

  const LetterBookScreen({
    super.key,
    required this.letters,
    this.initialIndex = 0,
    required this.spaceId,
  });

  @override
  State<LetterBookScreen> createState() => _LetterBookScreenState();
}

class _LetterBookScreenState extends State<LetterBookScreen> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.letters.isNotEmpty ? widget.letters.length - 1 : 0);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Color _getSealColor(String sealType) {
    switch (sealType.toLowerCase()) {
      case 'terra':
        return AppColors.terra;
      case 'slate':
        return AppColors.slate;
      case 'rose':
        return AppColors.rose;
      case 'green':
      default:
        return AppColors.sage;
    }
  }

  bool _isLetterLocked(LetterItem letter) {
    if (letter.sealedUntilDate == null) return false;
    final todayStr = DateTime.now().toIso8601String().split('T').first;
    return todayStr.compareTo(letter.sealedUntilDate!) < 0;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final letters = widget.letters;

    final bgColor = isDark ? const Color(0xFF0F0E17) : const Color(0xFFFAF7F2);
    final cardBg = isDark ? const Color(0xFF181622) : const Color(0xFFFFFFFF);
    final textColor = isDark ? AppColors.darkInk : AppColors.lightInk;
    final subtextColor = isDark ? AppColors.darkSoft : AppColors.lightSoft;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: bgColor,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: bgColor,
        body: SafeArea(
          child: Column(
            children: [
              // 1. Top Book Navigation Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Back Button
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(context);
                      },
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                          border: Border.all(
                            color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
                          ),
                        ),
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 16,
                          color: textColor,
                        ),
                      ),
                    ),

                    // Book Title & Page Pill
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'LOVE LETTERBOOK',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                            color: AppColors.terra,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Letter ${_currentIndex + 1} of ${letters.length}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: subtextColor,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Right Wax Seal Badge
                    if (letters.isNotEmpty)
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _getSealColor(letters[_currentIndex].sealType),
                          boxShadow: [
                            BoxShadow(
                              color: _getSealColor(letters[_currentIndex].sealType).withOpacity(0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: const Text('✦', style: TextStyle(color: Colors.white, fontSize: 14)),
                      )
                    else
                      const SizedBox(width: 36),
                  ],
                ),
              ),

              // 2. Full-Screen Slideable Book Pages (PageView)
              Expanded(
                child: letters.isEmpty
                    ? Center(
                        child: Text(
                          'No letters in archive yet ✉️',
                          style: TextStyle(color: subtextColor, fontSize: 14),
                        ),
                      )
                    : PageView.builder(
                        controller: _pageController,
                        physics: const BouncingScrollPhysics(),
                        itemCount: letters.length,
                        onPageChanged: (index) {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _currentIndex = index;
                          });
                        },
                        itemBuilder: (context, index) {
                          final letter = letters[index];
                          final isLocked = _isLetterLocked(letter) && !letter.isMine;

                          if (isLocked) {
                            return _buildLockedLetterPage(
                              letter: letter,
                              isDark: isDark,
                              cardBg: cardBg,
                              textColor: textColor,
                              subtextColor: subtextColor,
                            );
                          }

                          return _buildOpenLetterPage(
                            letter: letter,
                            isDark: isDark,
                            cardBg: cardBg,
                            textColor: textColor,
                            subtextColor: subtextColor,
                          );
                        },
                      ),
              ),

              // 3. Bottom Flip Navigation Bar
              if (letters.length > 1)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Previous Letter Button
                      GestureDetector(
                        onTap: _currentIndex > 0
                            ? () {
                                _pageController.previousPage(
                                  duration: const Duration(milliseconds: 320),
                                  curve: Curves.easeInOut,
                                );
                              }
                            : null,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: _currentIndex > 0 ? 1.0 : 0.25,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.arrow_back_rounded, size: 14, color: textColor),
                                const SizedBox(width: 6),
                                Text(
                                  'Previous',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Book Turn Hint
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_stories_rounded, size: 14, color: AppColors.terra.withOpacity(0.8)),
                          const SizedBox(width: 5),
                          Text(
                            'Swipe like book ✦',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: subtextColor,
                            ),
                          ),
                        ],
                      ),

                      // Next Letter Button
                      GestureDetector(
                        onTap: _currentIndex < letters.length - 1
                            ? () {
                                _pageController.nextPage(
                                  duration: const Duration(milliseconds: 320),
                                  curve: Curves.easeInOut,
                                );
                              }
                            : null,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: _currentIndex < letters.length - 1 ? 1.0 : 0.25,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Next',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor),
                                ),
                                const SizedBox(width: 6),
                                Icon(Icons.arrow_forward_rounded, size: 14, color: textColor),
                              ],
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
    );
  }

  // Beautiful Keepsake Open Letter Page
  Widget _buildOpenLetterPage({
    required LetterItem letter,
    required bool isDark,
    required Color cardBg,
    required Color textColor,
    required Color subtextColor,
  }) {
    final sealColor = _getSealColor(letter.sealType);
    final dateStr = letter.writtenDate.split('T').first;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.35 : 0.06),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Category & Wax Tag
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: sealColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: sealColor.withOpacity(0.25)),
                      ),
                      child: Text(
                        letter.category.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                          color: sealColor,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Icon(Icons.lock_open_rounded, size: 14, color: subtextColor),
                        const SizedBox(width: 4),
                        Text(
                          'Unsealed Keepsake',
                          style: TextStyle(fontSize: 10, color: subtextColor),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Title
                Text(
                  letter.title,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 8),

                // Author & Date
                Text(
                  'Written with love by ${letter.authorName} · $dateStr',
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: subtextColor,
                  ),
                ),
                const SizedBox(height: 16),

                // Decorative Floral Divider
                Row(
                  children: [
                    Expanded(child: Divider(color: isDark ? Colors.white12 : Colors.black12, thickness: 1)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        '✦ ⋆⋅♥⋅⋆ ✦',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.terra.withOpacity(0.8),
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: isDark ? Colors.white12 : Colors.black12, thickness: 1)),
                  ],
                ),
                const SizedBox(height: 20),

                // Letter Body Content
                SelectableText(
                  letter.body,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.75,
                    letterSpacing: 0.25,
                    color: textColor.withOpacity(0.92),
                  ),
                ),

                if (letter.voiceUrl != null && letter.voiceUrl!.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  SanctuaryVoicePlayer(
                    id: 'letter_${letter.id}',
                    audioUrl: letter.voiceUrl!,
                    isDark: isDark,
                  ),
                ],

                const SizedBox(height: 36),

                // Signature Sign-off Block
                Align(
                  alignment: Alignment.centerRight,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Always yours,',
                        style: TextStyle(
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                          color: subtextColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${letter.authorName} ♡',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.terra,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Locked Timelocked Letter Page
  Widget _buildLockedLetterPage({
    required LetterItem letter,
    required bool isDark,
    required Color cardBg,
    required Color textColor,
    required Color subtextColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: Colors.amber.withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.amber.withOpacity(0.08),
              blurRadius: 24,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.amber.withOpacity(0.12),
                  border: Border.all(color: Colors.amber.withOpacity(0.4)),
                ),
                alignment: Alignment.center,
                child: const Text('🔒', style: TextStyle(fontSize: 32)),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'SEALED UNTIL ${letter.sealedUntilDate}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                    color: Colors.amber,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                letter.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Written by ${letter.authorName}',
                style: TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: subtextColor,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'This letter has been locked with a timelock seal. It will automatically open for you on ${letter.sealedUntilDate} ✨',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: subtextColor,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
