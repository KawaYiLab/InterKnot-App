import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:inter_knot/api/api.dart';
import 'package:inter_knot/controllers/data.dart';
import 'package:inter_knot/models/ai_role_card.dart';
import 'package:inter_knot/models/dm_conversation.dart';
import 'package:inter_knot/models/dm_event.dart';
import 'package:inter_knot/models/dm_message.dart';
import 'package:inter_knot/models/knock_conversation.dart';
import 'package:inter_knot/models/knock_sse_event.dart';
import 'package:inter_knot/models/notification.dart';
import 'package:inter_knot/services/dm_web_socket_service.dart';
import 'package:inter_knot/services/knock_sse_service.dart';

/// 阶段 2：敲敲 + DM 统一控制器。
class MessagingController extends GetxController {
  final Api api = Get.find<Api>();

  final KnockSseService _knockSse = KnockSseService();
  late final DmWebSocketService _dmWs;

  final isLoading = false.obs;
  final isDmLoading = false.obs;
  final isKnockLoading = false.obs;

  final dmConversations = <DmConversationSummary>[].obs;
  final knockConversations = <KnockConversation>[].obs;
  final aiCharacters = <AiRoleCard>[].obs;

  final currentDmId = ''.obs;
  final currentDmConversation = Rxn<DmConversationSummary>();
  final currentDmMessages = <DmMessage>[].obs;
  final currentDmHasMore = false.obs;
  final currentDmNextCursor = ''.obs;

  final currentKnockId = ''.obs;
  final currentKnockMessages = <NotificationModel>[].obs;
  final currentKnockHasMore = false.obs;
  final currentKnockNextCursor = ''.obs;

  final typingDmIds = <String>{}.obs;
  final aiStreaming = false.obs;

  StreamSubscription<DmEvent>? _wsSub;
  StreamSubscription<KnockSseEvent>? _sseSub;

  Timer? _typingTimer;

  MessagingController() {
    _dmWs = DmWebSocketService(api: api);
  }

  @override
  void onInit() {
    super.onInit();
    _sseSub = _knockSse.eventStream.listen(_handleSseEvent);
    _wsSub = _dmWs.eventStream.listen(_handleWsEvent);

    final c = Get.find<Controller>();
    ever(c.isLogin, (login) {
      if (login) {
        start();
      } else {
        stop();
      }
    });

    if (c.isLogin.value) start();
  }

  @override
  void onClose() {
    _sseSub?.cancel();
    _wsSub?.cancel();
    _knockSse.stop();
    _dmWs.stop();
    _typingTimer?.cancel();
    super.onClose();
  }

  void start() {
    _knockSse.start();
    _dmWs.start();
    refreshDmConversations();
    refreshKnockConversations();
    refreshAiCharacters();
  }

  void stop() {
    _knockSse.stop();
    _dmWs.stop();
    currentDmId.value = '';
    currentDmConversation.value = null;
    currentDmMessages.clear();
    currentKnockId.value = '';
    currentKnockMessages.clear();
  }

  Future<void> refreshDmConversations() async {
    isDmLoading.value = true;
    try {
      final list = await api.getDmConversations();
      list.sort((a, b) {
        final pinDiff = (b.self.pinned ? 1 : 0) - (a.self.pinned ? 1 : 0);
        if (pinDiff != 0) return pinDiff;
        final atA = a.lastMessageAt ?? DateTime(0);
        final atB = b.lastMessageAt ?? DateTime(0);
        return atB.compareTo(atA);
      });
      dmConversations.assignAll(list);
      _updateUnreadBadge();
    } catch (e) {
      debugPrint('refreshDmConversations error: $e');
    } finally {
      isDmLoading.value = false;
    }
  }

  Future<void> refreshKnockConversations() async {
    isKnockLoading.value = true;
    try {
      final list = await api.getKnockConversations();
      knockConversations.assignAll(list);
      _updateUnreadBadge();
    } catch (e) {
      debugPrint('refreshKnockConversations error: $e');
    } finally {
      isKnockLoading.value = false;
    }
  }

  Future<void> refreshAiCharacters() async {
    try {
      final list = await api.getAgentCharacters();
      list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      aiCharacters.assignAll(list);
    } catch (e) {
      debugPrint('refreshAiCharacters error: $e');
    }
  }

  void _updateUnreadBadge() {
    final dmUnread = dmConversations.fold<int>(
      0,
      (sum, c) => sum + c.unreadCount,
    );
    final knockUnread = knockConversations.fold<int>(
      0,
      (sum, c) => sum + c.unread,
    );
    final c = Get.find<Controller>();
    c.unreadNotificationCount.value = dmUnread + knockUnread;
  }

  Future<void> enterDmChat(String conversationId) async {
    currentDmId.value = conversationId;
    currentDmMessages.clear();
    currentDmHasMore.value = false;
    currentDmNextCursor.value = '';

    final conv = dmConversations.firstWhereOrNull(
      (c) => c.documentId == conversationId,
    );
    currentDmConversation.value = conv;

    await loadDmMessages();

    try {
      await api.markDmConversationAsRead(conversationId);
      if (conv != null) {
        final idx = dmConversations.indexOf(conv);
        if (idx >= 0) {
          final updated = conv; // immutable; replace with copy
          dmConversations[idx] = DmConversationSummary(
            documentId: updated.documentId,
            kind: updated.kind,
            title: updated.title,
            avatar: updated.avatar,
            peer: updated.peer,
            memberCount: updated.memberCount,
            lastMessageAt: updated.lastMessageAt,
            lastMessage: updated.lastMessage,
            unreadCount: 0,
            self: updated.self,
            pseudoKind: updated.pseudoKind,
          );
          dmConversations.refresh();
          _updateUnreadBadge();
        }
      }
    } catch (e) {
      debugPrint('markDmAsRead error: $e');
    }
  }

  Future<void> loadDmMessages({bool append = false}) async {
    final id = currentDmId.value;
    if (id.isEmpty) return;
    final before = append ? currentDmNextCursor.value : null;
    try {
      final result = await api.getDmMessages(id, before: (before?.isEmpty ?? true) ? null : before);
      // 后端返回 createdAt desc，展示时需要按时间升序排列
      final items = result.items.toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      if (append) {
        currentDmMessages.insertAll(0, items);
      } else {
        currentDmMessages.assignAll(items);
      }
      currentDmHasMore.value = result.hasMore;
      currentDmNextCursor.value = result.nextCursor ?? '';
    } catch (e) {
      debugPrint('loadDmMessages error: $e');
    }
  }

  Future<void> openDirectChat(int targetUserId) async {
    try {
      isLoading.value = true;
      final result = await api.openDirectConversation(targetUserId);
      final summary = result.summary;
      if (!dmConversations.any((c) => c.documentId == summary.documentId)) {
        dmConversations.insert(0, summary);
      }
      await enterDmChat(summary.documentId);
    } finally {
      isLoading.value = false;
    }
  }

  Future<DmMessage?> sendDmText(String text, {String? replyTo}) async {
    var id = currentDmId.value;
    if (id.isEmpty || text.trim().isEmpty) return null;

    // pseudo:user 会话需要先实质化为真实 DM 会话
    if (id.startsWith('pseudo:user:')) {
      final peer = currentDmConversation.value?.peer;
      if (peer?.userId != null) {
        await openDirectChat(peer!.userId!);
        id = currentDmId.value;
      }
    }

    if (id.startsWith('pseudo:')) {
      debugPrint('cannot send to pseudo/anonymous/system conversation');
      return null;
    }

    try {
      final msg = await api.sendDmMessage(
        id,
        content: text.trim(),
        replyTo: replyTo,
      );
      // 防止 WS 推送先到达导致重复
      if (!currentDmMessages.any((m) => m.documentId == msg.documentId)) {
        currentDmMessages.add(msg);
      }
      // 只有对 AI 角色发消息时才显示「AI 正在输入」
      aiStreaming.value = currentDmConversation.value?.peer?.isAiAgent == true;
      return msg;
    } catch (e) {
      debugPrint('sendDmText error: $e');
      return null;
    }
  }

  Future<void> editDmMessage(String messageId, String content) async {
    try {
      await api.editDmMessage(messageId, content);
      final idx = currentDmMessages.indexWhere((m) => m.documentId == messageId);
      if (idx >= 0) {
        final old = currentDmMessages[idx];
        currentDmMessages[idx] = DmMessage(
          documentId: old.documentId,
          kind: old.kind,
          content: content,
          createdAt: old.createdAt,
          editedAt: DateTime.now(),
          deletedAt: old.deletedAt,
          sender: old.sender,
          replyTo: old.replyTo,
          notificationKind: old.notificationKind,
          notificationDocumentId: old.notificationDocumentId,
          notificationRead: old.notificationRead,
          article: old.article,
          comment: old.comment,
        );
      }
    } catch (e) {
      debugPrint('editDmMessage error: $e');
    }
  }

  Future<void> withdrawDmMessage(String messageId) async {
    try {
      await api.withdrawDmMessage(messageId);
      final idx = currentDmMessages.indexWhere((m) => m.documentId == messageId);
      if (idx >= 0) {
        final old = currentDmMessages[idx];
        currentDmMessages[idx] = DmMessage(
          documentId: old.documentId,
          kind: old.kind,
          content: null,
          createdAt: old.createdAt,
          editedAt: old.editedAt,
          deletedAt: DateTime.now(),
          sender: old.sender,
          replyTo: old.replyTo,
          notificationKind: old.notificationKind,
          notificationDocumentId: old.notificationDocumentId,
          notificationRead: old.notificationRead,
          article: old.article,
          comment: old.comment,
        );
      }
    } catch (e) {
      debugPrint('withdrawDmMessage error: $e');
    }
  }

  Future<void> resetDmContext() async {
    final id = currentDmId.value;
    if (id.isEmpty) return;
    try {
      await api.resetDmContext(id);
    } catch (e) {
      debugPrint('resetDmContext error: $e');
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await api.markAllDmAsRead();
      await refreshDmConversations();
      await refreshKnockConversations();
    } catch (e) {
      debugPrint('markAllAsRead error: $e');
    }
  }

  Future<void> leaveDmConversation(String conversationId) async {
    try {
      await api.leaveDmConversation(conversationId);
      dmConversations.removeWhere((c) => c.documentId == conversationId);
    } catch (e) {
      debugPrint('leaveDmConversation error: $e');
    }
  }

  void sendTyping(String conversationId) {
    _dmWs.sendTyping(conversationId);
  }

  Future<void> enterKnockChat(String conversationId) async {
    currentKnockId.value = conversationId;
    currentKnockMessages.clear();
    currentKnockHasMore.value = false;
    currentKnockNextCursor.value = '';
    await markCurrentKnockAsRead();
  }

  /// 标记当前敲敲会话已读并重新加载消息（先调用 mark-read，再拉取消息，使返回的 isRead 已更新）
  Future<void> markCurrentKnockAsRead() async {
    final id = currentKnockId.value;
    if (id.isEmpty) return;

    try {
      await api.markKnockConversationAsRead(id);
      final idx = knockConversations.indexWhere((c) => c.id == id);
      if (idx >= 0) {
        final old = knockConversations[idx];
        knockConversations[idx] = KnockConversation(
          id: old.id,
          category: old.category,
          peerKey: old.peerKey,
          peerName: old.peerName,
          peerAvatar: old.peerAvatar,
          unread: 0,
          lastPreview: old.lastPreview,
          lastAt: old.lastAt,
          lastType: old.lastType,
        );
        knockConversations.refresh();
        _updateUnreadBadge();
      }
    } catch (e) {
      debugPrint('markKnockAsRead error: $e');
    }

    await loadKnockMessages();
  }

  Future<void> loadKnockMessages({bool append = false}) async {
    final id = currentKnockId.value;
    if (id.isEmpty) return;
    final cursor = append ? currentKnockNextCursor.value : null;
    try {
      final result = await api.getKnockMessages(id, cursor: cursor);
      // 后端 /knock/messages 已返回 createdAt asc；追加历史时应插到列表头部
      final items = result.items.toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      if (append) {
        currentKnockMessages.insertAll(0, items);
      } else {
        currentKnockMessages.assignAll(items);
      }
      currentKnockHasMore.value = result.hasMore;
      currentKnockNextCursor.value = result.nextCursor ?? '';
    } catch (e) {
      debugPrint('loadKnockMessages error: $e');
    }
  }

  void _handleWsEvent(DmEvent event) {
    final type = event.type;
    switch (type) {
      case 'message.created':
        final payload = event.dataValue<Map<String, dynamic>>('message');
        if (payload == null) return;
        final msg = DmMessage.fromJson(payload);
        if (msg.documentId.isEmpty) return;
        if (currentDmId.value == event.conversationId) {
          if (!currentDmMessages.any((m) => m.documentId == msg.documentId)) {
            currentDmMessages.add(msg);
            aiStreaming.value = false;
          }
        }
        _refreshDmConversationsList();
        break;
      case 'message.edited':
        final messageId = event.messageId;
        if (messageId == null || currentDmId.value != event.conversationId) return;
        final content = event.dataValue<String>('content');
        final editedAtRaw = event.dataValue<String>('editedAt');
        final idx = currentDmMessages.indexWhere((m) => m.documentId == messageId);
        if (idx >= 0 && content != null) {
          final old = currentDmMessages[idx];
          currentDmMessages[idx] = DmMessage(
            documentId: old.documentId,
            kind: old.kind,
            content: content,
            createdAt: old.createdAt,
            editedAt: editedAtRaw != null ? DateTime.tryParse(editedAtRaw) : DateTime.now(),
            deletedAt: old.deletedAt,
            sender: old.sender,
            replyTo: old.replyTo,
            notificationKind: old.notificationKind,
            notificationDocumentId: old.notificationDocumentId,
            notificationRead: old.notificationRead,
            article: old.article,
            comment: old.comment,
          );
        }
        break;
      case 'message.deleted':
        final messageId = event.messageId;
        if (messageId == null || currentDmId.value != event.conversationId) return;
        final idx = currentDmMessages.indexWhere((m) => m.documentId == messageId);
        if (idx >= 0) {
          final old = currentDmMessages[idx];
          currentDmMessages[idx] = DmMessage(
            documentId: old.documentId,
            kind: old.kind,
            content: null,
            createdAt: old.createdAt,
            editedAt: old.editedAt,
            deletedAt: DateTime.now(),
            sender: old.sender,
            replyTo: old.replyTo,
            notificationKind: old.notificationKind,
            notificationDocumentId: old.notificationDocumentId,
            notificationRead: old.notificationRead,
            article: old.article,
            comment: old.comment,
          );
        }
        break;
      case 'message.delta':
        final messageId = event.messageId;
        if (messageId == null || currentDmId.value != event.conversationId) return;
        final acc = event.dataValue<String>('content') ?? '';
        final idx = currentDmMessages.indexWhere((m) => m.documentId == messageId);
        if (idx >= 0) {
          final old = currentDmMessages[idx];
          currentDmMessages[idx] = DmMessage(
            documentId: old.documentId,
            kind: old.kind,
            content: acc,
            createdAt: old.createdAt,
            editedAt: old.editedAt,
            deletedAt: old.deletedAt,
            sender: old.sender,
            replyTo: old.replyTo,
            notificationKind: old.notificationKind,
            notificationDocumentId: old.notificationDocumentId,
            notificationRead: old.notificationRead,
            article: old.article,
            comment: old.comment,
          );
          aiStreaming.value = true;
        } else {
          // 未找到则视为新消息，可能是一条流式占位
          final payload = event.data;
          if (payload != null && payload['message'] is Map<String, dynamic>) {
            final msg = DmMessage.fromJson(payload['message'] as Map<String, dynamic>);
            currentDmMessages.add(msg);
          }
        }
        break;
      case 'conversation.read':
        if (event.conversationId == currentDmId.value) {
          final conv = currentDmConversation.value;
          if (conv != null) {
            currentDmConversation.value = DmConversationSummary(
              documentId: conv.documentId,
              kind: conv.kind,
              title: conv.title,
              avatar: conv.avatar,
              peer: conv.peer,
              memberCount: conv.memberCount,
              lastMessageAt: conv.lastMessageAt,
              lastMessage: conv.lastMessage,
              unreadCount: 0,
              self: conv.self,
              pseudoKind: conv.pseudoKind,
            );
          }
        }
        _refreshDmConversationsList();
        break;
      case 'conversation.read.all':
        _refreshDmConversationsList();
        break;
      case 'conversation.updated':
        _refreshDmConversationsList();
        break;
      case 'conversation.member.removed':
        _refreshDmConversationsList();
        break;
      case 'typing':
        final convId = event.conversationId;
        if (convId != null && convId != currentDmId.value) {
          typingDmIds.add(convId);
          _typingTimer?.cancel();
          _typingTimer = Timer(const Duration(seconds: 3), () {
            typingDmIds.remove(convId);
          });
        }
        break;
    }
  }

  void _handleSseEvent(KnockSseEvent event) {
    switch (event.type) {
      case 'hello':
      case 'bye':
        break;
      case 'notification.created':
      case 'notification.read':
      case 'notification.read.bulk':
        refreshKnockConversations();
        refreshDmConversations();
        break;
    }
  }

  Future<void> _refreshDmConversationsList() async {
    try {
      final list = await api.getDmConversations();
      list.sort((a, b) {
        final pinDiff = (b.self.pinned ? 1 : 0) - (a.self.pinned ? 1 : 0);
        if (pinDiff != 0) return pinDiff;
        final atA = a.lastMessageAt ?? DateTime(0);
        final atB = b.lastMessageAt ?? DateTime(0);
        return atB.compareTo(atA);
      });
      dmConversations.assignAll(list);
      _updateUnreadBadge();
    } catch (e) {
      debugPrint('_refreshDmConversationsList error: $e');
    }
  }
}
