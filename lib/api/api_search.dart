part of 'api.dart';

/// 搜索相关接口（@提及选人、搜索建议等）。
extension SearchApi on Api {
  /// 实时搜索联想（GET /api/articles/suggest）。
  Future<List<SearchSuggestionModel>> searchSuggestions(
    String q, {
    String? categorySlug,
    int limit = 8,
  }) async {
    final trimmed = q.trim();
    if (trimmed.isEmpty) return [];

    final res = await getWithRetry(
      '/api/articles/suggest',
      query: {
        'q': trimmed,
        'limit': limit.toString(),
        if (categorySlug != null && categorySlug.isNotEmpty)
          'categorySlug': categorySlug,
      },
      operationName: 'Search suggestions',
    );

    final data = unwrapData<List<dynamic>>(res);
    return data
        .whereType<Map<String, dynamic>>()
        .map(SearchSuggestionModel.fromJson)
        .where((s) => s.documentId.isNotEmpty && s.title.isNotEmpty)
        .toList();
  }

  Future<List<MentionCandidateModel>> searchAuthors(
    String q, {
    int limit = 8,
  }) async {
    final trimmed = q.trim();
    if (trimmed.isEmpty) return [];

    final res = await get(
      '/api/authors/search',
      query: {
        'q': trimmed,
        'limit': limit.toString(),
      },
    );

    final data = unwrapData<List<dynamic>>(res);
    return data
        .whereType<Map<String, dynamic>>()
        .map(MentionCandidateModel.fromJson)
        .where((c) => c.documentId.isNotEmpty && c.name.isNotEmpty)
        .toList();
  }
}
