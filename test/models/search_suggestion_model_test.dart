import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inter_knot/models/search_suggestion.dart';

void main() {
  group('SearchSuggestionModel', () {
    test('parses backend suggestion json', () {
      const json = {
        'documentId': 'abc123',
        'title': '绝区零攻略',
        'titleHighlighted': '绝区零<mark>攻略</mark>',
        'excerpt': '这是一篇<mark>攻略</mark>',
        'authorName': 'Author',
        'categoryName': '攻略',
        'categorySlug': 'guide',
        'isAnonymous': false,
      };

      final s = SearchSuggestionModel.fromJson(json);

      expect(s.documentId, 'abc123');
      expect(s.title, '绝区零攻略');
      expect(s.titleHighlighted, '绝区零<mark>攻略</mark>');
      expect(s.excerpt, '这是一篇<mark>攻略</mark>');
      expect(s.authorName, 'Author');
      expect(s.categoryName, '攻略');
      expect(s.categorySlug, 'guide');
      expect(s.isAnonymous, false);
    });

    test('handles missing optional fields safely', () {
      const json = {
        'documentId': 'abc123',
        'title': '绝区零攻略',
      };

      final s = SearchSuggestionModel.fromJson(json);

      expect(s.authorName, isNull);
      expect(s.categoryName, isNull);
      expect(s.categorySlug, isNull);
      expect(s.isAnonymous, false);
    });

    test('history and viewAll constructors use correct flags', () {
      const history = SearchSuggestionModel.history('keyword');
      const viewAll = SearchSuggestionModel.viewAll('keyword');

      expect(history.isHistory, true);
      expect(history.isViewAll, false);
      expect(history.title, 'keyword');

      expect(viewAll.isHistory, false);
      expect(viewAll.isViewAll, true);
      expect(viewAll.query, 'keyword');
    });

    test('buildHighlightSpans separates plain and marked text', () {
      const html = '绝区零<mark>攻略</mark>指南';
      final spans = SearchSuggestionModel.buildHighlightSpans(
        html,
        baseStyle: const TextStyle(color: Colors.white),
        highlightStyle: const TextStyle(color: Colors.black),
      );

      expect(spans.length, 3);
      expect((spans[0] as TextSpan).text, '绝区零');
      expect((spans[1] as TextSpan).text, '攻略');
      expect((spans[1] as TextSpan).style?.color, Colors.black);
      expect((spans[2] as TextSpan).text, '指南');
    });

    test('buildHighlightSpans preserves inter-word spaces around marks', () {
      const html = 'Hello <mark>world</mark> test';
      final spans = SearchSuggestionModel.buildHighlightSpans(
        html,
        baseStyle: const TextStyle(color: Colors.white),
        highlightStyle: const TextStyle(color: Colors.black),
      );

      expect(spans.length, 3);
      expect((spans[0] as TextSpan).text, 'Hello ');
      expect((spans[1] as TextSpan).text, 'world');
      expect((spans[2] as TextSpan).text, ' test');
    });
  });
}
