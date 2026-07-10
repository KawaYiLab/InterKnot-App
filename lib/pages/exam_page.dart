import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:inter_knot/api/api.dart';
import 'package:inter_knot/api/api_exception.dart';
import 'package:inter_knot/controllers/data.dart';
import 'package:inter_knot/helpers/toast.dart';

class ExamPage extends StatefulWidget {
  const ExamPage({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ExamPage(),
      ),
    );
  }

  @override
  State<ExamPage> createState() => _ExamPageState();
}

class _ExamPageState extends State<ExamPage> {
  final api = Get.find<Api>();
  final c = Get.find<Controller>();

  bool _loading = true;
  String? _error;

  ExamStatus? _status;
  ExamStartResult? _exam;

  Timer? _countdownTimer;
  int _remainingSeconds = 0;

  final Map<String, List<String>> _answers = {};
  bool _submitting = false;
  ExamSubmitResult? _submitResult;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final status = await api.getExamStatus();
      _status = status;
      if (status.passed) {
        setState(() => _loading = false);
        return;
      }
      if (status.cooldownRemaining > 0) {
        _startCountdown(status.cooldownRemaining);
        setState(() => _loading = false);
        return;
      }
      if (status.activeAttempt != null) {
        // Resume active attempt
        await _startOrResume();
        return;
      }
      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _error = e is ApiException ? e.message : e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _startOrResume() async {
    setState(() => _loading = true);
    try {
      final exam = await api.startExam();
      _exam = exam;
      _answers.clear();
      _remainingSeconds = _examDurationSeconds(exam);
      _startCountdown(_remainingSeconds);
    } catch (e) {
      _error = e is ApiException ? e.message : e.toString();
    } finally {
      setState(() => _loading = false);
    }
  }

  int _examDurationSeconds(ExamStartResult exam) {
    final expires = DateTime.tryParse(exam.expiresAt);
    final started = DateTime.tryParse(exam.startedAt);
    if (expires != null && started != null) {
      return expires.difference(started).inSeconds;
    }
    return exam.config.timeLimitSeconds;
  }

  void _startCountdown(int seconds) {
    _remainingSeconds = seconds;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_remainingSeconds > 0) _remainingSeconds--;
      });
      if (_remainingSeconds <= 0) {
        timer.cancel();
        if (_exam != null && !_submitting && _submitResult == null) {
          _submit(auto: true);
        }
      }
    });
  }

  Future<void> _submit({bool auto = false}) async {
    if (_exam == null) return;
    if (_submitting) return;

    final answers = <String, List<String>>{};
    for (final q in _exam!.questions) {
      answers[q.questionId] = List<String>.from(_answers[q.questionId] ?? []);
    }

    setState(() => _submitting = true);
    try {
      final result = await api.submitExam(_exam!.attemptId, answers);
      _submitResult = result;
      _countdownTimer?.cancel();
      if (result.passed) {
        await c.refreshMyExp();
      }
      showToast(result.passed ? '通过入站考试！' : '未通过考试，请稍后再试');
    } catch (e) {
      showToast(e is ApiException ? e.message : '提交失败', isError: true);
    } finally {
      setState(() => _submitting = false);
    }
  }

  void _onOptionTap(ExamQuestion q, String key) {
    if (_submitting || _submitResult != null) return;
    final current = _answers[q.questionId] ?? [];
    setState(() {
      if (q.type == 'multiple') {
        if (current.contains(key)) {
          current.remove(key);
        } else {
          current.add(key);
        }
        _answers[q.questionId] = List<String>.from(current);
      } else {
        _answers[q.questionId] = [key];
      }
    });
  }

  String _formatCountdown(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xff0A0A0A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '入站考试',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xffD7FF00)),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 15),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadStatus,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xffD7FF00),
                  foregroundColor: Colors.black,
                ),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    if (_status?.passed == true) {
      return _buildPassed();
    }

    if (_status?.cooldownRemaining != null && _status!.cooldownRemaining > 0) {
      return _buildCooldown();
    }

    if (_submitResult != null) {
      return _buildResult();
    }

    if (_exam == null) {
      return _buildIntro();
    }

    return _buildQuestions();
  }

  Widget _buildPassed() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.verified_rounded,
                color: Color(0xffD7FF00), size: 64),
            const SizedBox(height: 16),
            const Text(
              '已通过入站考试',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '通过时间：${_status?.passedAt ?? ''}',
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xffD7FF00),
                foregroundColor: Colors.black,
              ),
              child: const Text('返回'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCooldown() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.timer_outlined, color: Colors.orange, size: 64),
            const SizedBox(height: 16),
            const Text(
              '考试冷却中',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '失败次数过多，请 ${_formatCountdown(_remainingSeconds)} 后再试',
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntro() {
    final config = _status?.config;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '入站考试',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '通过考试后才可以发帖、评论与使用三连。\n'
            '共 ${config?.questionCount ?? 0} 题，满分 ${config?.passScorePercent ?? 0}% 通过，'
            '限时 ${config?.timeLimitSeconds ?? 0} 秒。',
            style: const TextStyle(color: Colors.grey, fontSize: 14, height: 1.6),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _startOrResume,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xffD7FF00),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('开始考试', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestions() {
    final exam = _exam!;
    final questions = exam.questions;
    final allAnswered = questions.every((q) {
      final list = _answers[q.questionId] ?? [];
      return list.isNotEmpty;
    });

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: Color(0xff1A1A1A),
            border: Border(
              bottom: BorderSide(color: Color(0xff2A2A2A)),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.timer, color: Color(0xffD7FF00), size: 18),
              const SizedBox(width: 8),
              Text(
                _formatCountdown(_remainingSeconds),
                style: const TextStyle(
                  color: Color(0xffD7FF00),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '已答 ${_answers.values.where((l) => l.isNotEmpty).length}/${questions.length}',
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: questions.length,
            itemBuilder: (context, index) {
              final q = questions[index];
              return _QuestionCard(
                index: index + 1,
                question: q,
                selected: _answers[q.questionId] ?? [],
                onTap: (key) => _onOptionTap(q, key),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: allAnswered && !_submitting ? _submit : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xffD7FF00),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                disabledBackgroundColor: const Color(0xff2A2A2A),
                disabledForegroundColor: const Color(0xff606060),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Text('提交答卷', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResult() {
    final result = _submitResult!;
    final passed = result.passed;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              passed ? Icons.verified_rounded : Icons.cancel_outlined,
              color: passed ? const Color(0xffD7FF00) : Colors.red,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              passed ? '通过入站考试' : '未通过考试',
              style: TextStyle(
                color: passed ? const Color(0xffD7FF00) : Colors.red,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '得分：${result.score}/${result.totalScore}（${result.scorePercent}%）\n'
              '答对：${result.correctCount}/${result.questionCount}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 15, height: 1.6),
            ),
            if (result.reward != null) ...[
              const SizedBox(height: 8),
              Text(
                '奖励：丁尼 +${result.reward!.denny}，绳网信用 +${result.reward!.exp}',
                style: const TextStyle(color: Color(0xffD7FF00), fontSize: 14),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xffD7FF00),
                foregroundColor: Colors.black,
              ),
              child: const Text('返回'),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  final int index;
  final ExamQuestion question;
  final List<String> selected;
  final ValueChanged<String> onTap;

  const _QuestionCard({
    required this.index,
    required this.question,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isMultiple = question.type == 'multiple';
    final isBoolean = question.type == 'boolean';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xff1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xff2A2A2A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$index.',
                style: const TextStyle(
                  color: Color(0xffD7FF00),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  question.question,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (isMultiple)
            const Padding(
              padding: EdgeInsets.only(top: 6, left: 24),
              child: Text(
                '（多选）',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          const SizedBox(height: 12),
          ...question.options.map((option) {
            final isSelected = selected.contains(option.key);
            if (isBoolean) {
              return _buildBooleanOption(option, isSelected);
            }
            return _buildOption(option, isSelected, isMultiple);
          }),
        ],
      ),
    );
  }

  Widget _buildOption(ExamOption option, bool isSelected, bool isMultiple) {
    return InkWell(
      onTap: () => onTap(option.key),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xffD7FF00).withValues(alpha: 0.12)
              : const Color(0xff252525),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xffD7FF00) : const Color(0xff2A2A2A),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isMultiple
                  ? (isSelected
                      ? Icons.check_box_rounded
                      : Icons.check_box_outline_blank_rounded)
                  : (isSelected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded),
              color: isSelected ? const Color(0xffD7FF00) : Colors.grey,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                option.text,
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xffCCCCCC),
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBooleanOption(ExamOption option, bool isSelected) {
    return InkWell(
      onTap: () => onTap(option.key),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xffD7FF00).withValues(alpha: 0.12)
              : const Color(0xff252525),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xffD7FF00) : const Color(0xff2A2A2A),
          ),
        ),
        child: Center(
          child: Text(
            option.text,
            style: TextStyle(
              color: isSelected ? const Color(0xffD7FF00) : Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }
}
