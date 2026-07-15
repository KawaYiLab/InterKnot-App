import 'package:flutter/material.dart';
import 'package:inter_knot/zzzui/zzzui.dart';

class CreateDiscussionDesktopSidebar extends StatelessWidget {
  const CreateDiscussionDesktopSidebar({
    super.key,
    required this.selectedIndex,
    required this.onSelectPage,
    this.showDrafts = true,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelectPage;
  final bool showDrafts;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: Container(
        margin: const EdgeInsets.only(
          top: 16,
          left: 16,
          right: 8,
          bottom: 16,
        ),
        height: double.infinity,
        decoration: BoxDecoration(
          border: Border.all(
            color: const Color(0xff313132),
            width: 4,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: ZzzMenu(
            active: selectedIndex,
            onChange: onSelectPage,
            children: [
              ZzzMenuItem(
                name: 0,
                label: '正文',
                active: selectedIndex == 0,
                onTap: () => onSelectPage(0),
              ),
              ZzzMenuItem(
                name: 1,
                label: '封面',
                active: selectedIndex == 1,
                onTap: () => onSelectPage(1),
              ),
              if (showDrafts)
                ZzzMenuItem(
                  name: 2,
                  label: '草稿',
                  active: selectedIndex == 2,
                  onTap: () => onSelectPage(2),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
