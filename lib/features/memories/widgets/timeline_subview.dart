import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/services/media_upload_service.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/memories_provider.dart';
import '../../../providers/audio_provider.dart';
import '../../../data/models/milestone_item.dart';
import '../../../widgets/sanctuary_voice_player.dart';

class TimelineSubview extends StatefulWidget {
  const TimelineSubview({super.key});

  @override
  State<TimelineSubview> createState() => _TimelineSubviewState();
}

class _TimelineSubviewState extends State<TimelineSubview> {
  // 0: Shared (Both), 1: You, 2: Partner
  int _selectedBranch = 0;

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;
    final allMilestones = context.select<MemoriesProvider, List<MilestoneItem>>(
      (p) => p.milestones,
    );
    final authProvider = context.watch<AuthProvider>();
    final spaceId = authProvider.space?.id ?? 'default_space';
    final user = authProvider.user;
    final partnerNickname = authProvider.partner?.nickname ?? 'Partner';

    // Filter milestones by selected branch
    final List<MilestoneItem> filteredMilestones = allMilestones.where((m) {
      if (_selectedBranch == 1) return m.isMine;
      if (_selectedBranch == 2) return !m.isMine;
      return true; // 0: Both
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Top Header & Add Milestone Action
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'OUR JOURNEY TIMELINE',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: AppColors.terra,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${allMilestones.length} Days Kept Together',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.sage,
                  foregroundColor: Colors.white,
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text(
                  'Add Moment',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                ),
                onPressed: () => _showAddMilestoneModal(context, spaceId, user?.id, partnerNickname),
              ),
            ],
          ),
        ),

        // 2. Dual-Branch Switcher (Shared / You / Partner)
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          padding: const EdgeInsets.all(3.5),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          child: Row(
            children: [
              _buildBranchPill(0, '🌿 Both', isDark),
              _buildBranchPill(1, 'You 👤', isDark),
              _buildBranchPill(2, '$partnerNickname 🤍', isDark),
            ],
          ),
        ),

        // 3. Timeline Branch Content
        if (filteredMilestones.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
            child: Center(
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: (isDark ? AppColors.darkSurface : AppColors.lightSurface),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const Text('🌿', style: TextStyle(fontSize: 28)),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _selectedBranch == 0
                        ? 'No timeline moments yet'
                        : (_selectedBranch == 1 ? 'No moments kept by you yet' : 'No moments kept by $partnerNickname yet'),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.darkInk : AppColors.lightInk,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Record the dates, thoughts, photos, and voice whispers that mark your journey together.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
            itemCount: filteredMilestones.length,
            itemBuilder: (context, index) {
              final milestone = filteredMilestones[index];
              final isFirst = index == 0;
              final isLast = index == filteredMilestones.length - 1;

              return _buildTimelineBranchNode(
                context,
                milestone: milestone,
                isFirst: isFirst,
                isLast: isLast,
                isDark: isDark,
                spaceId: spaceId,
                partnerNickname: partnerNickname,
              );
            },
          ),
      ],
    );
  }

  Widget _buildBranchPill(int index, String label, bool isDark) {
    final isSelected = _selectedBranch == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedBranch = index);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6.5),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? AppColors.darkCard : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(13),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1.5),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected
                  ? (isDark ? AppColors.darkInk : AppColors.lightInk)
                  : (isDark ? AppColors.darkSoft : AppColors.lightSoft),
            ),
          ),
        ),
      ),
    );
  }

  /// Builds a single node along the vertical timeline branch
  Widget _buildTimelineBranchNode(
    BuildContext context, {
    required MilestoneItem milestone,
    required bool isFirst,
    required bool isLast,
    required bool isDark,
    required String spaceId,
    required String partnerNickname,
  }) {
    final branchColor = milestone.isMine ? AppColors.sage : AppColors.terra;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline Stem (Line + Node Dot)
          SizedBox(
            width: 32,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                // Top Connector Line
                Positioned(
                  top: 0,
                  bottom: 0,
                  left: 15,
                  child: Container(
                    width: 2,
                    color: isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                  ),
                ),

                // Node Circle Indicator
                Positioned(
                  top: 14,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkBg : AppColors.lightBg,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: branchColor,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: branchColor.withOpacity(0.2),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      milestone.isMine ? 'Y' : (partnerNickname.isNotEmpty ? partnerNickname[0].toUpperCase() : 'P'),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: branchColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Milestone Card (Tappable into Full Viewer)
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                _openMilestoneDetail(context, milestone, isDark, spaceId, partnerNickname);
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Row: Primary Date (DD/MM/YYYY) + Author Tag + Media Badges
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Primary Date Badge: Strict DD/MM/YYYY as requested
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                          decoration: BoxDecoration(
                            color: branchColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            milestone.formattedDisplayDate,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                              color: branchColor,
                            ),
                          ),
                        ),

                        // Author & Media Badges
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (milestone.hasImage) ...[
                              Icon(Icons.photo_rounded, size: 13, color: isDark ? AppColors.darkSoft : AppColors.lightSoft),
                              const SizedBox(width: 4),
                            ],
                            if (milestone.hasAudio) ...[
                              Icon(Icons.graphic_eq_rounded, size: 14, color: isDark ? AppColors.darkSoft : AppColors.lightSoft),
                              const SizedBox(width: 4),
                            ],
                            Text(
                              milestone.isMine ? 'Kept by You' : 'Kept by $partnerNickname',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontStyle: FontStyle.italic,
                                color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Optional Title (If present, rendered subtly below the date)
                    if (milestone.title.trim().isNotEmpty && milestone.title != milestone.formattedDisplayDate) ...[
                      const SizedBox(height: 6),
                      Text(
                        milestone.title.trim(),
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkInk : AppColors.lightInk,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    // Story preview
                    if (milestone.story.trim().isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        milestone.story.trim(),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    // Image / Audio Attachment Previews
                    if (milestone.hasImage || milestone.hasAudio) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (milestone.hasImage)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: CachedNetworkImage(
                                imageUrl: milestone.imageUrl!,
                                width: 44,
                                height: 44,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => const Icon(Icons.broken_image, size: 20),
                              ),
                            ),
                          if (milestone.hasImage && milestone.hasAudio) const SizedBox(width: 8),
                          if (milestone.hasAudio)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: (isDark ? AppColors.darkCard : AppColors.lightCard),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.play_circle_fill_rounded, size: 16, color: branchColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    milestone.audioDuration != null
                                        ? '${milestone.audioDuration}s Voice Whisper'
                                        : 'Voice Whisper',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w500,
                                      color: isDark ? AppColors.darkInk : AppColors.lightInk,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],

                    // Tap Hint Footer
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          'View moment',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: branchColor.withOpacity(0.8),
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 9,
                          color: branchColor.withOpacity(0.8),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Opens the detailed viewer modal when a timeline moment is tapped
  void _openMilestoneDetail(
    BuildContext context,
    MilestoneItem milestone,
    bool isDark,
    String spaceId,
    String partnerNickname,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final memoriesProvider = ctx.watch<MemoriesProvider>();
        final audioProvider = ctx.watch<AudioProvider>();
        final branchColor = milestone.isMine ? AppColors.sage : AppColors.terra;


        return Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Drag Handle & Close
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: branchColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      milestone.formattedDisplayDate,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.4,
                        color: branchColor,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, size: 20, color: isDark ? AppColors.darkSoft : AppColors.lightSoft),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Author & Relative Time Header
              Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: branchColor.withOpacity(0.2),
                    child: Text(
                      milestone.isMine ? 'Y' : (partnerNickname.isNotEmpty ? partnerNickname[0].toUpperCase() : 'P'),
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: branchColor),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    milestone.isMine ? 'Kept by You' : 'Kept by $partnerNickname',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkInk : AppColors.lightInk,
                    ),
                  ),
                  if (milestone.relativeTime.isNotEmpty) ...[
                    Text(
                      ' · ${milestone.relativeTime}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                      ),
                    ),
                  ],
                ],
              ),

              const Divider(height: 24),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Optional Title
                      if (milestone.title.trim().isNotEmpty && milestone.title != milestone.formattedDisplayDate) ...[
                        Text(
                          milestone.title.trim(),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.darkInk : AppColors.lightInk,
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],

                      // Full Story / Content
                      if (milestone.story.trim().isNotEmpty) ...[
                        SelectableText(
                          milestone.story.trim(),
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? AppColors.darkInk : AppColors.lightInk,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Attached Photo Full View
                      if (milestone.hasImage) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: CachedNetworkImage(
                            imageUrl: milestone.imageUrl!,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              height: 180,
                              color: isDark ? AppColors.darkCard : AppColors.lightCard,
                              alignment: Alignment.center,
                              child: const CircularProgressIndicator(strokeWidth: 2),
                            ),
                            errorWidget: (_, __, ___) => const Padding(
                              padding: EdgeInsets.all(24.0),
                              child: Center(child: Text('Image could not be loaded')),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Attached Audio Voice Whisper Player
                      if (milestone.hasAudio) ...[
                        SanctuaryVoicePlayer(
                          id: 'milestone_' + milestone.id,
                          audioUrl: milestone.audioUrl!,
                          durationSeconds: milestone.audioDuration,
                          isDark: isDark,
                          ambientAudio: audioProvider,
                        ),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ),
                ),
              ),

              // Bottom Actions (Delete option if author)
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (milestone.isMine)
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                      ),
                      icon: const Icon(Icons.delete_outline_rounded, size: 16),
                      label: const Text('Delete Moment', style: TextStyle(fontSize: 12)),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: ctx,
                          builder: (dCtx) => AlertDialog(
                            backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                            title: const Text('Delete Timeline Moment?'),
                            content: const Text('This memory will be removed from your shared journey timeline.'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(dCtx, false),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                                onPressed: () => Navigator.pop(dCtx, true),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true && context.mounted) {
                          Navigator.pop(ctx);
                          context.read<MemoriesProvider>().deleteMilestone(spaceId, milestone.id);
                        }
                      },
                    )
                  else
                    const SizedBox.shrink(),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                      foregroundColor: isDark ? AppColors.darkInk : AppColors.lightInk,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Done', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// Add Milestone Modal with Date Picker (DD/MM/YYYY), Image & Audio attachments
  void _showAddMilestoneModal(BuildContext context, String spaceId, String? userId, String partnerNickname) {
    if (userId == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddMilestoneModalSheet(
        spaceId: spaceId,
        userId: userId,
        partnerNickname: partnerNickname,
      ),
    );
  }
}

class _AddMilestoneModalSheet extends StatefulWidget {
  final String spaceId;
  final String userId;
  final String partnerNickname;

  const _AddMilestoneModalSheet({
    required this.spaceId,
    required this.userId,
    required this.partnerNickname,
  });

  @override
  State<_AddMilestoneModalSheet> createState() => _AddMilestoneModalSheetState();
}

class _AddMilestoneModalSheetState extends State<_AddMilestoneModalSheet> {
  DateTime _selectedDate = DateTime.now();
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _storyCtrl = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  final AudioRecorder _audioRecorder = AudioRecorder();

  File? _attachedImage;
  File? _attachedAudio;
  bool _isRecording = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;
  bool _isSaving = false;
  String _uploadStatus = '';

  @override
  void dispose() {
    _recordTimer?.cancel();
    _audioRecorder.dispose();
    _titleCtrl.dispose();
    _storyCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        imageQuality: 85,
      );
      if (file != null) {
        setState(() => _attachedImage = File(file.path));
      }
    } catch (_) {}
  }

  Future<void> _toggleAudioRecording() async {
    if (_isRecording) {
      // Stop recording
      try {
        _recordTimer?.cancel();
        final path = await _audioRecorder.stop();
        if (path != null) {
          setState(() {
            _isRecording = false;
            _attachedAudio = File(path);
          });
        }
      } catch (_) {
        setState(() => _isRecording = false);
      }
    } else {
      // Start recording
      try {
        if (await _audioRecorder.hasPermission()) {
          final tempDir = await getTemporaryDirectory();
          final path = '${tempDir.path}/milestone_${DateTime.now().millisecondsSinceEpoch}.m4a';

          await _audioRecorder.start(
            const RecordConfig(encoder: AudioEncoder.aacLc),
            path: path,
          );

          setState(() {
            _isRecording = true;
            _recordSeconds = 0;
          });

          _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
            setState(() => _recordSeconds++);
            if (_recordSeconds >= 60) {
              await _toggleAudioRecording();
            }
          });
        }
      } catch (_) {}
    }
  }

  Future<void> _submitMilestone() async {
    if (_storyCtrl.text.trim().isEmpty && _titleCtrl.text.trim().isEmpty && _attachedImage == null && _attachedAudio == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a thought, story, photo, or voice whisper for this day.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
      _uploadStatus = 'Preserving milestone...';
    });

    String? uploadedImageUrl;
    String? uploadedAudioUrl;

    try {
      if (_attachedImage != null) {
        setState(() => _uploadStatus = 'Uploading photo...');
        final res = await MediaUploadService.uploadFile(_attachedImage!, folder: 'milestones');
        uploadedImageUrl = res.url;
      }

      if (_attachedAudio != null) {
        setState(() => _uploadStatus = 'Uploading voice whisper...');
        final res = await MediaUploadService.uploadFile(_attachedAudio!, folder: 'milestones_audio');
        uploadedAudioUrl = res.url;
      }

      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

      if (mounted) {
        await context.read<MemoriesProvider>().addMilestone(
              spaceId: widget.spaceId,
              title: _titleCtrl.text.trim(),
              date: dateStr,
              story: _storyCtrl.text.trim(),
              author: widget.userId,
              imageUrl: uploadedImageUrl,
              audioUrl: uploadedAudioUrl,
              audioDuration: _attachedAudio != null ? _recordSeconds : null,
            );

        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save moment: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final formattedDateStr = DateFormat('dd/MM/yyyy').format(_selectedDate);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Record Timeline Moment',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.darkInk : AppColors.lightInk,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, size: 20, color: isDark ? AppColors.darkSoft : AppColors.lightSoft),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Date Picker Anchor (Shows DD/MM/YYYY)
              Text(
                'DATE OF MOMENT',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                  color: AppColors.terra,
                ),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(1970),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: ColorScheme.light(
                            primary: AppColors.sage,
                            onPrimary: Colors.white,
                            onSurface: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (picked != null) {
                    setState(() => _selectedDate = picked);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : AppColors.lightCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.terra),
                      const SizedBox(width: 10),
                      Text(
                        formattedDateStr,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          color: isDark ? AppColors.darkInk : AppColors.lightInk,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Change Date',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.sage,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Optional Title Input
              TextField(
                controller: _titleCtrl,
                style: TextStyle(fontSize: 14, color: isDark ? AppColors.darkInk : AppColors.lightInk),
                decoration: InputDecoration(
                  labelText: 'Title (Optional - date is default)',
                  labelStyle: TextStyle(fontSize: 12, color: isDark ? AppColors.darkSoft : AppColors.lightSoft),
                  filled: true,
                  fillColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Story / Memory Description
              TextField(
                controller: _storyCtrl,
                maxLines: 4,
                style: TextStyle(fontSize: 13.5, color: isDark ? AppColors.darkInk : AppColors.lightInk),
                decoration: InputDecoration(
                  hintText: 'What happened on this day? Write your thoughts, places visited, or words said...',
                  hintStyle: TextStyle(fontSize: 12, color: isDark ? AppColors.darkSoft : AppColors.lightSoft),
                  filled: true,
                  fillColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                  contentPadding: const EdgeInsets.all(14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Media Attachments Bar (Photo + Audio)
              Row(
                children: [
                  // Attach Photo Button
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        side: BorderSide(
                          color: _attachedImage != null ? AppColors.sage : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                        ),
                      ),
                      icon: Icon(
                        _attachedImage != null ? Icons.check_circle_rounded : Icons.photo_camera_rounded,
                        size: 16,
                        color: _attachedImage != null ? AppColors.sage : (isDark ? AppColors.darkInk : AppColors.lightInk),
                      ),
                      label: Text(
                        _attachedImage != null ? 'Photo Added' : 'Attach Photo',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _attachedImage != null ? AppColors.sage : (isDark ? AppColors.darkInk : AppColors.lightInk),
                        ),
                      ),
                      onPressed: _pickImage,
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Record Voice Whisper Button
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        side: BorderSide(
                          color: _isRecording
                              ? Colors.redAccent
                              : (_attachedAudio != null ? AppColors.terra : (isDark ? AppColors.darkBorder : AppColors.lightBorder)),
                        ),
                        backgroundColor: _isRecording ? Colors.redAccent.withOpacity(0.1) : null,
                      ),
                      icon: Icon(
                        _isRecording
                            ? Icons.stop_circle_rounded
                            : (_attachedAudio != null ? Icons.check_circle_rounded : Icons.mic_rounded),
                        size: 16,
                        color: _isRecording
                            ? Colors.redAccent
                            : (_attachedAudio != null ? AppColors.terra : (isDark ? AppColors.darkInk : AppColors.lightInk)),
                      ),
                      label: Text(
                        _isRecording
                            ? 'Stop ($_recordSeconds s)'
                            : (_attachedAudio != null ? 'Voice Added' : 'Voice Note'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _isRecording
                              ? Colors.redAccent
                              : (_attachedAudio != null ? AppColors.terra : (isDark ? AppColors.darkInk : AppColors.lightInk)),
                        ),
                      ),
                      onPressed: _toggleAudioRecording,
                    ),
                  ),
                ],
              ),

              // Attached Previews & Remove Options
              if (_attachedImage != null || _attachedAudio != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (_attachedImage != null)
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.file(_attachedImage!, width: 56, height: 56, fit: BoxFit.cover),
                          ),
                          Positioned(
                            top: 2,
                            right: 2,
                            child: GestureDetector(
                              onTap: () => setState(() => _attachedImage = null),
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle),
                                child: const Icon(Icons.close, size: 12, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    if (_attachedImage != null && _attachedAudio != null) const SizedBox(width: 10),
                    if (_attachedAudio != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkCard : AppColors.lightCard,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.terra.withOpacity(0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.audiotrack_rounded, size: 16, color: AppColors.terra),
                            const SizedBox(width: 6),
                            Text(
                              'Voice (${_recordSeconds}s)',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? AppColors.darkInk : AppColors.lightInk),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => setState(() => _attachedAudio = null),
                              child: const Icon(Icons.close, size: 14, color: Colors.redAccent),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],

              if (_isSaving) ...[
                const SizedBox(height: 14),
                LinearProgressIndicator(color: AppColors.sage),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    _uploadStatus,
                    style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkSoft : AppColors.lightSoft),
                  ),
                ),
              ],

              const SizedBox(height: 18),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.sage,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _isSaving ? null : _submitMilestone,
                  child: const Text(
                    'Save to Journey Timeline ✦',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
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
