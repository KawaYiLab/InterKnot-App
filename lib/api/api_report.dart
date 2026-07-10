part of 'api.dart';

/// 举报原因（与后端 REPORT_REASONS 对齐）
const reportReasons = [
  'spam',
  'abuse',
  'porn',
  'illegal',
  'privacy',
  'misinfo',
  'plagiarism',
  'other',
];

class ReportCreated {
  final String? documentId;
  final String targetType;
  final String reason;
  final String reportStatus;
  final String? createdAt;

  ReportCreated({
    this.documentId,
    required this.targetType,
    required this.reason,
    required this.reportStatus,
    this.createdAt,
  });

  factory ReportCreated.fromJson(Map<String, dynamic> json) => ReportCreated(
        documentId: json['documentId']?.toString(),
        targetType: json['targetType']?.toString() ?? '',
        reason: json['reason']?.toString() ?? '',
        reportStatus: json['reportStatus']?.toString() ?? '',
        createdAt: json['createdAt']?.toString(),
      );
}

class ReportItem {
  final String? documentId;
  final String targetType;
  final String reason;
  final String? detail;
  final String reportStatus;
  final String? resolution;
  final String? createdAt;
  final String? handledAt;
  final Map<String, dynamic>? target;

  ReportItem({
    this.documentId,
    required this.targetType,
    required this.reason,
    this.detail,
    required this.reportStatus,
    this.resolution,
    this.createdAt,
    this.handledAt,
    this.target,
  });

  factory ReportItem.fromJson(Map<String, dynamic> json) => ReportItem(
        documentId: json['documentId']?.toString(),
        targetType: json['targetType']?.toString() ?? '',
        reason: json['reason']?.toString() ?? '',
        detail: json['detail']?.toString(),
        reportStatus: json['reportStatus']?.toString() ?? '',
        resolution: json['resolution']?.toString(),
        createdAt: json['createdAt']?.toString(),
        handledAt: json['handledAt']?.toString(),
        target: json['target'] is Map<String, dynamic>
            ? json['target'] as Map<String, dynamic>
            : null,
      );
}

class ReportListResult {
  final List<ReportItem> data;
  final int total;

  ReportListResult({required this.data, required this.total});

  factory ReportListResult.fromJson(Map<String, dynamic> json) {
    final list = json['data'];
    final meta = json['meta'];
    final pagination = meta is Map ? meta['pagination'] : null;
    return ReportListResult(
      data: list is List
          ? list
              .whereType<Map<String, dynamic>>()
              .map(ReportItem.fromJson)
              .toList()
          : [],
      total: (pagination is Map ? (pagination['total'] as num?)?.toInt() : null) ??
          (list is List ? list.length : 0),
    );
  }
}

extension ReportApi on Api {
  /// POST /api/reports
  Future<ReportCreated> createReport({
    required String targetType,
    required String targetId,
    required String reason,
    String? detail,
  }) async {
    final res = await post('/api/reports', {
      'targetType': targetType,
      'targetId': targetId,
      'reason': reason,
      if (detail != null && detail.isNotEmpty) 'detail': detail,
    });
    if (res.hasError) {
      throw ApiException(
        _errorMessageFromBody(res.body) ?? '举报失败',
        statusCode: res.statusCode,
      );
    }
    final body = res.body;
    if (body is Map<String, dynamic>) {
      final data = body['data'];
      if (data is Map<String, dynamic>) {
        return ReportCreated.fromJson(data);
      }
    }
    throw ApiException('举报返回数据格式异常');
  }

  /// GET /api/reports/check
  /// query: { targetType, targetIds: comma-separated }
  Future<Map<String, bool>> checkReportStatus({
    required String targetType,
    required List<String> targetIds,
  }) async {
    if (targetIds.isEmpty) return {};
    final res = await get('/api/reports/check', query: {
      'targetType': targetType,
      'targetIds': targetIds.join(','),
    });
    if (res.hasError) {
      throw ApiException(
        _errorMessageFromBody(res.body) ?? '获取举报状态失败',
        statusCode: res.statusCode,
      );
    }
    final body = res.body;
    if (body is Map<String, dynamic>) {
      final data = body['data'];
      if (data is Map) {
        return data.map((k, v) => MapEntry(k.toString(), v == true));
      }
    }
    throw ApiException('举报状态数据格式异常');
  }

  /// GET /api/reports/my-list
  Future<ReportListResult> getMyReports({
    int start = 0,
    int limit = 20,
  }) async {
    final res = await get('/api/reports/my-list', query: {
      'start': start.toString(),
      'limit': limit.toString(),
    });
    if (res.hasError) {
      throw ApiException(
        _errorMessageFromBody(res.body) ?? '获取举报列表失败',
        statusCode: res.statusCode,
      );
    }
    final body = res.body;
    if (body is Map<String, dynamic>) {
      return ReportListResult.fromJson(body);
    }
    throw ApiException('举报列表数据格式异常');
  }
}
