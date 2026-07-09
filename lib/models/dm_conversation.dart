enum DmConversationKind { direct, group, unknown }

enum DmMemberRole { owner, admin, member }

enum DmPseudoKind { user, anonymous, system }

class DmPeer {
  final int? userId;
  final String? authorDocumentId;
  final String name;
  final String? avatar;
  final int? level;
  final bool isAiAgent;

  DmPeer({
    this.userId,
    this.authorDocumentId,
    required this.name,
    this.avatar,
    this.level,
    this.isAiAgent = false,
  });

  factory DmPeer.fromJson(Map<String, dynamic> json) {
    return DmPeer(
      userId: json['userId'] as int?,
      authorDocumentId: json['authorDocumentId'] as String?,
      name: json['name'] as String? ?? '未知用户',
      avatar: json['avatar'] as String?,
      level: json['level'] as int?,
      isAiAgent: json['isAiAgent'] == true,
    );
  }
}

class DmSelfState {
  final DmMemberRole role;
  final bool muted;
  final bool pinned;
  final DateTime? lastReadAt;

  DmSelfState({
    required this.role,
    this.muted = false,
    this.pinned = false,
    this.lastReadAt,
  });

  factory DmSelfState.fromJson(Map<String, dynamic> json) {
    final roleStr = json['role'] as String? ?? 'member';
    final role = switch (roleStr) {
      'owner' => DmMemberRole.owner,
      'admin' => DmMemberRole.admin,
      _ => DmMemberRole.member,
    };
    final lastReadAtRaw = json['lastReadAt'] as String?;
    return DmSelfState(
      role: role,
      muted: json['muted'] == true,
      pinned: json['pinned'] == true,
      lastReadAt: lastReadAtRaw != null ? DateTime.tryParse(lastReadAtRaw) : null,
    );
  }
}

class DmLastMessagePreview {
  final String documentId;
  final String content;
  final DateTime createdAt;
  final String kind;
  final int? senderUserId;

  DmLastMessagePreview({
    required this.documentId,
    required this.content,
    required this.createdAt,
    required this.kind,
    this.senderUserId,
  });

  factory DmLastMessagePreview.fromJson(Map<String, dynamic> json) {
    final createdAtRaw = json['createdAt'] as String?;
    return DmLastMessagePreview(
      documentId: json['documentId'] as String? ?? '',
      content: json['content'] as String? ?? '',
      createdAt: createdAtRaw != null ? DateTime.parse(createdAtRaw) : DateTime.now(),
      kind: json['kind'] as String? ?? '',
      senderUserId: json['senderUserId'] as int?,
    );
  }
}

class DmConversationSummary {
  final String documentId;
  final DmConversationKind kind;
  final String? title;
  final String? avatar;
  final DmPeer? peer;
  final int memberCount;
  final DateTime? lastMessageAt;
  final DmLastMessagePreview? lastMessage;
  final int unreadCount;
  final DmSelfState self;
  final DmPseudoKind? pseudoKind;

  DmConversationSummary({
    required this.documentId,
    required this.kind,
    this.title,
    this.avatar,
    this.peer,
    this.memberCount = 0,
    this.lastMessageAt,
    this.lastMessage,
    this.unreadCount = 0,
    required this.self,
    this.pseudoKind,
  });

  factory DmConversationSummary.fromJson(Map<String, dynamic> json) {
    final kindStr = json['kind'] as String?;
    final kind = switch (kindStr) {
      'direct' => DmConversationKind.direct,
      'group' => DmConversationKind.group,
      _ => DmConversationKind.unknown,
    };

    final peerRaw = json['peer'];
    final peer = peerRaw is Map<String, dynamic> ? DmPeer.fromJson(peerRaw) : null;

    final lastMessageRaw = json['lastMessage'];
    final lastMessage = lastMessageRaw is Map<String, dynamic>
        ? DmLastMessagePreview.fromJson(lastMessageRaw)
        : null;

    final selfRaw = json['self'];
    final self = selfRaw is Map<String, dynamic>
        ? DmSelfState.fromJson(selfRaw)
        : DmSelfState(role: DmMemberRole.member);

    final lastMessageAtRaw = json['lastMessageAt'] as String?;

    var pseudoKind = json['pseudoKind'] as String?;
    if (pseudoKind == null) {
      final docId = json['documentId'] as String? ?? '';
      if (docId.startsWith('pseudo:user:')) pseudoKind = 'user';
      if (docId.startsWith('pseudo:anonymous:')) pseudoKind = 'anonymous';
      if (docId == 'pseudo:system') pseudoKind = 'system';
    }

    return DmConversationSummary(
      documentId: json['documentId'] as String? ?? '',
      kind: kind,
      title: json['title'] as String?,
      avatar: json['avatar'] as String?,
      peer: peer,
      memberCount: json['memberCount'] as int? ?? 0,
      lastMessageAt: lastMessageAtRaw != null ? DateTime.tryParse(lastMessageAtRaw) : null,
      lastMessage: lastMessage,
      unreadCount: json['unreadCount'] as int? ?? 0,
      self: self,
      pseudoKind: switch (pseudoKind) {
        'user' => DmPseudoKind.user,
        'anonymous' => DmPseudoKind.anonymous,
        'system' => DmPseudoKind.system,
        _ => null,
      },
    );
  }

  /// 显示标题：群聊用 title，私聊用 peer 名称，否则 unknown。
  String get displayTitle {
    if (kind == DmConversationKind.group) return title ?? '群聊';
    return peer?.name ?? title ?? '';
  }

  /// 显示头像：群聊用 avatar，私聊用 peer 头像。
  String? get displayAvatar {
    if (kind == DmConversationKind.group) return avatar;
    return peer?.avatar ?? avatar;
  }
}
