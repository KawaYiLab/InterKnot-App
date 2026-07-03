import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:inter_knot/api/api.dart';
import 'package:inter_knot/api/api_exception.dart';
import 'package:inter_knot/controllers/data.dart';
import 'package:inter_knot/helpers/toast.dart';
import 'package:inter_knot/models/exam.dart';
import 'package:inter_knot/pages/exam_route_state.dart';

enum _ExamPhase { loading, intro, quiz, result }

class ExamPage extends StatefulWidget {
  const ExamPage({super.key});

  @override
  State<ExamPage> createState() => _ExamPageState();
}

class _ExamPageState extends State<ExamPage> {
  final c = Get.find<Controller>();
  late final api = Get.find<Api>();

  _ExamPhase _phase = _ExamPhase.loading;
  ExamStatus? _status;
  ExamStartResult? _attempt;
  ExamSubmitResult? _result;
  String? _attemptId;
  final Map<String, List<String>> _answers = {};
  int _qIndex = 0;
  DateTime _now = DateTime.now();
  Timer? _ticker;
  bool _starting = false;
  bool _submitting = false;
  bool _isCooldown = false;
  int _cooldownRemaining = 0;

  @override
  void initState() {
    super.initState();
    ExamRouteState.isOpen = true;
    ExamRouteState.examPageBuilder = () => const ExamPage();
    _loadStatus();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _now = DateTime.now();
        if (_cooldownRemaining > 0) {
          _cooldownRemaining -= 1;
        }
      });
      if (_phase == _ExamPhase.quiz &&
          !_submitting &&
          remainingSeconds <= 0 &&
          _attemptId != null &&
          _attemptId!.isNotEmpty) {
        unawaited(_submit(auto: true));
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    ExamRouteState.isOpen = false;
    super.dispose();
  }

  int get remainingSeconds {
    final expiresAt = _attempt?.expiresAt;
    if (expiresAt == null || expiresAt.isEmpty) return 0;
    return _diffSeconds(expiresAt);
  }

  int _diffSeconds(String isoTime) {
    final deadline = DateTime.tryParse(isoTime);
    if (deadline == null) return 0;
    return deadline.difference(_now).inSeconds;
  }

  ExamQuestion? get _currentQuestion {
    final questions = _attempt?.questions ?? const <ExamQuestion>[];
    if (questions.isEmpty) return null;
    if (_qIndex < 0 || _qIndex >= questions.length) return null;
    return questions[_qIndex];
  }

  int get _answeredCount {
    final questions = _attempt?.questions ?? const <ExamQuestion>[];
    return questions.where((q) => (_answers[q.questionId] ?? const []).isNotEmpty).length;
  }

  bool get _canStart {
    if (_starting) return false;
    if (_isCooldown && _cooldownRemaining > 0) return false;
    return true;
  }

  Future<void> _loadStatus() async {
    setState(() {
      _phase = _ExamPhase.loading;
    });
    try {
      final status = await api.getExamStatus();
      if (!mounted) return;
      setState(() {
        _status = status;
        _cooldownRemaining = status.cooldownRemaining ?? 0;
        _isCooldown = _cooldownRemaining > 0;
        _phase = _ExamPhase.intro;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = null;
        _phase = _ExamPhase.intro;
      });
      showToast('获取考试状态失败: $e', isError: true);
    }
  }

  Future<void> _startExam() async {
    if (!_canStart) return;
    setState(() {
      _starting = true;
    });
    try {
      final attempt = await api.startExam();
      if (!mounted) return;
      setState(() {
        _attempt = attempt;
        _attemptId = attempt.attemptId;
        _answers.clear();
        for (final question in attempt.questions) {
          _answers[question.questionId] = <String>[];
        }
        _qIndex = 0;
        _status = _status == null
            ? null
            : ExamStatus(
                passed: false,
                passedAt: _status?.passedAt,
                cooldownRemaining: 0,
                activeAttempt: ExamActiveAttempt(
                  attemptId: attempt.attemptId,
                  startedAt: attempt.startedAt,
                  expiresAt: attempt.expiresAt,
                  questionCount: attempt.questions.length,
                ),
                config: attempt.config,
              );
        _cooldownRemaining = 0;
        _isCooldown = false;
        _phase = _ExamPhase.quiz;
      });
      if (attempt.resumed) {
        showToast('已继续进行中的考试');
      }
    } catch (e) {
      final message = e.toString();
      final apiError = e is ApiException ? e : null;
      final code = apiError?.statusCode;
      final details = apiError?.details;
      final errorCode = details is Map
          ? details['error'] is Map
              ? details['error']['code']?.toString()
              : null
          : null;

      if (errorCode == 'EXAM_ALREADY_PASSED') {
        await _loadStatus();
        showToast('你已通过入站考试', isError: false);
        return;
      }

      if (errorCode == 'EXAM_COOLDOWN' || code == 429) {
        final retryAfter = details is Map
            ? details['error'] is Map
                ? details['error']['details'] is Map
                    ? details['error']['details']['retryAfter']
                    : null
                : null
            : null;
        setState(() {
          _isCooldown = true;
          _cooldownRemaining = int.tryParse(retryAfter?.toString() ?? '') ?? _cooldownRemaining;
          _phase = _ExamPhase.intro;
        });
        showToast('考试失败次数过多，请稍后再试', isError: true);
        return;
      }

      showToast('开始考试失败: ${message.replaceFirst('Exception: ', '')}', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _starting = false;
        });
      }
    }
  }

  Future<void> _submit({bool auto = false}) async {
    if (_submitting || _attemptId == null || _attemptId!.isEmpty) return;
    if (!auto && _attempt != null && _answeredCount < _attempt!.questions.length) {
      final remain = _attempt!.questions.length - _answeredCount;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xff101010),
          title: const Text('确认提交'),
          content: Text('还有 $remain 题未作答，确定提交吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('提交'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() {
      _submitting = true;
    });
    try {
      final res = await api.submitExam(_attemptId!, _answers);
      if (!mounted) return;
      setState(() {
        _result = res;
        _cooldownRemaining = res.cooldownRemaining;
        _isCooldown = res.cooldownRemaining > 0;
        _phase = _ExamPhase.result;
      });

      if (res.passed) {
        try {
          await c.refreshSelfUserInfo();
        } catch (_) {}
        showToast('考试通过，写作功能已解锁');
      }
    } catch (e) {
      final body = e is ApiException ? e.details : null;
      final errorCode = body is Map && body['error'] is Map
          ? body['error']['code']?.toString()
          : null;
      final message = e.toString().replaceFirst('Exception: ', '');

      if (errorCode == 'EXAM_ATTEMPT_EXPIRED') {
        showToast('考试已超时，请重新开始', isError: true);
        await _loadStatus();
        return;
      }
      if (errorCode == 'EXAM_ATTEMPT_ALREADY_SUBMITTED') {
        showToast('本场考试已提交', isError: true);
        await _loadStatus();
        return;
      }
      if (errorCode == 'EXAM_ATTEMPT_NOT_FOUND') {
        showToast('考试场次不存在，请重新开始', isError: true);
        await _loadStatus();
        return;
      }

      showToast('提交失败: $message', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  void _setSingle(ExamQuestion question, String? key) {
    setState(() {
      _answers[question.questionId] = key == null ? <String>[] : <String>[key];
    });
  }

  void _toggleMulti(ExamQuestion question, String key) {
    setState(() {
      final current = List<String>.from(_answers[question.questionId] ?? const []);
      if (current.contains(key)) {
        current.remove(key);
      } else {
        current.add(key);
      }
      _answers[question.questionId] = current;
    });
  }

  void _goPrev() {
    if (_qIndex > 0) {
      setState(() {
        _qIndex -= 1;
      });
    }
  }

  void _goNext() {
    final questions = _attempt?.questions ?? const <ExamQuestion>[];
    if (_qIndex < questions.length - 1) {
      setState(() {
        _qIndex += 1;
      });
    }
  }

  Future<void> _restart() async {
    setState(() {
      _attempt = null;
      _attemptId = null;
      _result = null;
      _qIndex = 0;
      _answers.clear();
      _phase = _ExamPhase.intro;
    });
    await _loadStatus();
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'multiple':
        return '多选';
      case 'boolean':
        return '判断';
      default:
        return '单选';
    }
  }

  String _formatDuration(int seconds) {
    final value = seconds < 0 ? 0 : seconds;
    final m = value ~/ 60;
    final s = value % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Widget _buildLoading() {
    return const Center(
      child: CircularProgressIndicator(
        color: Color(0xffD7FF00),
      ),
    );
  }

  Widget _buildIntro() {
    final status = _status;
    final config = status?.config;
    final passed = status?.passed == true;
    final activeAttempt = status?.activeAttempt;
    final cooldown = status?.cooldownRemaining ?? _cooldownRemaining;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xff101010),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xff2A2A2A)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '入网测验',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  passed
                      ? '你已通过入网测验，所有写作功能已解锁。'
                      : '为了维护社区氛围，新成员需要先通过入网测验才能正式入站。',
                  style: const TextStyle(
                    color: Color(0xffB0B0B0),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                if (passed) ...[
                  const _ExamInfoRow(
                    label: '状态',
                    value: '已通过',
                  ),
                ] else ...[
                  _ExamInfoRow(
                    label: '状态',
                    value: activeAttempt != null
                        ? '有进行中的考试'
                        : cooldown > 0
                            ? '冷却中'
                            : '可开始',
                  ),
                  if (config != null) ...[
                    const SizedBox(height: 12),
                    _ExamInfoRow(
                      label: '题数',
                      value: '${config.questionCount}',
                    ),
                    _ExamInfoRow(
                      label: '时限',
                      value: '${(config.timeLimitSeconds / 60).round()} 分钟',
                    ),
                    _ExamInfoRow(
                      label: '及格线',
                      value: '${config.passScorePercent}%',
                    ),
                    _ExamInfoRow(
                      label: '奖励',
                      value: '${config.rewardDenny} 丁尼 / ${config.rewardExp} 经验',
                    ),
                  ],
                  if (activeAttempt != null) ...[
                    const SizedBox(height: 12),
                    _ExamInfoRow(
                      label: '进行中',
                      value:
                          '共 ${activeAttempt.questionCount} 题，截止 ${activeAttempt.expiresAt}',
                    ),
                  ],
                  if (cooldown > 0) ...[
                    const SizedBox(height: 12),
                    _ExamInfoRow(
                      label: '冷却剩余',
                      value: _formatDuration(cooldown),
                    ),
                  ],
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: passed || !_canStart ? null : _startExam,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xffD7FF00),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          passed
                              ? '已通过'
                              : activeAttempt != null
                                  ? '继续考试'
                                  : '开始考试',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuiz() {
    final questions = _attempt?.questions ?? const <ExamQuestion>[];
    final question = _currentQuestion;
    final timeLeft = remainingSeconds;

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xff101010),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xff2A2A2A)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '已答 $_answeredCount / ${questions.length}',
                style: const TextStyle(color: Color(0xffE0E0E0)),
              ),
              Text(
                _formatDuration(timeLeft),
                style: TextStyle(
                  color: timeLeft <= 300
                      ? const Color(0xffFF6B6B)
                      : const Color(0xffD7FF00),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: LinearProgressIndicator(
            value: questions.isEmpty ? 0 : _answeredCount / questions.length,
            minHeight: 6,
            backgroundColor: const Color(0xff202020),
            valueColor:
                const AlwaysStoppedAnimation<Color>(Color(0xffD7FF00)),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: question == null
                ? const Center(child: Text('题目加载失败'))
                : Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xff101010),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xff2A2A2A)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_qIndex + 1}. ${question.question}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _typeLabel(question.type),
                          style: const TextStyle(
                            color: Color(0xff9A9A9A),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Expanded(
                          child: ListView.separated(
                            itemCount: question.options.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final option = question.options[index];
                              final selected =
                                  (_answers[question.questionId] ?? const [])
                                      .contains(option.key);
                              final isMulti = question.type == 'multiple';
                              return InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () {
                                  if (isMulti) {
                                    _toggleMulti(question, option.key);
                                  } else {
                                    _setSingle(question, option.key);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? const Color(0xffD7FF00)
                                        : const Color(0xff181818),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: selected
                                          ? const Color(0xffD7FF00)
                                          : const Color(0xff2A2A2A),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      if (isMulti)
                                        Checkbox(
                                          value: selected,
                                          onChanged: (_) =>
                                              _toggleMulti(question, option.key),
                                          activeColor: const Color(0xffD7FF00),
                                          checkColor: Colors.black,
                                        )
                                      else
                                        Icon(
                                          selected
                                              ? Icons.radio_button_checked
                                              : Icons.radio_button_unchecked,
                                          color: selected
                                              ? const Color(0xffD7FF00)
                                              : const Color(0xff7A7A7A),
                                        ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '${option.key}. ${option.text}',
                                          style: TextStyle(
                                            color: selected
                                                ? Colors.black
                                                : Colors.white,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            TextButton(
                              onPressed: _qIndex > 0 ? _goPrev : null,
                              child: const Text('上一题'),
                            ),
                            const SizedBox(width: 12),
                            if (_qIndex < questions.length - 1)
                              ElevatedButton(
                                onPressed: _goNext,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xffD7FF00),
                                  foregroundColor: Colors.black,
                                ),
                                child: const Text('下一题'),
                              )
                            else
                              ElevatedButton(
                                onPressed: _submitting ? null : () => _submit(),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xffD7FF00),
                                  foregroundColor: Colors.black,
                                ),
                                child: Text(_submitting ? '提交中…' : '提交'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildResult() {
    final result = _result;
    if (result == null) {
      return const Center(child: Text('暂无结果'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xff101010),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xff2A2A2A)),
            ),
            child: Column(
              children: [
                Text(
                  result.passed ? '🎉 考试通过！' : '未通过',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '得分 ${result.scorePercent}%（${result.correctCount} / ${result.questionCount} 题正确，及格线 ${result.passScorePercent}%）',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xffE0E0E0)),
                ),
                if (result.reward != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    '奖励：${result.reward!.denny} 丁尼 / ${result.reward!.exp} 经验',
                    style: const TextStyle(color: Color(0xffB0B0B0)),
                  ),
                ],
                const SizedBox(height: 24),
                if (result.passed)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Get.back(result: true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xffD7FF00),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text('返回'),
                    ),
                  )
                else ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _restart,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xffD7FF00),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text('重新开始'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Get.back(),
                    child: const Text('返回'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xff101010),
        elevation: 0,
        title: const Text('入网测验'),
        leading: IconButton(
          onPressed: () => Get.back(),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: switch (_phase) {
            _ExamPhase.loading => _buildLoading(),
            _ExamPhase.intro => _buildIntro(),
            _ExamPhase.quiz => _buildQuiz(),
            _ExamPhase.result => _buildResult(),
          },
        ),
      ),
    );
  }
}

class _ExamInfoRow extends StatelessWidget {
  const _ExamInfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xff9A9A9A),
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
