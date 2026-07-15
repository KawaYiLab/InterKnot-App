import 'package:flutter/material.dart';

import 'zzz_colors.dart';

class ZzzInput extends StatefulWidget {
  const ZzzInput({
    super.key,
    this.controller,
    this.initialValue,
    this.onChanged,
    this.onSubmitted,
    this.onFocus,
    this.onBlur,
    this.hintText,
    this.labelText,
    this.obscureText = false,
    this.clearable = false,
    this.prefix,
    this.suffix,
    this.prefixIcon,
    this.suffixIcon,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.minLines,
    this.maxLines = 1,
    this.maxLength,
    this.keyboardType,
    this.textInputAction,
    this.style,
  });

  final TextEditingController? controller;
  final String? initialValue;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onFocus;
  final VoidCallback? onBlur;
  final String? hintText;
  final String? labelText;
  final bool obscureText;
  final bool clearable;
  final Widget? prefix;
  final Widget? suffix;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final bool enabled;
  final bool readOnly;
  final bool autofocus;
  final int? minLines;
  final int? maxLines;
  final int? maxLength;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextStyle? style;

  @override
  State<ZzzInput> createState() => _ZzzInputState();
}

class _ZzzInputState extends State<ZzzInput>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  late final AnimationController _focusController;
  late final Animation<Color?> _focusColor;
  bool _isInternalController = false;
  bool _obscure = false;
  bool _hasText = false;

  bool get isTextarea =>
      (widget.maxLines == null || (widget.maxLines != null && widget.maxLines! > 1));

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _controller = TextEditingController(text: widget.initialValue ?? '');
      _isInternalController = true;
    }
    _obscure = widget.obscureText;
    _hasText = _controller.text.isNotEmpty;
    _controller.addListener(_handleTextChange);

    _focusNode = FocusNode();
    _focusNode.addListener(_handleFocusChange);

    _focusController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _focusColor = ColorTween(
      begin: ZzzColors.gradientYellow,
      end: ZzzColors.gradientGreen,
    ).animate(_focusController);
  }

  @override
  void didUpdateWidget(covariant ZzzInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_handleTextChange);
      if (_isInternalController) {
        _controller.dispose();
      }
      if (widget.controller != null) {
        _controller = widget.controller!;
        _isInternalController = false;
      } else {
        _controller = TextEditingController(text: widget.initialValue ?? '');
        _isInternalController = true;
      }
      _controller.addListener(_handleTextChange);
      _hasText = _controller.text.isNotEmpty;
    }
    if (oldWidget.obscureText != widget.obscureText) {
      _obscure = widget.obscureText;
    }
  }

  @override
  void dispose() {
    _focusController.dispose();
    _focusNode.dispose();
    _controller.removeListener(_handleTextChange);
    if (_isInternalController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _handleTextChange() {
    final hasText = _controller.text.isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  void _handleFocusChange() {
    if (_focusNode.hasFocus) {
      _focusController.repeat(reverse: true);
      widget.onFocus?.call();
    } else {
      _focusController.stop();
      _focusController.value = 0;
      widget.onBlur?.call();
    }
  }

  Color get _borderColor {
    if (!widget.enabled) return ZzzColors.inputBorder;
    if (_focusNode.hasFocus) {
      return _focusColor.value ?? ZzzColors.inputBorder;
    }
    return ZzzColors.inputBorder;
  }

  Color get _backgroundColor {
    if (!widget.enabled) {
      return isTextarea ? ZzzColors.black : ZzzColors.inputDisabledBackground;
    }
    return isTextarea ? ZzzColors.black : ZzzColors.inputBackground;
  }

  TextStyle get _defaultStyle {
    return TextStyle(
      color: widget.enabled ? ZzzColors.white : ZzzColors.inputDisabledColor,
      fontSize: 14,
    );
  }

  BorderRadius get _borderRadius {
    return isTextarea
        ? BorderRadius.circular(16)
        : BorderRadius.circular(9999);
  }

  Widget _buildIcon(IconData? icon, VoidCallback? onTap) {
    if (icon == null) return const SizedBox.shrink();
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Icon(
          icon,
          size: 18,
          color: ZzzColors.inputPlaceholder,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = widget.style ?? _defaultStyle;

    final suffixIcons = <Widget>[];
    if (widget.clearable && _hasText && widget.enabled) {
      suffixIcons.add(_buildIcon(
        Icons.cancel_outlined,
        () {
          _controller.clear();
          widget.onChanged?.call('');
        },
      ));
    }
    if (widget.obscureText) {
      suffixIcons.add(_buildIcon(
        _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        () => setState(() => _obscure = !_obscure),
      ));
    }
    if (widget.suffixIcon != null) {
      suffixIcons.add(_buildIcon(widget.suffixIcon, null));
    }
    if (widget.suffix != null) suffixIcons.add(widget.suffix!);

    final prefix = widget.prefixIcon != null
        ? _buildIcon(widget.prefixIcon, null)
        : null;
    final prefixWidget = widget.prefix;

    return AnimatedBuilder(
      animation: _focusController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            color: _backgroundColor,
            borderRadius: _borderRadius,
            border: Border.all(color: _borderColor, width: 3),
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              if (prefix != null) prefix,
              if (prefixWidget != null) prefixWidget,
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  enabled: widget.enabled,
                  readOnly: widget.readOnly,
                  autofocus: widget.autofocus,
                  obscureText: _obscure,
                  minLines: widget.minLines,
                  maxLines: widget.maxLines,
                  maxLength: widget.maxLength,
                  keyboardType: widget.keyboardType,
                  textInputAction: widget.textInputAction,
                  style: effectiveStyle,
                  cursorColor: ZzzColors.gradientYellow,
                  onChanged: widget.onChanged,
                  onSubmitted: widget.onSubmitted,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    hintText: widget.hintText,
                    hintStyle: const TextStyle(
                      color: ZzzColors.inputPlaceholder,
                      fontSize: 14,
                    ),
                    counterText: '',
                    filled: false,
                  ),
                  buildCounter: (context,
                      {required currentLength,
                      required isFocused,
                      required maxLength}) => null,
                ),
              ),
              ...suffixIcons,
            ],
          ),
        );
      },
    );
  }
}
