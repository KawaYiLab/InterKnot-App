class ExamOption {
  final String key;
  final String text;

  const ExamOption({
    required this.key,
    required this.text,
  });

  factory ExamOption.fromJson(Map<String, dynamic> json) {
    return ExamOption(
      key: json['key']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        'text': text,
      };
}

class ExamQuestion {
  final String questionId;
  final String question;
  final String type;
  final List<ExamOption> options;
  final int weight;

  const ExamQuestion({
    required this.questionId,
    required this.question,
    required this.type,
    required this.options,
    required this.weight,
  });

  bool get isMultiple => type == 'multiple';
  bool get isBoolean => type == 'boolean';

  factory ExamQuestion.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'];
    return ExamQuestion(
      questionId: json['questionId']?.toString() ??
          json['documentId']?.toString() ??
          json['id']?.toString() ??
          '',
      question: json['question']?.toString() ?? '',
      type: json['type']?.toString() ?? 'single',
      options: rawOptions is List
          ? rawOptions
              .whereType<Map>()
              .map((item) =>
                  ExamOption.fromJson(Map<String, dynamic>.from(item)))
              .where((item) => item.key.isNotEmpty || item.text.isNotEmpty)
              .toList()
          : const <ExamOption>[],
      weight: json['weight'] is int
          ? json['weight'] as int
          : int.tryParse(json['weight']?.toString() ?? '') ?? 1,
    );
  }

  Map<String, dynamic> toJson() => {
        'questionId': questionId,
        'question': question,
        'type': type,
        'options': options.map((e) => e.toJson()).toList(),
        'weight': weight,
      };
}

class ExamConfig {
  final int questionCount;
  final int passScorePercent;
  final int timeLimitSeconds;
  final int maxFailsBeforeCooldown;
  final int failCooldownSeconds;
  final int rewardDenny;
  final int rewardExp;

  const ExamConfig({
    required this.questionCount,
    required this.passScorePercent,
    required this.timeLimitSeconds,
    required this.maxFailsBeforeCooldown,
    required this.failCooldownSeconds,
    required this.rewardDenny,
    required this.rewardExp,
  });

  factory ExamConfig.fromJson(Map<String, dynamic> json) {
    int readInt(String key) {
      final value = json[key];
      if (value is int) return value;
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    return ExamConfig(
      questionCount: readInt('questionCount'),
      passScorePercent: readInt('passScorePercent'),
      timeLimitSeconds: readInt('timeLimitSeconds'),
      maxFailsBeforeCooldown: readInt('maxFailsBeforeCooldown'),
      failCooldownSeconds: readInt('failCooldownSeconds'),
      rewardDenny: readInt('rewardDenny'),
      rewardExp: readInt('rewardExp'),
    );
  }

  Map<String, dynamic> toJson() => {
        'questionCount': questionCount,
        'passScorePercent': passScorePercent,
        'timeLimitSeconds': timeLimitSeconds,
        'maxFailsBeforeCooldown': maxFailsBeforeCooldown,
        'failCooldownSeconds': failCooldownSeconds,
        'rewardDenny': rewardDenny,
        'rewardExp': rewardExp,
      };
}

class ExamActiveAttempt {
  final String attemptId;
  final String startedAt;
  final String expiresAt;
  final int questionCount;

  const ExamActiveAttempt({
    required this.attemptId,
    required this.startedAt,
    required this.expiresAt,
    required this.questionCount,
  });

  factory ExamActiveAttempt.fromJson(Map<String, dynamic> json) {
    return ExamActiveAttempt(
      attemptId: json['attemptId']?.toString() ?? '',
      startedAt: json['startedAt']?.toString() ?? '',
      expiresAt: json['expiresAt']?.toString() ?? '',
      questionCount: json['questionCount'] is int
          ? json['questionCount'] as int
          : int.tryParse(json['questionCount']?.toString() ?? '') ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'attemptId': attemptId,
        'startedAt': startedAt,
        'expiresAt': expiresAt,
        'questionCount': questionCount,
      };
}

class ExamStatus {
  final bool passed;
  final String? passedAt;
  final int? cooldownRemaining;
  final ExamActiveAttempt? activeAttempt;
  final ExamConfig config;

  const ExamStatus({
    required this.passed,
    required this.passedAt,
    required this.cooldownRemaining,
    required this.activeAttempt,
    required this.config,
  });

  factory ExamStatus.fromJson(Map<String, dynamic> json) {
    final activeAttempt = json['activeAttempt'];
    final config = json['config'];
    return ExamStatus(
      passed: json['passed'] == true,
      passedAt: json['passedAt']?.toString(),
      cooldownRemaining: json['cooldownRemaining'] is int
          ? json['cooldownRemaining'] as int
          : int.tryParse(json['cooldownRemaining']?.toString() ?? ''),
      activeAttempt: activeAttempt is Map
          ? ExamActiveAttempt.fromJson(
              Map<String, dynamic>.from(activeAttempt),
            )
          : null,
      config: config is Map
          ? ExamConfig.fromJson(Map<String, dynamic>.from(config))
          : const ExamConfig(
              questionCount: 0,
              passScorePercent: 0,
              timeLimitSeconds: 0,
              maxFailsBeforeCooldown: 0,
              failCooldownSeconds: 0,
              rewardDenny: 0,
              rewardExp: 0,
            ),
    );
  }

  Map<String, dynamic> toJson() => {
        'passed': passed,
        'passedAt': passedAt,
        'cooldownRemaining': cooldownRemaining,
        'activeAttempt': activeAttempt?.toJson(),
        'config': config.toJson(),
      };
}

class ExamReward {
  final int denny;
  final int exp;

  const ExamReward({
    required this.denny,
    required this.exp,
  });

  factory ExamReward.fromJson(Map<String, dynamic> json) {
    int readInt(String key) {
      final value = json[key];
      if (value is int) return value;
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    return ExamReward(
      denny: readInt('denny'),
      exp: readInt('exp'),
    );
  }

  Map<String, dynamic> toJson() => {
        'denny': denny,
        'exp': exp,
      };
}

class ExamStartResult {
  final String attemptId;
  final bool resumed;
  final String startedAt;
  final String expiresAt;
  final List<ExamQuestion> questions;
  final ExamConfig config;

  const ExamStartResult({
    required this.attemptId,
    required this.resumed,
    required this.startedAt,
    required this.expiresAt,
    required this.questions,
    required this.config,
  });

  factory ExamStartResult.fromJson(Map<String, dynamic> json) {
    final questions = json['questions'];
    final config = json['config'];
    return ExamStartResult(
      attemptId: json['attemptId']?.toString() ?? '',
      resumed: json['resumed'] == true,
      startedAt: json['startedAt']?.toString() ?? '',
      expiresAt: json['expiresAt']?.toString() ?? '',
      questions: questions is List
          ? questions
              .whereType<Map>()
              .map((item) =>
                  ExamQuestion.fromJson(Map<String, dynamic>.from(item)))
              .toList()
          : const <ExamQuestion>[],
      config: config is Map
          ? ExamConfig.fromJson(Map<String, dynamic>.from(config))
          : const ExamConfig(
              questionCount: 0,
              passScorePercent: 0,
              timeLimitSeconds: 0,
              maxFailsBeforeCooldown: 0,
              failCooldownSeconds: 0,
              rewardDenny: 0,
              rewardExp: 0,
            ),
    );
  }

  Map<String, dynamic> toJson() => {
        'attemptId': attemptId,
        'resumed': resumed,
        'startedAt': startedAt,
        'expiresAt': expiresAt,
        'questions': questions.map((e) => e.toJson()).toList(),
        'config': config.toJson(),
      };
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
  final ExamReward? reward;

  const ExamSubmitResult({
    required this.passed,
    required this.score,
    required this.totalScore,
    required this.scorePercent,
    required this.correctCount,
    required this.questionCount,
    required this.passScorePercent,
    required this.cooldownRemaining,
    required this.reward,
  });

  factory ExamSubmitResult.fromJson(Map<String, dynamic> json) {
    int readInt(String key) {
      final value = json[key];
      if (value is int) return value;
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    final reward = json['reward'];
    return ExamSubmitResult(
      passed: json['passed'] == true,
      score: readInt('score'),
      totalScore: readInt('totalScore'),
      scorePercent: readInt('scorePercent'),
      correctCount: readInt('correctCount'),
      questionCount: readInt('questionCount'),
      passScorePercent: readInt('passScorePercent'),
      cooldownRemaining: readInt('cooldownRemaining'),
      reward: reward is Map
          ? ExamReward.fromJson(Map<String, dynamic>.from(reward))
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'passed': passed,
        'score': score,
        'totalScore': totalScore,
        'scorePercent': scorePercent,
        'correctCount': correctCount,
        'questionCount': questionCount,
        'passScorePercent': passScorePercent,
        'cooldownRemaining': cooldownRemaining,
        'reward': reward?.toJson(),
      };
}
