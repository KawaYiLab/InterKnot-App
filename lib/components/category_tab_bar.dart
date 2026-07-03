import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:inter_knot/controllers/data.dart';

/// 首页频道/分区横向 tab。空 slug 代表「全部」。
/// 数据源为 Controller.categories，选中态绑定 Controller.selectedCategorySlug。
class CategoryTabBar extends StatelessWidget {
  const CategoryTabBar({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<Controller>();

    return Obx(() {
      final cats = c.categories;
      // 频道尚未加载出来时不占位。
      if (cats.isEmpty) return const SizedBox.shrink();

      final selected = c.selectedCategorySlug.value;
      final items = <({String label, String slug})>[
        (label: '全部', slug: ''),
        ...cats.map((e) => (label: e.name, slug: e.slug)),
      ];

      return SizedBox(
        height: 48,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final item = items[index];
            final isActive = item.slug == selected;
            return _CategoryChip(
              label: item.label,
              isActive: isActive,
              onTap: () => c.selectCategory(item.slug),
            );
          },
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
