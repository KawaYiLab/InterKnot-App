/// 与 InterKnot-Web 同款的 mention / emote 解析器。
///
/// 两端独立维护，改动时务必保持正则 / 行为一致。
/// 来源：InterKnot-Web/app/utils/mention.ts、emote.ts

const _mentionPattern = r'@\[([^\[\]\n]{1,40})\]\(([A-Za-z0-9]{6,32})\)';
const _emotePattern = r':(ik-[a-z0-9-]{1,32}):';

final _mentionRegex = RegExp(_mentionPattern, multiLine: true);
final _emoteRegex = RegExp(_emotePattern, multiLine: true);

/// 提及 token。
class MentionToken {
  final String name;
  final String authorDocumentId;
  final int start;
  final int end;

  const MentionToken({
    required this.name,
    required this.authorDocumentId,
    required this.start,
    required this.end,
  });
}

/// 表情 token。
class EmoteToken {
  final String code;
  final int start;
  final int end;

  const EmoteToken({
    required this.code,
    required this.start,
    required this.end,
  });
}

/// 统一内容分段，用于把正文切成可直接渲染的单元。
sealed class ContentSegment {}

class TextSegment extends ContentSegment {
  final String value;

  TextSegment(this.value);
}

class MentionSegment extends ContentSegment {
  final String name;
  final String authorDocumentId;

  MentionSegment({
    required this.name,
    required this.authorDocumentId,
  });
}

class EmoteSegment extends ContentSegment {
  final String code;

  EmoteSegment(this.code);
}

/// 解析所有 mention token，保持出现顺序、不去重。
List<MentionToken> parseMentions(String content) {
  if (content.isEmpty) return [];
  final re = RegExp(_mentionPattern, multiLine: true);
  final out = <MentionToken>[];
  for (final m in re.allMatches(content)) {
    out.add(MentionToken(
      name: m.group(1) ?? '',
      authorDocumentId: m.group(2) ?? '',
      start: m.start,
      end: m.end,
    ));
  }
  return out;
}

/// 解析所有 emote token，保持出现顺序、不去重。
List<EmoteToken> parseEmotes(String content) {
  if (content.isEmpty) return [];
  final re = RegExp(_emotePattern, multiLine: true);
  final out = <EmoteToken>[];
  for (final m in re.allMatches(content)) {
    out.add(EmoteToken(
      code: m.group(1) ?? '',
      start: m.start,
      end: m.end,
    ));
  }
  return out;
}

/// 把正文按 text / mention / emote 切成段，便于流式渲染。
///
/// 重叠 token 时跳过后一个，做防御性处理。
List<ContentSegment> splitContent(String content) {
  if (content.isEmpty) return [TextSegment('')];

  final mentionTokens = parseMentions(content);
  final emoteTokens = parseEmotes(content);

  if (mentionTokens.isEmpty && emoteTokens.isEmpty) {
    return [TextSegment(content)];
  }

  final allTokens = <_Token>[]
    ..addAll(mentionTokens.map((t) => _Token.mention(
          start: t.start,
          end: t.end,
          name: t.name,
          authorDocumentId: t.authorDocumentId,
        )))
    ..addAll(emoteTokens.map((t) => _Token.emote(
          start: t.start,
          end: t.end,
          code: t.code,
        )))
    ..sort((a, b) => a.start - b.start);

  final segments = <ContentSegment>[];
  var cursor = 0;

  for (final tok in allTokens) {
    if (tok.start < cursor) continue;
    if (tok.start > cursor) {
      segments.add(TextSegment(content.substring(cursor, tok.start)));
    }

    switch (tok) {
      case _MentionToken():
        segments.add(MentionSegment(
          name: tok.name,
          authorDocumentId: tok.authorDocumentId,
        ));
      case _EmoteToken():
        if (tok.code.isNotEmpty) {
          segments.add(EmoteSegment(tok.code));
        }
    }
    cursor = tok.end;
  }

  if (cursor < content.length) {
    segments.add(TextSegment(content.substring(cursor)));
  }

  return segments;
}

/// 把所有 mention token 替换成 `@显示名`，用于摘要/会话列表预览。
String stripMentionsToPlain(String content) {
  if (content.isEmpty) return '';
  return content.replaceAllMapped(
    _mentionRegex,
    (m) => '@${m.group(1) ?? ''}',
  );
}

/// 把所有 emote token 替换成 `[表情:<name>]` 或 `[表情]`，用于摘要/预览。
///
/// [nameLookup] 接收 code，返回显示名；查不到时降级为 `[表情]`。
String stripEmotesToPlain(
  String content, {
  String? Function(String code)? nameLookup,
}) {
  if (content.isEmpty) return '';
  return content.replaceAllMapped(
    _emoteRegex,
    (m) {
      final code = m.group(1) ?? '';
      final name = nameLookup?.call(code);
      return name != null && name.isNotEmpty ? '[表情:$name]' : '[表情]';
    },
  );
}

/// 拼装 mention token，供 @选人后插入编辑器。
String buildMentionToken(String name, String authorDocumentId) {
  final safeName = name.length > 40 ? name.substring(0, 40) : name;
  final clean = safeName.replaceAll(RegExp(r'[\[\]\n]'), '');
  return '@[$clean]($authorDocumentId)';
}

/// 拼装 emote token，供表情选择器插入编辑器。
String buildEmoteToken(String code) => ':$code:';

/// 把正文中的 mention / emote token 替换成可被 MarkdownWidget 渲染的语法。
///
/// - 提及 `@[name](id)` → `[@name](ik://profile/id)`（点击后由调用方拦截）
/// - 表情 `:ik-code:` → `![:$code:](emoteUrl)`
/// - 找不到 URL 的表情保持原 token，等待清单加载后重新渲染
String enrichMarkdownForRichRender(
  String content, {
  Map<String, String>? emoteUrlMap,
}) {
  if (content.isEmpty) return '';
  final urlMap = emoteUrlMap ?? const {};
  final segments = splitContent(content);
  final buffer = StringBuffer();

  for (final seg in segments) {
    switch (seg) {
      case TextSegment():
        buffer.write(seg.value);
      case MentionSegment():
        buffer.write('[@${seg.name}](ik://profile/${seg.authorDocumentId})');
      case EmoteSegment():
        final url = urlMap[seg.code];
        if (url != null && url.isNotEmpty) {
          buffer.write('![:${seg.code}:]($url)');
        } else {
          buffer.write(':${seg.code}:');
        }
    }
  }

  return buffer.toString();
}

/// 内部联合 token 类型，用于排序和分段。
sealed class _Token {
  final int start;
  final int end;

  const _Token({required this.start, required this.end});

  factory _Token.mention({
    required int start,
    required int end,
    required String name,
    required String authorDocumentId,
  }) = _MentionToken;

  factory _Token.emote({
    required int start,
    required int end,
    required String code,
  }) = _EmoteToken;
}

class _MentionToken extends _Token {
  final String name;
  final String authorDocumentId;

  const _MentionToken({
    required super.start,
    required super.end,
    required this.name,
    required this.authorDocumentId,
  });
}

class _EmoteToken extends _Token {
  final String code;

  const _EmoteToken({
    required super.start,
    required super.end,
    required this.code,
  });
}
