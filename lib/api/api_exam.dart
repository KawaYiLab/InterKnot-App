part of 'api.dart';

class ExamOption {
  final String key;
  final String text;

  ExamOption({required this.key, required this.text});

  factory ExamOption.fromJson(Map<String, dynamic> json) => ExamOption(
        key: json['key']?.toString() ?? '',
        text: json['text']?.toString() ?? '',
      );
}

class ExamQuestion {
  final String questionId;
  final String question;
  final String type;
  final List<ExamOption> options;
  final int weight;

  ExamQuestion({
    required this.questionId,
    required this.question,
    required this.type,
    required this.options,
    required this.weight,
  });

  factory ExamQuestion.fromJson(Map<String, dynamic> json) => ExamQuestion(
        questionId: json['questionId']?.toString() ?? '',
        question: json['question']?.toString() ?? '',
        type: json['type']?.toString() ?? 'single',
        options: (json['options'] as List<dynamic>?)
                ?.map((e) => e is Map<String, dynamic>
                    ? ExamOption.fromJson(e)
                    : ExamOption(key: '', text: ''))
                .where((o) => o.key.isNotEmpty)
                .toList() ??
            [],
        weight: (json['weight'] as num?)?.toInt() ?? 1,
      );
}

class ExamConfig {
  final int questionCount;
  final int passScorePercent;
  final int timeLimitSeconds;
  final int maxFailsBeforeCooldown;
  final int failCooldownSeconds;
  final int rewardDenny;
  final int rewardExp;

  ExamConfig({
    required this.questionCount,
    required this.passScorePercent,
    required this.timeLimitSeconds,
    required this.maxFailsBeforeCooldown,
    required this.failCooldownSeconds,
    required this.rewardDenny,
    required this.rewardExp,
  });

  factory ExamConfig.fromJson(Map<String, dynamic> json) => ExamConfig(
        questionCount: (json['questionCount'] as num?)?.toInt() ?? 0,
        passScorePercent: (json['passScorePercent'] as num?)?.toInt() ?? 0,
        timeLimitSeconds: (json['timeLimitSeconds'] as num?)?.toInt() ?? 0,
        maxFailsBeforeCooldown:
            (json['maxFailsBeforeCooldown'] as num?)?.toInt() ?? 0,
        failCooldownSeconds:
            (json['failCooldownSeconds'] as num?)?.toInt() ?? 0,
        rewardDenny: (json['rewardDenny'] as num?)?.toInt() ?? 0,
        rewardExp: (json['rewardExp'] as num?)?.toInt() ?? 0,
      );
}

class ExamStatus {
  final bool passed;
  final String? passedAt;
  final int cooldownRemaining;
  final ExamActiveAttempt? activeAttempt;
  final ExamConfig config;

  ExamStatus({
    required this.passed,
    this.passedAt,
    this.cooldownRemaining = 0,
    this.activeAttempt,
    required this.config,
  });

  factory ExamStatus.fromJson(Map<String, dynamic> json) => ExamStatus(
        passed: json['passed'] == true,
        passedAt: json['passedAt']?.toString(),
        cooldownRemaining: (json['cooldownRemaining'] as num?)?.toInt() ?? 0,
        activeAttempt: json['activeAttempt'] is Map<String, dynamic>
            ? ExamActiveAttempt.fromJson(
                json['activeAttempt'] as Map<String, dynamic>)
            : null,
        config: ExamConfig.fromJson(
          json['config'] is Map<String, dynamic>
              ? json['config'] as Map<String, dynamic>
              : {},
        ),
      );
}

class ExamActiveAttempt {
  final String attemptId;
  final String startedAt;
  final String expiresAt;
  final int questionCount;

  ExamActiveAttempt({
    required this.attemptId,
    required this.startedAt,
    required this.expiresAt,
    required this.questionCount,
  });

  factory ExamActiveAttempt.fromJson(Map<String, dynamic> json) =>
      ExamActiveAttempt(
        attemptId: json['attemptId']?.toString() ?? '',
        startedAt: json['startedAt']?.toString() ?? '',
        expiresAt: json['expiresAt']?.toString() ?? '',
        questionCount: (json['questionCount'] as num?)?.toInt() ?? 0,
      );
}

class ExamStartResult {
  final String attemptId;
  final bool resumed;
  final String startedAt;
  final String expiresAt;
  final List<ExamQuestion> questions;
  final ExamConfig config;

  ExamStartResult({
    required this.attemptId,
    required this.resumed,
    required this.startedAt,
    required this.expiresAt,
    required this.questions,
    required this.config,
  });

  factory ExamStartResult.fromJson(Map<String, dynamic> json) =>
      ExamStartResult(
        attemptId: json['attemptId']?.toString() ?? '',
        resumed: json['resumed'] == true,
        startedAt: json['startedAt']?.toString() ?? '',
        expiresAt: json['expiresAt']?.toString() ?? '',
        questions: (json['questions'] as List<dynamic>?)
                ?.map((e) => e is Map<String, dynamic>
                    ? ExamQuestion.fromJson(e)
                    : ExamQuestion(
                        questionId: '',
                        question: '',
                        type: 'single',
                        options: [],
                        weight: 1))
                .where((q) => q.questionId.isNotEmpty)
                .toList() ??
            [],
        config: ExamConfig.fromJson(
          json['config'] is Map<String, dynamic>
              ? json['config'] as Map<String, dynamic>
              : {},
        ),
      );
}

class ExamSubmitResult {
  final bool passed;
  final int score;
  final int totalScore;
  final int scorePercent;
  final int correctCount;
  final int questionCount;
  final int passScorePercent;
  final int cooldownRemaining;
  final ({int denny, int exp})? reward;

  ExamSubmitResult({
    required this.passed,
    required this.score,
    required this.totalScore,
    required this.scorePercent,
    required this.correctCount,
    required this.questionCount,
    required this.passScorePercent,
    required this.cooldownRemaining,
    this.reward,
  });

  factory ExamSubmitResult.fromJson(Map<String, dynamic> json) {
    final rewardMap = json['reward'];
    return ExamSubmitResult(
      passed: json['passed'] == true,
      score: (json['score'] as num?)?.toInt() ?? 0,
      totalScore: (json['totalScore'] as num?)?.toInt() ?? 0,
      scorePercent: (json['scorePercent'] as num?)?.toInt() ?? 0,
      correctCount: (json['correctCount'] as num?)?.toInt() ?? 0,
      questionCount: (json['questionCount'] as num?)?.toInt() ?? 0,
      passScorePercent: (json['passScorePercent'] as num?)?.toInt() ?? 0,
      cooldownRemaining: (json['cooldownRemaining'] as num?)?.toInt() ?? 0,
      reward: rewardMap is Map<String, dynamic>
          ? (
              denny: (rewardMap['denny'] as num?)?.toInt() ?? 0,
              exp: (rewardMap['exp'] as num?)?.toInt() ?? 0,
            )
          : null,
    );
  }
}

extension ExamApi on Api {
  /// GET /api/exam/status
  Future<ExamStatus> getExamStatus() async {
    final res = await get('/api/exam/status');
    if (res.hasError) {
      throw ApiException(
        _errorMessageFromBody(res.body) ?? '获取考试状态失败',
        statusCode: res.statusCode,
        details: res.body,
      );
    }
    final body = res.body;
    if (body is Map<String, dynamic>) {
      return ExamStatus.fromJson(body);
    }
    throw ApiException('考试状态数据格式异常');
  }

  /// POST /api/exam/start
  Future<ExamStartResult> startExam() async {
    final res = await post('/api/exam/start', <String, dynamic>{});
    if (res.hasError) {
      throw ApiException(
        _errorMessageFromBody(res.body) ?? '开始考试失败',
        statusCode: res.statusCode,
        details: res.body,
      );
    }
    final body = res.body;
    if (body is Map<String, dynamic>) {
      return ExamStartResult.fromJson(body);
    }
    throw ApiException('开始考试数据格式异常');
  }

  /// POST /api/exam/submit
  Future<ExamSubmitResult> submitExam(
    String attemptId,
    Map<String, List<String>> answers,
  ) async {
    final res = await post(
      '/api/exam/submit',
      {
        'attemptId': attemptId,
        'answers': answers,
      },
    );
    if (res.hasError) {
      throw ApiException(
        _errorMessageFromBody(res.body) ?? '提交答卷失败',
        statusCode: res.statusCode,
        details: res.body,
      );
    }
    final body = res.body;
    if (body is Map<String, dynamic>) {
      return ExamSubmitResult.fromJson(body);
    }
    throw ApiException('提交答卷数据格式异常');
  }
}
