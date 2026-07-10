part of 'api.dart';

class FollowAuthor {
  final String documentId;
  final String name;
  final String? avatar;

  FollowAuthor({
    required this.documentId,
    required this.name,
    this.avatar,
  });

  factory FollowAuthor.fromJson(Map<String, dynamic> json) => FollowAuthor(
        documentId: json['documentId']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        avatar: json['avatar']?.toString(),
      );
}

class FollowToggleResult {
  final bool following;
  final int followersCount;

  FollowToggleResult({required this.following, required this.followersCount});

  factory FollowToggleResult.fromJson(Map<String, dynamic> json) =>
      FollowToggleResult(
        following: json['following'] == true,
        followersCount: (json['followersCount'] as num?)?.toInt() ?? 0,
      );
}

class FollowCheckResult {
  final Map<String, bool> data;

  FollowCheckResult({required this.data});

  factory FollowCheckResult.fromJson(Map<String, dynamic> json) {
    final raw = json['data'];
    return FollowCheckResult(
      data: raw is Map
          ? raw.map((k, v) => MapEntry(k.toString(), v == true))
          : {},
    );
  }
}

class FollowListResult {
  final List<FollowAuthor> data;
  final int total;

  FollowListResult({required this.data, required this.total});

  factory FollowListResult.fromJson(Map<String, dynamic> json) {
    final list = json['data'];
    final meta = json['meta'];
    final pagination = meta is Map ? meta['pagination'] : null;
    return FollowListResult(
      data: list is List
          ? list
              .whereType<Map<String, dynamic>>()
              .map(FollowAuthor.fromJson)
              .toList()
          : [],
      total: (pagination is Map ? (pagination['total'] as num?)?.toInt() : null) ??
          (list is List ? list.length : 0),
    );
  }
}

extension FollowApi on Api {
  /// POST /api/follows/toggle
  /// body: { authorDocumentId }
  Future<FollowToggleResult> toggleFollow(String authorDocumentId) async {
    final res = await post('/api/follows/toggle', {
      'authorDocumentId': authorDocumentId,
    });
    if (res.hasError) {
      throw ApiException(
        _errorMessageFromBody(res.body) ?? '关注操作失败',
        statusCode: res.statusCode,
      );
    }
    final body = res.body;
    if (body is Map<String, dynamic>) {
      return FollowToggleResult.fromJson(body);
    }
    throw ApiException('关注返回数据格式异常');
  }

  /// GET /api/follows/check
  /// query: { authorIds: String (comma-separated) }
  Future<Map<String, bool>> checkFollowStatus(List<String> authorIds) async {
    if (authorIds.isEmpty) return {};
    final res = await get(
      '/api/follows/check',
      query: {'authorIds': authorIds.join(',')},
    );
    if (res.hasError) {
      throw ApiException(
        _errorMessageFromBody(res.body) ?? '获取关注状态失败',
        statusCode: res.statusCode,
      );
    }
    final body = res.body;
    if (body is Map<String, dynamic>) {
      return FollowCheckResult.fromJson(body).data;
    }
    throw ApiException('关注状态数据格式异常');
  }

  /// GET /api/follows/following
  /// 当前用户关注的作者列表。
  Future<FollowListResult> getFollowingList({
    int start = 0,
    int limit = 24,
  }) async {
    final res = await get('/api/follows/following', query: {
      'start': start.toString(),
      'limit': limit.toString(),
    });
    if (res.hasError) {
      throw ApiException(
        _errorMessageFromBody(res.body) ?? '获取关注列表失败',
        statusCode: res.statusCode,
      );
    }
    final body = res.body;
    if (body is Map<String, dynamic>) {
      return FollowListResult.fromJson(body);
    }
    throw ApiException('关注列表数据格式异常');
  }
}
