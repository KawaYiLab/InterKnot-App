part of 'api.dart';

/// 搜索相关接口（@提及选人、搜索建议等）。
extension SearchApi on Api {
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
