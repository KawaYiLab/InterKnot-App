import 'package:flutter/material.dart';

import 'zzz_button.dart';

class ZzzBacktop extends StatefulWidget {
  const ZzzBacktop({
    super.key,
    required this.scrollController,
    this.visibleHeight = 200,
    this.right = 32,
    this.bottom = 95,
    this.size = ZzzButtonSize.extra,
  });

  final ScrollController scrollController;
  final double visibleHeight;
  final double right;
  final double bottom;
  final ZzzButtonSize size;

  @override
  State<ZzzBacktop> createState() => _ZzzBacktopState();
}

class _ZzzBacktopState extends State<ZzzBacktop> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_handleScroll);
  }

  @override
  void didUpdateWidget(covariant ZzzBacktop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController.removeListener(_handleScroll);
      widget.scrollController.addListener(_handleScroll);
      _handleScroll();
    }
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_handleScroll);
    super.dispose();
  }

  void _handleScroll() {
    final offset = widget.scrollController.offset;
    final shouldShow = offset >= widget.visibleHeight;
    if (shouldShow != _visible) {
      setState(() => _visible = shouldShow);
    }
  }

  void _scrollToTop() {
    if (widget.scrollController.hasClients) {
      widget.scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 200),
      right: widget.right,
      bottom: _visible ? widget.bottom : -80,
      child: ZzzButton(
        size: widget.size,
        circle: true,
        icon: Icons.keyboard_arrow_up,
        onPressed: _scrollToTop,
      ),
    );
  }
}
