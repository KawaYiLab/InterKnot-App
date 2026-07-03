import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:inter_knot/api/api_exception.dart';
import 'package:inter_knot/constants/api_config.dart';
import 'package:inter_knot/helpers/box.dart';
import 'package:inter_knot/models/author.dart';
import 'package:inter_knot/models/captcha.dart';
import 'package:inter_knot/models/comment.dart';
import 'package:inter_knot/models/discussion.dart';
import 'package:inter_knot/models/h_data.dart';
import 'package:inter_knot/models/pagination.dart';
import 'package:inter_knot/controllers/data.dart';

part 'api_auth.dart';
part 'api_system.dart';
part 'api_article.dart';
part 'api_comment.dart';
part 'api_interaction.dart';
part 'api_profile.dart';
part 'api_upload.dart';
part 'api_notification.dart';

String? _captchaErrorMessage(String? code) {
  switch (code) {
    case 'CAPTCHA_REQUIRED':
      return '请先完成验证码验证';
    case 'CAPTCHA_INVALID':
      return '验证码未通过，请重试';
    case 'CAPTCHA_VERIFY_FAILED':
      return '验证码服务异常，请稍后重试';
    case 'CAPTCHA_NOT_CONFIGURED':
      return '验证码服务未配置完成，请稍后再试';
    default:
      return null;
  }
}

class AuthApi extends GetConnect {
  @override
  void onInit() {
    httpClient.baseUrl = ApiConfig.baseUrl;
    httpClient.timeout = ApiConfig.timeout;
    httpClient.defaultContentType = 'application/json';
  }
}

class BaseConnect extends GetConnect {
  static final authApi = Get.put(AuthApi());

  // 重试配置
  static const int _maxRetries = 3;
  static const Duration _baseRetryDelay = Duration(milliseconds: 500);
  static const Duration _maxRetryDelay = Duration(seconds: 5);

  @override
  void onInit() {
    httpClient.baseUrl = ApiConfig.baseUrl;
    httpClient.timeout = ApiConfig.timeout;
    httpClient.defaultContentType = 'application/json';
    httpClient.addRequestModifier<dynamic>((request) {
      final token = box.read<String>('access_token') ?? '';
      final path = request.url.path;

      // Define public endpoints that should not send auth token to maximize cache hits
      // Matches /api/articles, /api/comments, /api/authors and their sub-paths
      // EXCEPT specific user-related endpoints like /api/articles/my
      final isPublicEndpoint =
          (path.startsWith('/api/articles') && !path.contains('/my')) ||
              (path.startsWith('/api/comments') && !path.contains('/likes')) ||
              path.startsWith('/api/profiles');

      // Only attach token if it exists AND (it's not a GET request OR it's not a public endpoint)
      // This ensures POST/PUT/DELETE always get auth, but GET public data stays anonymous for caching
      if (token.isNotEmpty &&
          !(request.method.toUpperCase() == 'GET' && isPublicEndpoint)) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      return Future.value(request);
    });
    httpClient.addResponseModifier((req, rep) {
      if (rep.statusCode == 401) {
        // Token is invalid/expired
        box.remove('access_token');
        // Do NOT redirect to login page automatically, let the UI handle the unauthenticated state
        // or let the user choose to login again.
        // Get.offAll(() => const LoginPage());
      }
      return rep;
    });
  }

  bool _shouldRetry(Response? response, dynamic error) {
    if (response == null) return true;

    final code = response.statusCode;
    if (code != null) {
      final s = code.toString();
      if (s.startsWith('5') ||
          s.startsWith('6') ||
          s.startsWith('7') ||
          code == 429) {
        return true;
      }
    }

    String? message;
    try {
      final body = response.body;
      if (body is Map && body['error'] != null) {
        final error = body['error'];
        if (error is Map && error['message'] != null) {
          message = error['message'].toString();
        } else if (error is String) {
          message = error;
        }
      }
    } catch (_) {}

    message ??= response.statusText ?? '';

    if (message.contains('短时间内请求数量过多') ||
        message.contains('XMLHttpRequest error')) {
      return true;
    }

    return false;
  }

  Duration _calculateDelay(int attempt) {
    final delayMs = _baseRetryDelay.inMilliseconds * (1 << attempt);
    final clampedDelayMs = delayMs.clamp(
      _baseRetryDelay.inMilliseconds,
      _maxRetryDelay.inMilliseconds,
    );
    return Duration(milliseconds: clampedDelayMs);
  }

  Future<Response<T>> retryRequest<T>(
    Future<Response<T>> Function() requestFn, {
    String? operationName,
  }) async {
    int attempts = 0;

    while (true) {
      try {
        final response = await requestFn();

        if (!response.hasError || !_shouldRetry(response, null)) {
          return response;
        }

        attempts++;
        if (attempts > _maxRetries) {
          debugPrint(
              '${operationName ?? "Request"} failed after $_maxRetries retries');
          return response;
        }

        final delay = _calculateDelay(attempts - 1);
        debugPrint(
            '${operationName ?? "Request"} failed with ${response.statusCode}, '
            'retrying in ${delay.inMilliseconds}ms (attempt $attempts/$_maxRetries)');

        await Future.delayed(delay);
      } catch (e) {
        attempts++;
        if (attempts > _maxRetries) {
          debugPrint(
              '${operationName ?? "Request"} failed after $_maxRetries retries: $e');
          rethrow;
        }

        final delay = _calculateDelay(attempts - 1);
        debugPrint('${operationName ?? "Request"} error: $e, '
            'retrying in ${delay.inMilliseconds}ms (attempt $attempts/$_maxRetries)');

        await Future.delayed(delay);
      }
    }
  }

  Future<Response<T>> getWithRetry<T>(
    String url, {
    Map<String, String>? query,
    String? contentType,
    Map<String, String>? headers,
    String? operationName,
  }) async {
    return retryRequest(
      () =>
          get<T>(url, query: query, contentType: contentType, headers: headers),
      operationName: operationName ?? 'GET $url',
    );
  }

  Future<Response<T>> postWithRetry<T>(
    String url,
    dynamic body, {
    String? contentType,
    Map<String, String>? headers,
    Map<String, dynamic>? query,
    void Function(double)? uploadProgress,
    String? operationName,
  }) async {
    return retryRequest(
      () => post<T>(url, body,
          contentType: contentType,
          headers: headers,
          query: query,
          uploadProgress: uploadProgress),
      operationName: operationName ?? 'POST $url',
    );
  }

  Future<Response<T>> putWithRetry<T>(
    String url,
    dynamic body, {
    String? contentType,
    Map<String, String>? headers,
    Map<String, dynamic>? query,
    String? operationName,
  }) async {
    return retryRequest(
      () => put<T>(url, body,
          contentType: contentType, headers: headers, query: query),
      operationName: operationName ?? 'PUT $url',
    );
  }

  Future<Response<T>> deleteWithRetry<T>(
    String url, {
    String? contentType,
    Map<String, String>? headers,
    Map<String, dynamic>? query,
    String? operationName,
  }) async {
    return retryRequest(
      () => delete<T>(url,
          contentType: contentType, headers: headers, query: query),
      operationName: operationName ?? 'DELETE $url',
    );
  }

  /// Extracts 'data' from Strapi v5 response and handles errors
  T unwrapData<T>(Response response) {
    if (response.hasError) {
      debugPrint('API Error: ${response.statusCode} - ${response.bodyString}');
      final body = response.body;
      String? message = response.statusText;

      if (body is Map) {
        final error = body['error'];
        if (error is Map) {
          message = _captchaErrorMessage(error['code']?.toString()) ??
              error['message']?.toString();
        } else if (error is String) {
          message = error;
        }
      }

      final code = response.statusCode;
      if (code != null) {
        final s = code.toString();
        if (s.startsWith('5') || s.startsWith('6') || s.startsWith('7')) {
          message = '短时间内请求数量过多';
        }
      }

      if (message != null && message.contains('XMLHttpRequest error')) {
        message = '短时间内请求数量过多';
      }

      throw ApiException(message ?? 'Unknown error',
          statusCode: response.statusCode, details: response.body);
    }

    final body = response.body;
    if (body is Map<String, dynamic>) {
      if (body.containsKey('data')) {
        return body['data'] as T;
      }
      return body as T;
    }
    return body as T;
  }
}

// Top-level function for compute
DiscussionModel _parseDiscussionSync(Map<String, dynamic> data) {
  return parseDiscussionData(data);
}

DiscussionModel _parseEditableDraftDiscussionSync(Map<String, dynamic> data) {
  return parseDiscussionData(
    data,
    isEditableDraft: true,
  );
}

({List<HDataModel> nodes, List<DiscussionModel> discussions})
    _parseHDataListAndDiscussionsSync(List<dynamic> data) {
  final nodes = <HDataModel>[];
  final discussions = <DiscussionModel>[];

  for (final e in data) {
    if (e is! Map<String, dynamic>) continue;
    try {
      final hData = HDataModel.fromMap(e);
      nodes.add(hData);

      if (e['title'] != null) {
        final discussion = DiscussionModel.fromJson(e);
        discussions.add(discussion);
      }
    } catch (_) {
      // ignore
    }
  }
  return (nodes: nodes, discussions: discussions);
}

({List<HDataModel> nodes, List<DiscussionModel> discussions})
    _parseEditableDraftListAndDiscussionsSync(List<dynamic> data) {
  final nodes = <HDataModel>[];
  final discussions = <DiscussionModel>[];

  for (final e in data) {
    if (e is! Map<String, dynamic>) continue;
    try {
      final hData = HDataModel.fromMap(
        e,
        isEditableDraft: true,
      );
      nodes.add(hData);

      if (e['title'] != null) {
        final discussion = DiscussionModel.fromJson(
          e,
          isEditableDraft: true,
        );
        discussions.add(discussion);
      }
    } catch (_) {
      // ignore
    }
  }

  return (nodes: nodes, discussions: discussions);
}

List<CommentModel> _parseCommentListSync(List<dynamic> data) {
  return data.cast<Map<String, dynamic>>().map(CommentModel.fromJson).toList();
}

class Api extends BaseConnect {
  String? _normalizeFileUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('http')) return url;
    return '${ApiConfig.baseUrl}$url';
  }

  Map<String, dynamic> _withCaptcha(
    Map<String, dynamic> payload,
    CaptchaPayload? captcha,
  ) {
    if (captcha == null) return payload;
    return {
      ...payload,
      'captcha': captcha.toJson(),
    };
  }

  String _contentTypeFromFilename(String filename) {
    final ext = filename.toLowerCase();
    if (ext.endsWith('.png')) return 'image/png';
    if (ext.endsWith('.webp')) return 'image/webp';
    if (ext.endsWith('.gif')) return 'image/gif';
    if (ext.endsWith('.bmp')) return 'image/bmp';
    return 'image/jpeg';
  }

  String _slugify(String input, {bool ensureUnique = false}) {
    final normalized = input
        .toLowerCase()
        .trim()
        .replaceAll(RegExp('[^a-z0-9]+'), '-')
        .replaceAll(RegExp('-{2,}'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    var slug = normalized.isEmpty ? 'author' : normalized;

    if (ensureUnique) {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      slug = '$slug-$timestamp';
    }

    return slug;
  }

  Object _coerceId(String value) {
    final asInt = int.tryParse(value);
    return asInt ?? value;
  }

  Future<void> _mergeReadStatus(List<dynamic> data,
      {required String tag}) async {
    final userId = box.read<String>('userId');
    if (userId == null || userId.isEmpty || data.isEmpty) return;

    final ids = <String>[];
    for (final item in data) {
      if (item is Map) {
        final id = item['documentId'];
        if (id != null) ids.add(id.toString());
      }
    }
    if (ids.isEmpty) return;

    try {
      final readRes = await post(
        '/api/article-reads/batch',
        {
          'articleDocumentIds': ids,
        },
      );
      final readList = unwrapData<List<dynamic>>(readRes);
      final readMap = <String, bool>{};
      for (final r in readList) {
        if (r is Map) {
          final articleId = r['articleDocumentId'];
          final isRead = r['isRead'] == true;
          if (isRead && articleId != null) {
            readMap[articleId.toString()] = true;
          }
        }
      }

      if (readMap.isEmpty) return;

      for (final d in data) {
        if (d is Map) {
          final id = d['documentId'];
          if (id != null && readMap.containsKey(id.toString())) {
            d['isRead'] = true;
          }
        }
      }
    } catch (e) {
      debugPrint('$tag Read Status Error: $e');
    }
  }

  dynamic _normalizeArticleCover(dynamic coverId) {
    if (coverId == null) return null;

    if (coverId is String) {
      if (coverId.isEmpty) return null;
      return _coerceId(coverId);
    }

    if (coverId is List) {
      final normalized = coverId
          .map((e) => e is String ? _coerceId(e) : e)
          .where((e) => e != null && e.toString().isNotEmpty)
          .toList();
      return normalized;
    }

    return coverId;
  }

  Future<void> _fetchAndSetAvatar(AuthorModel user) async {
    if (user.avatar.isEmpty &&
        user.authorId != null &&
        user.authorId!.isNotEmpty) {
      try {
        final url = await getAuthorAvatarUrl(user.authorId!);
        if (url != null && url.isNotEmpty) {
          user.avatar = url;
        }
      } catch (_) {
        // Ignore avatar fetch errors
      }
    }
  }
}
