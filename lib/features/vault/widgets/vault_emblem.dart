import 'package:flutter/material.dart';

class VaultEmblem extends StatelessWidget {
  final String shape;
  final double size;
  final Color color;

  const VaultEmblem({
    super.key,
    required this.shape,
    this.size = 48,
    this.color = const Color(0xFFFFECC7),
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _VaultEmblemPainter(shape: shape, color: color),
      ),
    );
  }
}

class _VaultEmblemPainter extends CustomPainter {
  final String shape;
  final Color color;

  _VaultEmblemPainter({required this.shape, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final w = size.width;
    final h = size.height;

    switch (shape) {
      case 'arch':
        // Elegant Portal Arch
        final path = Path()
          ..moveTo(w * 0.2, h * 0.9)
          ..lineTo(w * 0.2, h * 0.45)
          ..arcToPoint(
            Offset(w * 0.8, h * 0.45),
            radius: Radius.circular(w * 0.3),
            clockwise: true,
          )
          ..lineTo(w * 0.8, h * 0.9)
          ..close();
        canvas.drawPath(path, strokePaint);
        break;

      case 'diamond':
        // Geometric Diamond
        final path = Path()
          ..moveTo(center.dx, h * 0.12)
          ..lineTo(w * 0.88, center.dy)
          ..lineTo(center.dx, h * 0.88)
          ..lineTo(w * 0.12, center.dy)
          ..close();
        canvas.drawPath(path, strokePaint);
        break;

      case 'square':
        // Minimal Square with center dot
        final rect = RRect.fromRectAndRadius(
          Rect.fromCenter(center: center, width: w * 0.75, height: h * 0.75),
          const Radius.circular(6),
        );
        canvas.drawRRect(rect, strokePaint);
        canvas.drawCircle(center, w * 0.12, fillPaint);
        break;

      case 'circle':
      default:
        // Concentric Vinyl / Celestial Ring
        canvas.drawCircle(center, w * 0.42, strokePaint);
        canvas.drawCircle(center, w * 0.16, fillPaint);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _VaultEmblemPainter oldDelegate) {
    return oldDelegate.shape != shape || oldDelegate.color != color;
  }
}
