part of 'api.dart';

extension InteractionApi on Api {
  Future<({List<HDataModel> items, Map<String, String> favoriteIds})>
      getFavorites(String username, String endCur) async {
    final start = int.tryParse(endCur.isEmpty ? '0' : endCur) ?? 0;

    final res = await get(
      '/api/favorites/list',
      query: {
        'start': start.toString(),
        'limit': ApiConfig.defaultPageSize.toString(),
      },
    );

    List<dynamic> list;
    try {
      list = unwrapData<List<dynamic>>(res);
    } catch (e) {
      return (items: <HDataModel>[], favoriteIds: <String, String>{});
    }

    final items = <HDataModel>[];
    final favoriteIds = <String, String>{};

    for (final entry in list) {
      if (entry is! Map) continue;
      final favoriteId = entry['documentId']?.toString();
      final article = entry['article'];

      if (article is Map<String, dynamic>) {
        final hData = HDataModel.fromJson(article);
        if (hData.id.isNotEmpty) {
          items.add(hData);
          if (favoriteId != null && favoriteId.isNotEmpty) {
            favoriteIds[hData.id] = favoriteId;
          }
        }
      }
    }
    return (items: items, favoriteIds: favoriteIds);
  }


  Future<String?> getFavoriteId({
    required String username,
    required String articleId,
  }) async {
    final res = await get(
      '/api/favorites',
      query: {
        'filters[user][username][\$eq]': username,
        'filters[article][documentId][\$eq]': articleId,
        'pagination[limit]': '1',
      },
    );

    try {
      final list = unwrapData<List<dynamic>>(res);
      if (list.isNotEmpty) {
        final first = list.first;
        if (first is Map) {
          return first['documentId']?.toString();
        }
      }
    } catch (e) {
      debugPrint('GetFavoriteId Error: $e');
    }
    return null;
  }


  Future<String?> createFavorite({
    required String userId,
    required String articleId,
  }) async {
    final res = await post(
      '/api/favorites',
      {
        'data': {
          'user': _coerceId(userId),
          'article': articleId,
        },
      },
    );

    try {
      final data = unwrapData<Map<String, dynamic>>(res);
      return data['documentId']?.toString();
    } catch (e) {
      debugPrint('CreateFavorite Error: $e');
      return null;
    }
  }


  Future<bool> deleteFavorite(String favoriteId) async {
    final res = await delete('/api/favorites/$favoriteId');
    return !res.hasError;
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
