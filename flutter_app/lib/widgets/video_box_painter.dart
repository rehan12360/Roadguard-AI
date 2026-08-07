import 'package:flutter/material.dart';

class DetectionBox {
  final double x1;
  final double y1;
  final double x2;
  final double y2;
  final String label;
  final double confidence;
  final String lane;

  DetectionBox({
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    required this.label,
    required this.confidence,
    this.lane = "center",
  });
}

class VideoBoxPainter extends CustomPainter {
  final List<DetectionBox> boxes;
  final bool showLaneOverlay;

  VideoBoxPainter({required this.boxes, this.showLaneOverlay = true});

  @override
  void paint(Canvas canvas, Size size) {
    if (showLaneOverlay) {
      _drawLaneGuides(canvas, size);
    }

    final boxPaint = Paint()
      ..color = const Color(0xFFFF2A5F) // Neon Cyber Red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;

    final glowPaint = Paint()
      ..color = const Color(0xFFFF2A5F).withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0;

    final bgPaint = Paint()
      ..color = const Color(0xFF0D1117).withOpacity(0.85)
      ..style = PaintingStyle.fill;

    for (final box in boxes) {
      final rect = Rect.fromLTRB(
        box.x1 * size.width,
        box.y1 * size.height,
        box.x2 * size.width,
        box.y2 * size.height,
      );

      // Draw Glow & Bounding Box
      canvas.drawRect(rect, glowPaint);
      canvas.drawRect(rect, boxPaint);

      // Corner accent brackets
      _drawCornerBrackets(canvas, rect);

      // Label Badge
      final textSpan = TextSpan(
        children: [
          TextSpan(
            text: '🚨 ${box.label.toUpperCase()} ',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          TextSpan(
            text: '${(box.confidence * 100).round()}% | Lane: ${box.lane.toUpperCase()}',
            style: const TextStyle(
              color: Color(0xFF00F2FE),
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      );

      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      final labelRect = Rect.fromLTWH(
        rect.left,
        rect.top - 28 < 0 ? rect.top : rect.top - 28,
        textPainter.width + 16,
        24,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(labelRect, const Radius.circular(6)),
        bgPaint,
      );

      textPainter.paint(
        canvas,
        Offset(labelRect.left + 8, labelRect.top + 3),
      );
    }
  }

  void _drawCornerBrackets(Canvas canvas, Rect rect) {
    final bracketPaint = Paint()
      ..color = const Color(0xFF00F2FE)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;

    const len = 12.0;

    // Top-Left
    canvas.drawLine(rect.topLeft, rect.topLeft + const Offset(len, 0), bracketPaint);
    canvas.drawLine(rect.topLeft, rect.topLeft + const Offset(0, len), bracketPaint);

    // Top-Right
    canvas.drawLine(rect.topRight, rect.topRight - const Offset(len, 0), bracketPaint);
    canvas.drawLine(rect.topRight, rect.topRight + const Offset(0, len), bracketPaint);

    // Bottom-Left
    canvas.drawLine(rect.bottomLeft, rect.bottomLeft + const Offset(len, 0), bracketPaint);
    canvas.drawLine(rect.bottomLeft, rect.bottomLeft - const Offset(0, len), bracketPaint);

    // Bottom-Right
    canvas.drawLine(rect.bottomRight, rect.bottomRight - const Offset(len, 0), bracketPaint);
    canvas.drawLine(rect.bottomRight, rect.bottomRight - const Offset(0, len), bracketPaint);
  }

  void _drawLaneGuides(Canvas canvas, Size size) {
    final lanePaint = Paint()
      ..color = const Color(0xFF00F2FE).withOpacity(0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Left Lane Guide
    final p1 = Offset(size.width * 0.25, size.height);
    final p2 = Offset(size.width * 0.42, size.height * 0.55);
    canvas.drawLine(p1, p2, lanePaint);

    // Right Lane Guide
    final p3 = Offset(size.width * 0.75, size.height);
    final p4 = Offset(size.width * 0.58, size.height * 0.55);
    canvas.drawLine(p3, p4, lanePaint);
  }

  @override
  bool shouldRepaint(covariant VideoBoxPainter oldDelegate) => true;
}
