enum KnockCategory {
  contacts,
  anonymous,
  other,
}

class KnockConversation {
  final String id;
  final KnockCategory category;
  final String peerKey;
  final String peerName;
  final String? peerAvatar;
  final int unread;
  final String lastPreview;
  final DateTime lastAt;
  final String lastType;

  KnockConversation({
    required this.id,
    required this.category,
    required this.peerKey,
    required this.peerName,
    this.peerAvatar,
    required this.unread,
    required this.lastPreview,
    required this.lastAt,
    required this.lastType,
  });

  factory KnockConversation.fromJson(Map<String, dynamic> json) {
    final categoryStr = json['category'] as String? ?? 'other';
    final category = switch (categoryStr) {
      'contacts' => KnockCategory.contacts,
      'anonymous' => KnockCategory.anonymous,
      _ => KnockCategory.other,
    };
    final lastAtRaw = json['lastAt'] as String?;
    return KnockConversation(
      id: json['id'] as String? ?? '',
      category: category,
      peerKey: json['peerKey'] as String? ?? '',
      peerName: json['peerName'] as String? ?? '',
      peerAvatar: json['peerAvatar'] as String?,
      unread: json['unread'] as int? ?? 0,
      lastPreview: json['lastPreview'] as String? ?? '',
      lastAt: lastAtRaw != null ? DateTime.parse(lastAtRaw) : DateTime.now(),
      lastType: json['lastType'] as String? ?? '',
    );
  }
}
