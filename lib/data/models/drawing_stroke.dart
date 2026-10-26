class StrokePoint {
  final double x;
  final double y;

  StrokePoint(this.x, this.y);

  Map<String, dynamic> toJson() => {'x': x, 'y': y};

  factory StrokePoint.fromJson(Map<String, dynamic> json) => StrokePoint(
        (json['x'] as num).toDouble(),
        (json['y'] as num).toDouble(),
      );
}

class DrawingStroke {
  final List<StrokePoint> points;
  final int colorValue;
  final double strokeWidth;
  final String tool; // 'pen', 'stardust', 'eraser'
  final bool isPartner;

  DrawingStroke({
    required this.points,
    required this.colorValue,
    this.strokeWidth = 3.0,
    this.tool = 'pen',
    this.isPartner = false,
  });

  Map<String, dynamic> toJson() => {
        'points': points.map((p) => p.toJson()).toList(),
        'color': colorValue,
        'width': strokeWidth,
        'tool': tool,
      };

  factory DrawingStroke.fromJson(Map<String, dynamic> json, {bool isPartner = false}) {
    final rawPoints = json['points'] as List? ?? [];
    return DrawingStroke(
      points: rawPoints
          .map((p) => StrokePoint.fromJson(Map<String, dynamic>.from(p as Map)))
          .toList(),
      colorValue: (json['color'] as num?)?.toInt() ?? 0xFFE2847A,
      strokeWidth: (json['width'] as num?)?.toDouble() ?? 3.0,
      tool: json['tool']?.toString() ?? 'pen',
      isPartner: isPartner,
    );
  }
}
