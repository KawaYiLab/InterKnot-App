part of 'api.dart';

extension ArticleApi on Api {
  Future<DiscussionModel> getDiscussion(String id) async {
    final userId = box.read<String>('userId');

    final articleFuture = get('/api/articles/detail/$id');

    Future<Response>? readStatusFuture;
    if (userId != null && userId.isNotEmpty) {
      readStatusFuture = post(
        '/api/article-reads/batch',
        {
          'articleDocumentIds': [id],
        },
      );
    }

    final token = box.read<String>('access_token') ?? '';
    Future<Map<String, bool>>? likedFuture;
    if (token.isNotEmpty) {
      likedFuture = batchCheckLikes(
        targetType: 'article',
        targetIds: [id],
      );
    }

    final res = await articleFuture;
    final data = unwrapData<Map<String, dynamic>>(res);

    if (readStatusFuture != null) {
      try {
        final readRes = await readStatusFuture;
        final readData = unwrapData<List<dynamic>>(readRes);
        if (readData.isNotEmpty) {
          final first = readData.first;
          if (first is Map) {
            final isRead = first['isRead'] == true;
            data['isRead'] = isRead;
          }
        }
      } catch (e) {
        debugPrint('Failed to fetch read status: $e');
      }
    }

    if (likedFuture != null) {
      try {
        final likedMap = await likedFuture;
        if (likedMap.containsKey(id)) {
          data['liked'] = likedMap[id];
        }
      } catch (e) {
        debugPrint('Failed to fetch liked status: $e');
      }
    }

    final discussion = await compute(_parseDiscussionSync, data);
    final controller = Get.find<Controller>();
    controller.applyLocalOverrides(discussion);
    HDataModel.upsertCachedDiscussion(discussion);
    return discussion;
  }


  Future<DiscussionModel> getMyDraftDetail(String documentId) async {
    final res = await get('/api/articles/my/detail/$documentId');
    final data = unwrapData<Map<String, dynamic>>(res);

    final discussion = await compute(_parseEditableDraftDiscussionSync, data);
    final controller = Get.find<Controller>();
    controller.applyLocalOverrides(discussion);

    final user = controller.user.value;
    if (discussion.author.authorId == null ||
        discussion.author.authorId!.isEmpty ||
        discussion.author.name == 'Unknown') {
      discussion.author
        ..name = user?.name ?? user?.login ?? discussion.author.name
        ..login = user?.login ?? discussion.author.login
        ..avatar = user?.avatar ?? discussion.author.avatar
        ..authorId = controller.authorId.value ??
            user?.authorId ??
            discussion.author.authorId;
    }

    HDataModel.upsertCachedDiscussion(discussion);
    return discussion;
  }


  Future<DiscussionModel> getArticleDetail(String documentId) async {
    final res = await get('/api/articles/detail/$documentId');
    final data = unwrapData<Map<String, dynamic>>(res);

    final token = box.read<String>('access_token') ?? '';
    if (token.isNotEmpty) {
      try {
        final likedMap = await batchCheckLikes(
          targetType: 'article',
          targetIds: [documentId],
        );
        if (likedMap.containsKey(documentId)) {
          data['liked'] = likedMap[documentId];
        }
      } catch (e) {
        debugPrint('ArticleDetail Liked Status Error: $e');
      }
    }

    return _parseDiscussionSync(data);
  }


  Future<void> viewArticle(String id) async {
    await post('/api/articles/$id/view', {});
  }


  Future<PaginationModel<HDataModel>> search(
      String query, String endCur) async {
    final start = int.tryParse(endCur.isEmpty ? '0' : endCur) ?? 0;

    if (query.isEmpty) {
      final res = await get(
        '/api/articles/list',
        query: {
          'start': start.toString(),
          'limit': ApiConfig.defaultPageSize.toString(),
        },
      );

      final data = unwrapData<List<dynamic>>(res);

      await _mergeReadStatus(data, tag: 'Search');

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

    final res = await get(
      '/api/articles/search',
      query: {
        'q': query,
        'start': start.toString(),
        'limit': ApiConfig.defaultPageSize.toString(),
      },
    );

    final data = unwrapData<List<dynamic>>(res);

    await _mergeReadStatus(data, tag: 'Search');

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


  Future<PaginationModel<HDataModel>> getUserDiscussions(
      String authorId, String endCur) async {
    final start = int.tryParse(endCur.isEmpty ? '0' : endCur) ?? 0;

    final currentAuthorId = Get.find<Controller>().authorId.value;

    if (currentAuthorId == authorId) {
      final res = await get(
        '/api/articles/my/published',
        query: {
          'start': start.toString(),
          'limit': ApiConfig.defaultPageSize.toString(),
        },
      );

      final data = unwrapData<List<dynamic>>(res);
      await _mergeReadStatus(data, tag: 'MyPublishedDiscussions');
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

    final queryParams = <String, dynamic>{
      'pagination[start]': start.toString(),
      'pagination[limit]': ApiConfig.defaultPageSize.toString(),
      'sort': 'updatedAt:desc',
      'filters[author][documentId][\$eq]': authorId,
      'populate[author][populate]': 'avatar',
      'populate[cover][fields][0]': 'url',
      'populate[cover][fields][1]': 'width',
      'populate[cover][fields][2]': 'height',
      'populate[blocks][populate]': '*',
    };

    final res = await get(
      '/api/articles',
      query: queryParams,
    );

    final data = unwrapData<List<dynamic>>(res);

    await _mergeReadStatus(data, tag: 'UserDiscussions');

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


  Future<PaginationModel<HDataModel>> getMyDraftDiscussions(
      String endCur) async {
    final start = int.tryParse(endCur.isEmpty ? '0' : endCur) ?? 0;

    final res = await get(
      '/api/articles/my/drafts',
      query: {
        'start': start.toString(),
        'limit': ApiConfig.defaultPageSize.toString(),
      },
    );

    final data = unwrapData<List<dynamic>>(res);
    final hasNext = data.length >= ApiConfig.defaultPageSize;
    final result =
        await compute(_parseEditableDraftListAndDiscussionsSync, data);

    final controller = Get.find<Controller>();
    final user = controller.user.value;
    for (final discussion in result.discussions) {
      controller.applyLocalOverrides(discussion);
      if (discussion.author.authorId == null ||
          discussion.author.authorId!.isEmpty ||
          discussion.author.name == 'Unknown') {
        discussion.author
          ..name = user?.name ?? user?.login ?? discussion.author.name
          ..login = user?.login ?? discussion.author.login
          ..avatar = user?.avatar ?? discussion.author.avatar
          ..authorId = controller.authorId.value ??
              user?.authorId ??
              discussion.author.authorId;
      }
      HDataModel.upsertCachedDiscussion(discussion);
    }

    return PaginationModel(
      nodes: result.nodes,
      endCursor: (start + ApiConfig.defaultPageSize).toString(),
      hasNextPage: hasNext,
    );
  }


  Future<int> getUserDiscussionCount(String authorId) async {
    final res = await get(
      '/api/articles',
      query: {
        'filters[author][documentId][\$eq]': authorId,
        'pagination[limit]': '1',
        'fields[0]': 'documentId',
      },
    );

    if (res.hasError) return 0;

    final body = res.body;
    if (body is Map<String, dynamic>) {
      final meta = body['meta'];
      if (meta is Map<String, dynamic>) {
        final pagination = meta['pagination'];
        if (pagination is Map<String, dynamic>) {
          return pagination['total'] as int? ?? 0;
        }
      }
    }
    return 0;
  }


  Future<PaginationModel<HDataModel>> getPinnedDiscussions(String? endCur) {
    // Reusing search/list endpoint with isPinned=true filter
    final start = int.tryParse(endCur?.isEmpty == true ? '0' : endCur!) ?? 0;

    final queryParams = <String, dynamic>{
      'pagination[start]': start.toString(),
      'pagination[limit]': ApiConfig.defaultPageSize.toString(),
      'sort[0]': 'updatedAt:desc',
      'filters[isPinned][\$eq]': 'true',
      'populate[author][populate]': 'avatar',
      'populate[cover][fields][0]': 'url',
      'populate[cover][fields][1]': 'width',
      'populate[cover][fields][2]': 'height',
      'populate[blocks][populate]': '*',
    };

    return get(
      '/api/articles',
      query: queryParams.map((k, v) => MapEntry(k, v.toString())),
    ).then((res) {
      final data = unwrapData<List<dynamic>>(res);
      final hasNext = data.length >= ApiConfig.defaultPageSize;
      return PaginationModel(
        nodes: data
            .map((e) => HDataModel.fromJson(e as Map<String, dynamic>))
            .toList(),
        endCursor: (start + ApiConfig.defaultPageSize).toString(),
        hasNextPage: hasNext,
      );
    });
  }


  Future<Response<Map<String, dynamic>>> createArticleDraft({
    String title = '',
    String text = '',
    List<dynamic>? editorState,
    dynamic coverId,
    String? authorId,
  }) {
    final Map<String, dynamic> data = {
      'title': title,
      'text': text,
      'editorState': editorState,
    };

    final normalizedCover = _normalizeArticleCover(coverId);
    if (normalizedCover != null) {
      data['cover'] = normalizedCover;
    }

    if (authorId != null && authorId.isNotEmpty) {
      data['author'] = _coerceId(authorId);
    }

    return post(
      '/api/articles',
      {'data': data},
      query: {'status': 'draft'},
    );
  }


  Future<Response<Map<String, dynamic>>> updateArticleDraft({
    required String id,
    String? title,
    String? text,
    List<dynamic>? editorState,
    dynamic coverId,
    String? authorId,
  }) {
    final Map<String, dynamic> data = {};
    if (title != null) data['title'] = title;
    if (text != null) data['text'] = text;
    data['editorState'] = editorState;
    final normalizedCover = _normalizeArticleCover(coverId);
    if (coverId is List && coverId.isEmpty) {
      data['cover'] = [];
    } else if (normalizedCover != null) {
      data['cover'] = normalizedCover;
    }
    if (authorId != null && authorId.isNotEmpty) {
      data['author'] = _coerceId(authorId);
    }

    return put(
      '/api/articles/$id',
      {'data': data},
      query: {'status': 'draft'},
    );
  }


  Future<Response<Map<String, dynamic>>> publishArticleDraft({
    required String id,
    CaptchaPayload? captcha,
  }) {
    return post(
      '/api/articles/$id/publish',
      _withCaptcha(<String, dynamic>{}, captcha),
    );
  }


  Future<Response<Map<String, dynamic>>> unpublishArticleDraft(
    String id, {
    bool discardDraft = false,
  }) {
    return post(
      '/api/articles/$id/unpublish',
      {
        'discardDraft': discardDraft,
      },
    );
  }


  Future<Response<Map<String, dynamic>>> deleteDiscussion(String id) =>
      delete('/api/articles/$id');


}
