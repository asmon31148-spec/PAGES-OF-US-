import 'dart:ui';
import 'package:flutter/material.dart';

/// CustomPainter that draws a cubic bezier arc with a dashed trail and
/// a paper plane icon animated along the path at [progress] (0.0 → 1.0).
class PaperPlanePainter extends CustomPainter {
  final double progress;
  final Color lineColor;
  final Color planeColor;
  final double planeSize;
  final bool isStationary;

  const PaperPlanePainter({
    required this.progress,
    required this.lineColor,
    required this.planeColor,
    this.planeSize = 18,
    this.isStationary = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final start = Offset(24, size.height - 12);
    final end = Offset(size.width - 24, size.height - 12);
    final cp1 = Offset(size.width * 0.2, size.height * 0.08);
    final cp2 = Offset(size.width * 0.8, size.height * 0.08);

    final fullPath = Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, end.dx, end.dy);

    final metric = fullPath.computeMetrics().first;
    final clampedProgress = isStationary ? 1.0 : progress.clamp(0.0, 1.0);
    final travelledDist = isStationary ? metric.length : metric.length * clampedProgress;

    // ── Dashed trail up to current progress ──────────────────────────────────
    _drawDashed(canvas, metric, travelledDist, lineColor.withOpacity(isStationary ? 0.35 : 0.85));

    // ── Ghost tail (remaining path) ───────────────────────────────────────────
    if (!isStationary && clampedProgress < 0.99) {
      _drawDashed(canvas, metric, metric.length, lineColor.withOpacity(0.12),
          start: travelledDist);
    }

    // ── Start marker ──────────────────────────────────────────────────────────
    canvas.drawCircle(
      start,
      4.5,
      Paint()..color = lineColor.withOpacity(0.55),
    );

    // ── Destination pulse ring (destination dot) ───────────────────────────────
    canvas.drawCircle(end, 4.5, Paint()..color = lineColor);
    canvas.drawCircle(
      end,
      9,
      Paint()
        ..color = lineColor.withOpacity(0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // ── Plane position ─────────────────────────────────────────────────────────
    if (travelledDist <= 0) return;
    final tangent = metric.getTangentForOffset(travelledDist);
    if (tangent == null) return;
    var pos = tangent.position;

    if (isStationary) {
      // Gentle floating breathing motion when resting
      final floatOffset = 3.0 * (0.5 - (0.5 - progress).abs());
      pos = Offset(pos.dx, pos.dy - floatOffset);
    }

    // Soft glow under the plane
    canvas.drawCircle(
      pos,
      14,
      Paint()
        ..color = planeColor.withOpacity(0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // Draw the ✈ character rotated to follow the bezier tangent
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(-tangent.angle);
    final tp = TextPainter(
      text: TextSpan(
        text: isStationary ? '🏡' : '✈',
        style: TextStyle(
          fontSize: planeSize,
          color: planeColor,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }

  void _drawDashed(
    Canvas canvas,
    PathMetric metric,
    double toDistance,
    Color color, {
    double start = 0.0,
  }) {
    const double dash = 7.0;
    const double gap = 4.0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    double d = start;
    while (d < toDistance) {
      final segEnd = (d + dash).clamp(0.0, toDistance);
      canvas.drawPath(metric.extractPath(d, segEnd), paint);
      d += dash + gap;
    }
  }

  @override
  bool shouldRepaint(PaperPlanePainter old) =>
      old.progress != progress ||
      old.lineColor != lineColor ||
      old.planeColor != planeColor;
}
