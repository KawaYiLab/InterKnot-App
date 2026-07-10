part of 'api.dart';

/// 私信（DM）接口与 WebSocket 协议封装（阶段 2 实现）。
/// 协议参考 Web 端 useDmStream.ts 与 useDmConversations.ts。
extension DmApi on Api {
  /// 获取 DM 会话列表（已融合通知聚合）
  Future<List<DmConversationSummary>> getDmConversations() async {
    final res = await getWithRetry('/api/dm/conversations');
    final body = res.body;
    if (body is! Map<String, dynamic>) return [];
    final data = body['data'];
    if (data is! List) return [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(DmConversationSummary.fromJson)
        .toList();
  }

  /// 取/建私聊会话
  Future<({DmConversationSummary summary, bool isNew})> openDirectConversation(
      int targetUserId) async {
    final res = await postWithRetry(
      '/api/dm/conversations/direct',
      {'targetUserId': targetUserId},
    );
    final body = res.body;
    if (body is! Map<String, dynamic>) {
      throw ApiException('私信对话数据格式异常');
    }
    final data = body['data'];
    if (data is! Map<String, dynamic>) {
      throw ApiException('私信对话数据格式异常');
    }
    return (
      summary: DmConversationSummary.fromJson(data),
      isNew: body['isNew'] == true,
    );
  }

  /// 获取某会话消息流（createdAt asc）
  Future<({List<DmMessage> items, bool hasMore, String? nextCursor})>
      getDmMessages(String conversationId,
          {String? before, int limit = 50}) async {
    final query = <String, String>{
      'limit': limit.toString(),
      if (before != null && before.isNotEmpty) 'before': before,
    };
    final res = await getWithRetry(
      '/api/dm/conversations/${Uri.encodeComponent(conversationId)}/messages',
      query: query,
    );
    final body = res.body;
    if (body is! Map<String, dynamic>) {
      return (items: <DmMessage>[], hasMore: false, nextCursor: null);
    }
    final data = body['data'];
    final items = data is List
        ? data
            .whereType<Map<String, dynamic>>()
            .map(DmMessage.fromJson)
            .toList()
        : <DmMessage>[];
    final meta =
        body['meta'] is Map<String, dynamic> ? body['meta'] as Map<String, dynamic> : null;
    final hasMore = meta?['hasMore'] == true;
    final nextCursor = meta?['nextCursor'] as String?;
    return (items: items, hasMore: hasMore, nextCursor: nextCursor);
  }

  /// 发送消息
  Future<DmMessage> sendDmMessage(
    String conversationId, {
    required String content,
    String? replyTo,
    String kind = 'text',
  }) async {
    final res = await postWithRetry(
      '/api/dm/conversations/${Uri.encodeComponent(conversationId)}/messages',
      {
        'content': content,
        if (replyTo != null && replyTo.isNotEmpty) 'replyTo': replyTo,
        'kind': kind,
      },
    );
    final body = res.body;
    if (body is! Map<String, dynamic>) {
      throw ApiException('私信发送失败');
    }
    final data = body['data'];
    if (data is! Map<String, dynamic>) {
      throw ApiException('私信发送失败');
    }
    return DmMessage.fromJson(data);
  }

  /// 编辑消息
  Future<void> editDmMessage(String messageId, String content) async {
    await patchWithRetry(
      '/api/dm/messages/${Uri.encodeComponent(messageId)}',
      {'content': content},
    );
  }

  /// 撤回消息
  Future<void> withdrawDmMessage(String messageId) async {
    await deleteWithRetry('/api/dm/messages/${Uri.encodeComponent(messageId)}');
  }

  /// 标记会话已读
  Future<void> markDmConversationAsRead(String conversationId) async {
    await patchWithRetry(
      '/api/dm/conversations/${Uri.encodeComponent(conversationId)}/read',
      {},
    );
  }

  /// 一键已读
  Future<void> markAllDmAsRead() async {
    await postWithRetry('/api/dm/read-all', {});
  }

  /// 离开会话
  Future<void> leaveDmConversation(String conversationId) async {
    await postWithRetry(
      '/api/dm/conversations/${Uri.encodeComponent(conversationId)}/leave',
      {},
    );
  }

  /// 更新会话偏好（muted/pinned/title）
  Future<void> updateDmConversation(
    String conversationId, {
    bool? muted,
    bool? pinned,
    String? title,
  }) async {
    await patchWithRetry(
      '/api/dm/conversations/${Uri.encodeComponent(conversationId)}',
      {
        if (muted != null) 'muted': muted,
        if (pinned != null) 'pinned': pinned,
        if (title != null) 'title': title,
      },
    );
  }

  /// 重置 AI 对话上下文
  Future<void> resetDmContext(String conversationId) async {
    await postWithRetry(
      '/api/dm/conversations/${Uri.encodeComponent(conversationId)}/reset-context',
      {},
    );
  }

  /// 获取 WebSocket 一次性 ticket
  Future<({String ticket, int ttlSec})> getDmSocketTicket() async {
    final res = await postWithRetry('/api/dm/socket/ticket', {});
    final body = res.body;
    if (body is! Map<String, dynamic>) {
      throw ApiException('会话票据数据格式异常');
    }
    final data = body['data'];
    if (data is! Map<String, dynamic>) {
      throw ApiException('会话票据数据格式异常');
    }
    return (
      ticket: data['ticket'] as String? ?? '',
      ttlSec: data['ttlSec'] as int? ?? 30,
    );
  }
}
