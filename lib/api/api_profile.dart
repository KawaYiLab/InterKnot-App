part of 'api.dart';

extension ProfileApi on Api {
  Future<String?> findAuthorIdByName(String name) async {
    final res = await get(
      '/api/authors',
      query: {
        'filters[name][\$eq]': name,
        'pagination[limit]': '1',
      },
    );

    try {
      final list = unwrapData<List<dynamic>>(res);
      if (list.isNotEmpty) {
        final first = list.first;
        if (first is Map) {
          return first['documentId'] as String?;
        }
      }
    } catch (e) {
      debugPrint('FindAuthor Error: $e');
    }
    return null;
  }


  Future<String?> createAuthor({
    required String name,
    String? userId,
    bool ensureUniqueSlug = false,
  }) async {
    final slug = _slugify(name, ensureUnique: ensureUniqueSlug);
    final res = await post(
      '/api/authors',
      {
        'data': {
          'name': name,
          'slug': slug,
        },
      },
    );

    if (res.hasError) {
      // Simple retry logic for slug conflict if needed,
      // but strictly we should check the error message.
      if (res.bodyString?.contains('unique') == true) {
        debugPrint('Slug conflict detected, retrying find by name');
        await Future.delayed(const Duration(milliseconds: 300));
        return await findAuthorIdByName(name);
      }
    }

    try {
      final data = unwrapData<Map<String, dynamic>>(res);
      return data['documentId'] as String?;
    } catch (e) {
      debugPrint('CreateAuthor Error: $e');
      return null;
    }
  }


  Future<void> linkAuthorToUser({
    required String authorId,
    required String userId,
  }) async {
    final res = await put(
      '/api/authors/$authorId',
      {
        'data': {
          'user': _coerceId(userId),
        },
      },
    );
    if (res.hasError) {
      debugPrint('UpdateAuthor Error: ${res.bodyString}');
    }
  }


  Future<void> updateAuthor({
    required String authorId,
    required Map<String, dynamic> data,
  }) async {
    final res = await put(
      '/api/authors/$authorId',
      {'data': data},
    );
    if (res.hasError) {
      debugPrint('UpdateAuthorGeneric Error: ${res.bodyString}');
      throw ApiException(res.statusText ?? 'Update author failed');
    }
  }


  Future<String?> ensureAuthorId({
    required String name,
    String? userId,
  }) async {
    var existingId = await findAuthorIdByName(name);
    if (existingId != null && existingId.isNotEmpty) return existingId;

    // Exponential backoff
    int delay = 200;
    for (int i = 0; i < 3; i++) {
      await Future.delayed(Duration(milliseconds: delay));
      existingId = await findAuthorIdByName(name);
      if (existingId != null && existingId.isNotEmpty) return existingId;
      delay *= 2; // 200, 400, 800
    }

    debugPrint('Warning: Author not found after retries, creating as fallback');
    return createAuthor(name: name, ensureUniqueSlug: true);
  }


  Future<AuthorModel> getSelfUserInfo(String login) async {
    // /api/users/me returns the user directly
    final res = await get(
      '/api/users/me',
      query: {'populate': '*'},
    );

    final data = unwrapData<Map<String, dynamic>>(res);
    final user = AuthorModel.fromJson(data);
    await _fetchAndSetAvatar(user);
    return user;
  }


  Future<AuthorModel> updateUser(
      String userId, Map<String, dynamic> data) async {
    final res = await put(
      '/api/users/$userId',
      data,
    );

    final body = unwrapData<Map<String, dynamic>>(res);
    final user = AuthorModel.fromJson(body);
    return user;
  }


  Future<AuthorModel> getUserInfo(String username) async {
    final res = await get(
      '/api/profiles/$username',
      query: {'populate': '*'},
    );

    final body = unwrapData<Map<String, dynamic>>(res);
    final user = AuthorModel.fromJson(body);
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
