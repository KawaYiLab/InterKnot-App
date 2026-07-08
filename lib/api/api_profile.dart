part of 'api.dart';

extension ProfileApi on Api {
  Future<AuthorModel> getSelfUserInfo(String login) async {
    // /api/users/me returns the user directly
    final res = await get(
      '/api/users/me',
      query: {'populate': '*'},
    );

    final data = unwrapData<Map<String, dynamic>>(res);
    // /api/users/me 不带 author 关联，避免 fromJson 回退到 user documentId
    data.remove('documentId');
    final user = AuthorModel.fromJson(data);
    try {
      final profile = await getMyProfile();
      final author = profile['author'];
      final id = author is Map ? author['documentId']?.toString() : null;
      if (id != null && id.isNotEmpty) {
        user.authorId = id;
      }
    } catch (_) {
      // author 关联获取失败时保持为空，后续 ensureAuthorForUser 会重试。
    }
    await _fetchAndSetAvatar(user);
    return user;
  }


  Future<String?> getAuthorAvatarUrl(String authorId) async {
    final res = await get(
      '/api/profiles/$authorId',
      query: {'populate': 'avatar'},
    );
    final profileData = unwrapData<Map<String, dynamic>>(res);
    final url = AuthorModel.extractAvatarUrl(profileData['avatar']);
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    if (url.startsWith('/')) return '${ApiConfig.baseUrl}$url';
    return '${ApiConfig.baseUrl}/$url';
  }

  Future<Map<String, dynamic>> getProfile(String documentId) async {
    final res = await get('/api/profiles/$documentId');
    return unwrapData<Map<String, dynamic>>(res);
  }

  Future<PaginationModel<HDataModel>> getProfileArticles(
    String documentId,
    String endCur, {
    Map<String, dynamic>? authorData,
  }) async {
    final start = int.tryParse(endCur.isEmpty ? '0' : endCur) ?? 0;

    final res = await get(
      '/api/profiles/$documentId/articles',
      query: {
        'start': start.toString(),
        'limit': ApiConfig.defaultPageSize.toString(),
      },
    );

    final data = unwrapData<List<dynamic>>(res);

    if (authorData != null) {
      for (final article in data) {
        if (article is Map<String, dynamic>) {
          article['author'] = authorData;
        }
      }
    }

    await _mergeReadStatus(data, tag: 'ProfileArticles');

    final hasNext = data.length >= ApiConfig.defaultPageSize;
    final result = await compute(_parseHDataListAndDiscussionsSync, data);

    final controller = Get.find<Controller>();
    for (final discussion in result.discussions) {
      controller.applyLocalOverrides(discussion);
      HDataModel.upsertCachedDiscussion(discussion);
    }

    return PaginationModel(
      nodes: result.nodes,
      endCursor: (start + ApiConfig.defaultPageSize).toString(),
      hasNextPage: hasNext,
    );
  }

  Future<PaginationModel<Map<String, dynamic>>> getProfileComments(
    String documentId,
    String endCur,
  ) async {
    final start = int.tryParse(endCur.isEmpty ? '0' : endCur) ?? 0;

    final res = await get(
      '/api/profiles/$documentId/comments',
      query: {
        'start': start.toString(),
        'limit': ApiConfig.defaultPageSize.toString(),
      },
    );

    final data = unwrapData<List<dynamic>>(res);
    final comments = data.cast<Map<String, dynamic>>();

    final hasNext = comments.length >= ApiConfig.defaultPageSize;

    return PaginationModel(
      nodes: comments,
      endCursor: (start + ApiConfig.defaultPageSize).toString(),
      hasNextPage: hasNext,
    );
  }
}
