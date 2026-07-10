part of 'api.dart';

class AvatarItem {
  final String documentId;
  final String name;
  final String type;
  final Map<String, dynamic>? image;

  AvatarItem({
    required this.documentId,
    required this.name,
    required this.type,
    this.image,
  });

  factory AvatarItem.fromJson(Map<String, dynamic> json) => AvatarItem(
        documentId: json['documentId']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        type: json['type']?.toString() ?? 'character',
        image: json['image'] is Map<String, dynamic>
            ? json['image'] as Map<String, dynamic>
            : null,
      );
}

class AvatarListResult {
  final List<AvatarItem> data;
  final String? equippedAvatarDocumentId;

  AvatarListResult({required this.data, this.equippedAvatarDocumentId});

  factory AvatarListResult.fromJson(Map<String, dynamic> json) =>
      AvatarListResult(
        data: (json['data'] as List<dynamic>?)
                ?.whereType<Map<String, dynamic>>()
                .map(AvatarItem.fromJson)
                .toList() ??
            [],
        equippedAvatarDocumentId:
            json['equippedAvatarDocumentId']?.toString(),
      );
}

class BusinessCardItem {
  final String documentId;
  final String name;
  final String? description;
  final String? story;
  final String type;
  final Map<String, dynamic>? image;

  BusinessCardItem({
    required this.documentId,
    required this.name,
    this.description,
    this.story,
    required this.type,
    this.image,
  });

  factory BusinessCardItem.fromJson(Map<String, dynamic> json) =>
      BusinessCardItem(
        documentId: json['documentId']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        description: json['description']?.toString(),
        story: json['story']?.toString(),
        type: json['type']?.toString() ?? 'character',
        image: json['image'] is Map<String, dynamic>
            ? json['image'] as Map<String, dynamic>
            : null,
      );
}

class BusinessCardListResult {
  final List<BusinessCardItem> data;
  final String? equippedCardDocumentId;

  BusinessCardListResult({
    required this.data,
    this.equippedCardDocumentId,
  });

  factory BusinessCardListResult.fromJson(Map<String, dynamic> json) =>
      BusinessCardListResult(
        data: (json['data'] as List<dynamic>?)
                ?.whereType<Map<String, dynamic>>()
                .map(BusinessCardItem.fromJson)
                .toList() ??
            [],
        equippedCardDocumentId: json['equippedCardDocumentId']?.toString(),
      );
}

class PinnedArticlesResult {
  final List<String>? pinned;
  final List<Map<String, dynamic>> candidates;
  final int max;

  PinnedArticlesResult({
    this.pinned,
    required this.candidates,
    required this.max,
  });

  factory PinnedArticlesResult.fromJson(Map<String, dynamic> json) =>
      PinnedArticlesResult(
        pinned: (json['pinned'] as List<dynamic>?)
            ?.whereType<String>()
            .toList(),
        candidates: (json['candidates'] as List<dynamic>?)
                ?.whereType<Map<String, dynamic>>()
                .toList() ??
            [],
        max: (json['max'] as num?)?.toInt() ?? 6,
      );
}

/// 当前登录用户相关接口（/api/me/*）。
extension MeApi on Api {
  /// GET /api/me/profile
  /// 返回当前用户信息及关联 author（含头像）。
  Future<Map<String, dynamic>> getMyProfile() async {
    final res = await get('/api/me/profile');
    if (res.hasError) {
      throw ApiException(
        _errorMessageFromBody(res.body) ?? '获取个人信息失败',
        statusCode: res.statusCode,
      );
    }
    final body = res.body;
    if (body is Map<String, dynamic>) return body;
    throw ApiException('个人资料数据格式异常');
  }

  /// PUT /api/me/profile/name
  /// 后端会同时更新 user.username 与 author.name（扣除 10 丁尼）。
  Future<String> updateMyName(String name) async {
    final res = await put('/api/me/profile/name', {'name': name});
    if (res.hasError) {
      throw ApiException(
        _errorMessageFromBody(res.body) ?? '改名失败',
        statusCode: res.statusCode,
      );
    }
    final body = res.body;
    if (body is Map && body['success'] == true) {
      return body['name']?.toString() ?? name;
    }
    throw ApiException('改名返回数据格式异常');
  }

  /// PUT /api/me/profile/bio
  Future<void> updateMyBio(String bio) async {
    final res = await put('/api/me/profile/bio', {'bio': bio});
    if (res.hasError) {
      throw ApiException(
        _errorMessageFromBody(res.body) ?? '更新签名失败',
        statusCode: res.statusCode,
      );
    }
  }

  /// PUT /api/me/profile/visibility
  Future<bool> updateMyVisibility(bool profileHidden) async {
    final res = await put('/api/me/profile/visibility', {
      'profileHidden': profileHidden,
    });
    if (res.hasError) {
      throw ApiException(
        _errorMessageFromBody(res.body) ?? '更新可见性失败',
        statusCode: res.statusCode,
      );
    }
    final body = res.body;
    if (body is Map && body['success'] == true) {
      return body['profileHidden'] == true;
    }
    return profileHidden;
  }

  /// GET /api/me/profile/pinned-articles
  Future<PinnedArticlesResult> getMyPinnedArticles() async {
    final res = await get('/api/me/profile/pinned-articles');
    if (res.hasError) {
      throw ApiException(
        _errorMessageFromBody(res.body) ?? '获取置顶候选失败',
        statusCode: res.statusCode,
      );
    }
    final body = res.body;
    if (body is Map<String, dynamic>) {
      return PinnedArticlesResult.fromJson(body);
    }
    throw ApiException('置顶文章数据格式异常');
  }

  /// PUT /api/me/profile/pinned-articles
  Future<List<String>?> updateMyPinnedArticles(List<String> pinned) async {
    final res = await put('/api/me/profile/pinned-articles', {
      'pinned': pinned,
    });
    if (res.hasError) {
      throw ApiException(
        _errorMessageFromBody(res.body) ?? '更新置顶失败',
        statusCode: res.statusCode,
      );
    }
    final body = res.body;
    if (body is Map) {
      final raw = body['pinned'];
      if (raw == null) return null;
      if (raw is List) {
        return raw.whereType<String>().toList();
      }
    }
    return pinned;
  }

  /// GET /api/me/avatars
  Future<AvatarListResult> getMyAvatars() async {
    final res = await get('/api/me/avatars');
    if (res.hasError) {
      throw ApiException(
        _errorMessageFromBody(res.body) ?? '获取头像列表失败',
        statusCode: res.statusCode,
      );
    }
    final body = res.body;
    if (body is Map<String, dynamic>) {
      return AvatarListResult.fromJson(body);
    }
    throw ApiException('头像列表数据格式异常');
  }

  /// PUT /api/me/avatars/equip
  Future<String?> equipAvatar(String? documentId) async {
    final res = await put('/api/me/avatars/equip', {
      'documentId': documentId,
    });
    if (res.hasError) {
      throw ApiException(
        _errorMessageFromBody(res.body) ?? '装备头像失败',
        statusCode: res.statusCode,
      );
    }
    final body = res.body;
    if (body is Map) {
      return body['equippedAvatarDocumentId']?.toString();
    }
    return documentId;
  }

  /// GET /api/me/business-cards
  Future<BusinessCardListResult> getMyBusinessCards({String? type}) async {
    final res = await get('/api/me/business-cards', query: {
      if (type != null && type.isNotEmpty) 'type': type,
    });
    if (res.hasError) {
      throw ApiException(
        _errorMessageFromBody(res.body) ?? '获取名片列表失败',
        statusCode: res.statusCode,
      );
    }
    final body = res.body;
    if (body is Map<String, dynamic>) {
      return BusinessCardListResult.fromJson(body);
    }
    throw ApiException('名片列表数据格式异常');
  }

  /// PUT /api/me/business-cards/equip
  Future<String?> equipBusinessCard(String? documentId) async {
    final res = await put('/api/me/business-cards/equip', {
      'documentId': documentId,
    });
    if (res.hasError) {
      throw ApiException(
        _errorMessageFromBody(res.body) ?? '装备名片失败',
        statusCode: res.statusCode,
      );
    }
    final body = res.body;
    if (body is Map) {
      return body['equippedCardDocumentId']?.toString();
    }
    return documentId;
  }

  /// GET /api/me/uploads
  Future<List<Map<String, dynamic>>> getMyUploads({
    int page = 1,
    int pageSize = 24,
  }) async {
    final res = await get('/api/me/uploads', query: {
      'page': page.toString(),
      'pageSize': pageSize.toString(),
    });
    if (res.hasError) {
      throw ApiException(
        _errorMessageFromBody(res.body) ?? '获取上传列表失败',
        statusCode: res.statusCode,
      );
    }
    final body = res.body;
    if (body is Map<String, dynamic>) {
      final data = body['data'];
      if (data is List) {
        return data.whereType<Map<String, dynamic>>().toList();
      }
    }
    throw ApiException('上传返回数据格式异常');
  }
}

/// 后端错误码/通用英文文案 → 中文用户提示
const _apiErrorCodeMessages = {
  // 通用 HTTP/Strapi 错误
  'TOO_MANY_REQUESTS': '请求太频繁，请稍后再试',
  'INTERNAL_SERVER_ERROR': '服务器内部错误，请稍后再试',
  'REQUEST_ERROR': '请求失败，请稍后再试',
  'UNAUTHORIZED': '请先登录',
  'FORBIDDEN': '没有权限执行该操作',
  'NOT_FOUND': '内容不存在或已被删除',
  'BAD_REQUEST': '请求参数错误，请检查输入内容',
  'PAYLOAD_TOO_LARGE': '请求内容过大',
  'CONFLICT': '操作冲突，请稍后再试',
  'NotFoundError': '内容不存在或已被删除',
  'UnauthorizedError': '请先登录',
  'ForbiddenError': '没有权限执行该操作',
  'ValidationError': '请求参数错误，请检查输入内容',
  'YupValidationError': '请求参数错误，请检查输入内容',
  'ApplicationError': '请求失败，请稍后再试',
  'RateLimitError': '请求太频繁，请稍后再试',
  'PayloadTooLargeError': '请求内容过大',
  'NotImplementedError': '该功能尚未实现',
  // 考试相关
  'EXAM_REQUIRED': '需要完成入站考试才能进行此操作',
  'EXAM_COOLDOWN': '考试失败次数过多，请稍后再试',
  'EXAM_NOT_AVAILABLE': '题库暂未配置，请稍后再试',
  'EXAM_ATTEMPT_ID_REQUIRED': '缺少考试场次标识',
  'EXAM_ATTEMPT_NOT_FOUND': '考试场次不存在',
  'EXAM_ATTEMPT_ALREADY_SUBMITTED': '本场考试已提交',
  'EXAM_ATTEMPT_EXPIRED': '考试已超时，请重新开始',
  'EXAM_ALREADY_PASSED': '你已通过入站考试',
  // 签到/丁尼/经济
  'CHECK_IN_ALREADY_TODAY': '今日已签到',
  'CHECK_IN_FAILED': '签到失败，请稍后再试',
  'INSUFFICIENT_BALANCE': '丁尼余额不足',
  'ALREADY_GIVEN': '已经投过币了',
  'SELF_GIVE': '不能给自己的帖子投币',
  'ANONYMOUS_ARTICLE': '匿名帖子不能投币',
  'DEDUCT_FAILED': '扣除丁尼失败，请稍后再试',
  // 关注/举报/资料
  'ALREADY_FAVORITED': '已经收藏了',
  'ALREADY_LIKED': '已经点赞了',
  'CANNOT_FOLLOW_SELF': '不能关注自己',
  'ALREADY_REPORTED': '已经举报过了，正在处理中',
  'INVALID_TARGET': '举报目标无效',
  'INVALID_TARGET_TYPE': '举报类型无效',
  'INVALID_REASON': '举报原因无效',
  'ARTICLE_NOT_FOUND': '帖子不存在或已被删除',
  'COMMENT_NOT_FOUND': '评论不存在或已被删除',
  'USER_NOT_FOUND': '用户不存在',
  'AUTHOR_NOT_FOUND': '该用户不存在',
  'PROFILE_NOT_FOUND': '作者资料不存在',
  'EMAIL_ALREADY_TAKEN': '该邮箱已注册',
  'REGISTER_DISABLED': '当前不允许注册',
  'INVALID_EMAIL': '邮箱格式不正确',
  'INVALID_PASSWORD': '密码长度不能少于 6 位',
  'INVALID_VERIFICATION_CODE': '验证码必须是 6 位数字',
  'REGISTER_CODE_NOT_FOUND': '验证码不存在或已失效',
  'REGISTER_CODE_EXPIRED': '验证码已过期',
  'REGISTER_CODE_TOO_MANY_ATTEMPTS': '验证码错误次数过多，请重新获取',
  'REGISTER_CODE_INVALID': '验证码错误',
  'RESET_CODE_NOT_FOUND': '验证码不存在或已失效',
  'RESET_CODE_EXPIRED': '验证码已过期',
  'RESET_CODE_TOO_MANY_ATTEMPTS': '验证码错误次数过多，请重新获取',
  'RESET_CODE_INVALID': '验证码错误',
};

/// 通用英文提示文案 → 中文用户提示
const _apiErrorMessageTranslations = {
  'Internal server error': '服务器内部错误，请稍后再试',
  'Internal server error.': '服务器内部错误，请稍后再试',
  'Request failed': '请求失败，请稍后再试',
  'Not Found': '内容不存在或已被删除',
  'Not Found.': '内容不存在或已被删除',
  'Not found': '内容不存在或已被删除',
  'Not found.': '内容不存在或已被删除',
  'Unauthorized': '请先登录',
  'Unauthorized.': '请先登录',
  'Forbidden': '没有权限执行该操作',
  'Forbidden.': '没有权限执行该操作',
  'Bad Request': '请求参数错误，请检查输入内容',
  'Bad Request.': '请求参数错误，请检查输入内容',
  'Bad request': '请求参数错误，请检查输入内容',
  'Bad request.': '请求参数错误，请检查输入内容',
  'Too Many Requests': '请求太频繁，请稍后再试',
  'Too Many Requests.': '请求太频繁，请稍后再试',
  'Conflict': '操作冲突，请稍后再试',
  'Conflict.': '操作冲突，请稍后再试',
  'Rate limit exceeded. Please slow down.': '请求太频繁，请稍后再试',
  'Already checked in today.': '今日已签到',
  'Already checked in for the current check-in day.': '今日已签到',
  'Invalid identifier or password': '账号或密码错误',
  'Your account email is not confirmed': '账号邮箱未验证',
  'Your account has been blocked by an administrator': '账号已被管理员禁用',
  'Missing or invalid credentials': '缺少或无效的登录凭证',
  'Author profile not found': '作者资料不存在',
  'Author profile not found.': '作者资料不存在',
  'Author not found': '该用户不存在',
  'Author not found.': '该用户不存在',
  'Target not found': '举报目标不存在',
  'Target not found.': '举报目标不存在',
  'Cannot follow yourself': '不能关注自己',
  'Cannot follow yourself.': '不能关注自己',
  'Author does not belong to you': '该作者不属于你',
  'Author does not belong to you.': '该作者不属于你',
  'Missing authorDocumentId': '缺少作者ID',
  'Missing targetId': '缺少目标ID',
  'Missing documentId': '缺少文档ID',
  'Invalid targetType': '举报类型无效',
  'Invalid reason': '举报原因无效',
  'detail is required for reason "other"': '选择“其他”时需要填写详细说明',
  'You cannot follow yourself': '不能关注自己',
  'Already following': '已经关注过该用户',
};

bool _containsChinese(String text) {
  // CJK Unified Ideographs range
  return text.runes.any((r) => r >= 0x4e00 && r <= 0x9fff);
}

String? _errorMessageFromBody(dynamic body) {
  if (body is! Map) return null;
  final error = body['error'];
  if (error is String && error.isNotEmpty) {
    return _apiErrorCodeMessages[error] ??
        _apiErrorMessageTranslations[error] ??
        error;
  }
  if (error is! Map) return null;

  final message = error['message']?.toString();
  final code = error['code']?.toString();

  // 1. 后端已返回中文业务提示，直接透传
  if (message != null && message.isNotEmpty && _containsChinese(message)) {
    return message;
  }

  // 2. 已知英文通用文案优先按完整消息映射
  if (message != null && message.isNotEmpty) {
    final translated = _apiErrorMessageTranslations[message];
    if (translated != null) return translated;
  }

  // 3. 按 error.code 映射
  if (code != null && code.isNotEmpty) {
    final translated = _apiErrorCodeMessages[code];
    if (translated != null) return translated;
  }

  // 4. 返回原始英文提示兜底
  if (message != null && message.isNotEmpty) return message;
  if (code != null && code.isNotEmpty) return code;
  return null;
}
