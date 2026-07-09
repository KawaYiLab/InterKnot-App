import 'package:flutter/material.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart';

/// 搜索建议项（GET /api/articles/suggest 或本地搜索历史）。
class SearchSuggestionModel {
  final String documentId;
  final String title;
  final String titleHighlighted;
  final String excerpt;
  final String? authorName;
  final String? categoryName;
  final String? categorySlug;
  final bool isAnonymous;
  final bool isHistory;
  final bool isViewAll;
  final String query;

  const SearchSuggestionModel({
    this.documentId = '',
    required this.title,
    this.titleHighlighted = '',
    this.excerpt = '',
    this.authorName,
    this.categoryName,
    this.categorySlug,
    this.isAnonymous = false,
    this.isHistory = false,
    this.isViewAll = false,
    this.query = '',
  });

  const SearchSuggestionModel.history(
    this.title, {
    this.query = '',
  })  : documentId = '',
        titleHighlighted = '',
        excerpt = '',
        authorName = null,
        categoryName = null,
        categorySlug = null,
        isAnonymous = false,
        isHistory = true,
        isViewAll = false;

  const SearchSuggestionModel.viewAll(this.query)
      : documentId = '',
        title = '',
        titleHighlighted = '',
        excerpt = '',
        authorName = null,
        categoryName = null,
        categorySlug = null,
        isAnonymous = false,
        isHistory = false,
        isViewAll = true;

  factory SearchSuggestionModel.fromJson(Map<String, dynamic> json) {
    return SearchSuggestionModel(
      documentId: json['documentId']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      titleHighlighted: json['titleHighlighted']?.toString() ?? '',
      excerpt: json['excerpt']?.toString() ?? '',
      authorName: json['authorName']?.toString(),
      categoryName: json['categoryName']?.toString(),
      categorySlug: json['categorySlug']?.toString(),
      isAnonymous: json['isAnonymous'] == true,
    );
  }

  SearchSuggestionModel copyWith({
    String? query,
  }) {
    return SearchSuggestionModel(
      documentId: documentId,
      title: title,
      titleHighlighted: titleHighlighted,
      excerpt: excerpt,
      authorName: authorName,
      categoryName: categoryName,
      categorySlug: categorySlug,
      isAnonymous: isAnonymous,
      isHistory: isHistory,
      isViewAll: isViewAll,
      query: query ?? this.query,
    );
  }

  /// 解析 titleHighlighted / excerpt 中的 `<mark>` 高亮，输出为 TextSpan 片段。
  static List<InlineSpan> buildHighlightSpans(
    String html, {
    TextStyle? baseStyle,
    TextStyle? highlightStyle,
  }) {
    final fragment = parseFragment(html);
    return _spansFromNodes(
      fragment.nodes,
      baseStyle ?? const TextStyle(color: Colors.white),
      highlightStyle ??
          const TextStyle(
            backgroundColor: Color(0xffD7FF00),
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
    );
  }

  static List<InlineSpan> _spansFromNodes(
    Iterable<dom.Node> nodes,
    TextStyle baseStyle,
    TextStyle highlightStyle,
  ) {
    final spans = <InlineSpan>[];
    for (final node in nodes) {
      if (node is dom.Text) {
        final text = node.text;
        if (text.isNotEmpty) {
          spans.add(TextSpan(text: text, style: baseStyle));
        }
      } else if (node is dom.Element) {
        if (node.localName == 'mark') {
          final text = node.text;
          if (text.isNotEmpty) {
            spans.add(TextSpan(text: text, style: highlightStyle));
          }
        } else {
          spans.addAll(_spansFromNodes(node.nodes, baseStyle, highlightStyle));
        }
      }
    }
    return spans;
  }
}
