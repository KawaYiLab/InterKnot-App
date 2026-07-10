part of 'api.dart';

class AvatarItem {
  final String documentId;
  final String name;
  final String type;
  final Map<String, dynamic>? image;

  AvatarItem({
    required this.documentId,
    required this.name,
    required this.type,
    this.image,
  });

  factory AvatarItem.fromJson(Map<String, dynamic> json) => AvatarItem(
        documentId: json['documentId']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        type: json['type']?.toString() ?? 'character',
        image: json['image'] is Map<String, dynamic>
            ? json['image'] as Map<String, dynamic>
            : null,
      );
}

class AvatarListResult {
  final List<AvatarItem> data;
  final String? equippedAvatarDocumentId;

  AvatarListResult({required this.data, this.equippedAvatarDocumentId});

  factory AvatarListResult.fromJson(Map<String, dynamic> json) =>
      AvatarListResult(
        data: (json['data'] as List<dynamic>?)
                ?.whereType<Map<String, dynamic>>()
                .map(AvatarItem.fromJson)
                .toList() ??
            [],
        equippedAvatarDocumentId:
            json['equippedAvatarDocumentId']?.toString(),
      );
}

class BusinessCardItem {
  final String documentId;
  final String name;
  final String? description;
  final String? story;
  final String type;
  final Map<String, dynamic>? image;

  BusinessCardItem({
    required this.documentId,
    required this.name,
    this.description,
    this.story,
    required this.type,
    this.image,
  });

  factory BusinessCardItem.fromJson(Map<String, dynamic> json) =>
      BusinessCardItem(
        documentId: json['documentId']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        description: json['description']?.toString(),
        story: json['story']?.toString(),
        type: json['type']?.toString() ?? 'character',
        image: json['image'] is Map<String, dynamic>
            ? json['image'] as Map<String, dynamic>
            : null,
      );
}

class BusinessCardListResult {
  final List<BusinessCardItem> data;
  final String? equippedCardDocumentId;

  BusinessCardListResult({
    required this.data,
    this.equippedCardDocumentId,
  });

  factory BusinessCardListResult.fromJson(Map<String, dynamic> json) =>
      BusinessCardListResult(
        data: (json['data'] as List<dynamic>?)
                ?.whereType<Map<String, dynamic>>()
                .map(BusinessCardItem.fromJson)
                .toList() ??
            [],
        equippedCardDocumentId: json['equippedCardDocumentId']?.toString(),
      );
}

class PinnedArticlesResult {
  final List<String>? pinned;
  final List<Map<String, dynamic>> candidates;
  final int max;

  PinnedArticlesResult({
    this.pinned,
    required this.candidates,
    required this.max,
  });

  factory PinnedArticlesResult.fromJson(Map<String, dynamic> json) =>
      PinnedArticlesResult(
        pinned: (json['pinned'] as List<dynamic>?)
            ?.whereType<String>()
            .toList(),
        candidates: (json['candidates'] as List<dynamic>?)
                ?.whereType<Map<String, dynamic>>()
                .toList() ??
            [],
        max: (json['max'] as num?)?.toInt() ?? 6,
      );
}

/// 当前登录用户相关接口（/api/me/*）。
extension MeApi on Api {
  /// GET /api/me/profile
  /// 返回当前用户信息及关联 author（含头像）。
  Future<Map<String, dynamic>> getMyProfile() async {
    final res = await get('/api/me/profile');
    if (res.hasError) {
      throw ApiException(
        _errorMessageFromBody(res.body) ?? '获取个人信息失败',
        statusCode: res.statusCode,
      );
    }
    final body = res.body;
    if (body is Map<String, dynamic>) return body;
    throw ApiException('Invalid profile response');
  }

  /// PUT /api/me/profile/name
  /// 后端会同时更新 user.username 与 author.name（扣除 10 丁尼）。
  Future<String> updateMyName(String name) async {
    final res = await put('/api/me/profile/name', {'name': name});
    if (res.hasError) {
      throw ApiException(
        _errorMessageFromBody(res.body) ?? '改名失败',
        statusCode: res.statusCode,
      );
    }
    final body = res.body;
    if (body is Map && body['success'] == true) {
      return body['name']?.toString() ?? name;
    }
    throw ApiException('Invalid update name response');
  }

  /// PUT /api/me/profile/bio
  Future<void> updateMyBio(String bio) async {
    final res = await put('/api/me/profile/bio', {'bio': bio});
    if (res.hasError) {
      throw ApiException(
        _errorMessageFromBody(res.body) ?? '更新签名失败',
        statusCode: res.statusCode,
      );
    }
  }

  /// PUT /api/me/profile/visibility
  Future<bool> updateMyVisibility(bool profileHidden) async {
    final res = await put('/api/me/profile/visibility', {
      'profileHidden': profileHidden,
    });
    if (res.hasError) {
      throw ApiException(
        _errorMessageFromBody(res.body) ?? '更新可见性失败',
        statusCode: res.statusCode,
      );
    }
    final body = res.body;
    if (body is Map && body['success'] == true) {
      return body['profileHidden'] == true;
    }
    return profileHidden;
  }

  /// GET /api/me/profile/pinned-articles
  Future<PinnedArticlesResult> getMyPinnedArticles() async {
    final res = await get('/api/me/profile/pinned-articles');
    if (res.hasError) {
      throw ApiException(
        _errorMessageFromBody(res.body) ?? '获取置顶候选失败',
        statusCode: res.statusCode,
      );
    }
    final body = res.body;
    if (body is Map<String, dynamic>) {
      return PinnedArticlesResult.fromJson(body);
    }
    throw ApiException('Invalid pinned articles response');
  }

  /// PUT /api/me/profile/pinned-articles
  Future<List<String>?> updateMyPinnedArticles(List<String> pinned) async {
    final res = await put('/api/me/profile/pinned-articles', {
      'pinned': pinned,
    });
    if (res.hasError) {
      throw ApiException(
        _errorMessageFromBody(res.body) ?? '更新置顶失败',
        statusCode: res.statusCode,
      );
    }
    final body = res.body;
    if (body is Map) {
      final raw = body['pinned'];
      if (raw == null) return null;
      if (raw is List) {
        return raw.whereType<String>().toList();
      }
    }
    return pinned;
  }

  /// GET /api/me/avatars
  Future<AvatarListResult> getMyAvatars() async {
    final res = await get('/api/me/avatars');
    if (res.hasError) {
      throw ApiException(
        _errorMessageFromBody(res.body) ?? '获取头像列表失败',
        statusCode: res.statusCode,
      );
    }
    final body = res.body;
    if (body is Map<String, dynamic>) {
      return AvatarListResult.fromJson(body);
    }
    throw ApiException('Invalid avatars response');
  }

  /// PUT /api/me/avatars/equip
  Future<String?> equipAvatar(String? documentId) async {
    final res = await put('/api/me/avatars/equip', {
      'documentId': documentId,
    });
    if (res.hasError) {
      throw ApiException(
        _errorMessageFromBody(res.body) ?? '装备头像失败',
        statusCode: res.statusCode,
      );
    }
    final body = res.body;
    if (body is Map) {
      return body['equippedAvatarDocumentId']?.toString();
    }
    return documentId;
  }

  /// GET /api/me/business-cards
  Future<BusinessCardListResult> getMyBusinessCards({String? type}) async {
    final res = await get('/api/me/business-cards', query: {
      if (type != null && type.isNotEmpty) 'type': type,
    });
    if (res.hasError) {
      throw ApiException(
        _errorMessageFromBody(res.body) ?? '获取名片列表失败',
        statusCode: res.statusCode,
      );
    }
    final body = res.body;
    if (body is Map<String, dynamic>) {
      return BusinessCardListResult.fromJson(body);
    }
    throw ApiException('Invalid business cards response');
  }

  /// PUT /api/me/business-cards/equip
  Future<String?> equipBusinessCard(String? documentId) async {
    final res = await put('/api/me/business-cards/equip', {
      'documentId': documentId,
    });
    if (res.hasError) {
      throw ApiException(
        _errorMessageFromBody(res.body) ?? '装备名片失败',
        statusCode: res.statusCode,
      );
    }
    final body = res.body;
    if (body is Map) {
      return body['equippedCardDocumentId']?.toString();
    }
    return documentId;
  }

  /// GET /api/me/uploads
  Future<List<Map<String, dynamic>>> getMyUploads({
    int page = 1,
    int pageSize = 24,
  }) async {
    final res = await get('/api/me/uploads', query: {
      'page': page.toString(),
      'pageSize': pageSize.toString(),
    });
    if (res.hasError) {
      throw ApiException(
        _errorMessageFromBody(res.body) ?? '获取上传列表失败',
        statusCode: res.statusCode,
      );
    }
    final body = res.body;
    if (body is Map<String, dynamic>) {
      final data = body['data'];
      if (data is List) {
        return data.whereType<Map<String, dynamic>>().toList();
      }
    }
    throw ApiException('Invalid uploads response');
  }
}

String? _errorMessageFromBody(dynamic body) {
  if (body is Map) {
    final error = body['error'];
    if (error is Map && error['message'] != null) {
      return error['message'].toString();
    }
    if (error is String && error.isNotEmpty) return error;
  }
  return null;
}
