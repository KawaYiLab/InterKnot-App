import 'package:flutter/material.dart';

import 'zzz_colors.dart';

enum ZzzRadioShape { icon, button }

enum ZzzRadioSize { extra, large, defaults, small, mini }

class ZzzRadio<T> extends StatelessWidget {
  const ZzzRadio({
    super.key,
    required this.value,
    this.groupValue,
    this.onChanged,
    this.label,
    this.disabled = false,
    this.shape = ZzzRadioShape.icon,
    this.size = ZzzRadioSize.defaults,
  });

  final T value;
  final T? groupValue;
  final ValueChanged<T?>? onChanged;
  final String? label;
  final bool disabled;
  final ZzzRadioShape shape;
  final ZzzRadioSize size;

  bool get _isSelected => value == groupValue;

  @override
  Widget build(BuildContext context) {
    return _ZzzOption(
      selected: _isSelected,
      onTap: disabled || onChanged == null
          ? null
          : () => onChanged!(value),
      label: label,
      disabled: disabled,
      shape: shape,
      size: size,
      isCheckbox: false,
    );
  }
}

class ZzzCheckbox<T> extends StatelessWidget {
  const ZzzCheckbox({
    super.key,
    this.value,
    this.groupValue,
    this.onChanged,
    this.checked,
    this.label,
    this.disabled = false,
    this.shape = ZzzRadioShape.icon,
    this.size = ZzzRadioSize.defaults,
  });

  final T? value;
  final Set<T>? groupValue;
  final ValueChanged<T?>? onChanged;
  final bool? checked;
  final String? label;
  final bool disabled;
  final ZzzRadioShape shape;
  final ZzzRadioSize size;

  bool get _isSelected {
    if (checked != null) return checked!;
    if (value != null && groupValue != null) return groupValue!.contains(value!);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return _ZzzOption(
      selected: _isSelected,
      onTap: disabled || onChanged == null
          ? null
          : () => onChanged!(value),
      label: label,
      disabled: disabled,
      shape: shape,
      size: size,
      isCheckbox: true,
    );
  }
}

class _ZzzOption extends StatelessWidget {
  const _ZzzOption({
    required this.selected,
    this.onTap,
    this.label,
    this.disabled = false,
    required this.shape,
    required this.size,
    required this.isCheckbox,
  });

  final bool selected;
  final VoidCallback? onTap;
  final String? label;
  final bool disabled;
  final ZzzRadioShape shape;
  final ZzzRadioSize size;
  final bool isCheckbox;

  static const _buttonPadding = EdgeInsets.symmetric(horizontal: 14, vertical: 10);
  static const _borderRadius = 10.0;

  @override
  Widget build(BuildContext context) {
    if (shape == ZzzRadioShape.button) {
      return _buildButton();
    }
    return _buildIconRow();
  }

  Widget _buildButton() {
    return MouseRegion(
      cursor: disabled
          ? SystemMouseCursors.forbidden
          : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: _buttonPadding,
          decoration: BoxDecoration(
            color: selected
                ? ZzzColors.gradientYellow
                : ZzzColors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(_borderRadius),
            border: Border.all(
              color: selected
                  ? ZzzColors.gradientYellow
                  : ZzzColors.white.withValues(alpha: 0.08),
              width: 1,
            ),
          ),
          child: Center(
            child: Text(
              label ?? '',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected
                    ? ZzzColors.black
                    : (disabled
                        ? ZzzColors.white.withValues(alpha: 0.4)
                        : ZzzColors.white),
                fontSize: 14,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconRow() {
    return MouseRegion(
      cursor: disabled
          ? SystemMouseCursors.forbidden
          : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ZzzRadioIcon(
              selected: selected,
              disabled: disabled,
              isCheckbox: isCheckbox,
              size: _sizeData.iconSize,
            ),
            if (label != null) ...[
              const SizedBox(width: 10),
              Text(
                label!,
                style: TextStyle(
                  color: selected
                      ? ZzzColors.white
                      : (disabled
                          ? ZzzColors.radioDisabledColor
                          : ZzzColors.white.withValues(alpha: 0.85)),
                  fontSize: _sizeData.fontSize,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  ({double iconSize, double fontSize}) get _sizeData {
    return switch (size) {
      ZzzRadioSize.extra => (iconSize: 20.0, fontSize: 16.0),
      ZzzRadioSize.large => (iconSize: 18.0, fontSize: 15.0),
      ZzzRadioSize.small => (iconSize: 14.0, fontSize: 12.0),
      ZzzRadioSize.mini => (iconSize: 12.0, fontSize: 10.0),
      ZzzRadioSize.defaults => (iconSize: 16.0, fontSize: 14.0),
    };
  }
}

class _ZzzRadioIcon extends StatelessWidget {
  const _ZzzRadioIcon({
    required this.selected,
    required this.disabled,
    required this.isCheckbox,
    this.size = 16,
  });

  final bool selected;
  final bool disabled;
  final bool isCheckbox;
  final double size;

  @override
  Widget build(BuildContext context) {
    final outerSize = size;
    final borderWidth = selected ? 3.0 : 2.0;
    final borderColor = disabled
        ? ZzzColors.radioDisabledColor
        : (selected ? ZzzColors.success : ZzzColors.inputBorder);
    final bgColor = disabled
        ? ZzzColors.black.withValues(alpha: 0.3)
        : Colors.transparent;

    return SizedBox(
      width: outerSize,
      height: outerSize,
      child: CustomPaint(
        painter: _ZzzRadioIconPainter(
          isCheckbox: isCheckbox,
          selected: selected,
          disabled: disabled,
          borderColor: borderColor,
          backgroundColor: bgColor,
          borderWidth: borderWidth,
        ),
        size: Size(outerSize, outerSize),
      ),
    );
  }
}

class _ZzzRadioIconPainter extends CustomPainter {
  _ZzzRadioIconPainter({
    required this.isCheckbox,
    required this.selected,
    required this.disabled,
    required this.borderColor,
    required this.backgroundColor,
    required this.borderWidth,
  });

  final bool isCheckbox;
  final bool selected;
  final bool disabled;
  final Color borderColor;
  final Color backgroundColor;
  final double borderWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final r = isCheckbox
        ? RRect.fromRectAndRadius(rect, const Radius.circular(4))
        : RRect.fromRectAndRadius(rect, Radius.circular(size.width / 2));

    // Outer black outline
    final outlinePaint = Paint()
      ..color = ZzzColors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRRect(r, outlinePaint);

    final inset = 1.0 + borderWidth / 2;
    final innerR = isCheckbox
        ? RRect.fromRectAndRadius(
            Rect.fromLTRB(
              inset,
              inset,
              size.width - inset,
              size.height - inset,
            ),
            const Radius.circular(3),
          )
        : RRect.fromRectAndRadius(
            Rect.fromLTRB(
              inset,
              inset,
              size.width - inset,
              size.height - inset,
            ),
            Radius.circular((size.width - 2 * inset) / 2),
          );

    // Background
    final bgPaint = Paint()..color = backgroundColor;
    canvas.drawRRect(innerR, bgPaint);

    // Border
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;
    canvas.drawRRect(innerR, borderPaint);

    // Check mark / dot
    if (selected) {
      final checkColor = disabled ? ZzzColors.radioDisabledColor : ZzzColors.success;
      if (isCheckbox) {
        final paint = Paint()
          ..color = checkColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round;
        final path = Path()
          ..moveTo(size.width * 0.25, size.height * 0.55)
          ..lineTo(size.width * 0.45, size.height * 0.75)
          ..lineTo(size.width * 0.75, size.height * 0.3);
        canvas.drawPath(path, paint);
      } else {
        final dotPaint = Paint()..color = checkColor;
        final dotRadius = (size.width / 2) - 4;
        canvas.drawCircle(
          Offset(size.width / 2, size.height / 2),
          dotRadius,
          dotPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
