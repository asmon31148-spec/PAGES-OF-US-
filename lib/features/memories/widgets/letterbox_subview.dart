import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/memories_provider.dart';
import '../../../data/models/letter_item.dart';

class LetterboxSubview extends StatefulWidget {
  const LetterboxSubview({super.key});

  @override
  State<LetterboxSubview> createState() => _LetterboxSubviewState();
}

class _LetterboxSubviewState extends State<LetterboxSubview> {
  LetterItem? _openedLetter;

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;
    final memoriesProvider = context.watch<MemoriesProvider>();
    final authProvider = context.watch<AuthProvider>();
    final spaceId = authProvider.space?.id ?? 'default_space';
    final user = authProvider.user;

    final letters = memoriesProvider.letters;

    return Column(
      children: [
        // Top Action Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'LETTERBOX ARCHIVE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                      color: AppColors.terra,
                    ),
                  ),
                  Text(
                    '${letters.length} Sealed Letters',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.terra,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                icon: const Icon(Icons.edit, size: 14),
                label: const Text('Write Letter', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                onPressed: () => _showWriteLetterModal(context, spaceId, user?.id),
              ),
            ],
          ),
        ),

        // Letters List
        if (letters.isEmpty)
          Padding(
            padding: const EdgeInsets.all(48.0),
            child: Column(
              children: [
                const Text('✉️', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 12),
                Text(
                  'No sealed letters yet',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkInk : AppColors.lightInk,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Write a quiet note, an open-when letter, or set a sealed-until date for your partner.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                  ),
                ),
              ],
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: letters.length,
            itemBuilder: (context, index) {
              final letter = letters[index];
              return _buildEnvelopeCard(context, letter, isDark, spaceId);
            },
          ),
      ],
    );
  }

  Widget _buildEnvelopeCard(
    BuildContext context,
    LetterItem letter,
    bool isDark,
    String spaceId,
  ) {
    Color sealColor = AppColors.sage;
    if (letter.sealType == 'terra') sealColor = AppColors.terra;
    if (letter.sealType == 'slate') sealColor = AppColors.slate;
    if (letter.sealType == 'rose') sealColor = AppColors.rose;

    // Check sealed until date
    bool isSealed = false;
    if (letter.sealedUntilDate != null) {
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      if (todayStr.compareTo(letter.sealedUntilDate!) < 0) {
        isSealed = true;
      }
    }

    return GestureDetector(
      onTap: () {
        if (isSealed && !letter.isMine) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Sealed until ${letter.sealedUntilDate} 🔒'),
            ),
          );
          return;
        }
        _showReadLetterModal(context, letter, spaceId);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Wax Seal Stamp
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: sealColor,
                boxShadow: [
                  BoxShadow(
                    color: sealColor.withOpacity(0.4),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                isSealed ? '🔒' : '✦',
                style: const TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
            const SizedBox(width: 14),

            // Content Preview
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: sealColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          letter.category.toUpperCase(),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: sealColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (isSealed)
                        const Text(
                          'TIMELOCKED',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    letter.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.darkInk : AppColors.lightInk,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'From ${letter.authorName} · ${letter.writtenDate.split("T").first}',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                    ),
                  ),
                ],
              ),
            ),

            Icon(
              Icons.chevron_right,
              color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _showReadLetterModal(BuildContext context, LetterItem letter, String spaceId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.75,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : const Color(0xFFFCFBF9),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    letter.category.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                      color: AppColors.terra,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              Text(
                letter.title,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkInk : AppColors.lightInk,
                ),
              ),
              Text(
                'Written by ${letter.authorName} · ${letter.writtenDate.split("T").first}',
                style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                ),
              ),
              const Divider(height: 24),
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    letter.body,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.6,
                      color: isDark ? AppColors.darkInk : AppColors.lightInk,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showWriteLetterModal(BuildContext context, String spaceId, String? userId) {
    if (userId == null) return;
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    String category = 'For a quiet day';
    String sealType = 'green';
    DateTime? sealedUntil;

    final categories = [
      'For a quiet day',
      'Open on our anniversary',
      'When you need a reminder',
      'For when we fight',
      'Open when you miss me',
      'Just because',
    ];

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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Seal a Love Letter in Letterbox',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkInk : AppColors.lightInk,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleCtrl,
                      style: TextStyle(color: isDark ? AppColors.darkInk : AppColors.lightInk),
                      decoration: InputDecoration(
                        labelText: 'Letter Title (e.g. When you miss home)',
                        labelStyle: TextStyle(color: isDark ? AppColors.darkSoft : AppColors.lightSoft),
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: category,
                      dropdownColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                      decoration: InputDecoration(
                        labelText: 'Envelope Prompt / Occasion',
                        labelStyle: TextStyle(color: isDark ? AppColors.darkSoft : AppColors.lightSoft),
                      ),
                      items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkInk : AppColors.lightInk)))).toList(),
                      onChanged: (val) {
                        if (val != null) setModalState(() => category = val);
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: bodyCtrl,
                      maxLines: 4,
                      style: TextStyle(color: isDark ? AppColors.darkInk : AppColors.lightInk),
                      decoration: InputDecoration(
                        labelText: 'Your Letter',
                        labelStyle: TextStyle(color: isDark ? AppColors.darkSoft : AppColors.lightSoft),
                        hintText: 'Write whatever is in your heart...',
                        hintStyle: TextStyle(color: isDark ? AppColors.darkSoft : AppColors.lightSoft),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Seal color
                    Row(
                      children: [
                        Text(
                          'Seal: ',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.darkInk : AppColors.lightInk,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ...[
                          {'id': 'green', 'color': AppColors.sage},
                          {'id': 'terra', 'color': AppColors.terra},
                          {'id': 'slate', 'color': AppColors.slate},
                          {'id': 'rose', 'color': AppColors.rose},
                        ].map((s) {
                          final isSel = sealType == s['id'];
                          return GestureDetector(
                            onTap: () => setModalState(() => sealType = s['id'] as String),
                            child: Container(
                              margin: const EdgeInsets.only(right: 8),
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: s['color'] as Color,
                                border: isSel ? Border.all(color: Colors.white, width: 2) : null,
                                boxShadow: isSel ? [const BoxShadow(color: Colors.black38, blurRadius: 4)] : null,
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.terra,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () {
                          if (titleCtrl.text.trim().isNotEmpty && bodyCtrl.text.trim().isNotEmpty) {
                            context.read<MemoriesProvider>().sendLetter(
                                  spaceId: spaceId,
                                  title: titleCtrl.text.trim(),
                                  body: bodyCtrl.text.trim(),
                                  sealType: sealType,
                                  category: category,
                                  author: userId,
                                );
                            Navigator.pop(ctx);
                          }
                        },
                        child: const Text('Seal in Letterbox ✉️', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
