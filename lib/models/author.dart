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

    return AuthorModel(
      login: json['name'] as String? ?? username ?? 'unknown',
      avatar: avatarUrl ?? '',
      name: json['name'] as String? ?? username,
      email: json['email'] as String?,
      userId: userId,
      authorId: authorId,
      createdAt: createdAt,
      exp: json['exp'] as int? ?? 0,
      level: json['level'] as int? ?? 1,
      denny: json['denny'] as int?,
      lastCheckInDate: json['lastCheckInDate'] as String?,
      consecutiveCheckInDays: json['consecutiveCheckInDays'] as int?,
      canCheckIn: json['canCheckIn'] as bool? ?? true,
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
    };
  }

  @override
  bool operator ==(Object other) =>
      other is AuthorModel && other.login == login;

  @override
  int get hashCode => login.hashCode;
}
