import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:inter_knot/components/avatar.dart';
import 'package:inter_knot/controllers/data.dart';
import 'package:inter_knot/controllers/messaging_controller.dart';
import 'package:inter_knot/helpers/time_formatter.dart';
import 'package:inter_knot/models/ai_role_card.dart';
import 'package:inter_knot/models/dm_conversation.dart';
import 'package:inter_knot/models/knock_conversation.dart';
import 'package:inter_knot/pages/dm_chat_page.dart';
import 'package:inter_knot/pages/knock_chat_page.dart';

/// 阶段 2 消息中心：通话（AI）/ 私聊（DM）/ 敲敲（通知聚合）
class MessageCenterPage extends StatefulWidget {
  const MessageCenterPage({super.key});

  @override
  State<MessageCenterPage> createState() => _MessageCenterPageState();
}

class _MessageCenterPageState extends State<MessageCenterPage>
    with SingleTickerProviderStateMixin {
  final controller = Get.find<MessagingController>();
  final c = Get.find<Controller>();
  late final TabController _tabController;

  static const _tabs = ['通话', '私聊', '敲敲'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    controller.refreshDmConversations();
    controller.refreshKnockConversations();
    controller.refreshAiCharacters();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 640;

    final body = Column(
      children: [
        _buildTabBar(),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              _AiCharacterTab(),
              _DmConversationListTab(),
              _KnockConversationListTab(),
            ],
          ),
        ),
      ],
    );

    if (isCompact) {
      return Scaffold(
        backgroundColor: const Color(0xff121212),
        appBar: AppBar(
          backgroundColor: Colors.black,
          title: const Text('消息中心', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(0),
            child: Container(),
          ),
        ),
        body: body,
      );
    }

    return body;
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.black,
      child: TabBar(
        controller: _tabController,
        indicatorColor: const Color(0xffD7FF00),
        labelColor: const Color(0xffD7FF00),
        unselectedLabelColor: Colors.white70,
        tabs: _tabs.map((t) => Tab(text: t)).toList(),
      ),
    );
  }
}

class _AiCharacterTab extends StatelessWidget {
  const _AiCharacterTab();

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<MessagingController>();
    return Obx(() {
      if (controller.isLoading.value && controller.aiCharacters.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }
      final list = controller.aiCharacters;
      if (list.isEmpty) {
        return const Center(child: Text('暂无 AI 角色', style: TextStyle(color: Colors.grey)));
      }
      return ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: list.length,
        itemBuilder: (context, index) {
          final card = list[index];
          return _AiCharacterTile(card: card);
        },
      );
    });
  }
}

class _AiCharacterTile extends StatelessWidget {
  final AiRoleCard card;

  const _AiCharacterTile({required this.card});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<MessagingController>();
    return ListTile(
      leading: Avatar(card.effectiveAvatar, size: 48),
      title: Text(card.displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      subtitle: card.bio != null && card.bio!.isNotEmpty
          ? Text(card.bio!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey))
          : null,
      onTap: () async {
        final boundId = card.boundUser?.id;
        if (boundId != null) {
          await controller.openDirectChat(boundId);
          if (context.mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DmChatPage()),
            );
          }
        }
      },
    );
  }
}

class _DmConversationListTab extends StatelessWidget {
  const _DmConversationListTab();

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<MessagingController>();
    return Obx(() {
      if (controller.isDmLoading.value && controller.dmConversations.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }
      final list = controller.dmConversations;
      if (list.isEmpty) {
        return const Center(child: Text('暂无私信', style: TextStyle(color: Colors.grey)));
      }
      return ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: list.length,
        itemBuilder: (context, index) => _DmConversationTile(conversation: list[index]),
      );
    });
  }
}

class _DmConversationTile extends StatelessWidget {
  final DmConversationSummary conversation;

  const _DmConversationTile({required this.conversation});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<MessagingController>();
    final last = conversation.lastMessage;
    return ListTile(
      leading: Avatar(conversation.displayAvatar, size: 48),
      title: Row(
        children: [
          Expanded(
            child: Text(
              conversation.displayTitle,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (conversation.unreadCount > 0)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              child: Text(
                conversation.unreadCount > 99 ? '99+' : conversation.unreadCount.toString(),
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
      subtitle: Text(
        last?.content ?? '',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
      ),
      trailing: last != null
          ? Text(
              formatRelativeTime(last.createdAt),
              style: const TextStyle(color: Colors.grey, fontSize: 11),
            )
          : null,
      onTap: () async {
        await controller.enterDmChat(conversation.documentId);
        if (context.mounted) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const DmChatPage()));
        }
      },
    );
  }
}

class _KnockConversationListTab extends StatelessWidget {
  const _KnockConversationListTab();

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<MessagingController>();
    return Obx(() {
      if (controller.isKnockLoading.value && controller.knockConversations.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }
      final list = controller.knockConversations;
      if (list.isEmpty) {
        return const Center(child: Text('暂无通知', style: TextStyle(color: Colors.grey)));
      }
      return ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: list.length,
        itemBuilder: (context, index) => _KnockConversationTile(conversation: list[index]),
      );
    });
  }
}

class _KnockConversationTile extends StatelessWidget {
  final KnockConversation conversation;

  const _KnockConversationTile({required this.conversation});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<MessagingController>();
    return ListTile(
      leading: Avatar(conversation.peerAvatar, size: 48),
      title: Row(
        children: [
          Expanded(
            child: Text(
              conversation.peerName,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          if (conversation.unread > 0)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              child: Text(
                conversation.unread > 99 ? '99+' : conversation.unread.toString(),
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
      subtitle: Text(
        conversation.lastPreview,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
      ),
      trailing: Text(
        formatRelativeTime(conversation.lastAt),
        style: const TextStyle(color: Colors.grey, fontSize: 11),
      ),
      onTap: () async {
        await controller.enterKnockChat(conversation.id);
        if (context.mounted) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const KnockChatPage()));
        }
      },
    );
  }
}
