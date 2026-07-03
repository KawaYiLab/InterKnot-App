part of 'api.dart';

extension NotificationApi on Api {
  Future<int> getUnreadNotificationCount() async {
    try {
      final res = await get('/api/notifications/unread-count');
      if (res.hasError) {
        debugPrint(
            'GetUnreadCount Error: ${res.statusCode} - ${res.bodyString}');
        if (res.statusCode == 403) {
          debugPrint(
              'Permission denied. Make sure user is logged in and has proper permissions.');
        }
        return 0;
      }
      final body = res.body;
      if (body is Map<String, dynamic>) {
        return body['count'] as int? ?? 0;
      }
      return 0;
    } catch (e) {
      debugPrint('GetUnreadCount Exception: $e');
      return 0;
    }
  }


  Future<PaginationModel<dynamic>> getNotifications(String endCur) async {
    final start = int.tryParse(endCur.isEmpty ? '0' : endCur) ?? 0;

    final queryParams = {
      'start': start.toString(),
      'limit': ApiConfig.defaultPageSize.toString(),
    };

    try {
      final res = await get(
        '/api/notifications/list',
        query: queryParams,
      );

      if (res.hasError) {
        debugPrint(
            'GetNotifications Error: ${res.statusCode} - ${res.bodyString}');
        if (res.statusCode == 403) {
          throw ApiException('没有权限访问通知', statusCode: 403);
        }
        throw ApiException('获取通知失败', statusCode: res.statusCode);
      }

      final data = unwrapData<List<dynamic>>(res);
      final hasNext = data.length >= ApiConfig.defaultPageSize;

      return PaginationModel(
        nodes: data,
        endCursor: (start + ApiConfig.defaultPageSize).toString(),
        hasNextPage: hasNext,
      );
    } catch (e) {
      debugPrint('GetNotifications Exception: $e');
      rethrow;
    }
  }


  Future<bool> markNotificationAsRead(String documentId) async {
    final res = await put(
      '/api/notifications/$documentId/mark-read',
      {},
    );
    if (res.hasError) {
      debugPrint(
          'MarkNotificationRead Error: ${res.statusCode} - ${res.bodyString}');
      return false;
    }
    final body = res.body;
    if (body is Map<String, dynamic>) {
      return body['success'] == true;
    }
    return false;
  }


  Future<bool> markAllNotificationsAsRead() async {
    final res = await put(
      '/api/notifications/mark-all-read',
      {},
    );
    if (res.hasError) {
      debugPrint(
          'MarkAllNotificationsRead Error: ${res.statusCode} - ${res.bodyString}');
      return false;
    }
    final body = res.body;
    if (body is Map<String, dynamic>) {
      return body['success'] == true;
    }
    return false;
  }

  // ─── Like API ───


}
