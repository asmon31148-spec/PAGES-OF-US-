import 'package:flutter/material.dart';
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
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 0.6,
          ),
        ),
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
                  const Text('📌 ', style: TextStyle(fontSize: 13)),
                  Text(
                    'Pinned For Today',
                    style: TextStyle(
                      fontSize: 13.5,
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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.sage.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Write Note ✎',
                      style: TextStyle(
                        fontSize: 11.5,
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
              maxLines: 2,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.darkInk : AppColors.lightInk,
              ),
              decoration: InputDecoration(
                hintText: 'Leave a sweet note for today...',
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
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : AppColors.lightCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        width: 0.8,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'From You',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.2,
                            color: isDark ? AppColors.sageLight : AppColors.sage,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          myNote?.isNotEmpty == true ? myNote! : 'Tap write note above...',
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.35,
                            fontStyle: myNote?.isNotEmpty == true
                                ? FontStyle.normal
                                : FontStyle.italic,
                            color: isDark ? AppColors.darkInk : AppColors.lightInk,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Partner note
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : AppColors.lightCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        width: 0.8,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'From $partnerDisplayName',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.2,
                            color: AppColors.terra,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          partnerNote?.isNotEmpty == true
                              ? partnerNote!
                              : 'No note pinned yet 🍃',
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.35,
                            fontStyle: partnerNote?.isNotEmpty == true
                                ? FontStyle.normal
                                : FontStyle.italic,
                            color: isDark ? AppColors.darkInk : AppColors.lightInk,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
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
}
