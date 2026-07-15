import 'package:flutter/material.dart';

import 'zzz_painters.dart';

enum ZzzPatternType { stripes, squares, rhombus }

class ZzzPattern extends StatelessWidget {
  const ZzzPattern({
    super.key,
    this.type = ZzzPatternType.squares,
    this.backgroundColor = Colors.transparent,
    this.borderRadius,
    this.child,
  });

  final ZzzPatternType type;
  final Color backgroundColor;
  final BorderRadius? borderRadius;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.zero;
    return ClipRRect(
      borderRadius: radius,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          Positioned.fill(
            child: Container(
              color: backgroundColor,
              child: CustomPaint(
                painter: _patternPainter,
              ),
            ),
          ),
          if (child != null) child!,
        ],
      ),
    );
  }

  CustomPainter get _patternPainter {
    switch (type) {
      case ZzzPatternType.stripes:
        return const LinearPatternPainter();
      case ZzzPatternType.squares:
        return const ChessboardPainter();
      case ZzzPatternType.rhombus:
        return const GridPatternPainter();
    }
  }
}
