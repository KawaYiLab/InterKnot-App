import 'package:flutter/material.dart';

import 'zzz_colors.dart';

class ZzzDropdown extends StatelessWidget {
  const ZzzDropdown({
    super.key,
    required this.child,
    this.items = const [],
    this.onCommand,
    this.trigger = 'hover',
    this.disabled = false,
    this.size,
  });

  final Widget child;
  final List<ZzzDropdownItem> items;
  final ValueChanged<dynamic>? onCommand;
  final String trigger;
  final bool disabled;
  final String? size;

  @override
  Widget build(BuildContext context) {
    if (disabled || items.isEmpty) return child;

    return PopupMenuButton<dynamic>(
      offset: const Offset(0, 8),
      color: ZzzColors.inputBackground,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: ZzzColors.inputBorder, width: 1),
      ),
      itemBuilder: (context) {
        return items.map((item) {
          return PopupMenuItem<dynamic>(
            value: item.command,
            enabled: !item.disabled,
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: item.child ??
                Text(
                  item.label,
                  style: TextStyle(
                    color: item.disabled
                        ? ZzzColors.radioDisabledColor
                        : ZzzColors.white,
                    fontSize: 14,
                  ),
                ),
          );
        }).toList();
      },
      onSelected: onCommand,
      child: child,
    );
  }
}

class ZzzDropdownItem extends StatelessWidget {
  const ZzzDropdownItem({
    super.key,
    this.command,
    this.label = '',
    this.disabled = false,
    this.child,
  });

  final dynamic command;
  final String label;
  final bool disabled;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return child ??
        Text(
          label,
          style: TextStyle(
            color: disabled
                ? ZzzColors.radioDisabledColor
                : ZzzColors.white,
            fontSize: 14,
          ),
        );
  }
}
