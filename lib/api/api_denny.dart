part of 'api.dart';

class DennyLog {
  final String action;
  final int amount;
  final int balance;
  final String? description;
  final String? createdAt;

  DennyLog({
    required this.action,
    required this.amount,
    required this.balance,
    this.description,
    this.createdAt,
  });

  factory DennyLog.fromJson(Map<String, dynamic> json) => DennyLog(
        action: json['action']?.toString() ?? '',
        amount: (json['amount'] as num?)?.toInt() ?? 0,
        balance: (json['balance'] as num?)?.toInt() ?? 0,
        description: json['description']?.toString(),
        createdAt: json['createdAt']?.toString(),
      );
}

class DennyBalance {
  final int denny;
  final int dennyGiven;
  final List<DennyLog> recentLogs;

  DennyBalance({
    required this.denny,
    required this.dennyGiven,
    required this.recentLogs,
  });

  factory DennyBalance.fromJson(Map<String, dynamic> json) => DennyBalance(
        denny: (json['denny'] as num?)?.toInt() ?? 0,
        dennyGiven: (json['dennyGiven'] as num?)?.toInt() ?? 0,
        recentLogs: (json['recentLogs'] as List<dynamic>?)
                ?.map((e) => e is Map<String, dynamic>
                    ? DennyLog.fromJson(e)
                    : DennyLog(action: '', amount: 0, balance: 0))
                .where((l) => l.action.isNotEmpty)
                .toList() ??
            [],
      );
}

class DennyGiveResult {
  final bool success;
  final String message;
  final int? newBalance;
  final int? articleDennyCount;

  DennyGiveResult({
    required this.success,
    required this.message,
    this.newBalance,
    this.articleDennyCount,
  });

  factory DennyGiveResult.fromJson(Map<String, dynamic> json) =>
      DennyGiveResult(
        success: json['success'] == true,
        message: json['message']?.toString() ?? '',
        newBalance: (json['newBalance'] as num?)?.toInt(),
        articleDennyCount: (json['articleDennyCount'] as num?)?.toInt(),
      );
}

extension DennyApi on Api {
  /// GET /api/user-denny
  Future<DennyBalance> getMyDenny() async {
    final res = await get('/api/user-denny');
    if (res.hasError) {
      throw ApiException(
        _errorMessageFromBody(res.body) ?? '获取丁尼余额失败',
        statusCode: res.statusCode,
      );
    }
    final body = res.body;
    if (body is Map<String, dynamic>) {
      return DennyBalance.fromJson(body);
    }
    throw ApiException('丁尼余额数据格式异常');
  }

  /// POST /api/user-denny/give
  /// 给帖子投 1 丁尼。
  Future<DennyGiveResult> giveDennyToArticle(
    String articleId, {
    String? message,
  }) async {
    final res = await post('/api/user-denny/give', {
      'articleId': articleId,
      if (message != null && message.isNotEmpty) 'message': message,
    });
    if (res.hasError) {
      throw ApiException(
        _errorMessageFromBody(res.body) ?? '投币失败',
        statusCode: res.statusCode,
      );
    }
    final body = res.body;
    if (body is Map<String, dynamic>) {
      return DennyGiveResult.fromJson(body);
    }
    throw ApiException('投币返回数据格式异常');
  }
}
