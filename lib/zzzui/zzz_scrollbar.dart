import 'package:flutter/material.dart';

class ZzzScrollbar extends StatelessWidget {
  const ZzzScrollbar({
    super.key,
    required this.child,
    this.controller,
    this.thumbVisibility = true,
    this.thickness = 6,
  });

  final Widget child;
  final ScrollController? controller;
  final bool thumbVisibility;
  final double thickness;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        scrollbarTheme: ScrollbarThemeData(
          thumbColor: WidgetStateProperty.all(
            Colors.white.withValues(alpha: 0.3),
          ),
          trackColor: WidgetStateProperty.all(Colors.transparent),
          trackBorderColor: WidgetStateProperty.all(Colors.transparent),
          radius: const Radius.circular(99),
          thickness: WidgetStateProperty.all(thickness),
          minThumbLength: 24,
          interactive: true,
        ),
      ),
      child: Scrollbar(
        controller: controller,
        thumbVisibility: thumbVisibility,
        thickness: thickness,
        radius: const Radius.circular(99),
        interactive: true,
        child: child,
      ),
    );
  }
}
