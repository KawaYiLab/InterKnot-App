import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:inter_knot/controllers/emote_controller.dart';
import 'package:inter_knot/models/emote.dart';

/// 表情选择底部弹窗。
///
/// 返回选中的表情 code；点 emoji 返回原始 Unicode 字符。
class EmotePicker extends StatefulWidget {
  const EmotePicker({super.key});

  @override
  State<EmotePicker> createState() => _EmotePickerState();
}

class _EmotePickerState extends State<EmotePicker> {
  final List<String> _emojiList = const [
    '😀', '😁', '😂', '🤣', '😅', '😊', '😇', '🙂', '🙃', '😉',
    '😍', '🥰', '😘', '😋', '😛', '😜', '🤪', '🤗', '🤔', '🤨',
    '😐', '😶', '🙄', '😏', '😣', '😥', '😮', '😪', '😫', '😴',
    '😌', '😒', '😔', '😕', '🙁', '😖', '😞', '😤', '😢', '😭',
    '😨', '😩', '🤯', '😬', '😰', '😱', '🥵', '🥶', '😳', '🥴',
    '😵', '🤠', '🥳', '😎', '🤓', '🧐', '😷', '🤒', '🤕', '🤢',
    '👍', '👎', '👌', '✌️', '🤝', '👏', '🙏', '💪', '🤙', '👋',
    '❤️', '💔', '✨', '🔥', '🎉', '🌟', '💤', '💦', '💀', '🌺',
  ];

  String _selectedGroup = 'emoji';

  @override
  Widget build(BuildContext context) {
    return GetBuilder<EmoteController>(
      init: EmoteController(),
      builder: (c) {
        final groups = c.groups;
        final emotes = c.emotes;
        final groupNames = groups.map((g) => g.name).toList();
        if (_selectedGroup != 'emoji' && !groupNames.contains(_selectedGroup)) {
          _selectedGroup = groupNames.isNotEmpty ? groupNames.first : 'emoji';
        }

        return SafeArea(
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xff222222),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    children: [
                      _buildGroupChip('emoji', 'emoji', null),
                      ...groups.map((g) {
                        final iconUrl = g.iconUrl;
                        final first = emotes.firstWhere(
                          (e) => e.group == g.name,
                          orElse: () => const EmoteModel(
                              code: '', name: '', url: ''),
                        );
                        final url = iconUrl ??
                            (first.url.isNotEmpty ? first.url : null);
                        return _buildGroupChip(g.name, g.name, url);
                      }),
                    ],
                  ),
                ),
                SizedBox(
                  height: 240,
                  child: _selectedGroup == 'emoji'
                      ? _buildEmojiGrid()
                      : _buildEmoteGrid(_selectedGroup, emotes),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGroupChip(String key, String label, String? iconUrl) {
    final selected = _selectedGroup == key;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (iconUrl != null)
              Image.network(
                iconUrl,
                width: 20,
                height: 20,
                errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 18),
              )
            else
              const Icon(Icons.tag, size: 18),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.black : Colors.grey,
                fontSize: 12,
              ),
            ),
          ],
        ),
        selected: selected,
        selectedColor: const Color(0xffBFFF09),
        backgroundColor: const Color(0xff2D2D2D),
        onSelected: (_) => setState(() => _selectedGroup = key),
      ),
    );
  }

  Widget _buildEmojiGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 8,
        childAspectRatio: 1,
      ),
      itemCount: _emojiList.length,
      itemBuilder: (context, index) {
        final emoji = _emojiList[index];
        return InkWell(
          onTap: () => Navigator.of(context).pop(emoji),
          child: Center(
            child: Text(
              emoji,
              style: const TextStyle(fontSize: 24),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmoteGrid(String group, List<EmoteModel> emotes) {
    final groupEmotes = emotes.where((e) => e.group == group).toList();
    if (groupEmotes.isEmpty) {
      return const Center(
        child: Text('暂无表情', style: TextStyle(color: Colors.grey)),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        childAspectRatio: 1,
      ),
      itemCount: groupEmotes.length,
      itemBuilder: (context, index) {
        final emote = groupEmotes[index];
        return InkWell(
          onTap: () => Navigator.of(context).pop(emote.code),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Image.network(
              emote.url,
              width: 36,
              height: 36,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
            ),
          ),
        );
      },
    );
  }
}
