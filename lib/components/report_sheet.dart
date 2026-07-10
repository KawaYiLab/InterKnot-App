import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:inter_knot/api/api.dart';
import 'package:inter_knot/api/api_exception.dart';
import 'package:inter_knot/helpers/toast.dart';

class ReportSheet extends StatefulWidget {
  const ReportSheet({
    super.key,
    required this.targetType,
    required this.targetId,
  });

  final String targetType;
  final String targetId;

  @override
  State<ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<ReportSheet> {
  final _reasonLabels = const {
    'spam': '垃圾广告',
    'abuse': '辱骂骚扰',
    'porn': '色情低俗',
    'illegal': '违法违规',
    'privacy': '侵犯隐私',
    'misinfo': '不实信息',
    'plagiarism': '抄袭盗用',
    'other': '其他',
  };

  final _api = Get.find<Api>();
  String? _selectedReason;
  final _detailController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _detailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _selectedReason;
    if (reason == null) {
      showToast('请选择举报原因', isError: true);
      return;
    }
    final detail = _detailController.text.trim();
    if (reason == 'other' && detail.isEmpty) {
      showToast('请填写具体说明', isError: true);
      return;
    }

    setState(() => _submitting = true);
    try {
      await _api.createReport(
        targetType: widget.targetType,
        targetId: widget.targetId,
        reason: reason,
        detail: detail.isNotEmpty ? detail : null,
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
      showToast('举报已提交，等待处理');
    } catch (e) {
      showToast(e is ApiException ? e.message : '举报失败', isError: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xff1A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '举报',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _reasonLabels.entries.map((entry) {
                final selected = _selectedReason == entry.key;
                return ChoiceChip(
                  label: Text(entry.value),
                  selected: selected,
                  selectedColor: const Color(0xffD7FF00).withValues(alpha: 0.2),
                  backgroundColor: const Color(0xff2A2A2A),
                  labelStyle: TextStyle(
                    color: selected ? const Color(0xffD7FF00) : Colors.grey,
                  ),
                  side: BorderSide(
                    color: selected ? const Color(0xffD7FF00) : const Color(0xff3A3A3A),
                  ),
                  onSelected: (_) =>
                      setState(() => _selectedReason = entry.key),
                );
              }).toList(),
            ),
            if (_selectedReason == 'other') ...[
              const SizedBox(height: 16),
              TextField(
                controller: _detailController,
                maxLines: 3,
                maxLength: 500,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: '请补充说明举报原因...',
                  hintStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: const Color(0xff2A2A2A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xffD7FF00),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
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
                    : const Text('提交举报', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showReportSheet(
  BuildContext context, {
  required String targetType,
  required String targetId,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => ReportSheet(
      targetType: targetType,
      targetId: targetId,
    ),
  );
}
