import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/media_upload_service.dart';
import '../../../providers/memories_provider.dart';

enum AddMemoryType { none, photo, video, voice }

class AddMemoryDialog extends StatefulWidget {
  final String spaceId;
  final String currentUserId;
  final String userNickname;
  final MemoriesProvider memoriesProvider;

  const AddMemoryDialog({
    super.key,
    required this.spaceId,
    required this.currentUserId,
    required this.userNickname,
    required this.memoriesProvider,
  });

  static void show(
    BuildContext context, {
    required String spaceId,
    required String currentUserId,
    required String userNickname,
    required MemoriesProvider memoriesProvider,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddMemoryDialog(
        spaceId: spaceId,
        currentUserId: currentUserId,
        userNickname: userNickname,
        memoriesProvider: memoriesProvider,
      ),
    );
  }

  @override
  State<AddMemoryDialog> createState() => _AddMemoryDialogState();
}

class _AddMemoryDialogState extends State<AddMemoryDialog> {
  AddMemoryType _selectedType = AddMemoryType.none;
  final ImagePicker _picker = ImagePicker();
  final AudioRecorder _audioRecorder = AudioRecorder();

  File? _selectedMediaFile;
  File? _recordedAudioFile;
  bool _isRecording = false;
  int _recordDurationSeconds = 0;
  Timer? _recordTimer;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _captionController = TextEditingController();
  bool _isUploading = false;
  double _uploadProgress = 0.0;

  @override
  void dispose() {
    _recordTimer?.cancel();
    _audioRecorder.dispose();
    _titleController.dispose();
    _captionController.dispose();
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
        setState(() => _selectedMediaFile = File(file.path));
      }
    } catch (_) {}
  }

  Future<void> _pickVideo() async {
    try {
      final XFile? file = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 5),
      );
      if (file != null) {
        setState(() => _selectedMediaFile = File(file.path));
      }
    } catch (_) {}
  }

  Future<void> _startAudioRecording({int maxSeconds = 30}) async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final tempDir = await getTemporaryDirectory();
        final path = '${tempDir.path}/whisper_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: path,
        );

        setState(() {
          _isRecording = true;
          _recordDurationSeconds = 0;
        });

        _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
          setState(() => _recordDurationSeconds++);
          if (_recordDurationSeconds >= maxSeconds) {
            await _stopAudioRecording();
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _stopAudioRecording() async {
    try {
      _recordTimer?.cancel();
      final path = await _audioRecorder.stop();
      if (path != null) {
        setState(() {
          _isRecording = false;
          _recordedAudioFile = File(path);
        });
      }
    } catch (_) {
      setState(() => _isRecording = false);
    }
  }

  Future<void> _submitMemory() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a title for this memory.')),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      String mediaUrl = '';
      String? voiceUrl;

      // Upload main media (Photo or Video)
      if (_selectedMediaFile != null) {
        final result = await MediaUploadService.uploadFile(
          _selectedMediaFile!,
          folder: 'memories',
          onProgress: (p) => setState(() => _uploadProgress = p * 0.7),
        );
        mediaUrl = result.url;
      }

      // Upload attached Voice Whisper or standalone audio
      if (_recordedAudioFile != null) {
        final audioResult = await MediaUploadService.uploadFile(
          _recordedAudioFile!,
          folder: 'audio',
          onProgress: (p) => setState(() => _uploadProgress = 0.7 + (p * 0.3)),
        );
        if (_selectedType == AddMemoryType.voice) {
          mediaUrl = ''; // Standalone audio uses voiceUrl / thumbnail_url
          voiceUrl = audioResult.url;
        } else {
          voiceUrl = audioResult.url;
        }
      }

      await widget.memoriesProvider.addMemory(
        spaceId: widget.spaceId,
        title: _titleController.text.trim(),
        caption: _captionController.text.trim(),
        mediaUrl: mediaUrl,
        voiceUrl: voiceUrl,
        author: widget.currentUserId,
        currentUserId: widget.currentUserId,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Memory preserved in your sanctuary ✦')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          child: _selectedType == AddMemoryType.none
              ? _buildTypeChooser(isDark)
              : _buildMemoryForm(isDark),
        ),
      ),
    );
  }

  Widget _buildTypeChooser(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Text(
            'NEW SANCTUARY MEMORY',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
              color: AppColors.terra,
            ),
          ),
          Text(
            'What would you like to keep?',
            style: TextStyle(
              fontFamily: 'serif',
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.darkInk : AppColors.lightInk,
            ),
          ),
          const SizedBox(height: 20),

          // Option 1: Photo + 30s voice whisper
          _buildOptionCard(
            title: 'Photo Memory',
            subtitle: 'Upload photo with optional 30s voice whisper',
            icon: Icons.photo_library_outlined,
            color: AppColors.sage,
            isDark: isDark,
            onTap: () {
              setState(() => _selectedType = AddMemoryType.photo);
              _pickImage();
            },
          ),
          const SizedBox(height: 12),

          // Option 2: Video Moment with caption
          _buildOptionCard(
            title: 'Video Moment',
            subtitle: 'Upload memorable clip from Google Photos or files',
            icon: Icons.videocam_outlined,
            color: AppColors.terra,
            isDark: isDark,
            onTap: () {
              setState(() => _selectedType = AddMemoryType.video);
              _pickVideo();
            },
          ),
          const SizedBox(height: 12),

          // Option 3: Voice Message only with caption
          _buildOptionCard(
            title: 'Voice Message',
            subtitle: 'Record an audio whisper directly or attach voice note',
            icon: Icons.mic_none_outlined,
            color: AppColors.slate,
            isDark: isDark,
            onTap: () {
              setState(() => _selectedType = AddMemoryType.voice);
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildOptionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.darkInk : AppColors.lightInk,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
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

  Widget _buildMemoryForm(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, size: 20),
                onPressed: () => setState(() => _selectedType = AddMemoryType.none),
              ),
              Text(
                _selectedType == AddMemoryType.photo
                    ? 'Photo Memory'
                    : _selectedType == AddMemoryType.video
                        ? 'Video Moment'
                        : 'Voice Message',
                style: const TextStyle(fontFamily: 'serif', fontSize: 16, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Media Preview / Picker Box
          if (_selectedType == AddMemoryType.photo) ...[
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 160,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.lightCard,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  image: _selectedMediaFile != null
                      ? DecorationImage(
                          image: FileImage(_selectedMediaFile!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: _selectedMediaFile == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add_photo_alternate, size: 36, color: AppColors.sage),
                          const SizedBox(height: 8),
                          Text('Choose Photo from Gallery', style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkSoft : AppColors.lightSoft)),
                        ],
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 12),

            // Optional 30s Voice Whisper Recorder
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      _isRecording ? Icons.stop_circle : Icons.mic,
                      color: _isRecording ? Colors.redAccent : AppColors.terra,
                      size: 28,
                    ),
                    onPressed: _isRecording ? _stopAudioRecording : () => _startAudioRecording(maxSeconds: 30),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isRecording
                              ? 'Recording... ($_recordDurationSeconds / 30s)'
                              : (_recordedAudioFile != null ? 'Voice Whisper Attached ✦' : 'Optional: Record 30s Voice Whisper'),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _isRecording ? Colors.redAccent : (isDark ? AppColors.darkInk : AppColors.lightInk),
                          ),
                        ),
                        Text(
                          'Plays via "Listen Voice Whisper" on this card',
                          style: TextStyle(fontSize: 10, color: isDark ? AppColors.darkSoft : AppColors.lightSoft),
                        ),
                      ],
                    ),
                  ),
                  if (_recordedAudioFile != null && !_isRecording)
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => setState(() => _recordedAudioFile = null),
                    ),
                ],
              ),
            ),
          ],

          if (_selectedType == AddMemoryType.video) ...[
            GestureDetector(
              onTap: _pickVideo,
              child: Container(
                height: 160,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.lightCard,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _selectedMediaFile != null ? Icons.check_circle : Icons.video_library,
                      size: 36,
                      color: _selectedMediaFile != null ? AppColors.sage : AppColors.terra,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _selectedMediaFile != null
                          ? 'Video Attached 🎬 (Tap to change)'
                          : 'Select Video from Files / Gallery',
                      style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkInk : AppColors.lightInk),
                    ),
                  ],
                ),
              ),
            ),
          ],

          if (_selectedType == AddMemoryType.voice) ...[
            Container(
              padding: const EdgeInsets.all(20),
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _isRecording ? _stopAudioRecording : () => _startAudioRecording(maxSeconds: 180),
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isRecording ? Colors.redAccent : AppColors.sage,
                        boxShadow: [
                          BoxShadow(
                            color: (_isRecording ? Colors.redAccent : AppColors.sage).withOpacity(0.3),
                            blurRadius: 16,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: Icon(
                        _isRecording ? Icons.stop : Icons.mic,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _isRecording
                        ? 'Recording voice note... ($_recordDurationSeconds s)'
                        : (_recordedAudioFile != null ? 'Voice Message Recorded ✦' : 'Tap to start recording'),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: _isRecording ? Colors.redAccent : (isDark ? AppColors.darkInk : AppColors.lightInk),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Plays in the upper sanctuary audio track',
                    style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkSoft : AppColors.lightSoft),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Title
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: 'Title',
              hintText: _selectedType == AddMemoryType.voice
                  ? 'e.g. Good morning my love...'
                  : _selectedType == AddMemoryType.video
                      ? 'e.g. Cooking together...'
                      : 'e.g. Our cozy cafe date...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 12),

          // Caption
          TextField(
            controller: _captionController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Caption / Sweet note',
              hintText: 'Write a few sweet words to remember this moment...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 18),

          if (_isUploading) ...[
            LinearProgressIndicator(value: _uploadProgress > 0 ? _uploadProgress : null),
            const SizedBox(height: 12),
            Center(
              child: Text(
                'Preserving to sanctuary... (${(_uploadProgress * 100).toInt()}%)',
                style: const TextStyle(fontSize: 11, color: AppColors.terra),
              ),
            ),
            const SizedBox(height: 12),
          ],

          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.sage,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _isUploading ? null : _submitMemory,
              child: const Text('Preserve to Sanctuary ✦', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
