import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';

class ScratchCardReveal extends StatefulWidget {
  final String secretMessage;
  final VoidCallback? onRevealed;

  const ScratchCardReveal({
    super.key,
    required this.secretMessage,
    this.onRevealed,
  });

  @override
  State<ScratchCardReveal> createState() => _ScratchCardRevealState();
}

class _ScratchCardRevealState extends State<ScratchCardReveal> {
  final List<Offset> _points = [];
  bool _isFullyRevealed = false;
  int _scratchCount = 0;

  void _addPoint(Offset point) {
    if (_isFullyRevealed) return;
    setState(() {
      _points.add(point);
      _scratchCount++;
    });

    if (_scratchCount % 8 == 0) {
      HapticFeedback.lightImpact();
    }

    if (_scratchCount > 45 && !_isFullyRevealed) {
      setState(() {
        _isFullyRevealed = true;
      });
      HapticFeedback.mediumImpact();
      widget.onRevealed?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 140),
      decoration: BoxDecoration(
        color: AppColors.romanceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.romanceRoseGold.withOpacity(0.4), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppColors.romanceWine.withOpacity(0.25),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Secret Revealed Content Underneath
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.card_giftcard_rounded, color: AppColors.romanceRoseGold, size: 18),
                      SizedBox(width: 6),
                      Text(
                        'SECRET EVENT PROMISE',
                        style: TextStyle(
                          color: AppColors.romanceRoseGold,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.secretMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.romanceInk,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Forever & Always ✦',
                    style: TextStyle(
                      color: AppColors.romanceSoft,
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),

            // Golden Scratch Foil Layer (Draws over secret message until scratched)
            if (!_isFullyRevealed)
              Positioned.fill(
                child: GestureDetector(
                  onPanStart: (details) => _addPoint(details.localPosition),
                  onPanUpdate: (details) => _addPoint(details.localPosition),
                  child: CustomPaint(
                    painter: _ScratchFoilPainter(points: _points),
                  ),
                ),
              ),

            // Hint to Scratch if not started
            if (!_isFullyRevealed && _points.length < 5)
              IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.65),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.romanceGold.withOpacity(0.6)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.touch_app_rounded, color: AppColors.romanceGold, size: 14),
                      SizedBox(width: 6),
                      Text(
                        'Scratch with finger to reveal ✨',
                        style: TextStyle(
                          color: AppColors.romanceGold,
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ScratchFoilPainter extends CustomPainter {
  final List<Offset> points;

  _ScratchFoilPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());

    // 1. Draw Golden Metallic Foil
    final foilPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFE5A93B),
          Color(0xFF9E651D),
          Color(0xFFF7D279),
          Color(0xFF884D11),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), foilPaint);

    // Decorative Foil Pattern
    final patternPaint = Paint()
      ..color = Colors.white.withOpacity(0.12)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    for (double i = -size.height; i < size.width; i += 24) {
      canvas.drawLine(Offset(i, 0), Offset(i + size.height, size.height), patternPaint);
    }

    // 2. Erase where finger scratched
    final clearPaint = Paint()
      ..blendMode = BlendMode.clear
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 36.0;

    for (final point in points) {
      canvas.drawCircle(point, 22.0, clearPaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ScratchFoilPainter oldDelegate) => true;
}
