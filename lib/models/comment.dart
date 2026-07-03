import 'package:inter_knot/constants/api_config.dart';
import 'package:inter_knot/helpers/normalize_markdown.dart';
import 'package:inter_knot/helpers/parse_html.dart';
import 'package:inter_knot/helpers/use.dart';
import 'package:inter_knot/models/author.dart';

String? _normalizeMediaUrl(String? url) {
  if (url == null || url.isEmpty) return null;
  if (url.startsWith('http://') || url.startsWith('https://')) return url;
  if (url.startsWith('/')) return '${ApiConfig.baseUrl}$url';
  return '${ApiConfig.baseUrl}/$url';
}

String? _extractMediaUrl(dynamic raw) {
  if (raw is String) {
    return _normalizeMediaUrl(raw);
  }
  if (raw is! Map) return null;

  final directUrl = raw['url'] as String?;
  if (directUrl != null && directUrl.isNotEmpty) {
    return _normalizeMediaUrl(directUrl);
  }

  final data = raw['data'];
  if (data is Map) {
    final nestedUrl = data['url'] as String?;
    if (nestedUrl != null && nestedUrl.isNotEmpty) {
      return _normalizeMediaUrl(nestedUrl);
    }
    final attributes = data['attributes'];
    if (attributes is Map) {
      final attrUrl = attributes['url'] as String?;
      if (attrUrl != null && attrUrl.isNotEmpty) {
        return _normalizeMediaUrl(attrUrl);
      }
    }
  }

  final attributes = raw['attributes'];
  if (attributes is Map) {
    final attrUrl = attributes['url'] as String?;
    if (attrUrl != null && attrUrl.isNotEmpty) {
      return _normalizeMediaUrl(attrUrl);
    }
  }

  return null;
}

List<String> _extractImages(dynamic raw) {
  if (raw is String) {
    final url = _normalizeMediaUrl(raw);
    return url == null ? const <String>[] : <String>[url];
  }
  if (raw is Map) {
    final url = _extractMediaUrl(raw);
    return url == null ? const <String>[] : <String>[url];
  }
  if (raw is! List) return const <String>[];

  final result = <String>[];
  for (final item in raw) {
    final url = _extractMediaUrl(item);
    if (url != null && url.isNotEmpty) {
      result.add(url);
    }
  }
  return result;
}

class CommentModel {
  final AuthorModel author;
  final String bodyHTML;
  final DateTime createdAt;
  final DateTime? lastEditedAt;
  final replies = <CommentModel>{};
  final String id;
  final String url;
  final List<String> images;
  final String? articleId;
  final String? articleTitle;
  int likesCount;
  bool liked;

  CommentModel({
    required this.author,
    required this.bodyHTML,
    required this.createdAt,
    required this.lastEditedAt,
    required Iterable<CommentModel> replies,
    required this.id,
    required this.url,
    this.images = const [],
    this.articleId,
    this.articleTitle,
    this.likesCount = 0,
    this.liked = false,
  }) {
    this.replies.addAll(replies);
  }

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    // 处理 content 字段（可能是 Markdown 或 HTML）
    final content =
        json['content'] as String? ?? json['bodyHTML'] as String? ?? '';
    final normalized = normalizeMarkdown(content);
    final (:cover, :html) = parseHtml(normalized, true);

    final repliesData = json['replies'];
    final repliesList = <CommentModel>[];
    if (repliesData is List) {
      for (final r in repliesData) {
        if (r is Map<String, dynamic>) {
          repliesList.add(CommentModel.fromJson(r));
        }
      }
    } else if (repliesData is Map<String, dynamic>) {
      // Handle Strapi v5 relation response if it's not a list directly but wrapped
      // or if it's a single object (unlikely for oneToMany but possible)
      // Usually relations come as List in JSON if populated
    }

    final articleData = json['article'];
    final articleMap = articleData is Map<String, dynamic> ? articleData : null;

    return CommentModel(
      author: AuthorModel.fromJson(json['author'] as Map<String, dynamic>),
      bodyHTML: html,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastEditedAt:
          (json['updatedAt'] as String?).use((v) => DateTime.parse(v)),
      replies: repliesList,
      id: (json['documentId'] as String?) ?? json['id']?.toString() ?? '',
      url: '', // URL not supported yet
      images: _extractImages(json['images']),
      articleId: articleMap == null
          ? json['articleId']?.toString()
          : (articleMap['documentId']?.toString() ??
              articleMap['id']?.toString()),
      articleTitle: articleMap == null
          ? json['articleTitle']?.toString()
          : articleMap['title']?.toString(),
      likesCount: (json['likescount'] ?? json['likesCount'] ?? 0) is int
          ? (json['likescount'] ?? json['likesCount'] ?? 0) as int
          : int.tryParse(
                  (json['likescount'] ?? json['likesCount'] ?? 0).toString()) ??
              0,
      liked: json['liked'] == true,
    );
  }

  @override
  bool operator ==(Object other) => other is CommentModel && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
