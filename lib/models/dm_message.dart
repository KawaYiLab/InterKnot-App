enum DmMessageKind { text, image, system, notification, unknown }

enum DmNotificationKind { like, favorite, comment, reply, mention, system, denny }

class DmMessageSender {
  final int? userId;
  final String? authorDocumentId;
  final String name;
  final String? avatar;
  final int? level;
  final bool isAiAgent;

  DmMessageSender({
    this.userId,
    this.authorDocumentId,
    required this.name,
    this.avatar,
    this.level,
    this.isAiAgent = false,
  });

  factory DmMessageSender.fromJson(Map<String, dynamic> json) {
    return DmMessageSender(
      userId: json['userId'] as int?,
      authorDocumentId: json['authorDocumentId'] as String?,
      name: json['name'] as String? ?? '未知用户',
      avatar: json['avatar'] as String?,
      level: json['level'] as int?,
      isAiAgent: json['isAiAgent'] == true,
    );
  }
}

class DmMessageReplyTo {
  final String documentId;
  final String? content;
  final int? senderUserId;

  DmMessageReplyTo({
    required this.documentId,
    this.content,
    this.senderUserId,
  });

  factory DmMessageReplyTo.fromJson(Map<String, dynamic> json) {
    return DmMessageReplyTo(
      documentId: json['documentId'] as String? ?? '',
      content: json['content'] as String?,
      senderUserId: json['senderUserId'] as int?,
    );
  }
}

class DmNotificationArticleRef {
  final String documentId;
  final String title;
  final double? coverAspectRatio;

  DmNotificationArticleRef({
    required this.documentId,
    required this.title,
    this.coverAspectRatio,
  });

  factory DmNotificationArticleRef.fromJson(Map<String, dynamic> json) {
    final ratio = json['coverAspectRatio'];
    return DmNotificationArticleRef(
      documentId: json['documentId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      coverAspectRatio: ratio is num ? ratio.toDouble() : null,
    );
  }
}

class DmNotificationCommentRef {
  final String documentId;
  final String content;
  final bool isAnonymous;

  DmNotificationCommentRef({
    required this.documentId,
    required this.content,
    this.isAnonymous = false,
  });

  factory DmNotificationCommentRef.fromJson(Map<String, dynamic> json) {
    return DmNotificationCommentRef(
      documentId: json['documentId'] as String? ?? '',
      content: json['content'] as String? ?? '',
      isAnonymous: json['isAnonymous'] == true,
    );
  }
}

class DmMessage {
  final String documentId;
  final DmMessageKind kind;
  final String? content;
  final DateTime createdAt;
  final DateTime? editedAt;
  final DateTime? deletedAt;
  final DmMessageSender? sender;
  final DmMessageReplyTo? replyTo;

  // notification-only fields
  final DmNotificationKind? notificationKind;
  final String? notificationDocumentId;
  final bool? notificationRead;
  final DmNotificationArticleRef? article;
  final DmNotificationCommentRef? comment;

  DmMessage({
    required this.documentId,
    required this.kind,
    this.content,
    required this.createdAt,
    this.editedAt,
    this.deletedAt,
    this.sender,
    this.replyTo,
    this.notificationKind,
    this.notificationDocumentId,
    this.notificationRead,
    this.article,
    this.comment,
  });

  factory DmMessage.fromJson(Map<String, dynamic> json) {
    final kindStr = json['kind'] as String?;
    final kind = switch (kindStr) {
      'text' => DmMessageKind.text,
      'image' => DmMessageKind.image,
      'system' => DmMessageKind.system,
      'notification' => DmMessageKind.notification,
      _ => DmMessageKind.unknown,
    };

    final senderRaw = json['sender'];
    final sender = senderRaw is Map<String, dynamic> ? DmMessageSender.fromJson(senderRaw) : null;

    final replyToRaw = json['replyTo'];
    final replyTo = replyToRaw is Map<String, dynamic> ? DmMessageReplyTo.fromJson(replyToRaw) : null;

    final articleRaw = json['article'];
    final article = articleRaw is Map<String, dynamic>
        ? DmNotificationArticleRef.fromJson(articleRaw)
        : null;

    final commentRaw = json['comment'];
    final comment = commentRaw is Map<String, dynamic>
        ? DmNotificationCommentRef.fromJson(commentRaw)
        : null;

    final notificationKindStr = json['notificationKind'] as String?;
    final notificationKind = switch (notificationKindStr) {
      'like' => DmNotificationKind.like,
      'favorite' => DmNotificationKind.favorite,
      'comment' => DmNotificationKind.comment,
      'reply' => DmNotificationKind.reply,
      'mention' => DmNotificationKind.mention,
      'system' => DmNotificationKind.system,
      'denny' => DmNotificationKind.denny,
      _ => null,
    };

    final createdAtRaw = json['createdAt'] as String?;
    final createdAt = createdAtRaw != null ? DateTime.parse(createdAtRaw) : DateTime.now();

    return DmMessage(
      documentId: json['documentId'] as String? ?? '',
      kind: kind,
      content: json['content'] as String?,
      createdAt: createdAt,
      editedAt: json['editedAt'] != null ? DateTime.tryParse(json['editedAt'] as String) : null,
      deletedAt: json['deletedAt'] != null ? DateTime.tryParse(json['deletedAt'] as String) : null,
      sender: sender,
      replyTo: replyTo,
      notificationKind: notificationKind,
      notificationDocumentId: json['notificationDocumentId'] as String?,
      notificationRead: json['notificationRead'] as bool?,
      article: article,
      comment: comment,
    );
  }

  /// 是否已撤回
  bool get isDeleted => deletedAt != null;

  /// 是否可以编辑/撤回：自己发送的文本消息且未撤回
  bool get canModify {
    if (kind != DmMessageKind.text) return false;
    if (isDeleted) return false;
    final age = DateTime.now().difference(createdAt);
    return age.inMinutes <= 5;
  }
}
