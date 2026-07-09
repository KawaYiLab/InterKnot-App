import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:inter_knot/components/notification_card.dart';
import 'package:inter_knot/controllers/messaging_controller.dart';
import 'package:inter_knot/models/notification.dart';

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
    // 敲敲会话页走批量已读，不再单独标记
  }

  void _openNotification(BuildContext context, NotificationModel msg) {
    // 可跳转文章详情；阶段 2 先保留空实现
  }
}
