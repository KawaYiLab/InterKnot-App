import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:inter_knot/api/api.dart';
import 'package:inter_knot/models/mention_candidate.dart';

/// @ 提及用户搜索底部弹窗。
///
/// 返回选中的 [MentionCandidateModel]；取消/未选择返回 null。
class MentionSearchSheet extends StatefulWidget {
  const MentionSearchSheet({super.key});

  @override
  State<MentionSearchSheet> createState() => _MentionSearchSheetState();
}

class _MentionSearchSheetState extends State<MentionSearchSheet> {
  final TextEditingController _searchController = TextEditingController();
  final api = Get.find<Api>();
  final List<MentionCandidateModel> _results = [];
  Timer? _debounce;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearch() {
    final text = _searchController.text.trim();
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _performSearch(text);
    });
  }

  Future<void> _performSearch(String q) async {
    if (q.isEmpty) {
      setState(() {
        _results.clear();
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    try {
      final list = await api.searchAuthors(q, limit: 15);
      if (mounted) {
        setState(() {
          _results
            ..clear()
            ..addAll(list);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xff222222),
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      decoration: const InputDecoration(
                        hintText: '搜索用户',
                        hintStyle: TextStyle(color: Colors.grey),
                        border: InputBorder.none,
                        prefixIcon: Icon(Icons.search, color: Colors.grey),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0xff2D2D2D), height: 1),
            Flexible(
              child: _loading && _results.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : _results.isEmpty
                      ? const Center(
                          child: Text(
                            '输入用户名搜索',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _results.length,
                          itemBuilder: (context, index) {
                            final candidate = _results[index];
                            return ListTile(
                              leading: _buildAvatar(candidate.avatar),
                              title: Text(
                                candidate.name,
                                style: const TextStyle(color: Colors.white),
                              ),
                              subtitle: candidate.username != null
                                  ? Text(
                                      '@${candidate.username}',
                                      style: const TextStyle(color: Colors.grey),
                                    )
                                  : null,
                              trailing: candidate.level != null
                                  ? Text(
                                      'Lv.${candidate.level}',
                                      style: const TextStyle(
                                        color: Color(0xffBFFF09),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  : null,
                              onTap: () => Navigator.of(context).pop(candidate),
                            );
                          },
                        ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(String? url) {
    if (url == null || url.isEmpty) {
      return const CircleAvatar(
        backgroundColor: Color(0xff2D2D2D),
        child: Icon(Icons.person, color: Colors.grey, size: 20),
      );
    }
    return CircleAvatar(
      backgroundImage: NetworkImage(url),
      onBackgroundImageError: (_, __) {},
    );
  }
}
