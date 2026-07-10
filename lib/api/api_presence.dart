part of 'api.dart';

class PresenceInfo {
  final int online;
  final List<String> avatars;

  PresenceInfo({required this.online, required this.avatars});

  factory PresenceInfo.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is Map<String, dynamic>) {
      final rawAvatars = data['avatars'];
      return PresenceInfo(
        online: (data['online'] as num?)?.toInt() ?? 0,
        avatars: rawAvatars is List
            ? rawAvatars.whereType<String>().toList()
            : [],
      );
    }
    return PresenceInfo(online: 0, avatars: []);
  }
}

extension PresenceApi on Api {
  /// POST /api/presence/ping
  /// 匿名用户必须传 [presenceId]；已登录用户可传 null。
  Future<PresenceInfo> pingPresence({String? presenceId}) async {
    final body = presenceId != null && presenceId.isNotEmpty
        ? {'presenceId': presenceId}
        : <String, dynamic>{};
    final res = await post('/api/presence/ping', body);
    if (res.hasError) {
      throw ApiException(
        _errorMessageFromBody(res.body) ?? '在线心跳失败',
        statusCode: res.statusCode,
      );
    }
    final bodyMap = res.body;
    if (bodyMap is Map<String, dynamic>) {
      return PresenceInfo.fromJson(bodyMap);
    }
    throw ApiException('在线心跳数据格式异常');
  }

  /// GET /api/presence/online
  Future<PresenceInfo> getOnlineStatus() async {
    final res = await get('/api/presence/online');
    if (res.hasError) {
      throw ApiException(
        _errorMessageFromBody(res.body) ?? '获取在线状态失败',
        statusCode: res.statusCode,
      );
    }
    final body = res.body;
    if (body is Map<String, dynamic>) {
      return PresenceInfo.fromJson(body);
    }
    throw ApiException('在线状态数据格式异常');
  }
}
