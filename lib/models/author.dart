class AuthorModel {
  static const String _baseUrl = 'https://ik.tiwat.cn';

  String login;
  String avatar;
  late String name;
  String? email;
  String? userId;
  String? authorId;
  DateTime? createdAt;
  int? exp;
  int? level;
  int? denny;
  String? lastCheckInDate;
  int? consecutiveCheckInDays;
  bool canCheckIn;
  bool isAdmin;
  bool examPassed;
  bool profileHidden;
  bool isAiAgent;
  String? bio;
  String? equippedAvatarDocumentId;
  String? equippedCardDocumentId;
  List<String> profilePinnedArticles;

  // Adjusted for custom backend
  String get url => ''; // No external profile URL yet

  AuthorModel({
    required this.login,
    required this.avatar,
    required String? name,
    this.email,
    this.userId,
    this.authorId,
    this.createdAt,
    this.exp,
    this.level,
    this.denny,
    this.lastCheckInDate,
    this.consecutiveCheckInDays,
    this.canCheckIn = true,
    this.isAdmin = false,
    this.examPassed = false,
    this.profileHidden = false,
    this.isAiAgent = false,
    this.bio,
    this.equippedAvatarDocumentId,
    this.equippedCardDocumentId,
    this.profilePinnedArticles = const [],
  }) : name = name ?? login;

  static String? extractAvatarUrl(dynamic avatarData) {
    if (avatarData is String) {
      return avatarData;
    }
    if (avatarData is! Map) return null;

    final directUrl = avatarData['url'] as String?;
    if (directUrl != null && directUrl.isNotEmpty) {
      return directUrl;
    }

    final data = avatarData['data'];
    if (data is Map) {
      final nestedUrl = data['url'] as String?;
      if (nestedUrl != null && nestedUrl.isNotEmpty) {
        return nestedUrl;
      }
      final attributes = data['attributes'];
      if (attributes is Map) {
        final attrUrl = attributes['url'] as String?;
        if (attrUrl != null && attrUrl.isNotEmpty) {
          return attrUrl;
        }
      }
    }

    final attributes = avatarData['attributes'];
    if (attributes is Map) {
      final attrUrl = attributes['url'] as String?;
      if (attrUrl != null && attrUrl.isNotEmpty) {
        return attrUrl;
      }
    }

    return null;
  }

  static String? extractBioText(dynamic bio) {
    if (bio is String) {
      return bio.trim();
    }
    if (bio is List && bio.isNotEmpty) {
      final buffer = StringBuffer();
      for (final block in bio) {
        if (block is Map && block['type'] == 'paragraph') {
          final children = block['children'];
          if (children is List) {
            for (final child in children) {
              if (child is Map && child['type'] == 'text') {
                buffer.write(child['text']?.toString() ?? '');
              }
            }
          }
        }
      }
      final text = buffer.toString().trim();
      return text.isNotEmpty ? text : null;
    }
    return null;
  }

  static String? _normalizeAvatarUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    if (url.startsWith('/')) {
      return '$_baseUrl$url';
    }
    return '$_baseUrl/$url';
  }

  factory AuthorModel.fromJson(Map<String, dynamic> json) {
    final authorData = json['author'];
    final authorMap = authorData is Map<String, dynamic> ? authorData : null;
    final authorDataMap = authorMap?['data'];
    final authorDataMapTyped =
        authorDataMap is Map<String, dynamic> ? authorDataMap : null;
    final authorDataAttributes = authorDataMapTyped?['attributes'];
    final authorAttributes = authorMap?['attributes'];

    final avatarData = json['avatar'] ??
        authorMap?['avatar'] ??
        authorDataMapTyped?['avatar'] ??
        (authorDataAttributes is Map ? authorDataAttributes['avatar'] : null) ??
        (authorAttributes is Map ? authorAttributes['avatar'] : null);
    String? avatarUrl = extractAvatarUrl(avatarData);

    avatarUrl = _normalizeAvatarUrl(avatarUrl);

    final username = json['username'] as String?;
    final userId = json['id']?.toString();
    final authorId = authorDataMapTyped?['documentId']?.toString() ??
        authorDataMapTyped?['id']?.toString() ??
        authorMap?['documentId']?.toString() ??
        authorMap?['id']?.toString() ??
        (authorData is String || authorData is num
            ? authorData.toString()
            : null) ??
        json['authorId']?.toString() ??
        json['documentId']?.toString();

    DateTime? createdAt;
    final createdStr = json['createdAt'] as String?;
    if (createdStr != null) {
      createdAt = DateTime.tryParse(createdStr);
    }

    // For /api/users/me author.name is the display name; for /api/profiles/* the
    // profile name is returned at the top-level name field.
    final authorName = authorMap?['name']?.toString() ??
        authorDataMapTyped?['name']?.toString() ??
        (authorAttributes is Map ? authorAttributes['name']?.toString() : null) ??
        (authorDataAttributes is Map ? authorDataAttributes['name']?.toString() : null);
    final name = json['name']?.toString() ?? authorName ?? username ?? 'unknown';
    final login = json['username']?.toString() ?? json['name']?.toString() ?? username ?? 'unknown';

    return AuthorModel(
      login: login,
      avatar: avatarUrl ?? '',
      name: name,
      email: json['email']?.toString(),
      userId: userId,
      authorId: authorId,
      createdAt: createdAt,
      exp: json['exp'] as int? ?? 0,
      level: json['level'] as int? ?? 1,
      denny: json['denny'] as int?,
      lastCheckInDate: json['lastCheckInDate']?.toString(),
      consecutiveCheckInDays: json['consecutiveCheckInDays'] is num
          ? (json['consecutiveCheckInDays'] as num).toInt()
          : int.tryParse(json['consecutiveCheckInDays']?.toString() ?? ''),
      canCheckIn: json['canCheckIn'] as bool? ?? true,
      isAdmin: json['isAdmin'] == true,
      examPassed: json['examPassed'] == true,
      profileHidden: json['profileHidden'] == true,
      isAiAgent: json['isAiAgent'] == true,
      bio: extractBioText(json['bio']),
      equippedAvatarDocumentId: json['equippedAvatar'] is Map
          ? json['equippedAvatar']['documentId']?.toString()
          : null,
      equippedCardDocumentId: json['equippedCard'] is Map
          ? json['equippedCard']['documentId']?.toString()
          : null,
      profilePinnedArticles: (json['profilePinnedArticles'] as List?)
              ?.whereType<String>()
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'username': login,
      'email': email,
      'id': userId,
      'documentId': authorId,
      'createdAt': createdAt?.toIso8601String(),
      'avatar': {'url': avatar},
      if (denny != null) 'denny': denny,
      'bio': bio,
      'equippedAvatarDocumentId': equippedAvatarDocumentId,
      'equippedCardDocumentId': equippedCardDocumentId,
      'profilePinnedArticles': profilePinnedArticles,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is AuthorModel && other.login == login;

  @override
  int get hashCode => login.hashCode;
}
