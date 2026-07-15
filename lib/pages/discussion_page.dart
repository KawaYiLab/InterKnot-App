import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:inter_knot/api/api.dart';
import 'package:inter_knot/controllers/data.dart';
import 'package:inter_knot/helpers/logger.dart';
import 'package:inter_knot/models/discussion.dart';
import 'package:inter_knot/models/h_data.dart';
import 'package:inter_knot/pages/discussion/discussion_action_buttons.dart';
import 'package:inter_knot/pages/discussion/discussion_comment_section.dart';
import 'package:inter_knot/pages/discussion/discussion_cover.dart';
import 'package:inter_knot/pages/discussion/discussion_desktop_body.dart';
import 'package:inter_knot/pages/discussion/discussion_detail_box.dart';
import 'package:inter_knot/pages/discussion/discussion_header_bar.dart';
import 'package:inter_knot/pages/discussion/new_comment_notification.dart';


class DiscussionPage extends StatefulWidget {
  const DiscussionPage({
    super.key,
    required this.discussion,
    required this.hData,
    this.reorderHistoryOnOpen = true,
  });

  final DiscussionModel discussion;
  final HDataModel hData;
  final bool reorderHistoryOnOpen;

  @override
  State<DiscussionPage> createState() => _DiscussionPageState();
}

class _DiscussionPageState extends State<DiscussionPage> {
  final scrollController = ScrollController();
  final leftScrollController =
      ScrollController(); // New controller for left side
  final c = Get.find<Controller>();
  final actionButtonsKey = GlobalKey<DiscussionActionButtonsState>(); // Add key
  bool _isLoadingMore = false;
  bool _isInitialLoading = false;
  Timer? _newCommentCheckTimer;
  final ValueNotifier<NewCommentCounts> _newCommentCounts =
      ValueNotifier(const NewCommentCounts(newCount: 0, serverCount: 0));
  bool _isDetailLoading = true;
  double? _mobileCoverAspectRatio; // 移动端封面的实际宽高比

  // 移动端封面使用图片加载后的实际宽高比，如果还没加载完则使用默认值 643/408
  // 限制最小宽高比为 0.6，防止竖图过高
  double _getMobileCoverAspectRatio() {
    final aspectRatio = _mobileCoverAspectRatio ?? (643 / 408);
    // 最小宽高比 0.6 (3:5)，即高度最多是宽度的 1.67 倍
    return aspectRatio < 0.6 ? 0.6 : aspectRatio;
  }

  Future<void> _fetchArticleDetails() async {
    try {
      final fullDiscussion =
          await Get.find<Api>().getArticleDetail(widget.discussion.id);
      if (mounted) {
        widget.discussion.updateFrom(fullDiscussion);
        setState(() {
          _isDetailLoading = false;
        });
      }
    } catch (e) {
      logger.e('Failed to fetch article details', error: e);
      if (mounted) {
        setState(() {
          _isDetailLoading = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    Future(() {
      if (widget.reorderHistoryOnOpen) {
        c.history({widget.hData, ...c.history});
      } else {
        if (!c.history.contains(widget.hData)) {
          c.history.add(widget.hData);
        }
      }
    });

    widget.discussion.comments.clear();
    _isInitialLoading = true;
    _startNewCommentCheck();
    _fetchArticleDetails();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final wasRead = widget.discussion.isRead;
      // 先立即完成本地的已读 + 浏览量乐观更新，再异步同步服务端
      c.markDiscussionReadAndViewed(widget.discussion);
      if (!wasRead) {
        Get.find<Api>().markAsRead(widget.discussion.id);
      }
      Get.find<Api>()
          .viewArticle(widget.discussion.id)
          .then((serverViews) {
        if (serverViews != null) {
          c.markDiscussionReadAndViewed(
            widget.discussion,
            serverViews: serverViews,
          );
        }
      })
          .catchError((e) {
        logger.e('Failed to record article view', error: e);
      });
    });

    scrollController.addListener(() {
      if (_isLoadingMore) return;
      final maxScroll = scrollController.position.maxScrollExtent;
      final currentScroll = scrollController.position.pixels;
      if (maxScroll - currentScroll < 200 && widget.discussion.hasNextPage()) {
        _isLoadingMore = true;
        widget.discussion.fetchComments().then((_) {
          if (mounted) {
            setState(() {});
          }
        }).catchError((e) {
          logger.e('Error loading more comments', error: e);
        }).whenComplete(() {
          _isLoadingMore = false;
        });
      }
    });

    // Delay initial loading until transition animation completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final route = ModalRoute.of(context);
      if (route != null &&
          route.animation != null &&
          !route.animation!.isCompleted) {
        void listener(AnimationStatus status) {
          if (status == AnimationStatus.completed) {
            route.animation!.removeStatusListener(listener);
            _startInitialLoad();
          }
        }

        route.animation!.addStatusListener(listener);
      } else {
        _startInitialLoad();
      }
    });
  }

  void _handleCommentAdded() {
    if (mounted) {
      setState(() {});
    }
    _scrollToBottom();
  }

  void _startInitialLoad() {
    if (!mounted) return;
    widget.discussion.fetchComments().then((e) async {
      try {
        while (scrollController.hasClients &&
            scrollController.position.maxScrollExtent == 0 &&
            widget.discussion.hasNextPage()) {
          await widget.discussion.fetchComments();
        }
      } catch (e, s) {
        logger.e('Failed to get scroll position', error: e, stackTrace: s);
      }
    }).whenComplete(() {
      if (mounted) {
        setState(() {
          _isInitialLoading = false;
        });
      }
    });
  }

  void _startNewCommentCheck() {
    _newCommentCheckTimer?.cancel();
    unawaited(_checkNewComments(syncOnly: true));
    _newCommentCheckTimer =
        Timer.periodic(const Duration(seconds: 15), (timer) {
      _checkNewComments();
    });
  }

  Future<void> _checkNewComments({bool syncOnly = false}) async {
    try {
      final count =
          await Get.find<Api>().getCommentCount(widget.discussion.id);
      if (syncOnly) {
        final shouldRefresh = count != widget.discussion.commentsCount;
        widget.discussion.commentsCount = count;
        if (_newCommentCounts.value.newCount > 0) {
          _newCommentCounts.value =
              const NewCommentCounts(newCount: 0, serverCount: 0);
        }
        if (shouldRefresh && mounted) setState(() {});
        return;
      }

      if (count > widget.discussion.commentsCount) {
        _newCommentCounts.value = NewCommentCounts(
          newCount: count - widget.discussion.commentsCount,
          serverCount: count,
        );
      } else if (_newCommentCounts.value.newCount > 0) {
        _newCommentCounts.value =
            const NewCommentCounts(newCount: 0, serverCount: 0);
      }
    } catch (e) {
      // 静默失败：拉不到服务端评论数时不打扰用户
    }
  }

  @override
  void dispose() {
    _newCommentCheckTimer?.cancel();
    _newCommentCounts.dispose();
    scrollController.dispose();
    leftScrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutQuart,
        );
      }
    });
  }

  Future<void> _handleNewCommentNotificationTap(NewCommentCounts counts) async {
    widget.discussion.commentsCount = counts.serverCount;
    _newCommentCounts.value =
        const NewCommentCounts(newCount: 0, serverCount: 0);

    if (widget.discussion.comments.isNotEmpty) {
      widget.discussion.comments.last.hasNextPage = true;
    }

    await widget.discussion.fetchComments();
    if (mounted) setState(() {});
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final isDesktop = screenW >= 800;
    final isFullScreen = screenW < 500;
    final double baseFactor = isDesktop ? 0.7 : (isFullScreen ? 1.0 : 0.9);
    final double zoomScale = isDesktop ? 1.1 : 1.0;
    final double layoutFactor = baseFactor * zoomScale;
    final double outerRadius = isFullScreen ? 0 : 24;
    final double innerRadius = isFullScreen ? 0 : 22;

    return SafeArea(
      child: Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final safeW = constraints.maxWidth;
            final safeH = constraints.maxHeight;
            return SizedBox(
              width: safeW * layoutFactor,
              height: safeH * layoutFactor,
              child: FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: safeW * baseFactor,
                  height: safeH * baseFactor,
                  child: Container(
                    padding: isFullScreen
                        ? EdgeInsets.zero
                        : const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(59, 255, 255, 255),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(outerRadius),
                        bottomLeft: Radius.circular(outerRadius),
                        bottomRight: Radius.circular(outerRadius),
                      ),
                    ),
                    child: Container(
                      padding: isFullScreen
                          ? EdgeInsets.zero
                          : const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(innerRadius),
                          bottomLeft: Radius.circular(innerRadius),
                          bottomRight: Radius.circular(innerRadius),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(innerRadius),
                          bottomLeft: Radius.circular(innerRadius),
                          bottomRight: Radius.circular(innerRadius),
                        ),
                        child: Scaffold(
                          backgroundColor: const Color(0xff121212),
                          body: Column(
                            children: [
                              DiscussionHeaderBar(
                                discussion: widget.discussion,
                                isMobile: !isDesktop,
                              ),
                              Expanded(
                                child: LayoutBuilder(
                                  builder: (context, con) {
                                    if (con.maxWidth < 800) {
                                      return _buildMobileBody(context, con);
                                    }
                                    return DiscussionDesktopBody(
                                      discussion: widget.discussion,
                                      hData: widget.hData,
                                      isDetailLoading: _isDetailLoading,
                                      isInitialLoading: _isInitialLoading,
                                      leftScrollController:
                                          leftScrollController,
                                      scrollController: scrollController,
                                      actionButtonsKey: actionButtonsKey,
                                      buildNewCommentNotification: () =>
                                          NewCommentNotification(
                                        countsListenable: _newCommentCounts,
                                        onTap:
                                            _handleNewCommentNotificationTap,
                                      ),
                                      onCommentAdded: _handleCommentAdded,
                                      onEditSuccess: () {
                                        _fetchArticleDetails();
                                      },
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMobileBody(BuildContext context, BoxConstraints constraints) {
    final maxCoverHeight = constraints.maxHeight * 0.5;
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              CustomScrollView(
                controller: scrollController,
                slivers: [
                  SliverToBoxAdapter(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: maxCoverHeight),
                      child: AspectRatio(
                        aspectRatio: _getMobileCoverAspectRatio(),
                        child: _isDetailLoading
                            ? const SizedBox.shrink()
                            : Cover(
                                discussion: widget.discussion,
                                isMobile: true,
                                maxHeight: maxCoverHeight,
                                borderRadius: BorderRadius.zero,
                                onImageLoaded: (aspectRatio) {
                                  if (mounted) {
                                    setState(() {
                                      _mobileCoverAspectRatio = aspectRatio;
                                    });
                                  }
                                },
                              ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _isDetailLoading
                        ? const SizedBox.shrink()
                        : DiscussionDetailBox(
                            discussion: widget.discussion,
                          ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          const SizedBox(height: 16),
                          const Divider(),
                          DiscussionCommentSection(
                            discussion: widget.discussion,
                            isInitialLoading: _isInitialLoading,
                            onReply: (
                              id,
                              userName, {
                              addPrefix = false,
                              authorDocumentId,
                            }) =>
                                actionButtonsKey.currentState?.replyTo(
                              id,
                              userName,
                              addPrefix: addPrefix,
                              authorDocumentId: authorDocumentId,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              NewCommentNotification(
                countsListenable: _newCommentCounts,
                onTap: _handleNewCommentNotificationTap,
              ),
            ],
          ),
        ),
        DiscussionActionButtons(
          key: actionButtonsKey,
          discussion: widget.discussion,
          hData: widget.hData,
          isMobile: true,
          onCommentAdded: _handleCommentAdded,
          onEditSuccess: () {
            _fetchArticleDetails();
          },
        ),
      ],
    );
  }
}
