import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../widgets/sanctuary_voice_player.dart';

import '../../../core/services/media_upload_service.dart';
import '../../../core/services/audio_cache_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/full_screen_video_player.dart';
import '../../../data/models/vault_item.dart';
import '../../../providers/audio_provider.dart';
import '../../../providers/vault_provider.dart';
import '../widgets/vault_emblem.dart';
import '../widgets/downloaded_music_picker_sheet.dart';
import '../../../core/services/youtube_music_service.dart';
import 'new_vault_screen.dart';

class VaultDetailScreen extends StatefulWidget {
  final VaultItem vault;
  final String spaceId;
  final String currentUserId;
  final String userNickname;
  final String partnerNickname;

  const VaultDetailScreen({
    super.key,
    required this.vault,
    required this.spaceId,
    required this.currentUserId,
    required this.userNickname,
    required this.partnerNickname,
  });

  @override
  State<VaultDetailScreen> createState() => _VaultDetailScreenState();
}

class _VaultDetailScreenState extends State<VaultDetailScreen> {
  late VaultItem _vault;
  final PageController _photoPageController = PageController();
  int _currentPhotoIndex = 0;


  bool _isMusicMuted = false;

  @override
  void initState() {
    super.initState();
    _vault = widget.vault;

    // Start background music smoothly on entering vault
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vp = context.read<VaultProvider>();
      vp.startVaultMusic(_vault.backgroundSong);
    });

  }


  @override
  void dispose() {
    _photoPageController.dispose();

    // Background music is stopped when exiting this screen
    // (Handled also in onWillPop / back arrow)
    super.dispose();
  }

  Future<void> _handleBack() async {
    await context.read<VaultProvider>().stopVaultMusic();
    if (mounted) Navigator.pop(context);
  }


  void _toggleMuteMusic() {
    final vp = context.read<VaultProvider>();
    if (_isMusicMuted) {
      vp.startVaultMusic(_vault.backgroundSong);
      setState(() => _isMusicMuted = false);
    } else {
      vp.stopVaultMusic();
      setState(() => _isMusicMuted = true);
    }
  }

  void _showMusicCustomizationSheet(BuildContext context) {
    bool isUploading = false;
    String? uploadStatusText;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF13101A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final audioProvider = ctx.watch<AudioProvider>();
            final currentSong = _vault.backgroundSong;

            final soundscapes = [
              {'key': 'lofi_sanctuary', 'name': 'Lo-Fi Sanctuary', 'icon': Icons.headphones_rounded, 'desc': 'Chill relaxing beats'},
              {'key': 'rain', 'name': 'Gentle Rain', 'icon': Icons.water_drop_outlined, 'desc': 'Cozy rainfall ambiance'},
              {'key': 'ocean', 'name': 'Ocean Waves', 'icon': Icons.waves_rounded, 'desc': 'Soothing rhythmic tide'},
              {'key': 'breeze', 'name': 'Night Breeze', 'icon': Icons.air_rounded, 'desc': 'Whispering evening wind'},
              {'key': 'fireplace', 'name': 'Warm Fireplace', 'icon': Icons.local_fire_department_outlined, 'desc': 'Crackling cozy embers'},
              {'key': 'birds', 'name': 'Morning Birds', 'icon': Icons.eco_outlined, 'desc': 'Peaceful dawn chorus'},
            ];

            Future<void> selectTrack(String trackKey) async {
              HapticFeedback.selectionClick();
              final updated = _vault.copyWith(backgroundSong: trackKey);
              setState(() => _vault = updated);
              setSheetState(() {});
              await context.read<VaultProvider>().updateVault(updated, widget.spaceId);
              if (mounted) {
                if (trackKey == 'none') {
                  await context.read<VaultProvider>().stopVaultMusic();
                  setState(() => _isMusicMuted = true);
                } else {
                  setState(() => _isMusicMuted = false);
                  await context.read<VaultProvider>().startVaultMusic(trackKey);
                }
              }
            }

            Future<void> setDownloadedTrackAsVaultMusic(YoutubeTrack track) async {
              if (track.localFilePath == null) return;
              final file = File(track.localFilePath!);
              setSheetState(() {
                isUploading = true;
                uploadStatusText = 'Setting "${track.title}"...';
              });

              try {
                final uploadRes = await MediaUploadService.uploadFile(
                  file,
                  folder: 'vault_music',
                );

                final updated = _vault.copyWith(backgroundSong: uploadRes.url);
                setState(() => _vault = updated);
                await context.read<VaultProvider>().updateVault(updated, widget.spaceId);

                if (mounted) {
                  setState(() => _isMusicMuted = false);
                  await context.read<VaultProvider>().startVaultMusic(uploadRes.url);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Vault Theme Music set to: ${track.title} 🎵'),
                      backgroundColor: const Color(0xFF1F1B2C),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  setSheetState(() => isUploading = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to set theme song: $e')),
                  );
                }
              }
            }

            Future<void> pickAndUploadCustomMusic() async {
              try {
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['mp3', 'm4a', 'wav', 'aac', 'ogg', 'flac'],
                );

                if (result != null && result.files.single.path != null) {
                  final file = File(result.files.single.path!);
                  setSheetState(() {
                    isUploading = true;
                    uploadStatusText = 'Uploading ${result.files.single.name}...';
                  });

                  final uploadRes = await MediaUploadService.uploadFile(
                    file,
                    folder: 'vault_music',
                  );

                  final updated = _vault.copyWith(backgroundSong: uploadRes.url);
                  setState(() => _vault = updated);
                  await context.read<VaultProvider>().updateVault(updated, widget.spaceId);

                  if (mounted) {
                    setState(() => _isMusicMuted = false);
                    await context.read<VaultProvider>().startVaultMusic(uploadRes.url);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Soundtrack set to: ${result.files.single.name}'),
                        backgroundColor: const Color(0xFF1F1B2C),
                      ),
                    );
                  }

                  if (ctx.mounted) {
                    setSheetState(() {
                      isUploading = false;
                      uploadStatusText = null;
                    });
                  }
                }
              } catch (e) {
                if (ctx.mounted) {
                  setSheetState(() {
                    isUploading = false;
                    uploadStatusText = null;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Upload failed: $e'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              }
            }

            return Container(
              height: MediaQuery.of(context).size.height * 0.78,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Header
                  Row(
                    children: [
                      const Icon(Icons.music_note_rounded, color: Color(0xFFD4AF37), size: 22),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Vault Soundtrack',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white70),
                        onPressed: () => Navigator.pop(sheetCtx),
                      ),
                    ],
                  ),
                  Text(
                    'Pick a nature soundscape, couple playlist song, or upload your own song from device storage.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 12.5,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 16),

                  Expanded(
                    child: ListView(
                      children: [
                        // --- 0. Select From In-App Downloaded Music ---
                        GestureDetector(
                          onTap: isUploading
                              ? null
                              : () async {
                                  final track = await DownloadedMusicPickerSheet.show(context);
                                  if (track != null) {
                                    await setDownloadedTrackAsVaultMusic(track);
                                  }
                                },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFFA3E635).withOpacity(0.18),
                                  const Color(0xFFA3E635).withOpacity(0.06),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFA3E635).withOpacity(0.5),
                                width: 1.2,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFA3E635).withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.download_done_rounded,
                                    color: Color(0xFFA3E635),
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'From Downloaded Music 🎵',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'Pick any YouTube Music song you downloaded',
                                        style: TextStyle(
                                          color: Color(0xFF94A3B8),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right_rounded, color: Color(0xFFA3E635), size: 20),
                              ],
                            ),
                          ),
                        ),

                        // --- 1. Upload Custom Audio from Device ---
                        GestureDetector(
                          onTap: isUploading ? null : pickAndUploadCustomMusic,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFFD4AF37).withOpacity(0.18),
                                  const Color(0xFFD4AF37).withOpacity(0.06),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFD4AF37).withOpacity(0.5),
                                width: 1.2,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFD4AF37).withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: isUploading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Color(0xFFD4AF37),
                                          ),
                                        )
                                      : const Icon(
                                          Icons.file_upload_outlined,
                                          color: Color(0xFFD4AF37),
                                          size: 22,
                                        ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isUploading
                                            ? (uploadStatusText ?? 'Uploading track...')
                                            : 'Upload Any Music from Phone',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        isUploading
                                            ? 'Saving to cloud & synchronizing...'
                                            : 'Select MP3, M4A, WAV, AAC from your device',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.6),
                                          fontSize: 11.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: Color(0xFFD4AF37),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // --- 2. Ambient Soundscapes ---
                        Text(
                          'SANCTUARY AMBIENT SOUNDSCAPES',
                          style: TextStyle(
                            color: const Color(0xFFD4AF37).withOpacity(0.8),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 8),

                        ...soundscapes.map((sc) {
                          final isSelected = currentSong == sc['key'];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFFD4AF37).withOpacity(0.12) : const Color(0xFF1E1A29),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected ? const Color(0xFFD4AF37) : Colors.white10,
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: ListTile(
                              onTap: () => selectTrack(sc['key'] as String),
                              dense: true,
                              leading: Icon(
                                sc['icon'] as IconData,
                                color: isSelected ? const Color(0xFFD4AF37) : Colors.white70,
                                size: 22,
                              ),
                              title: Text(
                                sc['name'] as String,
                                style: TextStyle(
                                  color: isSelected ? const Color(0xFFD4AF37) : Colors.white,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  fontSize: 13.5,
                                ),
                              ),
                              subtitle: Text(
                                sc['desc'] as String,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 11.5,
                                ),
                              ),
                              trailing: isSelected
                                  ? const Icon(Icons.check_circle_rounded, color: Color(0xFFD4AF37), size: 20)
                                  : null,
                            ),
                          );
                        }),

                        const SizedBox(height: 16),

                        // --- 3. Couple Playlist Songs ---
                        if (audioProvider.songs.isNotEmpty) ...[
                          Text(
                            "COUPLE'S PLAYLIST SONGS",
                            style: TextStyle(
                              color: const Color(0xFFD4AF37).withOpacity(0.8),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 8),

                          ...audioProvider.songs.map((song) {
                            final isSelected = currentSong == song.audioUrl;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFFD4AF37).withOpacity(0.12) : const Color(0xFF1E1A29),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected ? const Color(0xFFD4AF37) : Colors.white10,
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: ListTile(
                                onTap: () => selectTrack(song.audioUrl),
                                dense: true,
                                leading: const Icon(
                                  Icons.music_note_rounded,
                                  color: Colors.white70,
                                  size: 20,
                                ),
                                title: Text(
                                  song.title,
                                  style: TextStyle(
                                    color: isSelected ? const Color(0xFFD4AF37) : Colors.white,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    fontSize: 13.5,
                                  ),
                                ),
                                subtitle: Text(
                                  song.artist,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.5),
                                    fontSize: 11.5,
                                  ),
                                ),
                                trailing: isSelected
                                    ? const Icon(Icons.check_circle_rounded, color: Color(0xFFD4AF37), size: 20)
                                    : null,
                              ),
                            );
                          }),
                          const SizedBox(height: 16),
                        ],

                        // --- 4. Turn Off Music ---
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: currentSong == 'none' || currentSong == null || currentSong.isEmpty
                                ? const Color(0xFFE57373).withOpacity(0.12)
                                : const Color(0xFF1E1A29),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: currentSong == 'none' || currentSong == null || currentSong.isEmpty
                                  ? const Color(0xFFE57373)
                                  : Colors.white10,
                              width: 1,
                            ),
                          ),
                          child: ListTile(
                            onTap: () => selectTrack('none'),
                            dense: true,
                            leading: const Icon(
                              Icons.volume_off_rounded,
                              color: Color(0xFFE57373),
                              size: 20,
                            ),
                            title: const Text(
                              'Turn Off Soundtrack (Silent Vault)',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                                fontSize: 13.5,
                              ),
                            ),
                            subtitle: Text(
                              'Quiet reading without background music',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 11.5,
                              ),
                            ),
                            trailing: (currentSong == 'none' || currentSong == null || currentSong.isEmpty)
                                ? const Icon(Icons.check_circle_rounded, color: Color(0xFFE57373), size: 20)
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBackgroundMusicBanner(VaultProvider vp) {
    final track = _vault.backgroundSong;
    final hasMusic = track != null && track.isNotEmpty && track != 'none';
    final trackName = VaultProvider.getTrackDisplayName(track);
    final isPlaying = vp.isAudioPlaying && !_isMusicMuted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF16141F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasMusic ? const Color(0xFFD4AF37).withOpacity(0.3) : Colors.white10,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: hasMusic
                  ? const Color(0xFFD4AF37).withOpacity(0.15)
                  : Colors.white.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              hasMusic
                  ? (isPlaying ? Icons.music_note_rounded : Icons.pause_rounded)
                  : Icons.music_off_outlined,
              color: hasMusic ? const Color(0xFFD4AF37) : Colors.white38,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BACKGROUND SOUNDTRACK',
                  style: TextStyle(
                    color: const Color(0xFFD4AF37).withOpacity(0.8),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  trackName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (hasMusic) ...[
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
              icon: Icon(
                _isMusicMuted || !vp.isAudioPlaying ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                color: const Color(0xFFD4AF37),
                size: 20,
              ),
              tooltip: _isMusicMuted ? 'Unmute' : 'Mute',
              onPressed: _toggleMuteMusic,
            ),
            const SizedBox(width: 4),
          ],
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4AF37).withOpacity(0.18),
              foregroundColor: const Color(0xFFD4AF37),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: const Size(0, 32),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: const Color(0xFFD4AF37).withOpacity(0.4)),
              ),
            ),
            onPressed: () => _showMusicCustomizationSheet(context),
            child: const Text(
              'Change',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteVault() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16141F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Vault?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to permanently delete "${_vault.title}"? This cannot be undone.',
          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13.5, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE57373),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<VaultProvider>().stopVaultMusic();
      await context.read<VaultProvider>().deleteVault(_vault.id, widget.spaceId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${_vault.title}" deleted.'),
            backgroundColor: const Color(0xFF1F1B2C),
          ),
        );
        Navigator.pop(context, 'deleted');
      }
    }
  }

  void _navigateToEdit() async {
    final updated = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(
        builder: (_) => NewVaultScreen(
          initialVault: _vault,
          spaceId: widget.spaceId,
          currentUserId: widget.currentUserId,
          userNickname: widget.userNickname,
          partnerNickname: widget.partnerNickname,
        ),
      ),
    );

    if (updated == 'deleted') {
      if (mounted) {
        await context.read<VaultProvider>().stopVaultMusic();
        Navigator.pop(context);
      }
    } else if (updated is VaultItem) {
      setState(() => _vault = updated);
      if (mounted) {
        context.read<VaultProvider>().startVaultMusic(_vault.backgroundSong);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vp = context.watch<VaultProvider>();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _handleBack();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0B12),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0D0B12),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            onPressed: _handleBack,
          ),
          actions: [
            // Background Music Quick Action: Mute / Play toggle
            IconButton(
              icon: Icon(
                (_vault.backgroundSong == null || _vault.backgroundSong == 'none' || _isMusicMuted || !vp.isAudioPlaying)
                    ? Icons.volume_off_rounded
                    : Icons.volume_up_rounded,
                color: const Color(0xFFD4AF37),
                size: 22,
              ),
              tooltip: _isMusicMuted || !vp.isAudioPlaying ? 'Play soundtrack' : 'Mute soundtrack',
              onPressed: _toggleMuteMusic,
            ),

            // Edit button (available for both partners)
            TextButton.icon(
              onPressed: _navigateToEdit,
              icon: const Icon(Icons.edit_outlined, color: Color(0xFFD4AF37), size: 16),
              label: const Text(
                'Edit',
                style: TextStyle(
                  color: Color(0xFFD4AF37),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),

            // Delete button
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFE57373), size: 20),
              tooltip: 'Delete vault',
              onPressed: _confirmDeleteVault,
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Hero Card (Matching Image 3)
              _buildHeroCard(),
              const SizedBox(height: 20),

              // 2. The Letter Section
              if (_vault.letter.isNotEmpty) ...[
                _buildSectionHeader('THE LETTER'),
                const SizedBox(height: 10),
                _buildLetterCard(),
                const SizedBox(height: 26),
              ],

              // 3. Dedicated Video Memory (when cover photo is on Hero Card)
              if (_vault.videoUrl != null && _vault.videoUrl!.isNotEmpty && (_vault.coverImageUrl != null && _vault.coverImageUrl!.isNotEmpty)) ...[
                _buildSectionHeader('VIDEO MEMORY 🎬'),
                const SizedBox(height: 10),
                _buildVideoMemoryCard(),
                const SizedBox(height: 26),
              ],

              // 4. Photos Horizontal Carousel (Polaroid Style)
              if (_vault.photoUrls.isNotEmpty) ...[
                _buildSectionHeader('PHOTOS (${_vault.photoUrls.length})'),
                const SizedBox(height: 10),
                _buildPhotoCarousel(),
                const SizedBox(height: 26),
              ],

              // 5. Voice Note Player
              if (_vault.voiceNoteUrl != null && _vault.voiceNoteUrl!.isNotEmpty) ...[
                _buildSectionHeader('VOICE MEMO'),
                const SizedBox(height: 10),
                _buildVoiceNoteCard(),
                const SizedBox(height: 26),
              ],

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        color: Colors.white.withOpacity(0.5),
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildHeroCard() {
    String subtitle = DateFormat('MMMM d, yyyy').format(_vault.createdAt);
    if (_vault.accessMode == 'timer' && _vault.specialDate != null) {
      final days = _vault.daysRemaining;
      subtitle = '${DateFormat("MMMM d, yyyy").format(_vault.specialDate!)} · ${days > 0 ? "$days days to go" : "Opened"}';
    }

    final hasCover = _vault.coverImageUrl != null && _vault.coverImageUrl!.isNotEmpty;

    if (hasCover) {
      return GestureDetector(
        onTap: () => _openFullScreenPhotos(context, [_vault.coverImageUrl!], 0),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Color(_vault.colorValue),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFFD4AF37).withOpacity(0.4),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Color(_vault.colorValue).withOpacity(0.4),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // Portrait-Friendly Aspect Ratio so top & bottom are NOT sliced off!
              AspectRatio(
                aspectRatio: 1.08,
                child: CachedNetworkImage(
                  imageUrl: _vault.coverImageUrl!,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  placeholder: (_, __) => Container(
                    color: Color(_vault.colorValue),
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFFD4AF37)),
                    ),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    color: Color(_vault.colorValue),
                    child: Center(
                      child: VaultEmblem(shape: _vault.emblemShape, size: 70),
                    ),
                  ),
                ),
              ),

              // Soft Vignette Scrim at Bottom
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 110,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.65),
                        Colors.black.withOpacity(0.92),
                      ],
                    ),
                  ),
                ),
              ),

              // Titles & Metadata with clean shadow
              Positioned(
                left: 18,
                right: 18,
                bottom: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _vault.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.2,
                        shadows: [
                          Shadow(color: Colors.black87, blurRadius: 6, offset: Offset(0, 2)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            shadows: const [
                              Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 1)),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.45),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white24, width: 0.8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.zoom_in_rounded, size: 12, color: Color(0xFFD4AF37)),
                              SizedBox(width: 4),
                              Text('Tap to zoom', style: TextStyle(color: Colors.white70, fontSize: 10)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Color(_vault.colorValue),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFD4AF37).withOpacity(0.4),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Color(_vault.colorValue).withOpacity(0.4),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Visual Area: Video player thumbnail OR Cover Image OR Emblem
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(23)),
            child: AspectRatio(
              aspectRatio: 16 / 10,
              child: _buildHeroVisual(),
            ),
          ),

          // Titles & Metadata
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _vault.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroVisual() {
    // 1. If cover image is present, display it cleanly in all its glory (NEVER overlay video play icon!)
    if (_vault.coverImageUrl != null && _vault.coverImageUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: _vault.coverImageUrl!,
        memCacheWidth: 800,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          color: Color(_vault.colorValue),
          child: const Center(
            child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFFD4AF37)),
          ),
        ),
        errorWidget: (_, __, ___) => Container(
          color: Color(_vault.colorValue),
          child: Center(
            child: VaultEmblem(shape: _vault.emblemShape, size: 70),
          ),
        ),
      );
    }

    // 2. If NO cover image is present, but video is present, display video player preview
    if (_vault.videoUrl != null && _vault.videoUrl!.isNotEmpty) {
      String videoThumb = '';
      if (_vault.videoUrl!.contains('cloudinary.com') || _vault.videoUrl!.contains('/video/upload/')) {
        videoThumb = _vault.videoUrl!.replaceAll(RegExp(r'\.(mp4|mov|avi|wmv|webm|mkv)$', caseSensitive: false), '.jpg');
        if (videoThumb.contains('/video/upload/')) {
          videoThumb = videoThumb.replaceAll('/video/upload/', '/video/upload/so_1,f_auto,q_auto/');
        }
      }

      return Stack(
        fit: StackFit.expand,
        children: [
          videoThumb.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: videoThumb,
                  memCacheWidth: 800,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: Colors.black54),
                  errorWidget: (_, __, ___) => Container(color: Colors.black54),
                )
              : Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF221626), Color(0xFF16101B)],
                    ),
                  ),
                ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.15),
                  Colors.black.withOpacity(0.4),
                ],
              ),
            ),
          ),
          Center(
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FullScreenVideoPlayer(
                      videoUrl: _vault.videoUrl!,
                      title: _vault.title,
                    ),
                  ),
                );
              },
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withOpacity(0.55),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.45),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.45),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
                ),
              ),
            ),
          ),
        ],
      );
    }

    // 3. Default: Center Emblem with golden ambiance
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 0.8,
          colors: [
            Colors.white.withOpacity(0.08),
            Colors.transparent,
          ],
        ),
      ),
      child: Center(
        child: VaultEmblem(shape: _vault.emblemShape, size: 90),
      ),
    );
  }

  Widget _buildVideoMemoryCard() {
    String videoThumb = '';
    if (_vault.videoUrl!.contains('cloudinary.com') || _vault.videoUrl!.contains('/video/upload/')) {
      videoThumb = _vault.videoUrl!.replaceAll(RegExp(r'\.(mp4|mov|avi|wmv|webm|mkv)$', caseSensitive: false), '.jpg');
      if (videoThumb.contains('/video/upload/')) {
        videoThumb = videoThumb.replaceAll('/video/upload/', '/video/upload/so_1,f_auto,q_auto/');
      }
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FullScreenVideoPlayer(
              videoUrl: _vault.videoUrl!,
              title: _vault.title,
            ),
          ),
        );
      },
      child: Container(
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFD4AF37).withOpacity(0.35),
            width: 1.1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (videoThumb.isNotEmpty)
              CachedNetworkImage(
                imageUrl: videoThumb,
                memCacheWidth: 600,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: const Color(0xFF161420)),
                errorWidget: (_, __, ___) => Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF221626), Color(0xFF14101A)],
                    ),
                  ),
                ),
              )
            else
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF221626), Color(0xFF14101A)],
                  ),
                ),
              ),

            // Ambient dark vignette
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.2),
                    Colors.black.withOpacity(0.6),
                  ],
                ),
              ),
            ),

            // Center Play Button
            Center(
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withOpacity(0.6),
                  border: Border.all(
                    color: const Color(0xFFD4AF37).withOpacity(0.8),
                    width: 1.4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Color(0xFFD4AF37),
                  size: 30,
                ),
              ),
            ),

            // Bottom pill
            Positioned(
              left: 14,
              bottom: 12,
              child: Row(
                children: [
                  const Icon(Icons.videocam_rounded, color: Colors.white70, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    'Tap to play video',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
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

  Widget _buildLetterCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF16141F),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.format_quote_rounded, color: Color(0xFFD4AF37), size: 28),
          const SizedBox(height: 8),
          Text(
            _vault.letter,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              height: 1.6,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '— Written by ${_vault.creatorName}, ${DateFormat("MMMM yyyy").format(_vault.createdAt)}',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openFullScreenPhotos(BuildContext context, List<String> urls, int initialIndex) {
    if (urls.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullScreenPhotoGallery(
          urls: urls,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  Widget _buildPhotoCarousel() {
    return Column(
      children: [
        SizedBox(
          height: 380, // Portrait-friendly height so heads & dresses are never cut off
          child: PageView.builder(
            controller: _photoPageController,
            itemCount: _vault.photoUrls.length,
            onPageChanged: (idx) => setState(() => _currentPhotoIndex = idx),
            itemBuilder: (context, index) {
              final photoUrl = _vault.photoUrls[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: GestureDetector(
                  onTap: () => _openFullScreenPhotos(context, _vault.photoUrls, index),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF16141F),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(19),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CachedNetworkImage(
                            imageUrl: photoUrl,
                            fit: BoxFit.cover,
                            alignment: Alignment.topCenter,
                            placeholder: (_, __) => const Center(
                              child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
                            ),
                            errorWidget: (_, __, ___) => const Center(
                              child: Icon(Icons.broken_image_rounded, color: Colors.white24, size: 40),
                            ),
                          ),
                          // Subtle tap-to-zoom indicator badge
                          Positioned(
                            bottom: 12,
                            right: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.55),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.white24, width: 0.8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.zoom_in_rounded, size: 12, color: Color(0xFFD4AF37)),
                                  SizedBox(width: 4),
                                  Text('Tap to zoom', style: TextStyle(color: Colors.white, fontSize: 10)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (_vault.photoUrls.length > 1) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_vault.photoUrls.length, (idx) {
              final isCurrent = idx == _currentPhotoIndex;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: isCurrent ? 16 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isCurrent ? const Color(0xFFD4AF37) : Colors.white24,
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }

  Widget _buildVoiceNoteCard() {
    if (_vault.voiceNoteUrl == null || _vault.voiceNoteUrl!.isEmpty) {
      return const SizedBox.shrink();
    }
    return SanctuaryVoicePlayer(
      id: 'vault_' + _vault.id,
      audioUrl: _vault.voiceNoteUrl!,
      durationSeconds: _vault.voiceNoteDurationSeconds,
      isDark: true,
      customCardColor: const Color(0xFF16141F), // Matches Letter card perfectly
      customAccentColor: const Color(0xFFD4AF37), // Luxury champagne gold button & bars
      customBorderColor: const Color(0xFFD4AF37).withOpacity(0.35),
      ambientAudio: context.read<AudioProvider>(),
      onPlayStarted: () {
        context.read<VaultProvider>().stopVaultMusic();
      },
      onPlaybackCompleted: () {
        if (!_isMusicMuted && mounted) {
          context.read<VaultProvider>().startVaultMusic(_vault.backgroundSong);
        }
      },
    );
  }
}

/// Fullscreen zoomable photo gallery with pinch-to-zoom and swipe
class _FullScreenPhotoGallery extends StatefulWidget {
  final List<String> urls;
  final int initialIndex;

  const _FullScreenPhotoGallery({
    required this.urls,
    this.initialIndex = 0,
  });

  @override
  State<_FullScreenPhotoGallery> createState() => _FullScreenPhotoGalleryState();
}

class _FullScreenPhotoGalleryState extends State<_FullScreenPhotoGallery> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: widget.urls.length,
              onPageChanged: (idx) => setState(() => _currentIndex = idx),
              itemBuilder: (context, index) {
                return Center(
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 4.0,
                    child: CachedNetworkImage(
                      imageUrl: widget.urls[index],
                      fit: BoxFit.contain,
                      placeholder: (_, __) => const Center(
                        child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
                      ),
                      errorWidget: (_, __, ___) => const Center(
                        child: Icon(Icons.broken_image_rounded, color: Colors.white24, size: 48),
                      ),
                    ),
                  ),
                );
              },
            ),

            // Top Bar: Back & Counter
            Positioned(
              top: 12,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                    ),
                  ),
                  if (widget.urls.length > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Text(
                        '${_currentIndex + 1} / ${widget.urls.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
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
}
