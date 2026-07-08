part of 'api.dart';

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
