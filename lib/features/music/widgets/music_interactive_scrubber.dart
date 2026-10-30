import 'package:flutter/material.dart';

class MusicInteractiveScrubber extends StatefulWidget {
  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;
  final Color activeColor;
  final Color inactiveColor;

  const MusicInteractiveScrubber({
    super.key,
    required this.position,
    required this.duration,
    required this.onSeek,
    this.activeColor = const Color(0xFFA3E635), // Echo Music signature lime
    this.inactiveColor = const Color(0xFF1E2F23),
  });

  @override
  State<MusicInteractiveScrubber> createState() => _MusicInteractiveScrubberState();
}

class _MusicInteractiveScrubberState extends State<MusicInteractiveScrubber> {
  bool _isDragging = false;
  double _dragPositionMs = 0.0;

  String _formatDuration(Duration d) {
    if (d < Duration.zero) d = Duration.zero;
    final m = d.inMinutes.remainder(60).toString();
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final durMs = widget.duration.inMilliseconds > 0
        ? widget.duration.inMilliseconds.toDouble()
        : 0.0;
    final maxMs = durMs > 0 ? durMs : 1.0;

    final currentMs = (_isDragging ? _dragPositionMs : widget.position.inMilliseconds.toDouble())
        .clamp(0.0, maxMs);

    final displayPos = _isDragging
        ? Duration(milliseconds: currentMs.toInt())
        : widget.position;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            activeTrackColor: widget.activeColor,
            inactiveTrackColor: widget.inactiveColor,
            thumbColor: widget.activeColor,
            overlayColor: widget.activeColor.withOpacity(0.18),
            thumbShape: RoundSliderThumbShape(
              enabledThumbRadius: _isDragging ? 7.5 : 5.5,
              elevation: 3,
            ),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          ),
          child: Slider(
            value: durMs > 0 ? currentMs : 0.0,
            min: 0.0,
            max: maxMs,
            onChangeStart: (val) {
              setState(() {
                _isDragging = true;
                _dragPositionMs = val.clamp(0.0, maxMs);
              });
            },
            onChanged: (val) {
              setState(() {
                _dragPositionMs = val.clamp(0.0, maxMs);
              });
            },
            onChangeEnd: (val) {
              final clampedVal = val.clamp(0.0, maxMs);
              final target = Duration(milliseconds: clampedVal.toInt());
              widget.onSeek(target);
              setState(() {
                _isDragging = false;
                _dragPositionMs = clampedVal;
              });
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(displayPos),
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF94A3B8),
                  letterSpacing: 0.4,
                ),
              ),
              Text(
                durMs > 0 ? _formatDuration(widget.duration) : '--:--',
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF94A3B8),
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
