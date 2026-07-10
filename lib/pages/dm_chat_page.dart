import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:inter_knot/api/api.dart';
import 'package:inter_knot/constants/api_config.dart';
import 'package:inter_knot/controllers/data.dart';
import 'package:inter_knot/controllers/messaging_controller.dart';
import 'package:inter_knot/helpers/dialog_helper.dart';
import 'package:inter_knot/helpers/time_formatter.dart';
import 'package:inter_knot/helpers/toast.dart';
import 'package:inter_knot/models/dm_message.dart';
import 'package:inter_knot/models/h_data.dart';
import 'package:inter_knot/pages/discussion_page.dart';

class DmChatPage extends StatefulWidget {
  const DmChatPage({super.key});

  @override
  State<DmChatPage> createState() => _DmChatPageState();
}

class _DmChatPageState extends State<DmChatPage> {
  final controller = Get.find<MessagingController>();
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  Worker? _scrollWorker;
  bool _isAtBottom = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.hasClients) {
        _isAtBottom = _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 48;
      }
    });
    _scrollWorker = ever(controller.currentDmMessages, (_) {
      _scrollToBottom();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom(force: true));
  }

  @override
  void dispose() {
    _scrollWorker?.dispose();
    _inputController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _send() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    _inputController.clear();
    controller.sendDmText(text);
    _scrollToBottom(force: true);
  }

  void _scrollToBottom({bool force = false}) {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!_scrollController.hasClients) return;
      if (!force && !_isAtBottom) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 640;

    return Scaffold(
      backgroundColor: const Color(0xff121212),
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Obx(() {
          final conv = controller.currentDmConversation.value;
          return Text(
            conv?.displayTitle ?? '私信',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          );
        }),
        actions: [
          Obx(() {
            final conv = controller.currentDmConversation.value;
            if (conv?.peer?.isAiAgent == true) {
              return IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                tooltip: '重置上下文',
                onPressed: () => controller.resetDmContext(),
              );
            }
            return const SizedBox.shrink();
          }),
          IconButton(
            icon: const Icon(Icons.check_circle_outline, color: Colors.white),
            tooltip: '一键已读',
            onPressed: () => controller.markAllAsRead(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Obx(() {
              final messages = controller.currentDmMessages;
              if (messages.isEmpty) {
                return const Center(
                  child: Text('暂无消息', style: TextStyle(color: Colors.grey)),
                );
              }
              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                itemCount: messages.length,
                itemBuilder: (context, index) => _DmMessageBubble(
                  message: messages[index],
                ),
              );
            }),
          ),
          _buildInputArea(isCompact),
        ],
      ),
    );
  }

  Widget _buildInputArea(bool isCompact) {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 12,
        top: 8,
      ),
      decoration: BoxDecoration(
        color: const Color(0xff1A1A1A),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              focusNode: _focusNode,
              style: const TextStyle(color: Colors.white),
              maxLines: 4,
              minLines: 1,
              decoration: InputDecoration(
                hintText: '发送消息...',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                filled: true,
                fillColor: const Color(0xff2A2A2A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onSubmitted: (_) => _send(),
            ),
          ),
          const SizedBox(width: 8),
          FloatingActionButton(
            mini: true,
            backgroundColor: const Color(0xffD7FF00),
            onPressed: _send,
            child: const Icon(Icons.send, color: Colors.black),
          ),
        ],
      ),
    );
  }
}

class _DmMessageBubble extends StatelessWidget {
  final DmMessage message;

  const _DmMessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<Controller>();
    final isSelf = message.sender?.userId?.toString() == c.user.value?.userId;
    final isSystem = message.kind == DmMessageKind.system;

    if (isSystem) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xff333333),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            message.content ?? '',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ),
      );
    }

    if (message.kind == DmMessageKind.notification) {
      return _NotificationMessage(message: message);
    }

    return Align(
      alignment: isSelf ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelf ? const Color(0xffD7FF00) : const Color(0xff2A2A2A),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isSelf && message.sender != null)
                Text(
                  message.sender!.name,
                  style: const TextStyle(
                    color: Color(0xff9AA0A6),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              _buildContent(isSelf),
              const SizedBox(height: 4),
              Text(
                formatRelativeTime(message.createdAt),
                style: TextStyle(
                  color: isSelf ? Colors.black54 : Colors.grey,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(bool isSelf) {
    if (message.isDeleted) {
      return Text(
        message.kind == DmMessageKind.image ? '[图片已撤回]' : '[消息已撤回]',
        style: TextStyle(
          color: isSelf ? Colors.black.withValues(alpha: 0.5) : Colors.grey,
          fontSize: 12,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    if (message.kind == DmMessageKind.image) {
      final url = _normalizeImageUrl(message.content);
      if (url != null && url.isNotEmpty) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Icon(Icons.image, color: Colors.grey),
          ),
        );
      }
      return const Icon(Icons.image, color: Colors.grey);
    }

    return Text(
      message.content ?? '',
      style: TextStyle(color: isSelf ? Colors.black : Colors.white),
    );
  }

  String? _normalizeImageUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    final base = ApiConfig.baseUrl.replaceAll(RegExp(r'/+$'), '');
    if (url.startsWith('/')) return '$base$url';
    return '$base/$url';
  }
}

class _NotificationMessage extends StatelessWidget {
  final DmMessage message;

  const _NotificationMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openArticle(context),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xff1F1F1F),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _notificationTitle(message),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (message.content?.isNotEmpty == true) ...[
                const SizedBox(height: 4),
                Text(
                  message.content!,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
                ),
              ],
              if (message.article?.title.isNotEmpty == true) ...[
                const SizedBox(height: 6),
                Text(
                  '《${message.article!.title}》',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openArticle(BuildContext context) async {
    final documentId = message.article?.documentId;
    if (documentId == null || documentId.isEmpty) return;
    try {
      final discussion = await Get.find<Api>().getArticleDetail(documentId);
      HDataModel.upsertCachedDiscussion(discussion);
      final hData = HDataModel(
        id: discussion.id,
        updatedAt: discussion.lastEditedAt ?? discussion.createdAt,
        createdAt: discussion.createdAt,
        isPinned: false,
      );
      if (!context.mounted) return;
      await showZZZDialog(
        context: context,
        pageBuilder: (context) => DiscussionPage(
          discussion: discussion,
          hData: hData,
        ),
      );
    } catch (e) {
      debugPrint('Load article error: $e');
      showToast('加载文章失败', isError: true);
    }
  }

  String _notificationTitle(DmMessage msg) {
    final senderName = msg.sender?.name ?? '';
    final prefix = senderName.isNotEmpty ? '${senderName}' : '';
    switch (msg.notificationKind) {
      case DmNotificationKind.like:
        return '${prefix}赞了你的帖子';
      case DmNotificationKind.favorite:
        return '${prefix}收藏了你的帖子';
      case DmNotificationKind.comment:
        return '${prefix}评论了你的帖子';
      case DmNotificationKind.reply:
        return '${prefix}回复了你的评论';
      case DmNotificationKind.mention:
        return '${prefix}提到了你';
      case DmNotificationKind.system:
        return '系统通知';
      default:
        return '通知';
    }
  }
}
