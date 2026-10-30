import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/services/media_upload_service.dart';
import '../../../data/models/vault_item.dart';
import '../../../providers/vault_provider.dart';
import '../widgets/vault_emblem.dart';
import '../../../widgets/sanctuary_voice_player.dart';
import '../widgets/downloaded_music_picker_sheet.dart';

class NewVaultScreen extends StatefulWidget {
  final VaultItem? initialVault;
  final String spaceId;
  final String currentUserId;
  final String userNickname;
  final String partnerNickname;

  const NewVaultScreen({
    super.key,
    this.initialVault,
    required this.spaceId,
    required this.currentUserId,
    required this.userNickname,
    required this.partnerNickname,
  });

  @override
  State<NewVaultScreen> createState() => _NewVaultScreenState();
}

class _NewVaultScreenState extends State<NewVaultScreen> {
  final _picker = ImagePicker();
  final _audioRecorder = AudioRecorder();

  late TextEditingController _titleController;
  late TextEditingController _pinController;
  late TextEditingController _letterController;

  late int _selectedColor;
  late String _selectedEmblem;
  late String _accessMode; // 'open', 'timer', 'pin'
  DateTime? _specialDate;

  File? _localCoverFile;
  String? _remoteCoverUrl;

  final List<File> _localPhotos = [];
  final List<String> _remotePhotos = [];

  File? _localVideoFile;
  String? _remoteVideoUrl;

  File? _localVoiceFile;
  String? _remoteVoiceUrl;
  int _voiceDurationSeconds = 0;
  bool _isRecordingVoice = false;
  Timer? _recordTimer;

  String _backgroundSong = 'lofi_sanctuary'; // 'lofi_sanctuary', 'romantic_piano', 'acoustic_warmth', 'none'
  File? _customAudioFile;
  String? _selectedDownloadedSongTitle;

  bool _isSaving = false;
  double _uploadProgress = 0.0;
  String _uploadStatus = '';

  static const List<int> _colorPalette = [
    0xFF541525, // Wine / Burgundy
    0xFF162238, // Midnight Navy
    0xFF0D383A, // Slate Teal
    0xFF2B133D, // Deep Purple
    0xFF1B2E24, // Deep Charcoal Emerald
  ];

  static const List<String> _emblemShapes = [
    'circle',
    'arch',
    'diamond',
    'square',
  ];

  @override
  void initState() {
    super.initState();
    final v = widget.initialVault;
    _titleController = TextEditingController(text: v?.title ?? '');
    _pinController = TextEditingController(text: v?.pinCode ?? '');
    _letterController = TextEditingController(text: v?.letter ?? '');

    _selectedColor = v?.colorValue ?? _colorPalette.first;
    _selectedEmblem = v?.emblemShape ?? 'circle';
    _accessMode = v?.accessMode ?? 'open';
    _specialDate = v?.specialDate ?? DateTime.now().add(const Duration(days: 30));

    _remoteCoverUrl = v?.coverImageUrl;
    if (v != null) {
      _remotePhotos.addAll(v.photoUrls);
      _remoteVideoUrl = v.videoUrl;
      _remoteVoiceUrl = v.voiceNoteUrl;
      _voiceDurationSeconds = v.voiceNoteDurationSeconds ?? 0;
      _backgroundSong = v.backgroundSong ?? 'lofi_sanctuary';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _pinController.dispose();
    _letterController.dispose();
    _recordTimer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  // --- Image & Media Actions ---

  Future<void> _pickCoverPhoto() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) {
      setState(() {
        _localCoverFile = File(picked.path);
        _remoteCoverUrl = null;
      });
    }
  }

  Future<void> _pickMultiplePhotos() async {
    final picked = await _picker.pickMultiImage(imageQuality: 85);
    if (picked.isNotEmpty) {
      setState(() {
        _localPhotos.addAll(picked.map((x) => File(x.path)));
      });
    }
  }

  Future<void> _pickVideo() async {
    final picked = await _picker.pickVideo(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _localVideoFile = File(picked.path);
        _remoteVideoUrl = null;
      });
    }
  }

  Future<void> _toggleVoiceRecording() async {
    if (_isRecordingVoice) {
      // Stop recording
      try {
        _recordTimer?.cancel();
        final path = await _audioRecorder.stop();
        if (path != null) {
          setState(() {
            _isRecordingVoice = false;
            _localVoiceFile = File(path);
            _remoteVoiceUrl = null;
          });
        }
      } catch (_) {
        setState(() => _isRecordingVoice = false);
      }
    } else {
      // Start recording
      try {
        if (await _audioRecorder.hasPermission()) {
          final tempDir = await getTemporaryDirectory();
          final path = '${tempDir.path}/vault_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
          await _audioRecorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);

          setState(() {
            _isRecordingVoice = true;
            _voiceDurationSeconds = 0;
            _localVoiceFile = null;
          });

          _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
            setState(() => _voiceDurationSeconds++);
          });
        }
      } catch (_) {}
    }
  }

  Future<void> _pickDownloadedMusic() async {
    final track = await DownloadedMusicPickerSheet.show(context);
    if (track != null && track.localFilePath != null) {
      setState(() {
        _customAudioFile = File(track.localFilePath!);
        _backgroundSong = 'custom';
        _selectedDownloadedSongTitle = track.title;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Selected "${track.title}" as Vault Theme Music ✦'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _pickCustomAudio() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'm4a', 'wav', 'aac', 'ogg', 'flac'],
      );
      if (result != null && result.files.single.path != null) {
        setState(() {
          _customAudioFile = File(result.files.single.path!);
          _backgroundSong = 'custom';
        });
        HapticFeedback.selectionClick();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Selected "${result.files.single.name}" as background song ✦'),
              backgroundColor: const Color(0xFF2E2A3A),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (_) {}
  }

  Future<void> _pickSpecialDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _specialDate ?? now.add(const Duration(days: 30)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 3650)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFD4AF37),
              onPrimary: Colors.black,
              surface: Color(0xFF1F1A2C),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _specialDate = picked);
    }
  }

  // --- Save / Create Action ---

  Future<void> _handleSave() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a name for your vault.')),
      );
      return;
    }

    if (_accessMode == 'pin' && _pinController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please set a secret PIN code for this vault.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
      _uploadProgress = 0.05;
      _uploadStatus = 'Preparing media...';
    });

    try {
      // 1. Upload cover photo if new local file picked
      String? coverUrl = _remoteCoverUrl;
      if (_localCoverFile != null) {
        setState(() => _uploadStatus = 'Uploading cover image...');
        final res = await MediaUploadService.uploadFile(_localCoverFile!, folder: 'vault_covers');
        coverUrl = res.url;
        setState(() => _uploadProgress = 0.25);
      }

      // 2. Upload any new photos
      List<String> finalPhotos = List.from(_remotePhotos);
      if (_localPhotos.isNotEmpty) {
        setState(() => _uploadStatus = 'Uploading photos (${_localPhotos.length})...');
        for (int i = 0; i < _localPhotos.length; i++) {
          final res = await MediaUploadService.uploadFile(_localPhotos[i], folder: 'vault_photos');
          finalPhotos.add(res.url);
          setState(() => _uploadProgress = 0.25 + (0.35 * (i + 1) / _localPhotos.length));
        }
      }

      // 3. Upload video if picked
      String? videoUrl = _remoteVideoUrl;
      if (_localVideoFile != null) {
        setState(() => _uploadStatus = 'Preserving video memory...');
        final res = await MediaUploadService.uploadFile(_localVideoFile!, folder: 'vault_videos');
        videoUrl = res.url;
        setState(() => _uploadProgress = 0.75);
      }

      // 4. Upload voice note if recorded
      String? voiceUrl = _remoteVoiceUrl;
      if (_localVoiceFile != null) {
        setState(() => _uploadStatus = 'Saving voice memo...');
        final res = await MediaUploadService.uploadFile(_localVoiceFile!, folder: 'vault_voice');
        voiceUrl = res.url;
        setState(() => _uploadProgress = 0.88);
      }

      // 5. Upload custom song if picked
      String? finalSong = _backgroundSong;
      if (_backgroundSong == 'custom' && _customAudioFile != null) {
        setState(() => _uploadStatus = 'Uploading background song...');
        final res = await MediaUploadService.uploadFile(_customAudioFile!, folder: 'vault_music');
        finalSong = res.url;
      }

      setState(() {
        _uploadStatus = 'Saving to sanctuary...';
        _uploadProgress = 0.95;
      });

      final vaultId = widget.initialVault?.id ?? 'vault_${DateTime.now().millisecondsSinceEpoch}';
      final isNew = widget.initialVault == null;

      final updatedVault = VaultItem(
        id: vaultId,
        creatorId: widget.initialVault?.creatorId ?? widget.currentUserId,
        creatorName: widget.initialVault?.creatorName ?? widget.userNickname,
        title: title,
        coverImageUrl: coverUrl,
        emblemShape: _selectedEmblem,
        colorValue: _selectedColor,
        specialDate: _accessMode == 'timer' ? _specialDate : null,
        accessMode: _accessMode,
        pinCode: _accessMode == 'pin' ? _pinController.text.trim() : null,
        videoUrl: videoUrl,
        photoUrls: finalPhotos,
        letter: _letterController.text.trim(),
        voiceNoteUrl: voiceUrl,
        voiceNoteDurationSeconds: _voiceDurationSeconds > 0 ? _voiceDurationSeconds : null,
        backgroundSong: finalSong,
        createdAt: widget.initialVault?.createdAt ?? DateTime.now(),
      );

      final vaultProvider = context.read<VaultProvider>();
      if (isNew) {
        await vaultProvider.createVault(updatedVault, widget.spaceId);
      } else {
        await vaultProvider.updateVault(updatedVault, widget.spaceId);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isNew ? 'Vault created successfully ✨' : 'Vault updated ✨')),
        );
        Navigator.pop(context, updatedVault);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save vault: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  // --- Real Permanent Hard Delete ---

  Future<void> _handleHardDelete() async {
    final v = widget.initialVault;
    if (v == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1624),
        title: const Text(
          'Delete Vault Permanently?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'This will permanently delete this vault and all its letters, photos, and memories from the database. This action cannot be undone.',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9E2A2B),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Permanent Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() {
        _isSaving = true;
        _uploadStatus = 'Deleting from database permanently...';
      });

      await context.read<VaultProvider>().deleteVault(v.id, widget.spaceId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vault permanently deleted from database.')),
        );
        Navigator.pop(context, 'deleted');
      }
    }
  }

  int _calculateMemoriesCount() {
    int count = _localPhotos.length + _remotePhotos.length;
    if (_localVideoFile != null || (_remoteVideoUrl != null && _remoteVideoUrl!.isNotEmpty)) count++;
    if (_localVoiceFile != null || (_remoteVoiceUrl != null && _remoteVoiceUrl!.isNotEmpty)) count++;
    if (_letterController.text.trim().isNotEmpty) count++;
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialVault != null;
    final memoriesCount = _calculateMemoriesCount();

    return Scaffold(
      backgroundColor: const Color(0xFF0D0B12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0B12),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isEditing ? 'Edit Vault' : 'New Vault',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Live Preview Card (Matching Mockup Image 2)
                _buildLivePreviewCard(memoriesCount),
                const SizedBox(height: 28),

                // 2. Cover Photo Section (Optional)
                _buildSectionHeader('COVER IMAGE (OPTIONAL)'),
                const SizedBox(height: 10),
                _buildCoverUploadArea(),
                const SizedBox(height: 24),

                // 3. Photos Horizontal Section (Optional)
                _buildSectionHeader('PHOTOS (OPTIONAL)'),
                const SizedBox(height: 10),
                _buildPhotosHorizontalList(),
                const SizedBox(height: 24),

                // 4. Vault Name Section
                _buildSectionHeader('VAULT NAME'),
                const SizedBox(height: 8),
                TextField(
                  controller: _titleController,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  decoration: InputDecoration(
                    hintText: 'E.g., Our First Paris Trip',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.35)),
                    helperText: 'Give this vault a meaningful name',
                    helperStyle: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
                    enabledBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFFD4AF37), width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 26),

                // 5. Choose Color Section
                _buildSectionHeader('CHOOSE A COLOR'),
                const SizedBox(height: 12),
                _buildColorPicker(),
                const SizedBox(height: 26),

                // 6. Emblem Section
                _buildSectionHeader('EMBLEM'),
                const SizedBox(height: 12),
                _buildEmblemSelector(),
                const SizedBox(height: 26),

                // 7. Special Date Section
                _buildSectionHeader('SPECIAL DATE'),
                const SizedBox(height: 10),
                InkWell(
                  onTap: _pickSpecialDate,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16141F),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _specialDate != null
                              ? DateFormat('MMMM d, yyyy').format(_specialDate!)
                              : 'Select a special date',
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                        ),
                        const Icon(Icons.calendar_today_rounded, color: Color(0xFFD4AF37), size: 18),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 26),

                // 8. Access Mode Section
                _buildSectionHeader('ACCESS MODE'),
                const SizedBox(height: 12),
                _buildAccessModeSelector(),
                const SizedBox(height: 26),

                // 9. Media & Extras: Video, Voice Memo, Music
                _buildSectionHeader('MEDIA & MEMORIES'),
                const SizedBox(height: 12),
                _buildMediaAndExtras(),
                const SizedBox(height: 26),

                // 10. The Letter Section
                _buildSectionHeader('THE LETTER'),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16141F),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: TextField(
                    controller: _letterController,
                    onChanged: (_) => setState(() {}),
                    maxLines: 5,
                    style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Write your private note, letter, or vows to be sealed inside this vault...',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(height: 36),

                // 11. Create / Save Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD4AF37),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                      elevation: 2,
                    ),
                    onPressed: _isSaving ? null : _handleSave,
                    child: Text(
                      isEditing ? 'Save Changes' : 'Create Vault',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

                // 12. If Editing: Delete Button with Hard Database Wipe
                if (isEditing) ...[
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton.icon(
                      onPressed: _isSaving ? null : _handleHardDelete,
                      icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFE57373), size: 18),
                      label: const Text(
                        'Delete this vault',
                        style: TextStyle(color: Color(0xFFE57373), fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 48),
              ],
            ),
          ),

          // Uploading overlay indicator
          if (_isSaving)
            Container(
              color: Colors.black87,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F1A2C),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.4)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: Color(0xFFD4AF37)),
                      const SizedBox(height: 16),
                      Text(
                        _uploadStatus,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: _uploadProgress,
                        backgroundColor: Colors.white12,
                        color: const Color(0xFFD4AF37),
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

  // --- Subcomponents matching Mockups ---

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        color: Colors.white.withOpacity(0.55),
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildLivePreviewCard(int memoriesCount) {
    String badgeText = 'Open anytime';
    IconData badgeIcon = Icons.lock_open_rounded;

    if (_accessMode == 'timer') {
      final days = _specialDate != null ? _specialDate!.difference(DateTime.now()).inDays : 0;
      badgeText = days > 0 ? 'Opens in $days days' : 'Unlocks today';
      badgeIcon = Icons.hourglass_top_rounded;
    } else if (_accessMode == 'pin') {
      badgeText = 'PIN locked';
      badgeIcon = Icons.lock_outline_rounded;
    }

    final cardTitle = _titleController.text.trim().isNotEmpty
        ? _titleController.text.trim()
        : 'E.g., Our First Paris Trip';

    return Center(
      child: Container(
        width: 220,
        height: 270,
        decoration: BoxDecoration(
          color: Color(_selectedColor),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFD4AF37).withOpacity(0.4),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Color(_selectedColor).withOpacity(0.5),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Top lock badge
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(badgeIcon, size: 10, color: const Color(0xFFD4AF37)),
                    const SizedBox(width: 4),
                    Text(
                      badgeText,
                      style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),

            // Center emblem or cover image preview
            Center(
              child: _localCoverFile != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.file(
                        _localCoverFile!,
                        width: 90,
                        height: 90,
                        fit: BoxFit.cover,
                      ),
                    )
                  : (_remoteCoverUrl != null && _remoteCoverUrl!.isNotEmpty)
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: CachedNetworkImage(
                            imageUrl: _remoteCoverUrl!,
                            width: 90,
                            height: 90,
                            fit: BoxFit.cover,
                          ),
                        )
                      : VaultEmblem(shape: _selectedEmblem, size: 70),
            ),

            // Bottom title & creator
            Positioned(
              left: 14,
              right: 14,
              bottom: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    cardTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'By You · $memoriesCount memories',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.65),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverUploadArea() {
    if (_localCoverFile != null || (_remoteCoverUrl != null && _remoteCoverUrl!.isNotEmpty)) {
      return Container(
        height: 120,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white24),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: _localCoverFile != null
                  ? Image.file(_localCoverFile!, fit: BoxFit.cover)
                  : CachedNetworkImage(imageUrl: _remoteCoverUrl!, fit: BoxFit.cover),
            ),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: Colors.black38,
              ),
            ),
            Positioned(
              bottom: 10,
              right: 10,
              child: Row(
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black54,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                    onPressed: _pickCoverPhoto,
                    child: const Text('Change', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9E2A2B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                    onPressed: () {
                      setState(() {
                        _localCoverFile = null;
                        _remoteCoverUrl = null;
                      });
                    },
                    child: const Text('Remove', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return InkWell(
      onTap: _pickCoverPhoto,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 80,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF16141F),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white24, style: BorderStyle.solid),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_photo_alternate_outlined, color: Color(0xFFD4AF37), size: 24),
            const SizedBox(height: 6),
            Text(
              '+ Add a cover photo',
              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotosHorizontalList() {
    return SizedBox(
      height: 90,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // Add photos button
          InkWell(
            onTap: _pickMultiplePhotos,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 80,
              height: 90,
              decoration: BoxDecoration(
                color: const Color(0xFF16141F),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_rounded, color: Color(0xFFD4AF37), size: 24),
                  const SizedBox(height: 4),
                  Text(
                    'Add photos',
                    style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Existing remote photos
          ..._remotePhotos.asMap().entries.map((entry) {
            final idx = entry.key;
            final url = entry.value;
            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: url,
                      width: 80,
                      height: 90,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => setState(() => _remotePhotos.removeAt(idx)),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Colors.black87,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded, size: 12, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),

          // Local photos
          ..._localPhotos.asMap().entries.map((entry) {
            final idx = entry.key;
            final file = entry.value;
            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      file,
                      width: 80,
                      height: 90,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => setState(() => _localPhotos.removeAt(idx)),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Colors.black87,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded, size: 12, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildColorPicker() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: _colorPalette.map((colorVal) {
        final isSelected = _selectedColor == colorVal;
        return GestureDetector(
          onTap: () => setState(() => _selectedColor = colorVal),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Color(colorVal),
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? const Color(0xFFD4AF37) : Colors.white24,
                width: isSelected ? 2.5 : 1.0,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: Color(colorVal).withOpacity(0.6),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ]
                  : [],
            ),
            child: isSelected
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                : null,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmblemSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: _emblemShapes.map((shape) {
        final isSelected = _selectedEmblem == shape;
        return GestureDetector(
          onTap: () => setState(() => _selectedEmblem = shape),
          child: Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: const Color(0xFF16141F),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? const Color(0xFFD4AF37) : Colors.white12,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Center(
              child: VaultEmblem(shape: shape, size: 36),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAccessModeSelector() {
    return Column(
      children: [
        _buildAccessOption(
          mode: 'open',
          title: 'Open anytime',
          subtitle: 'Both of you can open this vault at any time',
          icon: Icons.lock_open_rounded,
        ),
        const SizedBox(height: 10),
        _buildAccessOption(
          mode: 'timer',
          title: 'Unlock on the date',
          subtitle: 'Sealed with a countdown timer until the special date',
          icon: Icons.hourglass_top_rounded,
        ),
        const SizedBox(height: 10),
        _buildAccessOption(
          mode: 'pin',
          title: 'PIN protected',
          subtitle: 'Requires a secret PIN to unlock',
          icon: Icons.lock_outline_rounded,
        ),
        if (_accessMode == 'pin') ...[
          const SizedBox(height: 14),
          TextField(
            controller: _pinController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            style: const TextStyle(color: Colors.white, fontSize: 16, letterSpacing: 4),
            decoration: InputDecoration(
              hintText: 'Enter 4-6 digit secret PIN',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.35), letterSpacing: 1),
              counterText: '',
              filled: true,
              fillColor: const Color(0xFF16141F),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFD4AF37)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 1.5),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAccessOption({
    required String mode,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _accessMode == mode;
    return InkWell(
      onTap: () => setState(() => _accessMode = mode),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF16141F),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? const Color(0xFFD4AF37) : Colors.white12,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFFD4AF37) : Colors.white54,
              size: 20,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? const Color(0xFFD4AF37) : Colors.white30,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Color(0xFFD4AF37),
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaAndExtras() {
    return Column(
      children: [
        // Video Picker Row
        _buildMediaActionTile(
          icon: Icons.videocam_outlined,
          title: 'Event Video',
          subtitle: _localVideoFile != null
              ? 'Video attached (${(_localVideoFile!.lengthSync() / 1024 / 1024).toStringAsFixed(1)} MB)'
              : (_remoteVideoUrl != null && _remoteVideoUrl!.isNotEmpty)
                  ? 'Video preserved'
                  : 'Add a video memory',
          trailing: _localVideoFile != null || (_remoteVideoUrl != null && _remoteVideoUrl!.isNotEmpty)
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 18),
                  onPressed: () => setState(() {
                    _localVideoFile = null;
                    _remoteVideoUrl = null;
                  }),
                )
              : null,
          onTap: _pickVideo,
        ),
        const SizedBox(height: 10),

        // Voice Memo Row
        _buildMediaActionTile(
          icon: _isRecordingVoice ? Icons.fiber_manual_record_rounded : Icons.mic_none_rounded,
          iconColor: _isRecordingVoice ? Colors.redAccent : const Color(0xFFD4AF37),
          title: 'Voice Memo',
          subtitle: _isRecordingVoice
              ? 'Recording... ($_voiceDurationSeconds s) Tap to stop'
              : (_localVoiceFile != null || (_remoteVoiceUrl != null && _remoteVoiceUrl!.isNotEmpty))
                  ? 'Voice memo attached (${_voiceDurationSeconds > 0 ? "$_voiceDurationSeconds s" : "ready"})'
                  : 'Tap to record a voice note',
          trailing: _localVoiceFile != null || (_remoteVoiceUrl != null && _remoteVoiceUrl!.isNotEmpty)
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 18),
                  onPressed: () => setState(() {
                    _localVoiceFile = null;
                    _remoteVoiceUrl = null;
                    _voiceDurationSeconds = 0;
                  }),
                )
              : null,
          onTap: _toggleVoiceRecording,
        ),
        if (_localVoiceFile != null || (_remoteVoiceUrl != null && _remoteVoiceUrl!.isNotEmpty)) ...[
          const SizedBox(height: 8),
          SanctuaryVoicePlayer(
            id: 'new_vault_voice_preview',
            audioUrl: _localVoiceFile?.path ?? _remoteVoiceUrl!,
            durationSeconds: _voiceDurationSeconds > 0 ? _voiceDurationSeconds : null,
            isDark: true,
          ),
        ],
        const SizedBox(height: 10),

        // Background Music Selector
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF16141F),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.music_note_rounded, color: Color(0xFFD4AF37), size: 20),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      'Background Song',
                      style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildMusicChip('lofi_sanctuary', '☕ Lo-fi Sanctuary'),
                  _buildMusicChip('rain', '🌧️ Gentle Rain'),
                  _buildMusicChip('ocean', '🌊 Ocean Waves'),
                  _buildMusicChip('breeze', '🍃 Night Breeze'),
                  _buildMusicChip('fireplace', '🔥 Cozy Fireplace'),
                  _buildMusicChip('birds', '🐦 Morning Birds'),
                  _buildMusicChip('none', '🔇 None'),
                  ActionChip(
                    backgroundColor: (_selectedDownloadedSongTitle != null)
                        ? const Color(0xFFD4AF37).withOpacity(0.2)
                        : const Color(0xFF1E1A29),
                    side: BorderSide(
                      color: (_selectedDownloadedSongTitle != null)
                          ? const Color(0xFFD4AF37)
                          : Colors.white12,
                    ),
                    avatar: const Icon(Icons.download_done_rounded, size: 14, color: Color(0xFFD4AF37)),
                    label: Text(
                      _selectedDownloadedSongTitle != null
                          ? '🎵 $_selectedDownloadedSongTitle ✓'
                          : '🎵 From Downloaded Music',
                      style: TextStyle(
                        color: (_selectedDownloadedSongTitle != null)
                            ? const Color(0xFFD4AF37)
                            : Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: _pickDownloadedMusic,
                  ),
                  ActionChip(
                    backgroundColor: (_backgroundSong == 'custom' || (_backgroundSong != null && _backgroundSong!.startsWith('http')))
                        ? const Color(0xFFD4AF37).withOpacity(0.2)
                        : const Color(0xFF1E1A29),
                    side: BorderSide(
                      color: (_backgroundSong == 'custom' || (_backgroundSong != null && _backgroundSong!.startsWith('http')))
                          ? const Color(0xFFD4AF37)
                          : Colors.white12,
                    ),
                    avatar: const Icon(Icons.upload_file_rounded, size: 14, color: Color(0xFFD4AF37)),
                    label: Text(
                      _customAudioFile != null
                          ? 'Custom: ${p.basename(_customAudioFile!.path)} ✓'
                          : (_backgroundSong != null && _backgroundSong!.startsWith('http')
                              ? 'Custom Song Saved ✓'
                              : '+ Upload Custom Song'),
                      style: TextStyle(
                        color: (_backgroundSong == 'custom' || (_backgroundSong != null && _backgroundSong!.startsWith('http')))
                            ? const Color(0xFFD4AF37)
                            : Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: _pickCustomAudio,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMediaActionTile({
    required IconData icon,
    Color? iconColor,
    required String title,
    required String subtitle,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF16141F),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor ?? const Color(0xFFD4AF37), size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 11.5),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  Widget _buildMusicChip(String trackKey, String label) {
    final isSelected = _backgroundSong == trackKey;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.black : Colors.white70,
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedColor: const Color(0xFFD4AF37),
      backgroundColor: const Color(0xFF1E1A29),
      side: BorderSide(color: isSelected ? const Color(0xFFD4AF37) : Colors.white12),
      onSelected: (_) => setState(() => _backgroundSong = trackKey),
    );
  }
}
