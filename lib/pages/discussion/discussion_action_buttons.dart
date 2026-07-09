import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:inter_knot/api/api.dart';
import 'package:inter_knot/components/click_region.dart';
import 'package:inter_knot/components/emote_picker.dart';
import 'package:inter_knot/components/mention_search_sheet.dart';
import 'package:inter_knot/components/triple_action_button.dart';
import 'package:inter_knot/constants/api_config.dart';
import 'package:inter_knot/constants/globals.dart';
import 'package:inter_knot/controllers/data.dart';
import 'package:inter_knot/helpers/content_segments.dart';
import 'package:inter_knot/helpers/dialog_helper.dart';
import 'package:inter_knot/helpers/toast.dart';
import 'package:inter_knot/models/discussion.dart';
import 'package:inter_knot/models/h_data.dart';
import 'package:inter_knot/models/mention_candidate.dart';
import 'package:inter_knot/pages/create_discussion_page.dart';
import 'package:image_picker/image_picker.dart';

/// 评论图片上传任务。
class _ImageUploadTask {
  List<int>? bytes;
  String? filename;
  String? mimeType;
  String? serverId;
  String? serverUrl;
  String? previewUrl;
  bool isUploading = false;
  int progress = 0;
  String? error;
}

class DiscussionActionButtons extends StatefulWidget {
  const DiscussionActionButtons({
    super.key,
    required this.discussion,
    required this.hData,
    this.onCommentAdded,
    this.onEditSuccess,
  });

  final DiscussionModel discussion;
  final HDataModel hData;
  final VoidCallback? onCommentAdded;
  final VoidCallback? onEditSuccess;

  @override
  State<DiscussionActionButtons> createState() =>
      DiscussionActionButtonsState();
}

class DiscussionActionButtonsState extends State<DiscussionActionButtons>
    with SingleTickerProviderStateMixin {
  final c = Get.find<Controller>();
  late final api = Get.find<Api>();

  bool _isWriting = false;
  bool _isLoading = false;
  bool _isOverlayOpen = false;
  String? _parentId;
  String? _replyToUser;
  String? _replyToAuthorId;
  bool _addReplyPrefix = false;

  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ImagePicker _imagePicker = ImagePicker();
  final List<_ImageUploadTask> _imageUploads = [];

  late final AnimationController _controller;
  late final Animation<double> _sizeAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _sizeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );
    _controller.value = 1.0;
  }

  Future<void> replyTo(
    String parentId,
    String? userName, {
    bool addPrefix = false,
    String? authorDocumentId,
  }) async {
    if (!await c.ensureLogin()) return;

    setState(() {
      _parentId = parentId;
      _replyToUser = userName;
      _replyToAuthorId =
          (authorDocumentId != null && authorDocumentId.isNotEmpty)
              ? authorDocumentId
              : null;
      _isWriting = true;
      _addReplyPrefix = addPrefix;
    });
    _controller.reverse();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });

    if (addPrefix &&
        userName != null &&
        authorDocumentId != null &&
        authorDocumentId.isNotEmpty) {
      final token = buildMentionToken(userName, authorDocumentId);
      final current = _stripLeadingMention(_textController.text);
      _textController.value = TextEditingValue(
        text: '$token $current',
        selection: TextSelection.collapsed(offset: token.length + 1),
      );
    }
  }

  String _stripLeadingMention(String text) {
    final tokens = parseMentions(text);
    if (tokens.isNotEmpty && tokens.first.start == 0) {
      var tail = text.substring(tokens.first.end);
      if (tail.startsWith(' ')) tail = tail.substring(1);
      return tail;
    }
    return text;
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    var content = _textController.text.trim();
    if (content.isEmpty) {
      showToast('评论内容不能为空', isError: true);
      return;
    }

    // 历史兼容：旧 reply 回填是纯文本，未带 authorDocumentId 时降级处理
    if (_addReplyPrefix && _replyToUser != null && _replyToAuthorId == null) {
      content = '回复 @$_replyToUser :$content';
    }

    if (!await c.ensureLogin()) return;

    final uploading = _imageUploads.any((t) => t.isUploading);
    if (uploading) {
      showToast('图片上传中，请稍候', isError: true);
      return;
    }

    final failedUploads = _imageUploads.where((t) => t.error != null).toList();
    if (failedUploads.isNotEmpty) {
      showToast('有 ${failedUploads.length} 张图片上传失败，将不会包含在评论中',
          isError: true);
    }

    final user = c.user.value;
    final authorId = c.authorId.value ?? await c.ensureAuthorForUser(user);
    if (authorId == null || authorId.isEmpty) {
      showToast('无法关联作者，请重新登录后再试', isError: true);
      return;
    }

    final imageIds = _imageUploads
        .where((t) => t.serverId != null && t.serverId!.isNotEmpty)
        .map((t) => t.serverId!)
        .toList();

    setState(() => _isLoading = true);

    try {
      final res = await api.addDiscussionComment(
        widget.discussion.id,
        content,
        authorId: authorId,
        parentId: _parentId,
        imageIds: imageIds,
      );

      if (res.hasError) {
        final dynamic body = res.body;
        final error = body is Map ? body['error'] : null;
        final message =
            error is Map ? error['message']?.toString() : null;
        throw Exception(message ?? res.statusText ?? 'Unknown error');
      }

      if (res.body?['errors'] != null) {
        final errors = res.body!['errors'] as List<dynamic>;
        if (errors.isNotEmpty) {
          final first = errors[0];
          final msg = first is Map ? first['message']?.toString() : null;
          throw Exception(msg ?? 'Failed to add comment');
        }
      }

      _textController.clear();
      _cancel();

      // 清空评论列表并重置分页状态
      widget.discussion.comments.clear();
      widget.discussion.commentsCount++;

      // 强制刷新评论列表
      await widget.discussion.fetchComments();

      // 强制刷新UI
      if (mounted) setState(() {});

      // 通知父组件刷新UI
      widget.onCommentAdded?.call();

      showToast('评论发布成功');
    } catch (e) {
      showToast('评论发布失败: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleTap() async {
    if (!await c.ensureLogin()) return;

    if (_isWriting) {
      _submit();
    } else {
      setState(() => _isWriting = true);
      _controller.reverse();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
      });
    }
  }

  void _cancel() {
    setState(() {
      _isWriting = false;
      _parentId = null;
      _replyToUser = null;
      _replyToAuthorId = null;
      _addReplyPrefix = false;
      _imageUploads.clear();
    });
    _textController.clear();
    _controller.forward();
    _focusNode.unfocus();
  }

  void _insertText(String text) {
    final value = _textController.value;
    final before = value.selection.textBefore(value.text);
    final after = value.selection.textAfter(value.text);
    _textController.value = value.copyWith(
      text: before + text + after,
      selection: TextSelection.collapsed(offset: before.length + text.length),
    );
  }

  Future<void> _openEmotePicker() async {
    setState(() => _isOverlayOpen = true);
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const EmotePicker(),
    ).whenComplete(() {
      if (mounted) setState(() => _isOverlayOpen = false);
    });
    if (result == null || !mounted) return;
    _focusNode.requestFocus();
    if (result.startsWith('ik-')) {
      _insertText(buildEmoteToken(result));
    } else {
      _insertText(result);
    }
  }

  Future<void> _openMentionPicker() async {
    setState(() => _isOverlayOpen = true);
    final candidate = await showModalBottomSheet<MentionCandidateModel>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const MentionSearchSheet(),
    ).whenComplete(() {
      if (mounted) setState(() => _isOverlayOpen = false);
    });
    if (candidate == null || !mounted) return;
    _focusNode.requestFocus();
    _insertText(buildMentionToken(candidate.name, candidate.documentId));
  }

  Future<void> _pickImages() async {
    setState(() => _isOverlayOpen = true);
    try {
      final picked = await _imagePicker.pickMultiImage();
      if (picked.isEmpty || !mounted) return;

      for (final xfile in picked) {
        final bytes = await xfile.readAsBytes();
        final mime = _guessMime(xfile.name);
        final task = _ImageUploadTask()
          ..bytes = bytes
          ..filename = xfile.name
          ..mimeType = mime
          ..isUploading = true;

        if (!mounted) return;
        setState(() => _imageUploads.add(task));
        _uploadImage(task);
      }
    } finally {
      if (mounted) setState(() => _isOverlayOpen = false);
    }
  }

  String _guessMime(String filename) {
    final ext = filename.split('.').lastOrNull?.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  Future<void> _uploadImage(_ImageUploadTask task) async {
    if (task.bytes == null || task.filename == null) return;
    try {
      final result = await api.uploadImage(
        bytes: task.bytes!,
        filename: task.filename!,
        mimeType: task.mimeType ?? 'image/jpeg',
        onProgress: (percent) {
          if (mounted) setState(() => task.progress = percent);
        },
      );
      final data = result;
      if (data == null) throw Exception('upload result is null');
      task.serverId = data['documentId']?.toString() ?? data['id']?.toString();
      final url = _normalizeUrl(data['url']?.toString() ??
          data['formats']?['thumbnail']?['url']?.toString());
      task.serverUrl = url;
      task.previewUrl = url;
    } catch (e) {
      if (mounted) {
        setState(() => task.error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => task.isUploading = false);
      }
    }
  }

  String? _normalizeUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    if (url.startsWith('/')) return '${ApiConfig.baseUrl}$url';
    return '${ApiConfig.baseUrl}/$url';
  }

  void _removeImage(int index) {
    setState(() => _imageUploads.removeAt(index));
  }

  bool _isLiking = false;
  bool _isTripling = false;

  Future<void> _handleLike() async {
    if (_isLiking || _isTripling) return;
    _isLiking = true;
    try {
      await c.toggleArticleLike(widget.discussion);
    } finally {
      if (mounted) setState(() {});
      _isLiking = false;
    }
  }

  Future<void> _handleTriple() async {
    if (_isLiking || _isTripling) return;
    _isTripling = true;
    try {
      await c.tripleArticle(widget.discussion, widget.hData);
    } finally {
      if (mounted) setState(() {});
      _isTripling = false;
    }
  }

  Widget _buildTripleActionButton() {
    return Obx(
      () => TripleActionButton(
        liked: widget.discussion.liked,
        likesCount: widget.discussion.likesCount,
        canTriple: c.canTriple(widget.discussion),
        busy: _isLiking || _isTripling,
        onLike: _handleLike,
        onTriple: _handleTriple,
      ),
    );
  }

  Future<void> _handleDelete() async {
    final isPublished = !widget.discussion.isEditableDraft;
    final confirmed = await showDeleteConfirmDialog(
      context: context,
      title: '确认删除',
      message: isPublished
          ? '删除已发布的帖子将扣除 10 丁尼，确定要继续吗？'
          : '确定要删除这个帖子吗？此操作不可恢复。',
      width: 320,
    );

    if (confirmed == true) {
      try {
        final res = await api.deleteDiscussion(widget.discussion.id);
        if (res.hasError) {
          showToast('删除失败: ${res.statusText}', isError: true);
        } else {
          final body = res.body;
          final newBalance = body is Map<String, dynamic>
              ? (body['newBalance'] as num?)?.toInt()
              : null;
          if (newBalance != null) {
            c.user.value?.denny = newBalance;
            c.user.refresh();
          }
          if (!mounted) return;
          Navigator.of(context).pop(true);
          showToast(isPublished ? '帖子已删除，扣除 10 丁尼' : '帖子已删除');
          c.searchResult.refresh();
          c.bookmarks.refresh();
          c.history.refresh();
        }
      } catch (e) {
        showToast('删除出错: $e', isError: true);
      }
    }
  }

  void _handleEdit() async {
    final result = await CreateDiscussionPage.show(
      context,
      documentId: widget.discussion.id,
      discussion: widget.discussion,
    );
    if (result == true) {
      widget.onEditSuccess?.call();
    }
  }

  Future<void> _handleUnpublish() async {
    final confirmed = await showDeleteConfirmDialog(
      context: context,
      title: '确认撤稿',
      message: '撤稿后帖子将不再公开，但内容仍保留在草稿中。确定继续吗？',
      confirmText: '撤稿',
      width: 320,
    );

    if (confirmed != true) return;

    try {
      final res = await api.unpublishArticleDraft(widget.discussion.id);
      if (res.hasError) {
        showToast('撤稿失败: ${res.statusText}', isError: true);
      } else {
        if (!mounted) return;
        showToast('已撤稿');
        c.searchResult.refresh();
        c.bookmarks.refresh();
        c.history.refresh();
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      showToast('撤稿出错: $e', isError: true);
    }
  }

  Widget _buildImagePreviews() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: SizedBox(
        height: 72,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _imageUploads.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final task = _imageUploads[index];
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xff2D2D2D),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: task.previewUrl != null && task.previewUrl!.isNotEmpty
                        ? Image.network(
                            task.previewUrl!,
                            fit: BoxFit.cover,
                            loadingBuilder: (_, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Center(
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.broken_image,
                                    color: Colors.grey, size: 24),
                          )
                        : const Center(
                            child: Icon(Icons.image, color: Colors.grey),
                          ),
                  ),
                ),
                if (task.isUploading)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black54,
                      child: Center(
                        child: CircularProgressIndicator(
                          value: task.progress / 100,
                          strokeWidth: 2,
                          color: const Color(0xffBFFF09),
                        ),
                      ),
                    ),
                  )
                else if (task.error != null)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black54,
                      child: const Center(
                        child: Icon(Icons.error_outline,
                            color: Colors.red, size: 20),
                      ),
                    ),
                  )
                else
                  Positioned(
                    top: -4,
                    right: -4,
                    child: ClickRegion(
                      onTap: () => _removeImage(index),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, size: 12),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 2),
      child: Row(
        children: [
          ClickRegion(
            onTap: _openEmotePicker,
            child: const Icon(Icons.emoji_emotions,
                color: Colors.grey, size: 22),
          ),
          const SizedBox(width: 16),
          ClickRegion(
            onTap: _openMentionPicker,
            child: const Icon(Icons.alternate_email,
                color: Colors.grey, size: 22),
          ),
          const SizedBox(width: 16),
          ClickRegion(
            onTap: _pickImages,
            child: const Icon(Icons.image, color: Colors.grey, size: 22),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TapRegion(
      onTapOutside: (_) {
        if (_isWriting && !_isOverlayOpen) _cancel();
      },
      child: Row(
        children: [
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xff222222),
                borderRadius: BorderRadius.circular(maxRadius),
                border: Border.all(color: const Color(0xff2D2D2D), width: 4),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final fullWidth = constraints.maxWidth;
                  const iconWidth = 48.0;

                  return AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      final progress = 1.0 - _controller.value;
                      final curve = Curves.easeInOut.transform(progress);

                      final inputWidth = (fullWidth - iconWidth) * curve;
                      final buttonWidth = fullWidth - inputWidth;

                      return Row(
                        children: [
                          SizedBox(
                            width: inputWidth,
                            child: ClipRect(
                              child: Align(
                                alignment: Alignment.centerLeft,
                                widthFactor: 1.0,
                                child: UnconstrainedBox(
                                  alignment: Alignment.centerLeft,
                                  constrainedAxis: Axis.vertical,
                                  child: SizedBox(
                                    width: fullWidth - iconWidth,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8.0),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (_imageUploads.isNotEmpty)
                                            _buildImagePreviews(),
                                          CallbackShortcuts(
                                            bindings: {
                                              const SingleActivator(
                                                      LogicalKeyboardKey
                                                          .escape):
                                                  _cancel,
                                              const SingleActivator(
                                                LogicalKeyboardKey.enter,
                                                control: true,
                                              ): _submit,
                                            },
                                            child: TextField(
                                              controller: _textController,
                                              focusNode: _focusNode,
                                              style: const TextStyle(
                                                  fontSize: 16,
                                                  color: Colors.white),
                                              cursorColor: Colors.white,
                                              minLines: 1,
                                              maxLines: 6,
                                              keyboardType:
                                                  TextInputType.multiline,
                                              decoration:
                                                  InputDecoration.collapsed(
                                                hintText: _replyToUser != null
                                                    ? '回复 @$_replyToUser：'
                                                    : '请输入文本...',
                                                hintStyle: const TextStyle(
                                                    color: Colors.grey),
                                              ),
                                            ),
                                          ),
                                          if (_isWriting)
                                            _buildToolbar(),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: buttonWidth,
                            child: ClickRegion(
                              onTap: _handleTap,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Opacity(
                                    opacity: curve,
                                    child: _isLoading
                                        ? const SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white),
                                          )
                                        : const Icon(Icons.send,
                                            key: ValueKey('send')),
                                  ),
                                  Opacity(
                                    opacity: 1.0 - curve,
                                    child: Transform.translate(
                                      offset: Offset(-50 * curve, 0),
                                      child: UnconstrainedBox(
                                        constrainedAxis: Axis.vertical,
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.add_comment_outlined),
                                            SizedBox(width: 8),
                                            Text(
                                              '评论',
                                              style: TextStyle(fontSize: 16),
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              widget.discussion.commentsCount
                                                  .toString(),
                                              style: TextStyle(fontSize: 16),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ),
          SizeTransition(
            sizeFactor: _sizeAnimation,
            axis: Axis.horizontal,
            alignment: Alignment.centerLeft,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  _buildTripleActionButton(),
                  const SizedBox(width: 8),
                  Obx(() {
                    final isLiked = c.bookmarks
                        .map((e) => e.id)
                        .contains(widget.discussion.id);
                    final count = widget.hData.favoritesCount;
                    return Tooltip(
                      message: isLiked ? '取消收藏' : '收藏',
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xff222222),
                          borderRadius: BorderRadius.circular(maxRadius),
                          border: Border.all(
                              color: const Color(0xff2D2D2D), width: 4),
                        ),
                        child: ClickRegion(
                          onTap: () => c.toggleFavorite(widget.hData),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isLiked
                                    ? Icons.favorite
                                    : Icons.favorite_outline,
                                color: isLiked ? Colors.red : null,
                                size: 22,
                              ),
                              if (count > 0) ...[
                                const SizedBox(width: 4),
                                Text(
                                  count.toString(),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isLiked ? Colors.red : Colors.grey,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  if (c.user.value?.login ==
                      widget.discussion.author.login) ...[
                    if (!widget.discussion.isEditableDraft) ...[
                      const SizedBox(width: 8),
                      Tooltip(
                        message: '撤稿',
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xff222222),
                            borderRadius: BorderRadius.circular(maxRadius),
                            border: Border.all(
                                color: const Color(0xff2D2D2D), width: 4),
                          ),
                          child: ClickRegion(
                            onTap: _handleUnpublish,
                            child: const Icon(Icons.visibility_off,
                                color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    Tooltip(
                      message: '编辑',
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xff222222),
                          borderRadius: BorderRadius.circular(maxRadius),
                          border: Border.all(
                              color: const Color(0xff2D2D2D), width: 4),
                        ),
                        child: ClickRegion(
                          onTap: _handleEdit,
                          child: const Icon(Icons.edit, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Tooltip(
                      message: '删除',
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xff222222),
                          borderRadius: BorderRadius.circular(maxRadius),
                          border: Border.all(
                              color: const Color(0xff2D2D2D), width: 4),
                        ),
                        child: ClickRegion(
                          onTap: _handleDelete,
                          child: const Icon(Icons.delete, color: Colors.red),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
