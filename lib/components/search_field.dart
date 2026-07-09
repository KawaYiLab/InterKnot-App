import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';
import 'package:inter_knot/api/api.dart';
import 'package:inter_knot/controllers/data.dart';
import 'package:inter_knot/helpers/page_transition_helper.dart';
import 'package:inter_knot/models/author.dart';
import 'package:inter_knot/models/discussion.dart';
import 'package:inter_knot/models/h_data.dart';
import 'package:inter_knot/models/search_suggestion.dart';
import 'package:inter_knot/pages/discussion_page.dart';

/// 顶部搜索栏：支持搜索历史、实时联想、高亮回车全量搜索。
/// 与 Web 端 AppHeader 搜索行为对齐：
/// - 输入框聚焦且无输入时展示搜索历史
/// - 输入字符 200ms 防抖后请求 /api/articles/suggest
/// - 第一条选项为「查看“关键词”的全部结果」，回车默认触发全量搜索
/// - 点选联想项直接进入帖子详情，并记录当前搜索关键词
class SearchField extends StatefulWidget {
  const SearchField({
    super.key,
    this.maxWidth = 700,
  });

  final double maxWidth;

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  final c = Get.find<Controller>();
  final FocusNode _focusNode = FocusNode();
  Timer? _suggestDebounce;
  int _suggestSeq = 0;
  Completer<Iterable<SearchSuggestionModel>>? _pendingCompleter;

  void _safeComplete(Iterable<SearchSuggestionModel> value) {
    final p = _pendingCompleter;
    if (p != null && !p.isCompleted) {
      p.complete(value);
    }
  }

  @override
  void dispose() {
    _suggestDebounce?.cancel();
    _safeComplete([]);
    _focusNode.dispose();
    super.dispose();
  }

  Future<Iterable<SearchSuggestionModel>> _buildOptions(
    TextEditingValue value,
  ) async {
    final query = value.text;
    if (query.isEmpty) {
      _safeComplete([]);
      return c.searchHistory
          .map((k) => SearchSuggestionModel.history(k, query: k))
          .toList();
    }

    final seq = ++_suggestSeq;
    _suggestDebounce?.cancel();
    _safeComplete([]);
    final completer = Completer<Iterable<SearchSuggestionModel>>();
    _pendingCompleter = completer;

    _suggestDebounce = Timer(const Duration(milliseconds: 200), () async {
      if (seq != _suggestSeq || !mounted) {
        if (!completer.isCompleted) completer.complete([]);
        return;
      }
      final categorySlug = c.selectedCategorySlug.value.isEmpty
          ? null
          : c.selectedCategorySlug.value;
      try {
        final list = await c.api.searchSuggestions(
          query,
          categorySlug: categorySlug,
          limit: 8,
        );
        if (seq != _suggestSeq || !mounted) {
          if (!completer.isCompleted) completer.complete([]);
          return;
        }
        if (!completer.isCompleted) {
          final viewAll = SearchSuggestionModel.viewAll(query);
          completer.complete([
            viewAll,
            ...list.map((s) => s.copyWith(query: query)),
          ]);
        }
      } catch (e) {
        if (!completer.isCompleted) completer.complete([]);
      }
    });

    return completer.future;
  }

  String _displayStringForOption(SearchSuggestionModel option) {
    if (option.isHistory) return option.title;
    return option.query;
  }

  void _onSelected(SearchSuggestionModel option) {
    final query = c.searchController.text.trim();
    if (option.isHistory) {
      _performSearch(option.title);
      return;
    }
    if (option.isViewAll) {
      _performSearch(query);
      return;
    }
    _addToSearchHistory(query);
    _openDiscussion(option);
  }

  void _performSearch(String keyword) {
    if (keyword.isEmpty) return;
    _addToSearchHistory(keyword);
    c.searchController.text = keyword;
    c.searchQuery.value = keyword;
    c.animateToPage(0, animate: false);
    _focusNode.unfocus();
  }

  void _addToSearchHistory(String keyword) {
    c.addSearchHistory(keyword);
  }

  void _openDiscussion(SearchSuggestionModel option) {
    final category = option.categorySlug != null
        ? PostCategory(
            name: option.categoryName ?? '',
            slug: option.categorySlug!,
          )
        : null;
    final author = option.isAnonymous
        ? AuthorModel(login: '', avatar: '', name: '匿名')
        : AuthorModel(
            login: '',
            avatar: '',
            name: option.authorName ?? 'Unknown',
          );
    final discussion = DiscussionModel(
      title: option.title,
      bodyHTML: '',
      bodyText: '',
      rawBodyText: '',
      coverImages: [],
      id: option.documentId,
      createdAt: DateTime.now(),
      commentsCount: 0,
      lastEditedAt: null,
      author: author,
      comments: [],
      databaseId: 0,
      isAnonymous: option.isAnonymous,
      category: category,
    );
    final hData = HDataModel(
      id: option.documentId,
      updatedAt: null,
      createdAt: null,
      isPinned: false,
      title: option.title,
      isAnonymous: option.isAnonymous,
      author: author,
      category: category,
    );
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      navigateWithSlideTransition(
        context,
        DiscussionPage(
          discussion: discussion,
          hData: hData,
          reorderHistoryOnOpen: false,
        ),
        routeName: '/discussion/${option.documentId}',
      );
    });
  }

  Widget _optionView(
    BuildContext context,
    AutocompleteOnSelected<SearchSuggestionModel> onSelected,
    Iterable<SearchSuggestionModel> options,
  ) {
    final highlighted = AutocompleteHighlightedOption.of(context);
    final isCompact = MediaQuery.of(context).size.width < 640;

    return Align(
      alignment: AlignmentDirectional.topStart,
      child: Material(
        elevation: 6,
        color: const Color(0xff1E1E1E),
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: isCompact ? 280 : 360,
            maxWidth: widget.maxWidth,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ListView.separated(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: options.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: Colors.white12),
              itemBuilder: (context, index) {
                final option = options.elementAt(index);
                final isActive = highlighted == index;
                return InkWell(
                  onTap: () => onSelected(option),
                  child: Container(
                    color: isActive
                        ? const Color(0xffD7FF00).withValues(alpha: 0.12)
                        : null,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: _buildOptionContent(option),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOptionContent(SearchSuggestionModel option) {
    if (option.isViewAll) {
      return Row(
        children: [
          const Icon(Icons.search, color: Color(0xffD7FF00), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '查看"${option.query}"的全部结果',
              style: const TextStyle(
                color: Color(0xffD7FF00),
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    if (option.isHistory) {
      return Row(
        children: [
          const Icon(Icons.history, color: Colors.grey, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              option.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: () {
              c.removeSearchHistory(option.title);
              // 移除后通过重新触发 controller listener，让 Autocomplete 重新查询历史
              final ctrl = c.searchController;
              ctrl.value = ctrl.value;
            },
            child: const Icon(
              Icons.close,
              color: Colors.grey,
              size: 16,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text.rich(
          TextSpan(
            children: SearchSuggestionModel.buildHighlightSpans(
              option.titleHighlighted.isNotEmpty
                  ? option.titleHighlighted
                  : option.title,
              baseStyle: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              highlightStyle: const TextStyle(
                color: Colors.black,
                backgroundColor: Color(0xffD7FF00),
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (option.excerpt.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              children: SearchSuggestionModel.buildHighlightSpans(
                option.excerpt,
                baseStyle: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
                highlightStyle: TextStyle(
                  color: Colors.black,
                  backgroundColor:
                      const Color(0xffD7FF00).withValues(alpha: 0.7),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        const SizedBox(height: 4),
        Row(
          children: [
            if (option.categoryName != null && option.categoryName!.isNotEmpty)
              _MetaChip(label: option.categoryName!),
            if (!option.isAnonymous &&
                option.authorName != null &&
                option.authorName!.isNotEmpty) ...[
              const SizedBox(width: 8),
              _MetaChip(
                label: option.authorName!,
                isAuthor: true,
              ),
            ],
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 640;

    return Autocomplete<SearchSuggestionModel>(
      optionsViewBuilder: _optionView,
      displayStringForOption: _displayStringForOption,
      optionsMaxHeight: isCompact ? 280 : 360,
      fieldViewBuilder: (
        context,
        textEditingController,
        focusNode,
        onFieldSubmitted,
      ) {
        return SearchBar(
          controller: textEditingController,
          focusNode: focusNode,
          onChanged: (_) {},
          onSubmitted: (_) {
            final text = textEditingController.text.trim();
            if (text.isNotEmpty) {
              _performSearch(text);
            } else {
              onFieldSubmitted();
            }
          },
          onTap: () => focusNode.requestFocus(),
          constraints: BoxConstraints(
            minHeight: isCompact ? 36 : 40,
            maxHeight: isCompact ? 36 : 40,
          ),
          padding: WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: isCompact ? 8 : 16),
          ),
          backgroundColor: const WidgetStatePropertyAll(Color(0xff1E1E1E)),
          elevation: const WidgetStatePropertyAll(0),
          side: WidgetStatePropertyAll(
            BorderSide(
              color: Colors.white.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
          ),
          leading: Padding(
            padding: EdgeInsets.only(left: isCompact ? 4 : 8),
            child: Icon(
              Icons.search,
              color: const Color(0xffB0B0B0),
              size: isCompact ? 20 : 22,
            ),
          ),
          hintText: '搜索一下 \(￣︶￣*))',
          hintStyle: WidgetStatePropertyAll(
            TextStyle(
              color: const Color(0xff808080),
              fontSize: isCompact ? 14 : 15,
            ),
          ),
          textStyle: WidgetStatePropertyAll(
            TextStyle(
              color: const Color(0xffE0E0E0),
              fontSize: isCompact ? 14 : 15,
            ),
          ),
          trailing: [
            AnimatedBuilder(
              animation: textEditingController,
              builder: (context, _) {
                final hasText = textEditingController.text.trim().isNotEmpty;
                if (!hasText) return const SizedBox.shrink();
                return IconButton(
                  tooltip: '清除',
                  onPressed: () {
                    textEditingController.clear();
                    c.searchQuery('');
                    focusNode.unfocus();
                  },
                  icon: Icon(
                    Icons.close_rounded,
                    color: const Color(0xffB0B0B0),
                    size: isCompact ? 18 : 20,
                  ),
                );
              },
            ),
          ],
        );
      },
      focusNode: _focusNode,
      textEditingController: c.searchController,
      optionsBuilder: _buildOptions,
      onSelected: _onSelected,
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;
  final bool isAuthor;

  const _MetaChip({
    required this.label,
    this.isAuthor = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isAuthor ? const Color(0xff2D2D2D) : const Color(0xff333333),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isAuthor ? const Color(0xffB0B0B0) : const Color(0xffD7FF00),
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
