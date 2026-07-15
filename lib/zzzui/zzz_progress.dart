import 'package:flutter/material.dart';

import 'zzz_colors.dart';

class ZzzProgress extends StatelessWidget {
  const ZzzProgress({
    super.key,
    required this.percent,
    this.color = ZzzColors.primary,
    this.height = 10,
    this.trackColor = const Color(0xFF222222),
    this.borderColor = ZzzColors.black,
    this.borderWidth = 1,
    this.borderRadius,
  });

  final double percent;
  final Color color;
  final double height;
  final Color trackColor;
  final Color borderColor;
  final double borderWidth;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(9999);
    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _ZzzProgressPainter(
          percent: percent.clamp(0, 100),
          color: color,
          trackColor: trackColor,
          borderColor: borderColor,
          borderWidth: borderWidth,
          borderRadius: radius,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _ZzzProgressPainter extends CustomPainter {
  _ZzzProgressPainter({
    required this.percent,
    required this.color,
    required this.trackColor,
    required this.borderColor,
    required this.borderWidth,
    required this.borderRadius,
  });

  final double percent;
  final Color color;
  final Color trackColor;
  final Color borderColor;
  final double borderWidth;
  final BorderRadius borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final trackRRect = borderRadius.toRRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
    );

    // Track
    final trackPaint = Paint()..color = trackColor;
    canvas.drawRRect(trackRRect, trackPaint);

    // Progress clip
    final progressWidth = size.width * (percent / 100);
    final progressRect = Rect.fromLTWH(0, 0, progressWidth, size.height);
    canvas.save();
    canvas.clipRRect(trackRRect);

    // Base color
    final basePaint = Paint()..color = color;
    canvas.drawRect(progressRect, basePaint);

    // Overlay sheen
    final overlayGradient = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        Colors.transparent,
        Colors.white.withValues(alpha: 0.35),
        Colors.transparent,
        color.withValues(alpha: 0.4),
        Colors.transparent,
      ],
      stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
    );
    final overlayPaint = Paint()
      ..shader = overlayGradient.createShader(progressRect)
      ..blendMode = BlendMode.overlay;
    canvas.drawRect(progressRect, overlayPaint);

    // Highlight sheen 2
    final highlightGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.white.withValues(alpha: 0.25),
        Colors.transparent,
        Colors.black.withValues(alpha: 0.25),
      ],
    );
    final highlightPaint = Paint()
      ..shader = highlightGradient.createShader(progressRect)
      ..blendMode = BlendMode.overlay;
    canvas.drawRect(progressRect, highlightPaint);

    canvas.restore();

    // Border
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;
    canvas.drawRRect(trackRRect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _ZzzProgressPainter oldDelegate) {
    return oldDelegate.percent != percent ||
        oldDelegate.color != color ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.borderWidth != borderWidth ||
        oldDelegate.borderRadius != borderRadius;
  }
}
