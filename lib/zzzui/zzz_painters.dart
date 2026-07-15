import 'dart:math' as math;

import 'package:flutter/material.dart';

class ChessboardPainter extends CustomPainter {
  const ChessboardPainter({
    this.squareColor = Colors.white,
    this.alpha = 0.06,
    this.cellSize = 6.0,
  });

  final Color squareColor;
  final double alpha;
  final double cellSize;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final paint = Paint()
      ..color = squareColor.withValues(alpha: alpha)
      ..style = PaintingStyle.fill;

    final rows = (size.height / cellSize).ceil() + 1;
    final cols = (size.width / cellSize).ceil() + 1;

    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if ((r + c).isEven) continue;
        final x = c * cellSize;
        final y = r * cellSize;
        canvas.drawRect(Rect.fromLTWH(x, y, cellSize, cellSize), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class LinearPatternPainter extends CustomPainter {
  const LinearPatternPainter({
    this.lineColor = Colors.white,
    this.alpha = 0.07,
    this.step = 10.0,
    this.angle = 40.0,
  });

  final Color lineColor;
  final double alpha;
  final double step;
  final double angle;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final paint = Paint()
      ..color = lineColor.withValues(alpha: alpha)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke;

    final rad = angle * math.pi / 180;
    final cos = math.cos(rad);
    final sin = math.sin(rad);
    final diagonal = size.width + size.height;

    for (double d = -diagonal; d < diagonal; d += step) {
      final x0 = d * cos;
      final y0 = d * sin;
      final x1 = x0 - diagonal * sin;
      final y1 = y0 + diagonal * cos;
      canvas.drawLine(Offset(x0, y0), Offset(x1, y1), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class GridPatternPainter extends CustomPainter {
  const GridPatternPainter({
    this.lineColor = Colors.black,
    this.alpha = 0.2,
    this.colorRate = 0.12,
    this.angle = 65.0,
    this.cellWidth = 8.0,
    this.cellHeight = 14.0,
  });

  final Color lineColor;
  final double alpha;
  final double colorRate;
  final double angle;
  final double cellWidth;
  final double cellHeight;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final paint = Paint()
      ..color = lineColor.withValues(alpha: alpha)
      ..style = PaintingStyle.fill;

    final rad = angle * math.pi / 180;
    final cos = math.cos(rad);
    final sin = math.sin(rad);
    final count = (size.width / cellWidth).ceil() + 2;
    final rows = (size.height / cellHeight).ceil() + 2;

    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < count; c++) {
        final cx = c * cellWidth;
        final cy = r * cellHeight;
        final path = Path();
        final w = cellWidth * colorRate;
        path.moveTo(cx, cy);
        path.lineTo(cx + w * cos, cy + w * sin);
        path.lineTo(
          cx + w * cos - cellHeight * sin,
          cy + w * sin + cellHeight * cos,
        );
        path.lineTo(cx - cellHeight * sin, cy + cellHeight * cos);
        path.close();
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
