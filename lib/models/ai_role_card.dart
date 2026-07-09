class AiRoleCard {
  final String slug;
  final String displayName;
  final String? bio;
  final String? avatar;
  final int sortOrder;
  final AiRoleBoundUser? boundUser;

  AiRoleCard({
    required this.slug,
    required this.displayName,
    this.bio,
    this.avatar,
    this.sortOrder = 0,
    this.boundUser,
  });

  factory AiRoleCard.fromJson(Map<String, dynamic> json) {
    final boundUserRaw = json['boundUser'];
    return AiRoleCard(
      slug: json['slug'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      bio: json['bio'] as String?,
      avatar: json['avatar'] as String?,
      sortOrder: json['sortOrder'] as int? ?? 0,
      boundUser: boundUserRaw is Map<String, dynamic>
          ? AiRoleBoundUser.fromJson(boundUserRaw)
          : null,
    );
  }

  String? get effectiveAvatar => avatar ?? boundUser?.avatar;
}

class AiRoleBoundUser {
  final int id;
  final String? login;
  final bool isAiAgent;
  final String? authorDocumentId;
  final String? name;
  final String? avatar;

  AiRoleBoundUser({
    required this.id,
    this.login,
    this.isAiAgent = false,
    this.authorDocumentId,
    this.name,
    this.avatar,
  });

  factory AiRoleBoundUser.fromJson(Map<String, dynamic> json) {
    return AiRoleBoundUser(
      id: json['id'] as int? ?? 0,
      login: json['login'] as String?,
      isAiAgent: json['isAiAgent'] == true,
      authorDocumentId: json['authorDocumentId'] as String?,
      name: json['name'] as String?,
      avatar: json['avatar'] as String?,
    );
  }
}
