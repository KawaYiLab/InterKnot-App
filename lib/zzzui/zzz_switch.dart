import 'package:flutter/material.dart';

import 'zzz_colors.dart';

class ZzzSwitch extends StatefulWidget {
  const ZzzSwitch({
    super.key,
    required this.value,
    this.onChanged,
    this.disabled = false,
    this.activeColor,
    this.width = 85,
    this.height = 34,
    this.knobSize = 24,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool disabled;
  final Color? activeColor;
  final double width;
  final double height;
  final double knobSize;

  @override
  State<ZzzSwitch> createState() => _ZzzSwitchState();
}

class _ZzzSwitchState extends State<ZzzSwitch>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: widget.value ? 1.0 : 0.0,
    );
  }

  @override
  void didUpdateWidget(covariant ZzzSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value && _controller.value != 1.0) {
      _controller.forward();
    } else if (!widget.value && _controller.value != 0.0) {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isInteractive => !widget.disabled && widget.onChanged != null;

  Color get _backgroundColor {
    if (widget.disabled) {
      return widget.value
          ? ZzzColors.switchCheckedDisabledBackground
          : ZzzColors.switchDisabledBackground;
    }
    return widget.value
        ? (widget.activeColor ?? ZzzColors.success)
        : ZzzColors.switchBackground;
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.value ? 'ON' : 'OFF';
    final labelColor = widget.disabled
        ? ZzzColors.switchDisabledColor
        : ZzzColors.black.withValues(alpha: 0.7);

    return MouseRegion(
      cursor: _isInteractive
          ? SystemMouseCursors.click
          : SystemMouseCursors.forbidden,
      child: GestureDetector(
        onTap: _isInteractive
            ? () => widget.onChanged!(!widget.value)
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: _backgroundColor,
            borderRadius: BorderRadius.circular(9999),
            border: Border.all(color: ZzzColors.black, width: 1),
            boxShadow: const [
              BoxShadow(
                color: Colors.black,
                offset: Offset(0, 1),
                blurRadius: 2,
              ),
            ],
          ),
          child: Stack(
            children: [
              AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                alignment: widget.value
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: widget.height / 2 - 6,
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: labelColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                ),
              ),
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final left = 4.0 +
                      _controller.value *
                          (widget.width - widget.knobSize - 8);
                  return Positioned(
                    left: left,
                    top: (widget.height - widget.knobSize) / 2,
                    child: child!,
                  );
                },
                child: _ZzzSwitchKnob(
                  size: widget.knobSize,
                  disabled: widget.disabled,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ZzzSwitchKnob extends StatelessWidget {
  const _ZzzSwitchKnob({required this.size, this.disabled = false});

  final double size;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ZzzColors.black, width: 1),
        gradient: SweepGradient(
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.7),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.3),
            Colors.transparent,
            Colors.white.withValues(alpha: 0.5),
            Colors.transparent,
          ],
          stops: const [0.0, 0.03, 0.15, 0.25, 0.42, 0.56, 0.72],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: disabled ? 0.0 : 0.4),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: size * 0.66,
          height: size * 0.66,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                const Color(0xFF585858),
                const Color(0xFF585858).withValues(alpha: 0.6),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withValues(alpha: disabled ? 0.0 : 0.2),
                blurRadius: 1,
                offset: const Offset(1, 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
