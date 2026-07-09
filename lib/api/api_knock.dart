part of 'api.dart';

/// 敲敲（Knock Knock）会话与通知接口（阶段 2 实现）。
/// 后端参考：ikserver src/api/notification/controllers/notification.ts
extension KnockApi on Api {
  /// 获取会话列表（按 sender / 匿名 / 系统聚合）
  Future<List<KnockConversation>> getKnockConversations() async {
    final res = await getWithRetry('/api/knock/conversations');
    final body = res.body;
    if (body is! Map<String, dynamic>) return [];
    final data = body['data'];
    if (data is! List) return [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(KnockConversation.fromJson)
        .toList();
  }

  /// 获取单会话消息流（createdAt asc）
  Future<({List<NotificationModel> items, bool hasMore, String? nextCursor})>
      getKnockMessages(String conversationId, {String? cursor, int limit = 50}) async {
    final query = <String, String>{
      'limit': limit.toString(),
      if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
    };
    final res = await getWithRetry(
      '/api/knock/conversations/${Uri.encodeComponent(conversationId)}/messages',
      query: query,
    );
    final body = res.body;
    if (body is! Map<String, dynamic>) return (items: <NotificationModel>[], hasMore: false, nextCursor: null);
    final data = body['data'];
    final items = data is List
        ? data
            .whereType<Map<String, dynamic>>()
            .map((e) => NotificationModel.fromJson(e))
            .toList()
        : <NotificationModel>[];
    final meta = body['meta'] is Map<String, dynamic> ? body['meta'] as Map<String, dynamic> : null;
    final hasMore = meta?['hasMore'] == true;
    final nextCursor = meta?['nextCursor'] as String?;
    return (items: items, hasMore: hasMore, nextCursor: nextCursor);
  }

  /// 标记会话已读
  Future<int> markKnockConversationAsRead(String conversationId) async {
    final res = await postWithRetry(
      '/api/knock/conversations/${Uri.encodeComponent(conversationId)}/mark-read',
      {},
    );
    final body = res.body;
    if (body is Map<String, dynamic>) {
      return body['updated'] as int? ?? 0;
    }
    return 0;
  }
}
