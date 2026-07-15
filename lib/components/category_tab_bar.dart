import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:inter_knot/controllers/data.dart';

/// 首页频道/分区横向 tab。空 slug 代表「最新」。
/// 数据源为 Controller.categories，选中态绑定 Controller.selectedCategorySlug
/// 与 Controller.feedMode。
class CategoryTabBar extends StatelessWidget {
  const CategoryTabBar({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<Controller>();

    return Obx(() {
      final cats = c.categories;
      final selected = c.selectedCategorySlug.value;
      final feed = c.feedMode.value;

      final children = <Widget>[];
      void addSep() => children.add(const SizedBox(width: 8));
      void addChip(String label, bool isActive, VoidCallback onTap) {
        children.add(_CategoryChip(
          label: label,
          isActive: isActive,
          onTap: onTap,
        ));
      }

      addChip(
        '最新',
        feed == 'recommend' && selected == '',
        () => c.selectCategory('', context: context),
      );
      addSep();

      for (final cat in cats) {
        addChip(
          cat.name,
          feed == 'recommend' && selected == cat.slug,
          () => c.selectCategory(cat.slug, context: context),
        );
        addSep();
      }

      children.add(Container(width: 1, height: 20, color: Colors.white24));
      addSep();

      addChip(
        '关注',
        feed == 'following',
        () => c.selectFeed('following', context: context),
      );
      addSep();
      addChip(
        '收藏',
        feed == 'favorites',
        () => c.selectFeed('favorites', context: context),
      );

      return SizedBox(
        height: 48,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          children: children,
        ),
      );
    });
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isActive ? const Color(0xffD7FF00) : const Color(0xff1E1E1E),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isActive ? const Color(0xffD7FF00) : const Color(0xff2A2A2A),
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.black : const Color(0xffB0B0B0),
              fontSize: 14,
              fontWeight: isActive ? FontWeight.w900 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
