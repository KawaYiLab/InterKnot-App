import 'package:flutter/material.dart';

class StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  StickyHeaderDelegate({
    required this.child,
  });

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: const Color(0xff121212),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      alignment: Alignment.center,
      child: child,
    );
  }

  @override
  double get maxExtent => 96.0;

  @override
  double get minExtent => 96.0;

  @override
  bool shouldRebuild(StickyHeaderDelegate oldDelegate) {
    return oldDelegate.child != child;
  }
}
