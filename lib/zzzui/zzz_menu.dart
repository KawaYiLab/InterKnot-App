import 'package:flutter/material.dart';

import 'zzz_colors.dart';
import 'zzz_scrollbar.dart';

class ZzzMenu<T> extends StatelessWidget {
  const ZzzMenu({
    super.key,
    this.active,
    this.onChange,
    this.accordion = false,
    this.children = const [],
  });

  final T? active;
  final ValueChanged<T>? onChange;
  final bool accordion;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ZzzColors.black,
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Icon(
              Icons.keyboard_arrow_up,
              size: 14,
              color: ZzzColors.white.withValues(alpha: 0.4),
            ),
          ),
          Expanded(
            child: ZzzScrollbar(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: children,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Icon(
              Icons.keyboard_arrow_down,
              size: 14,
              color: ZzzColors.white.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}

class ZzzMenuItem<T> extends StatelessWidget {
  const ZzzMenuItem({
    super.key,
    required this.name,
    this.label,
    this.child,
    this.active = false,
    this.disabled = false,
    this.onTap,
    this.onChanged,
  });

  final T name;
  final String? label;
  final Widget? child;
  final bool active;
  final bool disabled;
  final VoidCallback? onTap;
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: disabled
          ? SystemMouseCursors.forbidden
          : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: disabled
            ? null
            : () {
                onTap?.call();
                onChanged?.call(name);
              },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: active ? ZzzColors.gradientYellow : Colors.transparent,
            borderRadius: BorderRadius.circular(0),
          ),
          child: DefaultTextStyle(
            style: TextStyle(
              color: active ? ZzzColors.black : ZzzColors.white,
              fontSize: 14,
              fontWeight: active ? FontWeight.w700 : FontWeight.w600,
            ),
            child: child ??
                Text(
                  label ?? name.toString(),
                  textAlign: TextAlign.center,
                ),
          ),
        ),
      ),
    );
  }
}
