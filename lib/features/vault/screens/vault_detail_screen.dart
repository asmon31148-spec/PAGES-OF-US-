import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:audioplayers/audioplayers.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/full_screen_video_player.dart';
import '../../../data/models/vault_item.dart';
import '../../../providers/vault_provider.dart';
import '../widgets/vault_emblem.dart';
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

  // Voice note player
  final AudioPlayer _voicePlayer = AudioPlayer();
  bool _isVoicePlaying = false;
  Duration _voicePosition = Duration.zero;
  Duration _voiceDuration = Duration.zero;
  StreamSubscription? _posSub;
  StreamSubscription? _durSub;
  StreamSubscription? _stateSub;

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

    _initVoicePlayer();
  }

  void _initVoicePlayer() {
    if (_vault.voiceNoteUrl == null || _vault.voiceNoteUrl!.isEmpty) return;

    _posSub = _voicePlayer.onPositionChanged.listen((pos) {
      if (mounted) setState(() => _voicePosition = pos);
    });

    _durSub = _voicePlayer.onDurationChanged.listen((dur) {
      if (mounted) setState(() => _voiceDuration = dur);
    });

    _stateSub = _voicePlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() => _isVoicePlaying = state == PlayerState.playing);
        // If voice memo completed, resume background music
        if (state == PlayerState.completed) {
          context.read<VaultProvider>().startVaultMusic(_vault.backgroundSong);
        }
      }
    });
  }

  @override
  void dispose() {
    _photoPageController.dispose();
    _posSub?.cancel();
    _durSub?.cancel();
    _stateSub?.cancel();
    _voicePlayer.dispose();

    // Background music is stopped when exiting this screen
    // (Handled also in onWillPop / back arrow)
    super.dispose();
  }

  Future<void> _handleBack() async {
    await context.read<VaultProvider>().stopVaultMusic();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _toggleVoicePlay() async {
    if (_vault.voiceNoteUrl == null) return;

    if (_isVoicePlaying) {
      await _voicePlayer.pause();
      // Resume background music
      if (!_isMusicMuted && mounted) {
        context.read<VaultProvider>().startVaultMusic(_vault.backgroundSong);
      }
    } else {
      // Lower or pause background music so voice memo is crystal clear
      await context.read<VaultProvider>().stopVaultMusic();
      await _voicePlayer.play(UrlSource(_vault.voiceNoteUrl!));
    }
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
            // Background Music Indicator & Mute toggle
            if (_vault.backgroundSong != null && _vault.backgroundSong != 'none')
              IconButton(
                icon: Icon(
                  _isMusicMuted || !vp.isAudioPlaying ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  color: const Color(0xFFD4AF37),
                  size: 20,
                ),
                tooltip: _isMusicMuted ? 'Play background music' : 'Mute music',
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
              const SizedBox(height: 24),

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

  Widget _buildPhotoCarousel() {
    return Column(
      children: [
        SizedBox(
          height: 240,
          child: PageView.builder(
            controller: _photoPageController,
            itemCount: _vault.photoUrls.length,
            onPageChanged: (idx) => setState(() => _currentPhotoIndex = idx),
            itemBuilder: (context, index) {
              final photoUrl = _vault.photoUrls[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF16141F),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: CachedNetworkImage(
                      imageUrl: photoUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => const Center(
                        child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
                      ),
                      errorWidget: (_, __, ___) => const Center(
                        child: Icon(Icons.broken_image_rounded, color: Colors.white24, size: 40),
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
    final posStr = '${_voicePosition.inMinutes}:${(_voicePosition.inSeconds % 60).toString().padLeft(2, '0')}';
    final durSec = _voiceDuration.inSeconds > 0
        ? _voiceDuration.inSeconds
        : (_vault.voiceNoteDurationSeconds ?? 30);
    final durStr = '${durSec ~/ 60}:${(durSec % 60).toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF16141F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _toggleVoicePlay,
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Color(0xFFD4AF37),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isVoicePlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.black,
                size: 26,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _isVoicePlaying ? 'Playing voice note...' : 'Voice note from ${_vault.creatorName}',
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      _isVoicePlaying ? posStr : durStr,
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: _voiceDuration.inMilliseconds > 0
                      ? (_voicePosition.inMilliseconds / _voiceDuration.inMilliseconds).clamp(0.0, 1.0)
                      : 0.0,
                  backgroundColor: Colors.white12,
                  color: const Color(0xFFD4AF37),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
