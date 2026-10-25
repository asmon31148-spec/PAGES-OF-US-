import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/media_upload_service.dart';
import '../../../data/models/event_capsule.dart';
import '../../../providers/vault_provider.dart';

class AddEventCapsuleDialog extends StatefulWidget {
  final String spaceId;
  final String userId;
  final String userName;
  final EventCapsule? initialCapsule;

  const AddEventCapsuleDialog({
    super.key,
    required this.spaceId,
    required this.userId,
    required this.userName,
    this.initialCapsule,
  });

  @override
  State<AddEventCapsuleDialog> createState() => _AddEventCapsuleDialogState();
}

class _AddEventCapsuleDialogState extends State<AddEventCapsuleDialog> {
  late TextEditingController _titleController;
  late TextEditingController _pinController;
  late TextEditingController _hintController;
  late TextEditingController _noteController;
  late TextEditingController _scratchController;

  String _eventType = 'Birthday 🎂';
  String? _videoUrl;
  bool _isTimeLocked = false;
  DateTime? _unlockDateTime;
  String _selectedTrack = 'lofi_sanctuary';
  bool _isUploadingVideo = false;

  final List<String> _eventTypes = [
    'Birthday 🎂',
    'Anniversary 💍',
    'Special Date ✨',
    'Just Because 💌',
    'First Meet 🌿',
  ];

  @override
  void initState() {
    super.initState();
    final c = widget.initialCapsule;
    _titleController = TextEditingController(text: c?.title ?? 'Her Birthday Surprise 🎂');
    _pinController = TextEditingController(text: c?.passcode ?? '251200');
    _hintController = TextEditingController(text: c?.passcodeHint ?? '');
    _noteController = TextEditingController(text: c?.personalNote ?? '');
    _scratchController = TextEditingController(text: c?.scratchSecret ?? '');
    _videoUrl = c?.videoUrl;
    _eventType = c?.eventType ?? 'Birthday 🎂';
    _unlockDateTime = c?.unlockAt;
    _isTimeLocked = c?.unlockAt != null;
    _selectedTrack = c?.ambientTrack ?? 'lofi_sanctuary';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _pinController.dispose();
    _hintController.dispose();
    _noteController.dispose();
    _scratchController.dispose();
    super.dispose();
  }

  Future<void> _pickVideoFile() async {
    try {
      final res = await FilePicker.platform.pickFiles(type: FileType.video);
      if (res != null && res.files.single.path != null) {
        setState(() => _isUploadingVideo = true);
        final uploaded = await MediaUploadService.uploadMedia(
          filePath: res.files.single.path!,
          spaceId: widget.spaceId,
        );
        setState(() {
          _videoUrl = uploaded.url;
          _isUploadingVideo = false;
        });
      }
    } catch (_) {
      setState(() => _isUploadingVideo = false);
    }
  }

  Future<void> _pickUnlockDate() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _unlockDateTime ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 2)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.romanceRoseGold,
              surface: AppColors.romanceCard,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null && mounted) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: const TimeOfDay(hour: 0, minute: 0),
        builder: (context, child) {
          return Theme(
            data: ThemeData.dark().copyWith(
              colorScheme: const ColorScheme.dark(
                primary: AppColors.romanceRoseGold,
                surface: AppColors.romanceCard,
              ),
            ),
            child: child!,
          );
        },
      );

      if (pickedTime != null) {
        setState(() {
          _unlockDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.romanceBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: Border.all(color: AppColors.romanceRoseGold.withOpacity(0.4), width: 1.2),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.initialCapsule == null ? 'Create Event Capsule ✦' : 'Edit Capsule ✦',
                    style: const TextStyle(
                      color: AppColors.romanceInk,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.romanceSoft, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Event Type Chips
              const Text('Event Type', style: TextStyle(color: AppColors.romanceRoseGold, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _eventTypes.map((t) {
                  final isSel = _eventType == t;
                  return ChoiceChip(
                    label: Text(t, style: TextStyle(fontSize: 11.5, color: isSel ? Colors.white : AppColors.romanceSoft, fontWeight: FontWeight.bold)),
                    selected: isSel,
                    selectedColor: AppColors.romanceWine,
                    backgroundColor: AppColors.romanceCard,
                    side: Border.all(color: isSel ? AppColors.romanceRoseGold : AppColors.romanceBorder),
                    onSelected: (_) => setState(() => _eventType = t),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Title
              _buildField('Capsule Title', _titleController, 'e.g. Her 22nd Birthday 🎂'),
              const SizedBox(height: 14),

              // 6-digit PIN
              _buildField(
                '6-Digit Secret Passcode',
                _pinController,
                'e.g. 251200',
                keyboardType: TextInputType.number,
                maxLength: 6,
              ),
              const SizedBox(height: 14),

              // Secret Clue
              _buildField('Secret Clue / Riddle for Her', _hintController, 'e.g. The day we first met under the rain (DDMMYY)'),
              const SizedBox(height: 16),

              // Time-Lock Toggle
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.romanceCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.romanceBorder),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.lock_clock_rounded, color: AppColors.romanceGold, size: 18),
                            SizedBox(width: 8),
                            Text('Time-Lock Until Midnight', style: TextStyle(color: AppColors.romanceInk, fontSize: 13, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Switch(
                          value: _isTimeLocked,
                          activeColor: AppColors.romanceRoseGold,
                          onChanged: (val) {
                            setState(() {
                              _isTimeLocked = val;
                              if (val && _unlockDateTime == null) {
                                _unlockDateTime = DateTime.now().add(const Duration(days: 1));
                              }
                            });
                          },
                        ),
                      ],
                    ),
                    if (_isTimeLocked) ...[
                      const Divider(color: AppColors.romanceBorder, height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _unlockDateTime != null
                                ? 'Unlocks: ${_unlockDateTime!.month}/${_unlockDateTime!.day}/${_unlockDateTime!.year} at ${_unlockDateTime!.hour.toString().padLeft(2, '0')}:${_unlockDateTime!.minute.toString().padLeft(2, '0')}'
                                : 'Select date & time',
                            style: const TextStyle(color: AppColors.romanceGold, fontSize: 12),
                          ),
                          TextButton(
                            onPressed: _pickUnlockDate,
                            child: const Text('Change Date', style: TextStyle(color: AppColors.romanceRoseGold, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Video File / URL
              const Text('Dedicated Event Video', style: TextStyle(color: AppColors.romanceRoseGold, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: _isUploadingVideo
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.romanceRoseGold))
                          : const Icon(Icons.video_file_rounded, color: AppColors.romanceRoseGold, size: 18),
                      label: Text(
                        _videoUrl != null ? 'Video Attached 🎬' : 'Select Video from Phone',
                        style: const TextStyle(color: AppColors.romanceInk, fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: Border.all(color: AppColors.romanceRoseGold.withOpacity(0.5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: _pickVideoFile,
                    ),
                  ),
                  if (_videoUrl != null)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Color(0xFFF87171)),
                      onPressed: () => setState(() => _videoUrl = null),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Love Letter
              _buildField('Secret Sealed Love Letter', _noteController, 'Write your heart out for this special event...', maxLines: 4),
              const SizedBox(height: 14),

              // Scratch-off Secret
              _buildField('Scratch-to-Reveal Surprise Promise', _scratchController, 'e.g. Candlelight rooftop dinner at sunset ✨'),
              const SizedBox(height: 20),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.romanceWine,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 4,
                  ),
                  onPressed: () async {
                    if (_titleController.text.trim().isEmpty) return;
                    final capsule = EventCapsule(
                      id: widget.initialCapsule?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                      creatorId: widget.userId,
                      creatorName: widget.userName,
                      title: _titleController.text.trim(),
                      eventType: _eventType,
                      passcode: _pinController.text.trim().isEmpty ? '251200' : _pinController.text.trim(),
                      passcodeHint: _hintController.text.trim().isNotEmpty ? _hintController.text.trim() : null,
                      unlockAt: _isTimeLocked ? _unlockDateTime : null,
                      videoUrl: _videoUrl,
                      personalNote: _noteController.text.trim(),
                      scratchSecret: _scratchController.text.trim().isNotEmpty ? _scratchController.text.trim() : null,
                      ambientTrack: _selectedTrack,
                      createdAt: widget.initialCapsule?.createdAt ?? DateTime.now(),
                    );

                    final vp = Navigator.of(context);
                    if (widget.initialCapsule == null) {
                      await context.read<VaultProvider>().addEventCapsule(capsule, widget.spaceId);
                    } else {
                      await context.read<VaultProvider>().updateEventCapsule(capsule, widget.spaceId);
                    }
                    vp.pop();
                  },
                  child: const Text('Save Event Capsule ✦', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(
    String label,
    TextEditingController controller,
    String hint, {
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    int? maxLength,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.romanceRoseGold, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          maxLength: maxLength,
          keyboardType: keyboardType,
          style: const TextStyle(color: AppColors.romanceInk, fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.romanceSoft, fontSize: 12),
            filled: true,
            fillColor: AppColors.romanceCard,
            counterText: '',
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.romanceBorder)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.romanceBorder)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.romanceRoseGold)),
          ),
        ),
      ],
    );
  }
}
