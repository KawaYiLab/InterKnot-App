part of 'api.dart';

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
        res.statusText ?? 'Request failed',
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
        res.statusText ?? 'Request failed',
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
