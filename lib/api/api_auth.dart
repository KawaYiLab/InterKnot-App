part of 'api.dart';

/// 从响应体提取后端返回的错误信息（Strapi 的 error.message），回退到状态文本，
/// 避免用户只看到 "Bad Request" 这类通用 HTTP 状态。
String _authErrorMessage(Response res) {
  final statusText = res.statusText ?? 'Request failed';
  if (statusText.contains('XMLHttpRequest error')) {
    return '短时间内请求数量过多';
  }
  try {
    final body = res.body;
    if (body is Map && body['error'] != null) {
      final error = body['error'];
      if (error is Map) {
        return error['message']?.toString() ?? statusText;
      } else if (error is String) {
        return error;
      }
    }
  } catch (_) {}
  return statusText;
}

extension AuthApiExtensions on AuthApi {
  Future<({String? token, AuthorModel user})> login(
      String email, String password,
      {CaptchaPayload? captcha}) async {
    final res = await post(
      '/api/auth/local',
      {'identifier': email, 'password': password},
    );

    if (res.hasError) {
      debugPrint('Login Error: ${res.statusCode} - ${res.bodyString}');
      throw ApiException(
        _authErrorMessage(res),
        statusCode: res.statusCode,
      );
    }

    final body = res.body as Map<String, dynamic>;
    return (
      token: body['jwt'] as String?,
      user: AuthorModel.fromJson(body['user'] as Map<String, dynamic>)
    );
  }


  Future<Response> sendRegisterCode(String email) {
    return post('/api/auth/send-register-code', {'email': email});
  }


  Future<({String? token, AuthorModel user})> registerWithCode(
    String email,
    String code,
    String password,
  ) async {
    final res = await post(
      '/api/auth/register-with-code',
      {'email': email, 'code': code, 'password': password},
    );

    if (res.hasError) {
      debugPrint('Register Error: ${res.statusCode} - ${res.bodyString}');
      throw ApiException(
        _authErrorMessage(res),
        statusCode: res.statusCode,
      );
    }

    final body = res.body as Map<String, dynamic>;
    return (
      token: body['jwt'] as String?,
      user: AuthorModel.fromJson(body['user'] as Map<String, dynamic>)
    );
  }


  Future<Response> sendResetCode(String email) {
    return post('/api/auth/send-reset-code', {'email': email});
  }


  Future<Response> resetPassword(
    String email,
    String code,
    String password,
  ) {
    return post('/api/auth/reset-password', {
      'email': email,
      'code': code,
      'password': password,
    });
  }
}
