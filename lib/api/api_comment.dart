part of 'api.dart';

extension CommentApi on Api {
  Future<PaginationModel<CommentModel>> getComments(
      String id, String endCur) async {
    final start = int.tryParse(endCur.isEmpty ? '0' : endCur) ?? 0;

    final queryParams = {
      'article': id,
      'start': start.toString(),
      'limit': ApiConfig.defaultPageSize.toString(),
      'ts': DateTime.now().millisecondsSinceEpoch.toString(),
    };

    final res = await get(
      '/api/comments/list',
      query: queryParams,
    );

    final data = unwrapData<List<dynamic>>(res);
    final comments = await compute(_parseCommentListSync, data);

    // Batch check liked status for comments
    try {
      final token = box.read<String>('access_token') ?? '';
      if (token.isNotEmpty && comments.isNotEmpty) {
        final allIds = <String>[];
        for (final c in comments) {
          allIds.add(c.id);
          for (final r in c.replies) {
            allIds.add(r.id);
          }
        }
        if (allIds.isNotEmpty) {
          final likedMap = await batchCheckLikes(
            targetType: 'comment',
            targetIds: allIds,
          );
          if (likedMap.isNotEmpty) {
            for (final c in comments) {
              if (likedMap.containsKey(c.id)) c.liked = likedMap[c.id]!;
              for (final r in c.replies) {
                if (likedMap.containsKey(r.id)) r.liked = likedMap[r.id]!;
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Comment Liked Status Error: $e');
    }

    final hasNextPage = comments.length >= ApiConfig.defaultPageSize;
    final nextEndCur =
        hasNextPage ? (start + ApiConfig.defaultPageSize).toString() : null;

    return PaginationModel(
      nodes: comments,
      hasNextPage: hasNextPage,
      endCursor: nextEndCur,
    );
  }


  /// 取服务端评论总数。后端已移除 /api/comments/count，改用 /api/comments/list
  /// 的 meta.pagination.total（用最小分页避免拉全量）。
  Future<int> getCommentCount(String discussionId) async {
    final res = await get(
      '/api/comments/list',
      query: {
        'article': discussionId,
        'start': '0',
        'limit': '1',
        'ts': DateTime.now().millisecondsSinceEpoch.toString(),
      },
    );

    if (res.hasError) return 0;

    final body = res.body;
    if (body is Map) {
      final meta = body['meta'];
      if (meta is Map) {
        final pagination = meta['pagination'];
        if (pagination is Map) {
          final total = pagination['total'];
          if (total is int) return total;
          return int.tryParse(total?.toString() ?? '') ?? 0;
        }
      }
    }
    return 0;
  }


  Future<Response<Map<String, dynamic>>> addDiscussionComment(
    String discussionId,
    String body, {
    String? authorId,
    String? parentId,
    List<String>? imageIds,
  }) {
    if (discussionId.isEmpty) {
      throw ApiException('Discussion ID cannot be empty');
    }

    debugPrint(
        'Adding comment to discussion: $discussionId, author: $authorId, parent: $parentId, images: $imageIds');

    final data = <String, dynamic>{
      'article': discussionId,
      'content': body,
      if (authorId != null && authorId.isNotEmpty) 'author': authorId,
      if (parentId != null && parentId.isNotEmpty) 'parent': parentId,
      if (imageIds != null && imageIds.isNotEmpty) 'images': imageIds,
    };

    return post(
      '/api/comments',
      {'data': data},
    );
  }


  Future<Response<Map<String, dynamic>>> deleteComment(String id) =>
      delete('/api/comments/$id');


}
