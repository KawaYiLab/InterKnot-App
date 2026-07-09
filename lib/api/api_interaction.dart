part of 'api.dart';

extension InteractionApi on Api {
  Future<({List<HDataModel> items})> getFavorites(
      String username, String endCur) async {
    final start = int.tryParse(endCur.isEmpty ? '0' : endCur) ?? 0;

    // 收藏 feed 依赖登录态，需显式携带 token（GET /api/articles 默认匿名）。
    final token = box.read<String>('access_token') ?? '';
    if (token.isEmpty) return (items: <HDataModel>[]);

    final res = await get(
      '/api/articles/list',
      query: {
        'feed': 'favorites',
        'start': start.toString(),
        'limit': ApiConfig.defaultPageSize.toString(),
      },
      headers: {'Authorization': 'Bearer $token'},
    );

    List<dynamic> list;
    try {
      list = unwrapData<List<dynamic>>(res);
    } catch (e) {
      return (items: <HDataModel>[]);
    }

    final items = <HDataModel>[];

    for (final entry in list) {
      if (entry is! Map<String, dynamic>) continue;
      final hData = HDataModel.fromJson(entry);
      if (hData.id.isNotEmpty) {
        items.add(hData);
      }
    }
    return (items: items);
  }


  Future<({bool favorited, int favoritesCount})> toggleFavorite(
      String articleId) async {
    final res = await post(
      '/api/favorites/toggle',
      {'targetId': articleId},
    );

    if (res.hasError) {
      debugPrint('ToggleFavorite Error: ${res.statusCode} - ${res.bodyString}');
      final body = res.body;
      String msg = '收藏操作失败';
      if (body is Map) {
        final error = body['error'];
        if (error is Map && error['message'] != null) {
          msg = error['message'].toString();
        }
      }
      throw ApiException(msg, statusCode: res.statusCode);
    }

    final body = res.body;
    if (body is Map<String, dynamic>) {
      return (
        favorited: body['favorited'] == true,
        favoritesCount: (body['favoritesCount'] as num?)?.toInt() ?? 0,
      );
    }
    throw ApiException('Invalid toggle favorite response');
  }

  Future<Map<String, bool>> batchCheckFavorites(
      List<String> targetIds) async {
    if (targetIds.isEmpty) return {};

    final token = box.read<String>('access_token') ?? '';
    if (token.isEmpty) return {};

    final res = await get(
      '/api/favorites/check',
      query: {'targetIds': targetIds.join(',')},
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.hasError) {
      debugPrint(
          'BatchCheckFavorites Error: ${res.statusCode} - ${res.bodyString}');
      return {};
    }

    final body = res.body;
    if (body is Map<String, dynamic>) {
      final data = body['data'];
      if (data is Map) {
        return data.map((k, v) => MapEntry(k.toString(), v == true));
      }
    }
    return {};
  }

  Future<({
    bool liked,
    int likesCount,
    bool favorited,
    int favoritesCount,
    bool coinGiven,
    String coinReason,
    int dennyCount,
    int? newBalance,
  })> tripleAction(String articleId) async {
    final res = await post(
      '/api/articles/triple',
      {'articleId': articleId},
    );

    if (res.hasError) {
      debugPrint('TripleAction Error: ${res.statusCode} - ${res.bodyString}');
      final body = res.body;
      String msg = '三连失败';
      if (body is Map) {
        final error = body['error'];
        if (error is Map && error['message'] != null) {
          msg = error['message'].toString();
        }
      }
      throw ApiException(msg, statusCode: res.statusCode);
    }

    final body = res.body;
    if (body is Map<String, dynamic>) {
      return (
        liked: body['liked'] == true,
        likesCount: (body['likesCount'] as num?)?.toInt() ?? 0,
        favorited: body['favorited'] == true,
        favoritesCount: (body['favoritesCount'] as num?)?.toInt() ?? 0,
        coinGiven: body['coinGiven'] == true,
        coinReason: body['coinReason']?.toString() ?? 'FAILED',
        dennyCount: (body['dennyCount'] as num?)?.toInt() ?? 0,
        newBalance: body['newBalance'] is int ? body['newBalance'] as int : null,
      );
    }
    throw ApiException('Invalid triple action response');
  }


  Future<void> markAsRead(String articleId) async {
    final userId = box.read<String>('userId');
    if (userId == null || userId.isEmpty) return;

    // Check if exists
    final checkRes = await get(
      '/api/article-reads',
      query: {
        'filters[user][id][\$eq]': userId,
        'filters[article][documentId][\$eq]': articleId,
        'fields[0]': 'isRead',
        'fields[1]': 'documentId',
      },
    );

    try {
      final list = unwrapData<List<dynamic>>(checkRes);
      if (list.isNotEmpty) {
        final item = list.first as Map;
        final isRead = item['isRead'] == true;
        final docId = item['documentId'] as String?;
        if (!isRead && docId != null) {
          // Update
          await put(
            '/api/article-reads/$docId',
            {
              'data': {'isRead': true}
            },
          );
        }
      } else {
        // Create
        await post(
          '/api/article-reads',
          {
            'data': {
              'user': _coerceId(userId),
              'article': articleId,
              'isRead': true,
            }
          },
        );
      }
    } catch (e) {
      debugPrint('MarkAsRead Error: $e');
    }
  }


  Future<({bool liked, int likesCount})> toggleLike({
    required String targetType,
    required String targetId,
  }) async {
    final res = await post(
      '/api/likes/toggle',
      {
        'targetType': targetType,
        'targetId': targetId,
      },
    );

    if (res.hasError) {
      debugPrint('ToggleLike Error: ${res.statusCode} - ${res.bodyString}');
      final body = res.body;
      String msg = 'Toggle like failed';
      if (body is Map) {
        final error = body['error'];
        if (error is Map && error['message'] != null) {
          msg = error['message'].toString();
        }
      }
      throw ApiException(msg, statusCode: res.statusCode);
    }

    final body = res.body;
    if (body is Map<String, dynamic>) {
      return (
        liked: body['liked'] == true,
        likesCount: (body['likesCount'] as num?)?.toInt() ?? 0,
      );
    }
    throw ApiException('Invalid toggle like response');
  }

  Future<Map<String, bool>> batchCheckLikes({
    required String targetType,
    required List<String> targetIds,
  }) async {
    if (targetIds.isEmpty) return {};

    final token = box.read<String>('access_token') ?? '';
    if (token.isEmpty) return {};

    final res = await get(
      '/api/likes/check',
      query: {
        'targetType': targetType,
        'targetIds': targetIds.join(','),
      },
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.hasError) {
      debugPrint(
          'BatchCheckLikes Error: ${res.statusCode} - ${res.bodyString}');
      return {};
    }

    final body = res.body;
    if (body is Map<String, dynamic>) {
      final data = body['data'];
      if (data is Map) {
        return data.map((k, v) => MapEntry(k.toString(), v == true));
      }
    }
    return {};
  }
}
