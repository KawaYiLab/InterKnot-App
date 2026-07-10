part of 'api.dart';

extension SystemApi on Api {
  Future<String?> renewToken() async {
    final res = await post('/api/auth/renew', {});
    if (res.hasError) {
      debugPrint('Renew Error: ${res.statusCode} - ${res.bodyString}');
      throw ApiException(
        _errorMessageFromBody(res.body) ?? '登录态刷新失败',
        statusCode: res.statusCode,
      );
    }

    final body = res.body as Map<String, dynamic>;
    return body['jwt'] as String?;
  }

  Future<(
    {
      int exp,
      int level,
      String? lastCheckInDate,
      int? consecutiveCheckInDays,
      DateTime? nextEligibleAtUtc,
      bool canCheckIn,
    }
  )> getMyExp() async {
    final res = await get('/api/me/exp');

    if (res.hasError) {
      throw ApiException(
        _errorMessageFromBody(res.body) ?? '获取经验失败',
        statusCode: res.statusCode,
        details: res.bodyString,
      );
    }

    final body = res.body;
    if (body is! Map) {
      throw ApiException('经验数据格式异常');
    }

    return (
      exp: (body['exp'] as num?)?.toInt() ?? 0,
      level: (body['level'] as num?)?.toInt() ?? 1,
      lastCheckInDate: body['lastCheckInDate']?.toString(),
      consecutiveCheckInDays: (body['consecutiveCheckInDays'] as num?)?.toInt(),
      nextEligibleAtUtc: DateTime.tryParse(
        body['nextEligibleAt']?.toString() ?? '',
      )?.toUtc(),
      canCheckIn: body['canCheckIn'] as bool? ?? true,
    );
  }

  Future<(
    {
      bool canCheckIn,
      int totalDays,
      int consecutiveDays,
      int rank,
      String? checkInDay,
      DateTime? nextEligibleAtUtc,
      int currentDenny,
    }
  )> getCheckInStatus() async {
    final res = await get('/api/check-in/status');
    if (res.hasError) {
      throw ApiException(
        _errorMessageFromBody(res.body) ?? '获取签到状态失败',
        statusCode: res.statusCode,
      );
    }
    final body = res.body;
    if (body is! Map) {
      throw ApiException('签到数据格式异常');
    }

    return (
      canCheckIn: body['canCheckIn'] as bool? ?? true,
      totalDays: (body['totalDays'] as num?)?.toInt() ?? 0,
      consecutiveDays: (body['consecutiveDays'] as num?)?.toInt() ?? 0,
      rank: (body['rank'] as num?)?.toInt() ?? 0,
      checkInDay: body['checkInDay']?.toString(),
      nextEligibleAtUtc: DateTime.tryParse(
        body['nextEligibleAt']?.toString() ?? '',
      )?.toUtc(),
      currentDenny: (body['currentDenny'] as num?)?.toInt() ?? 0,
    );
  }

  Future<(
    {
      String message,
      int? reward,
      int? consecutiveDays,
      int? totalDays,
      int? rank,
      int? currentExp,
      int? currentLevel,
      int? currentDenny,
      int? dennyAdded,
      bool? dennyCapped,
      DateTime? nextEligibleAtUtc,
    }
  )> checkIn() async {
    final res = await post('/api/check-in', <String, dynamic>{});

    if (res.hasError) {
      final bodyMap = res.body is Map ? res.body as Map : null;
      final errorMap = bodyMap?['error'] is Map ? bodyMap!['error'] as Map : null;
      final details = errorMap?['details'] ?? bodyMap;
      throw ApiException(
        _errorMessageFromBody(res.body) ?? '签到失败',
        statusCode: res.statusCode,
        details: details,
      );
    }

    final body = res.body as Map<String, dynamic>;
    return (
      message: body['message'] as String? ?? '签到成功',
      reward: (body['reward'] as num?)?.toInt(),
      consecutiveDays: (body['consecutiveDays'] as num?)?.toInt(),
      totalDays: (body['totalDays'] as num?)?.toInt(),
      rank: (body['rank'] as num?)?.toInt(),
      currentExp: (body['currentExp'] as num?)?.toInt(),
      currentLevel: (body['currentLevel'] as num?)?.toInt(),
      currentDenny: (body['currentDenny'] as num?)?.toInt(),
      dennyAdded: (body['dennyAdded'] as num?)?.toInt(),
      dennyCapped: body['dennyCapped'] as bool?,
      nextEligibleAtUtc: DateTime.tryParse(
        body['nextEligibleAt']?.toString() ?? '',
      )?.toUtc(),
    );
  }
}
