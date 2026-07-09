import 'package:extended_text/extended_text.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:inter_knot/models/emote.dart';

/// 点击 mention 的回调，参数为 authorDocumentId。
typedef MentionTapCallback = void Function(String authorDocumentId);

class IkTextSpanBuilder extends RegExpSpecialTextSpanBuilder {
  IkTextSpanBuilder({
    Map<String, EmoteModel>? emoteMap,
    this.onMentionTap,
    this.mentionColor = const Color(0xffBFFF09),
  }) : emoteMap = emoteMap ?? const {};

  final Map<String, EmoteModel> emoteMap;
  final MentionTapCallback? onMentionTap;
  final Color mentionColor;

  static const _mentionPattern = r'@\[([^\[\]\n]{1,40})\]\(([A-Za-z0-9]{6,32})\)';
  static const _emotePattern = r':(ik-[a-z0-9-]{1,32}):';

  @override
  List<RegExpSpecialText> get regExps => [
        _MentionSpecialText(onMentionTap: onMentionTap, color: mentionColor),
        _EmoteSpecialText(emoteMap: emoteMap),
      ];
}

class _MentionSpecialText extends RegExpSpecialText {
  _MentionSpecialText({
    this.onMentionTap,
    this.color = const Color(0xffBFFF09),
  });

  final MentionTapCallback? onMentionTap;
  final Color color;

  @override
  RegExp get regExp => RegExp(IkTextSpanBuilder._mentionPattern, multiLine: true);

  @override
  InlineSpan finishText(
    int start,
    Match match, {
    TextStyle? textStyle,
    SpecialTextGestureTapCallback? onTap,
  }) {
    final name = match.group(1) ?? '';
    final authorId = match.group(2) ?? '';
    final display = name.isEmpty ? '@$authorId' : '@$name';

    return TextSpan(
      text: display,
      style: (textStyle ?? const TextStyle()).copyWith(
        color: color,
        fontWeight: FontWeight.w500,
      ),
      recognizer: TapGestureRecognizer()
        ..onTap = () {
          if (authorId.isNotEmpty) {
            onMentionTap?.call(authorId);
          }
        },
    );
  }
}

class _EmoteSpecialText extends RegExpSpecialText {
  _EmoteSpecialText({required this.emoteMap});

  final Map<String, EmoteModel> emoteMap;

  @override
  RegExp get regExp => RegExp(IkTextSpanBuilder._emotePattern, multiLine: true);

  @override
  InlineSpan finishText(
    int start,
    Match match, {
    TextStyle? textStyle,
    SpecialTextGestureTapCallback? onTap,
  }) {
    final code = match.group(1) ?? '';
    final emote = emoteMap[code];

    if (emote == null || emote.url.isEmpty) {
      return TextSpan(text: ':$code:', style: textStyle);
    }

    const size = 24.0;
    return ImageSpan(
      NetworkImage(emote.url),
      imageWidth: size,
      imageHeight: size,
      actualText: ':$code:',
    );
  }
}
