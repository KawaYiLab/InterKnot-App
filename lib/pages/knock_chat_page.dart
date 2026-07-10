import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:inter_knot/api/api.dart';
import 'package:inter_knot/components/notification_card.dart';
import 'package:inter_knot/controllers/messaging_controller.dart';
import 'package:inter_knot/helpers/dialog_helper.dart';
import 'package:inter_knot/helpers/toast.dart';
import 'package:inter_knot/models/h_data.dart';
import 'package:inter_knot/models/notification.dart';
import 'package:inter_knot/pages/discussion_page.dart';

class KnockChatPage extends StatefulWidget {
  const KnockChatPage({super.key});

  @override
  State<KnockChatPage> createState() => _KnockChatPageState();
}

class _KnockChatPageState extends State<KnockChatPage> {
  final controller = Get.find<MessagingController>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff121212),
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Obx(() {
          final name = controller.knockConversations
              .firstWhereOrNull((c) => c.id == controller.currentKnockId.value)
              ?.peerName;
          return Text(
            name ?? '通知',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          );
        }),
      ),
      body: Obx(() {
        final messages = controller.currentKnockMessages;
        if (messages.isEmpty) {
          return const Center(
            child: Text('暂无通知', style: TextStyle(color: Colors.grey)),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final msg = messages[index];
            return NotificationCard(
              notification: msg,
              onTap: () => _openNotification(context, msg),
              onMarkRead: () => _markSingleRead(msg),
            );
          },
        );
      }),
    );
  }

  void _markSingleRead(NotificationModel msg) {
    // 会话级已读：先调用 mark-read 再刷新当前会话消息
    controller.markCurrentKnockAsRead();
  }

  Future<void> _openNotification(BuildContext context, NotificationModel msg) async {
    final documentId = msg.articleDocumentId ?? '';
    if (documentId.isEmpty) {
      _markSingleRead(msg);
      return;
    }
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
      _markSingleRead(msg);
    } catch (e) {
      debugPrint('Load article error: $e');
      showToast('加载文章失败', isError: true);
    }
  }
}
