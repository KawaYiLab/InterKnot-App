import 'package:flutter/material.dart';

import 'zzz_colors.dart';
import 'zzz_painters.dart';

enum ZzzButtonType {
  defaults,
  primary,
  success,
  danger,
  warning,
  info,
  ether,
  fire,
  electric,
  ice,
  physical,
}

enum ZzzButtonSize { extra, large, defaults, small, mini }

class ZzzButtonIconSpec {
  const ZzzButtonIconSpec(this.icon, {this.color = ZzzColors.white});

  final IconData icon;
  final Color color;

  static ZzzButtonIconSpec? fromWebIcon(dynamic icon) {
    if (icon is ZzzButtonIconSpec) return icon;
    if (icon is IconData) return ZzzButtonIconSpec(icon);
    if (icon is Map) {
      if (icon.isEmpty) return null;
      final entry = icon.entries.first;
      return ZzzButtonIconSpec(_nameToIcon(entry.key.toString()),
          color: _parseColor(entry.value));
    }
    if (icon is String) {
      return ZzzButtonIconSpec(_nameToIcon(icon));
    }
    return null;
  }

  static IconData _nameToIcon(String name) {
    return switch (name) {
      'error' => Icons.error_outline,
      'success' => Icons.check_circle_outline,
      'loading' => Icons.sync,
      'close' => Icons.close,
      'arrow_back' => Icons.arrow_back,
      'arrow_forward' => Icons.arrow_forward,
      _ => Icons.circle,
    };
  }

  static Color _parseColor(dynamic v) {
    if (v is Color) return v;
    if (v is String) {
      final hex = v.replaceFirst('#', '');
      if (hex.length == 6) return Color(int.parse('FF$hex', radix: 16));
      if (hex.length == 8) return Color(int.parse(hex, radix: 16));
    }
    return ZzzColors.white;
  }
}

class _ZzzButtonSizeData {
  const _ZzzButtonSizeData({
    required this.paddingX,
    required this.paddingY,
    required this.fontSize,
    required this.iconSize,
    required this.iconMargin,
  });

  final double paddingX;
  final double paddingY;
  final double fontSize;
  final double iconSize;
  final double iconMargin;
}

class ZzzButton extends StatefulWidget {
  const ZzzButton({
    super.key,
    this.size = ZzzButtonSize.defaults,
    this.type = ZzzButtonType.defaults,
    this.icon,
    this.loading = false,
    this.disabled = false,
    this.plain = false,
    this.hollow = false,
    this.round = true,
    this.circle = false,
    this.highlight = false,
    this.onPressed,
    this.child,
    this.label,
  });

  final ZzzButtonSize size;
  final ZzzButtonType type;
  final dynamic icon;
  final bool loading;
  final bool disabled;
  final bool plain;
  final bool hollow;
  final bool round;
  final bool circle;
  final bool highlight;
  final VoidCallback? onPressed;
  final Widget? child;
  final String? label;

  @override
  State<ZzzButton> createState() => _ZzzButtonState();
}

class _ZzzButtonState extends State<ZzzButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _highlightController;
  late final Animation<Color?> _highlightAnimation;

  @override
  void initState() {
    super.initState();
    _highlightController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _highlightAnimation = ColorTween(
      begin: ZzzColors.gradientYellow,
      end: ZzzColors.gradientGreen,
    ).animate(CurvedAnimation(
      parent: _highlightController,
      curve: Curves.linear,
    ));
    if (widget.highlight) _highlightController.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant ZzzButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.highlight && !_highlightController.isAnimating) {
      _highlightController.repeat(reverse: true);
    } else if (!widget.highlight && _highlightController.isAnimating) {
      _highlightController.stop();
    }
  }

  @override
  void dispose() {
    _highlightController.dispose();
    super.dispose();
  }

  _ZzzButtonSizeData get _sizeData {
    const base = _ZzzButtonSizeData(
      paddingX: 28,
      paddingY: 12,
      fontSize: 14,
      iconSize: 22,
      iconMargin: 8,
    );
    switch (widget.size) {
      case ZzzButtonSize.extra:
        return _ZzzButtonSizeData(
          paddingX: base.paddingX + 5 * 6,
          paddingY: base.paddingY + 2 * 2,
          fontSize: base.fontSize + 2 * 2,
          iconSize: base.iconSize + 2 * 4,
          iconMargin: base.iconMargin + 2 * 1,
        );
      case ZzzButtonSize.large:
        return _ZzzButtonSizeData(
          paddingX: base.paddingX + 3 * 6,
          paddingY: base.paddingY + 2,
          fontSize: base.fontSize + 2,
          iconSize: base.iconSize + 4,
          iconMargin: base.iconMargin + 1,
        );
      case ZzzButtonSize.defaults:
        return base;
      case ZzzButtonSize.small:
        return _ZzzButtonSizeData(
          paddingX: base.paddingX - 6,
          paddingY: base.paddingY - 2,
          fontSize: base.fontSize - 2,
          iconSize: base.iconSize - 4,
          iconMargin: base.iconMargin - 1,
        );
      case ZzzButtonSize.mini:
        return _ZzzButtonSizeData(
          paddingX: base.paddingX - 2 * 6,
          paddingY: base.paddingY - 2 * 2,
          fontSize: base.fontSize - 2 * 2,
          iconSize: base.iconSize - 2 * 4,
          iconMargin: base.iconMargin - 2 * 1,
        );
    }
  }

  Color get _typeColor {
    switch (widget.type) {
      case ZzzButtonType.defaults:
        return ZzzColors.black;
      case ZzzButtonType.primary:
        return ZzzColors.primary;
      case ZzzButtonType.success:
        return ZzzColors.success;
      case ZzzButtonType.danger:
        return ZzzColors.danger;
      case ZzzButtonType.warning:
        return ZzzColors.warning;
      case ZzzButtonType.info:
        return ZzzColors.info;
      case ZzzButtonType.ether:
        return ZzzColors.ether;
      case ZzzButtonType.fire:
        return ZzzColors.fire;
      case ZzzButtonType.electric:
        return ZzzColors.electric;
      case ZzzButtonType.ice:
        return ZzzColors.ice;
      case ZzzButtonType.physical:
        return ZzzColors.physical;
    }
  }

  Color get _afterColor {
    if (widget.disabled && widget.hollow) {
      return ZzzColors.buttonDisabledBackground;
    }
    if (widget.plain) return ZzzColors.buttonPlainBackground;
    if (widget.hollow) return ZzzColors.black;
    if (widget.disabled) return ZzzColors.black;
    return _typeColor;
  }

  Color get _ringColor {
    if (widget.disabled) return ZzzColors.buttonDisabledBackground;
    if (widget.plain || widget.hollow) return ZzzColors.buttonBorder;
    return _typeColor;
  }

  bool get _drawBlackBand => !widget.disabled;

  Color get _foregroundColor {
    if (widget.disabled) {
      if (widget.plain || widget.hollow) return ZzzColors.buttonHollowDisabledColor;
      return ZzzColors.buttonDisabledColor;
    }
    if (widget.plain) {
      if (widget.type == ZzzButtonType.defaults ||
          widget.type == ZzzButtonType.primary) {
        return ZzzColors.black;
      }
    }
    return ZzzColors.white;
  }

  bool get _isInteractive => !widget.disabled && !widget.loading && widget.onPressed != null;

  Widget get _child {
    if (widget.child != null) return widget.child!;
    if (widget.label != null) {
      return Text(
        widget.label!,
        style: TextStyle(
          fontSize: _sizeData.fontSize,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
          height: 1,
        ),
      );
    }
    return const SizedBox.shrink();
  }

  ZzzButtonIconSpec? get _iconSpec => ZzzButtonIconSpec.fromWebIcon(widget.icon);

  @override
  Widget build(BuildContext context) {
    final size = _sizeData;
    final borderRadius =
        widget.circle ? BorderRadius.circular(9999) : (widget.round ? BorderRadius.circular(9999) : BorderRadius.circular(6));

    Widget content = _child;
    if (widget.loading) {
      content = _IconRow(
        size: size,
        icon: SizedBox(
          width: size.iconSize,
          height: size.iconSize,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(_foregroundColor),
          ),
        ),
        child: content,
      );
    } else if (_iconSpec != null) {
      content = _IconRow(
        size: size,
        icon: Icon(
          _iconSpec!.icon,
          size: size.iconSize,
          color: _iconSpec!.color,
        ),
        child: content,
      );
    }

    final innerPadding = 1.0 + (_drawBlackBand ? 4.0 : 0.0) + 3.0;

    content = AnimatedBuilder(
      animation: _highlightController,
      builder: (context, child) {
        final fg = widget.highlight
            ? (_highlightAnimation.value ?? _foregroundColor)
            : _foregroundColor;
        return DefaultTextStyle(
          style: TextStyle(color: fg),
          child: IconTheme(
            data: IconThemeData(color: fg, size: size.iconSize),
            child: child!,
          ),
        );
      },
      child: content,
    );

    Widget button = Container(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
      ),
      clipBehavior: Clip.antiAlias,
      child: CustomPaint(
        painter: _ZzzButtonPainter(
          afterColor: _afterColor,
          ringColor: _ringColor,
          drawBlackBand: _drawBlackBand,
          borderRadius: borderRadius,
        ),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: innerPadding + size.paddingX,
            vertical: innerPadding + size.paddingY,
          ),
          child: content,
        ),
      ),
    );

    return MouseRegion(
      cursor: _isInteractive ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
      child: GestureDetector(
        onTap: _isInteractive ? widget.onPressed : null,
        behavior: HitTestBehavior.opaque,
        child: button,
      ),
    );
  }
}

class _IconRow extends StatelessWidget {
  const _IconRow({
    required this.size,
    required this.icon,
    required this.child,
  });

  final _ZzzButtonSizeData size;
  final Widget icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final hasChild = child is! SizedBox ||
        (child is SizedBox && (child as SizedBox).width != null);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        if (hasChild) ...[
          SizedBox(width: size.iconMargin),
          child,
        ],
      ],
    );
  }
}

class _ZzzButtonPainter extends CustomPainter {
  _ZzzButtonPainter({
    required this.afterColor,
    required this.ringColor,
    required this.drawBlackBand,
    required this.borderRadius,
  });

  final Color afterColor;
  final Color ringColor;
  final bool drawBlackBand;
  final BorderRadius borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final r = borderRadius.toRRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // Background
    final bgPaint = Paint()..color = afterColor;
    canvas.drawRRect(r, bgPaint);

    // Chessboard pattern
    final patternPainter = const ChessboardPainter(alpha: 0.06, cellSize: 6);
    patternPainter.paint(canvas, size);

    // Outer 1px black border
    final outerBorderPaint = Paint()
      ..color = ZzzColors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRRect(r, outerBorderPaint);

    double inset = 1;
    if (drawBlackBand) {
      final blackBandR = borderRadius.toRRect(
        Rect.fromLTWH(inset, inset, size.width - 2 * inset, size.height - 2 * inset),
      );
      final blackPaint = Paint()..color = ZzzColors.black;
      canvas.drawRRect(blackBandR, blackPaint);
      // Draw chessboard over the black band? No, the black band should be solid black.
      // The web uses black inset box-shadow, which is opaque black.
      inset += 4;
    }

    // 3px ring
    if (inset + 3 <= size.width / 2 && inset + 3 <= size.height / 2) {
      final ringR = borderRadius.toRRect(
        Rect.fromLTWH(inset, inset, size.width - 2 * inset, size.height - 2 * inset),
      );
      final ringPaint = Paint()
        ..color = ringColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      canvas.drawRRect(ringR, ringPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
