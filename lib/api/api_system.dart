part of 'api.dart';

extension SystemApi on Api {
  Future<String?> renewToken() async {
    final res = await post('/api/auth/renew', {});
    if (res.hasError) {
      debugPrint('Renew Error: ${res.statusCode} - ${res.bodyString}');
      throw ApiException(
        res.statusText ?? 'Request failed',
        statusCode: res.statusCode,
      );
    }

    final body = res.body as Map<String, dynamic>;
    return body['jwt'] as String?;
  }


  Future<
      ({
        int exp,
        int level,
        String? lastCheckInDate,
        int? consecutiveCheckInDays,
        DateTime? nextEligibleAtUtc,
        bool canCheckIn,
      })> getMyExp() async {
    final res = await get('/api/me/exp');

    if (res.hasError) {
      throw ApiException(res.statusText ?? 'Failed to fetch exp',
          statusCode: res.statusCode, details: res.bodyString);
    }

    final body = res.body;
    if (body is! Map) {
      throw ApiException('Invalid exp response');
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


  Future<
      ({
        String message,
        int? reward,
        int? consecutiveDays,
        int? rank,
        int? currentExp,
        int? currentLevel,
      })> checkIn() async {
    final res = await post('/api/check-in', <String, dynamic>{});

    if (res.hasError) {
      String errorMessage = '签到失败';
      dynamic details;
      if (res.body is Map) {
        final error = res.body['error'];
        if (error is Map) {
          final code = error['code']?.toString();
          details = error['details'] ?? res.body;

          if (code == 'CHECK_IN_ALREADY_TODAY') {
            errorMessage = '今日已签到';
          } else if (error['message'] == 'Already checked in today.') {
            // Backward compatibility for old backend message.
            errorMessage = '今日已签到';
          }
        }
      }
      throw ApiException(
        errorMessage,
        statusCode: res.statusCode,
        details: details,
      );
    }

    final body = res.body as Map<String, dynamic>;
    return (
      message: body['message'] as String? ?? '签到成功',
      reward: body['reward'] as int?,
      consecutiveDays: body['consecutiveDays'] as int?,
      rank: (body['rank'] as num?)?.toInt(),
      currentExp: (body['currentExp'] as num?)?.toInt(),
      currentLevel: (body['currentLevel'] as num?)?.toInt(),
    );
  }


}
