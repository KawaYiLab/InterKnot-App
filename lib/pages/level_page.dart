import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:inter_knot/api/api.dart';
import 'package:inter_knot/api/api_exception.dart';
import 'package:inter_knot/controllers/data.dart';
import 'package:inter_knot/helpers/toast.dart';
import 'package:inter_knot/utils/level_utils.dart';

class LevelPage extends StatefulWidget {
  const LevelPage({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LevelPage()),
    );
  }

  @override
  State<LevelPage> createState() => _LevelPageState();
}

class _LevelPageState extends State<LevelPage> {
  final c = Get.find<Controller>();
  final api = Get.find<Api>();

  bool _loadingCheckIn = true;

  bool _canCheckIn = true;
  int _totalDays = 0;
  int _consecutiveDays = 0;
  int _rank = 0;
  int _currentDenny = 0;

  @override
  void initState() {
    super.initState();
    _loadCheckInStatus();
  }

  Future<void> _loadCheckInStatus() async {
    try {
      final status = await api.getCheckInStatus();
      _canCheckIn = status.canCheckIn;
      _totalDays = status.totalDays;
      _consecutiveDays = status.consecutiveDays;
      _rank = status.rank;
      _currentDenny = status.currentDenny;
    } catch (e) {
      // Silent failure: keep defaults and let user retry.
    } finally {
      setState(() => _loadingCheckIn = false);
    }
  }

  Future<void> _doCheckIn() async {
    try {
      final result = await api.checkIn();
      await c.refreshMyExp();
      await _loadCheckInStatus();
      showToast(
        '签到成功！第${result.rank ?? '?'}名，信用+${result.reward ?? 0}，连续${result.consecutiveDays ?? '?'}天',
      );
    } catch (e) {
      showToast(e is ApiException ? e.message : '签到失败', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xff0A0A0A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '绳网等级',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Obx(() {
        final user = c.user.value;
        final exp = user?.exp ?? 0;
        final denny = user?.denny ?? 0;
        final level = user?.level ?? LevelUtils.currentLevel(exp);
        final title = LevelUtils.titleFor(level);
        final progress = LevelUtils.progress(exp);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Level card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xff1A1A1A),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xff2A2A2A)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xffD7FF00).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xffD7FF00).withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          'Lv.$level',
                          style: const TextStyle(
                            color: Color(0xffD7FF00),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Text(
                        '称号：$title',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '绳网信用 $exp',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '丁尼 $denny',
                        style: const TextStyle(
                          color: Color(0xffD7FF00),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 10,
                      backgroundColor: const Color(0xff2A2A2A),
                      color: const Color(0xffD7FF00),
                    ),
                  ),
                  if (level < LevelUtils.maxLevel) ...[
                    const SizedBox(height: 8),
                    Text(
                      '距离升级还需 ${LevelUtils.expToNextLevel(exp)} 绳网信用',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Check-in card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xff1A1A1A),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xff2A2A2A)),
              ),
              child: _loadingCheckIn
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xffD7FF00),
                        strokeWidth: 2,
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '每日签到',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _Stat(label: '累计', value: '$_totalDays天'),
                            _Stat(label: '连续', value: '$_consecutiveDays天'),
                            _Stat(label: '今日', value: _rank > 0 ? '第$_rank名' : '未签到'),
                            _Stat(label: '丁尼', value: '$_currentDenny'),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _canCheckIn ? _doCheckIn : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xffD7FF00),
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              disabledBackgroundColor: const Color(0xff2A2A2A),
                              disabledForegroundColor: const Color(0xff606060),
                            ),
                            child: Text(
                              _canCheckIn ? '今日签到' : '今日已签到',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 16),
            // Level table
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xff1A1A1A),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xff2A2A2A)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '等级一览',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...List.generate(LevelUtils.maxLevel, (i) {
                    final l = i + 1;
                    final isCurrent = l == level;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isCurrent
                                  ? const Color(0xffD7FF00).withValues(alpha: 0.15)
                                  : const Color(0xff2A2A2A),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Lv.$l',
                              style: TextStyle(
                                color: isCurrent
                                    ? const Color(0xffD7FF00)
                                    : Colors.grey,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              LevelUtils.titleFor(l),
                              style: TextStyle(
                                color: isCurrent ? Colors.white : Colors.grey,
                                fontWeight:
                                    isCurrent ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ),
                          Text(
                            '${LevelUtils.expAtLevel(l)}',
                            style: TextStyle(
                              color: isCurrent ? Colors.white : Colors.grey,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Rules
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xff1A1A1A),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xff2A2A2A)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '经验规则',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    '自己主动行为：\n'
                    '• 每日签到：基础 6 XP，连签每天 +1（最多额外 +4）\n'
                    '• 发布文章：+4 XP\n'
                    '• 发表评论：+3 XP\n'
                    '• 给别人点赞：+1 XP\n'
                    '• 每日上限：50 XP\n\n'
                    '别人对你产生的行为：\n'
                    '• 点赞你的内容：+1 XP\n'
                    '• 评论你的文章或评论：+1 XP\n'
                    '• 收藏你的文章：+2 XP\n'
                    '• 每日上限：1000 XP',
                    style: TextStyle(
                      color: Color(0xffB8B8B8),
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;

  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
