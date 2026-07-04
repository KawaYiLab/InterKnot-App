import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:inter_knot/controllers/data.dart';

class CategorySelector extends StatelessWidget {
  const CategorySelector({
    super.key,
    required this.selectedCategorySlug,
    required this.onCategorySelected,
  });

  final String? selectedCategorySlug;
  final ValueChanged<String?> onCategorySelected;

  @override
  Widget build(BuildContext context) {
    final c = Get.find<Controller>();

    return Obx(() {
      final categories = c.categories.where((e) => !e.adminOnly).toList();
      final items = <({String label, String? slug})>[
        (label: '未分区', slug: null),
        ...categories.map((e) => (label: e.name, slug: e.slug)),
      ];

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '分区',
            style: TextStyle(
              color: Color(0xff9A9A9A),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.zero,
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final item = items[index];
                final isActive = item.slug == selectedCategorySlug;
                return _CategoryChip(
                  label: item.label,
                  isActive: isActive,
                  onTap: () => onCategorySelected(item.slug),
                );
              },
            ),
          ),
        ],
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
              color: isActive
                  ? const Color(0xffD7FF00)
                  : const Color(0xff2A2A2A),
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
