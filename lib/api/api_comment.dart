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


  Future<Response<Map<String, dynamic>>> addDiscussionComment(
    String discussionId,
    String body, {
    String? authorId,
    String? parentId,
    CaptchaPayload? captcha,
  }) {
    if (discussionId.isEmpty) {
      throw ApiException('Discussion ID cannot be empty');
    }

    debugPrint(
        'Adding comment to discussion: $discussionId, author: $authorId, parent: $parentId');

    final data = <String, dynamic>{
      'article': discussionId,
      'content': body,
      if (authorId != null && authorId.isNotEmpty) 'author': authorId,
      if (parentId != null && parentId.isNotEmpty) 'parent': parentId,
    };

    return post(
      '/api/comments',
      _withCaptcha({'data': data}, captcha),
    );
  }


  Future<Response<Map<String, dynamic>>> deleteComment(String id) =>
      delete('/api/comments/$id');


}
