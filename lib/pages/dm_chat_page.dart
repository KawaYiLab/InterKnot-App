import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:inter_knot/controllers/data.dart';
import 'package:inter_knot/controllers/messaging_controller.dart';
import 'package:inter_knot/helpers/time_formatter.dart';
import 'package:inter_knot/models/dm_message.dart';

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

  @override
  void dispose() {
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
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
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
                  isFirst: index == 0,
                  isLast: index == messages.length - 1,
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
  final bool isFirst;
  final bool isLast;

  const _DmMessageBubble({
    required this.message,
    required this.isFirst,
    required this.isLast,
  });

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
              Text(
                message.content ?? '',
                style: TextStyle(color: isSelf ? Colors.black : Colors.white),
              ),
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
}

class _NotificationMessage extends StatelessWidget {
  final DmMessage message;

  const _NotificationMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
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
          ],
        ),
      ),
    );
  }

  String _notificationTitle(DmMessage msg) {
    switch (msg.notificationKind) {
      case DmNotificationKind.like:
        return '赞了你的帖子';
      case DmNotificationKind.favorite:
        return '收藏了你的帖子';
      case DmNotificationKind.comment:
        return '评论了你的帖子';
      case DmNotificationKind.reply:
        return '回复了你的评论';
      case DmNotificationKind.mention:
        return '提到了你';
      case DmNotificationKind.system:
        return '系统通知';
      default:
        return '通知';
    }
  }
}
