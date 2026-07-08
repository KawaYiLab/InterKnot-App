part of 'api.dart';

extension UploadApi on Api {
  Future<String?> uploadAvatar({
    required List<int> bytes,
    required String filename,
    String? contentType,
  }) async {
    final result = await uploadImageDirect(
      bytes: bytes,
      filename: filename,
      mimeType: contentType ?? _contentTypeFromFilename(filename),
      path: 'avatars',
      onProgress: (_) {}, // 头像上传不需要进度回调
    );

    if (result == null) {
      throw ApiException('Upload failed');
    }

    final rawAvatarId = result['id'];
    if (rawAvatarId == null) {
      throw ApiException('Upload response missing file id');
    }
    final uploadedUrl = _normalizeFileUrl(result['url'] as String?);

    // 后端统一的自定义头像入口（同时清空装备头像，扣除丁尼）
    final updateRes = await put(
      '/api/me/avatars/upload-custom',
      {'fileId': rawAvatarId},
    );

    if (updateRes.hasError) {
      throw ApiException(
        _errorMessageFromBody(updateRes.body) ??
            updateRes.statusText ??
            'Failed to bind avatar',
        statusCode: updateRes.statusCode,
      );
    }

    final body = updateRes.body;
    if (body is Map) {
      final avatar = body['avatar'];
      final url = avatar is Map ? avatar['url']?.toString() : null;
      if (url != null && url.isNotEmpty) return _normalizeFileUrl(url);
    }
    return uploadedUrl;
  }

  /// 直传图片到对象存储
  ///
  /// [bytes] - 图片二进制数据
  /// [filename] - 文件名
  /// [mimeType] - MIME 类型，如 'image/png'
  /// [path] - 存储路径，如 'avatars', 'editor'
  /// [onProgress] - 进度回调，参数为 0-100
  Future<Map<String, dynamic>?> uploadImageDirect({
    required List<int> bytes,
    required String filename,
    required String mimeType,
    String path = 'editor',
    int? width,
    int? height,
    required void Function(int percent) onProgress,
  }) async {
    final token = box.read<String>('access_token') ?? '';
    final authHeaders = token.isNotEmpty
        ? {'Authorization': 'Bearer $token'}
        : <String, String>{};

    // 1. 获取签名
    final signRes = await postWithRetry(
      '/api/direct-upload/sign',
      {
        'filename': filename,
        'mimeType': mimeType,
        'size': bytes.length,
        'path': path,
        'fileInfo': {
          'name': filename,
          'alternativeText': filename,
        },
      },
      headers: authHeaders,
      operationName: 'DirectUpload Sign',
    );

    if (signRes.hasError) {
      throw ApiException(
        signRes.statusText ?? '获取上传签名失败',
        statusCode: signRes.statusCode,
      );
    }

    final signData = unwrapData<Map<String, dynamic>>(signRes);
    final uploadUrl = signData['uploadUrl'] as String;
    final uploadToken = signData['uploadToken'] as String;
    final headers = (signData['headers'] as Map<String, dynamic>?)
            ?.map((k, v) => MapEntry(k, v.toString())) ??
        <String, String>{};

    onProgress(10);

    // 2. 直传到对象存储（使用原始字节流）
    try {
      final uploadResp = await http.put(
        Uri.parse(uploadUrl),
        headers: headers,
        body: bytes,
      );

      if (uploadResp.statusCode != 200 && uploadResp.statusCode != 204) {
        throw ApiException(
          '上传到对象存储失败: ${uploadResp.statusCode} ${uploadResp.body}',
          statusCode: uploadResp.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('上传到对象存储失败: $e');
    }

    onProgress(80);

    // 3. 完成上传
    final completePayload = <String, dynamic>{
      'uploadToken': uploadToken,
    };
    if (width != null && height != null && width > 0 && height > 0) {
      completePayload['width'] = width;
      completePayload['height'] = height;
    }
    final completeRes = await postWithRetry(
      '/api/direct-upload/complete',
      completePayload,
      headers: authHeaders,
      operationName: 'DirectUpload Complete',
    );

    if (completeRes.hasError) {
      throw ApiException(
        completeRes.statusText ?? '完成上传失败',
        statusCode: completeRes.statusCode,
      );
    }

    onProgress(100);

    final completeData = unwrapData<Map<String, dynamic>>(completeRes);
    return completeData;
  }

  /// 通用图片上传（使用直传）
  ///
  /// [bytes] - 图片二进制数据
  /// [filename] - 文件名
  /// [mimeType] - MIME 类型，如 'image/png'
  /// [onProgress] - 进度回调，参数为 0-100
  Future<Map<String, dynamic>?> uploadImage({
    required List<int> bytes,
    required String filename,
    required String mimeType,
    int? width,
    int? height,
    required void Function(int percent) onProgress,
  }) async {
    return uploadImageDirect(
      bytes: bytes,
      filename: filename,
      mimeType: mimeType,
      width: width,
      height: height,
      onProgress: onProgress,
    );
  }
}
