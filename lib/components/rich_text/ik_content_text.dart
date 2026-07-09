import 'package:extended_text/extended_text.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:inter_knot/components/rich_text/ik_text_span_builder.dart';
import 'package:inter_knot/controllers/emote_controller.dart';

/// 渲染带 mention 与表情 shortcode 的正文/评论内容。
///
/// 普通文本原样展示；`@[name](id)` 渲染为可点击的 `@name`；
/// `:ik-code:` 渲染为清单中对应的表情图片（清单未加载时先显示占位 token）。
class IkContentText extends StatelessWidget {
  const IkContentText(
    this.content, {
    super.key,
    this.style,
    this.textAlign = TextAlign.start,
    this.onMentionTap,
    this.maxLines,
  });

  final String content;
  final TextStyle? style;
  final TextAlign textAlign;
  final MentionTapCallback? onMentionTap;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<EmoteController>(
      init: EmoteController(),
      builder: (c) {
        final emoteMap = c.emoteMap;
        return ExtendedText(
          content,
          style: style ??
              const TextStyle(
                fontSize: 16,
                color: Color(0xffE0E0E0),
              ),
          textAlign: textAlign,
          maxLines: maxLines,
          softWrap: true,
          specialTextSpanBuilder: IkTextSpanBuilder(
            emoteMap: emoteMap,
            onMentionTap: onMentionTap,
          ),
        );
      },
    );
  }
}
