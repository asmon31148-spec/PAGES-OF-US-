import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/stage_provider.dart';

class StagePinnedCorkboard extends StatefulWidget {
  const StagePinnedCorkboard({super.key});

  @override
  State<StagePinnedCorkboard> createState() => _StagePinnedCorkboardState();
}

class _StagePinnedCorkboardState extends State<StagePinnedCorkboard> {
  final TextEditingController _noteController = TextEditingController();
  bool _isEditing = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;
    final authProvider = context.watch<AuthProvider>();
    final stageProvider = context.watch<StageProvider>();
    final user = authProvider.user;
    final partner = authProvider.partner;
    final space = authProvider.space;

    final myNote = user != null ? stageProvider.pinnedNotes[user.id]?.text : null;
    final otherNotes = stageProvider.pinnedNotes.entries.where((e) => e.key != user?.id);
    final partnerEntry = otherNotes.isNotEmpty ? otherNotes.first : null;
    final partnerNote = (partner != null && stageProvider.pinnedNotes.containsKey(partner.id))
        ? stageProvider.pinnedNotes[partner.id]?.text
        : partnerEntry?.value.text;
    final partnerDisplayName = partner?.nickname ??
        (partnerEntry?.value.authorNickname.isNotEmpty == true
            ? partnerEntry!.value.authorNickname
            : 'Partner');

    return Container(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('📌 ', style: TextStyle(fontSize: 14)),
                  Text(
                    'Pinned For Today',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.darkInk : AppColors.lightInk,
                    ),
                  ),
                ],
              ),
              if (!_isEditing)
                GestureDetector(
                  onTap: () {
                    _noteController.text = myNote ?? '';
                    setState(() => _isEditing = true);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.sage.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Write Note ✎',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.sage,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          if (_isEditing) ...[
            TextField(
              controller: _noteController,
              maxLines: 3,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.darkInk : AppColors.lightInk,
              ),
              decoration: InputDecoration(
                hintText: 'Leave a sweet little love note for $partnerDisplayName...',
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
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => setState(() => _isEditing = false),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    HapticFeedback.lightImpact();
                    if (space != null && user != null) {
                      await stageProvider.savePinnedNote(
                        space.id,
                        user.id,
                        user.nickname,
                        _noteController.text.trim(),
                      );
                    }
                    setState(() => _isEditing = false);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.sage,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Pin Note', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                // You note
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      if (myNote?.isNotEmpty == true) {
                        _showFullNoteModal(
                          context: context,
                          title: 'From You',
                          emoji: '✍️',
                          noteText: myNote,
                          isMine: true,
                          isDark: isDark,
                          partnerDisplayName: partnerDisplayName,
                        );
                      } else {
                        _noteController.text = '';
                        setState(() => _isEditing = true);
                      }
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 96),
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1B2620) : AppColors.sage.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? AppColors.sage.withOpacity(0.35) : Colors.white.withOpacity(0.80),
                          width: 1.0,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Text('✍️ ', style: TextStyle(fontSize: 11)),
                                  Text(
                                    'From You',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.2,
                                      color: isDark ? AppColors.sageLight : AppColors.sage,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (myNote?.isNotEmpty == true) ...[
                                    Icon(
                                      Icons.open_in_full_rounded,
                                      size: 11,
                                      color: isDark ? AppColors.sageLight.withOpacity(0.7) : AppColors.sage.withOpacity(0.7),
                                    ),
                                    const SizedBox(width: 6),
                                    GestureDetector(
                                      onTap: () async {
                                        HapticFeedback.lightImpact();
                                        if (space != null && user != null) {
                                          await stageProvider.savePinnedNote(space.id, user.id, user.nickname, '');
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: (isDark ? Colors.white : Colors.black).withOpacity(0.06),
                                        ),
                                        child: Icon(
                                          Icons.close_rounded,
                                          size: 14,
                                          color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 7),
                          Text(
                            myNote?.isNotEmpty == true
                                ? myNote!
                                : 'Tap write note to leave a whisper...',
                            style: TextStyle(
                              fontSize: 13.5,
                              height: 1.4,
                              fontStyle: myNote?.isNotEmpty == true
                                  ? FontStyle.normal
                                  : FontStyle.italic,
                              color: myNote?.isNotEmpty == true
                                  ? (isDark ? AppColors.darkInk : AppColors.lightInk)
                                  : (isDark ? AppColors.darkSoft : AppColors.lightSoft),
                            ),
                            maxLines: 5,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Partner note
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _showFullNoteModal(
                        context: context,
                        title: 'From $partnerDisplayName',
                        emoji: '💌',
                        noteText: partnerNote,
                        isMine: false,
                        isDark: isDark,
                        partnerDisplayName: partnerDisplayName,
                      );
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 96),
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF261D1A) : AppColors.terra.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? AppColors.terra.withOpacity(0.35) : Colors.white.withOpacity(0.80),
                          width: 1.0,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('💌 ', style: TextStyle(fontSize: 11)),
                              Expanded(
                                child: Text(
                                  'From $partnerDisplayName',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.2,
                                    color: AppColors.terra,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (partnerNote?.isNotEmpty == true)
                                Icon(
                                  Icons.open_in_full_rounded,
                                  size: 11,
                                  color: AppColors.terra.withOpacity(0.7),
                                ),
                            ],
                          ),
                          const SizedBox(height: 7),
                          Text(
                            partnerNote?.isNotEmpty == true
                                ? partnerNote!
                                : 'Waiting for a sweet note from $partnerDisplayName... 🍃',
                            style: TextStyle(
                              fontSize: 13.5,
                              height: 1.4,
                              fontStyle: partnerNote?.isNotEmpty == true
                                  ? FontStyle.normal
                                  : FontStyle.italic,
                              color: partnerNote?.isNotEmpty == true
                                  ? (isDark ? AppColors.darkInk : AppColors.lightInk)
                                  : (isDark ? AppColors.darkSoft : AppColors.lightSoft),
                            ),
                            maxLines: 5,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showFullNoteModal({
    required BuildContext context,
    required String title,
    required String emoji,
    required String? noteText,
    required bool isMine,
    required bool isDark,
    required String partnerDisplayName,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.75,
              ),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF13151B).withValues(alpha: 0.96)
                    : Colors.white.withValues(alpha: 0.96),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border(
                  top: BorderSide(
                    color: isDark ? Colors.white.withOpacity(0.25) : Colors.black.withOpacity(0.1),
                    width: 1.2,
                  ),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(emoji, style: const TextStyle(fontSize: 22)),
                          const SizedBox(width: 8),
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isMine
                                  ? (isDark ? AppColors.sageLight : AppColors.sage)
                                  : AppColors.terra,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: Icon(
                          Icons.close_rounded,
                          color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: isMine
                              ? (isDark ? const Color(0xFF1B2620) : AppColors.sage.withOpacity(0.10))
                              : (isDark ? const Color(0xFF261D1A) : AppColors.terra.withOpacity(0.10)),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isMine
                                ? (isDark ? AppColors.sage.withOpacity(0.35) : AppColors.sage.withOpacity(0.25))
                                : (isDark ? AppColors.terra.withOpacity(0.35) : AppColors.terra.withOpacity(0.25)),
                          ),
                        ),
                        child: SelectableText(
                          noteText?.isNotEmpty == true
                              ? noteText!
                              : (isMine
                                  ? 'No note pinned yet. Tap edit below to write one!'
                                  : 'Waiting for a sweet note from $partnerDisplayName... 🍃'),
                          style: TextStyle(
                            fontSize: 15.5,
                            height: 1.6,
                            letterSpacing: 0.2,
                            fontStyle: noteText?.isNotEmpty == true ? FontStyle.normal : FontStyle.italic,
                            color: noteText?.isNotEmpty == true
                                ? (isDark ? AppColors.darkInk : AppColors.lightInk)
                                : (isDark ? AppColors.darkSoft : AppColors.lightSoft),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (isMine)
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _noteController.text = noteText ?? '';
                              setState(() => _isEditing = true);
                            },
                            icon: const Icon(Icons.edit_note_rounded, size: 20),
                            label: const Text('Edit Note ✎', style: TextStyle(fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.sage,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(46),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: isDark ? AppColors.darkInk : AppColors.lightInk,
                              minimumSize: const Size.fromHeight(46),
                              side: BorderSide(
                                color: isDark ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.15),
                              ),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: const Text('Close'),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
        );
      },
    );
  }
}
