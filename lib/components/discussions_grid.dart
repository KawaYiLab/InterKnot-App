import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:inter_knot/components/discussion_card.dart';
import 'package:inter_knot/controllers/data.dart';
import 'package:inter_knot/helpers/dialog_helper.dart';
import 'package:inter_knot/helpers/smooth_scroll.dart';
import 'package:inter_knot/models/discussion.dart';
import 'package:inter_knot/models/h_data.dart';
import 'package:inter_knot/pages/discussion_page.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:waterfall_flow/waterfall_flow.dart';

const homeAlignedDesktopDiscussionCardExtent = 232.0;

class DiscussionEmptyState extends StatelessWidget {
  const DiscussionEmptyState({
    super.key,
    required this.message,
    this.imageAsset,
    this.imageSize = 120,
    this.textStyle,
  });

  final String message;
  final String? imageAsset;
  final double imageSize;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final hasImage = imageAsset != null && imageAsset!.isNotEmpty;
    final hasMessage = message.trim().isNotEmpty;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 16),
        if (hasImage)
          Image.asset(
            imageAsset!,
            width: imageSize,
            height: imageSize,
          ),
        if (hasImage && hasMessage) const SizedBox(height: 16),
        if (hasMessage)
          Text(
            message,
            style: textStyle,
          ),
      ],
    );
  }
}

class DiscussionGrid extends StatefulWidget {
  const DiscussionGrid({
    super.key,
    required this.list,
    required this.hasNextPage,
    this.fetchData,
    this.controller,
    this.reorderHistoryOnOpen = true,
    this.onOpenItem,
    this.compactMaxCrossAxisExtent,
    this.desktopMaxCrossAxisExtent,
    this.crossAxisCount,
    this.mainAxisSpacing,
    this.crossAxisSpacing,
    this.gridPadding,
    this.shrinkWrap = false,
    this.physics,
    this.emptyMessage,
  });

  final Set<HDataModel> list;
  final bool hasNextPage;
  final void Function()? fetchData;
  final ScrollController? controller;
  final bool reorderHistoryOnOpen;
  final double? compactMaxCrossAxisExtent;
  final double? desktopMaxCrossAxisExtent;
  final int? crossAxisCount;
  final double? mainAxisSpacing;
  final double? crossAxisSpacing;
  final EdgeInsets? gridPadding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final String? emptyMessage;
  final Future<void> Function(
    BuildContext context,
    HDataModel item,
    DiscussionModel discussion,
  )? onOpenItem;

  @override
  State<DiscussionGrid> createState() => _DiscussionGridState();
}

class _DiscussionGridState extends State<DiscussionGrid>
    with AutomaticKeepAliveClientMixin {
  late final ScrollController scrollController;
  bool _isLocalController = false;

  Widget _buildInsertedPostAnimation(String id, Widget child) {
    if (id.isEmpty) return child;

    return Obx(() {
      final shouldAnimate =
          Get.find<Controller>().newlyInsertedPostIds.contains(id);

      return TweenAnimationBuilder<double>(
        key: ValueKey('insert-$id-${shouldAnimate ? 1 : 0}'),
        tween: Tween(begin: shouldAnimate ? 0 : 1, end: 1),
        duration: Duration(milliseconds: shouldAnimate ? 520 : 180),
        curve: shouldAnimate ? Curves.easeOutCubic : Curves.easeOut,
        child: child,
        builder: (context, value, builtChild) {
          final opacity = value < 0 ? 0.0 : (value > 1 ? 1.0 : value);
          final dy = (1 - value) * 16;
          final scale = 0.985 + (0.015 * value);
          return Opacity(
            opacity: opacity,
            child: Transform.translate(
              offset: Offset(0, dy),
              child: Transform.scale(
                scale: scale,
                child: builtChild,
              ),
            ),
          );
        },
      );
    });
  }

  @override
  bool get wantKeepAlive => true;

  Widget _buildCard(
      BuildContext context, HDataModel item, DiscussionModel discussion) {
    return DiscussionCard(
      discussion: discussion,
      hData: item,
      onTap: () async {
        if (widget.onOpenItem != null) {
          await widget.onOpenItem!(context, item, discussion);
          return;
        }
        final result = await showZZZDialog(
          context: context,
          pageBuilder: (context) {
            return DiscussionPage(
              discussion: discussion,
              hData: item,
              reorderHistoryOnOpen: widget.reorderHistoryOnOpen,
            );
          },
        );

        if (result == true) {
          if (widget.list is RxSet) {
            widget.list.remove(item);
          } else {
            setState(() {
              widget.list.remove(item);
            });
          }
        }
      },
    );
  }

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      scrollController = widget.controller!;
    } else {
      scrollController = ScrollController();
      _isLocalController = true;
    }
  }

  @override
  void didUpdateWidget(covariant DiscussionGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      if (oldWidget.controller == null) {
        if (_isLocalController) {
          scrollController.dispose();
          _isLocalController = false;
        }
      }
      if (widget.controller != null) {
        scrollController = widget.controller!;
        _isLocalController = false;
      } else {
        scrollController = ScrollController();
        _isLocalController = true;
      }
    }
  }

  @override
  void dispose() {
    if (_isLocalController) {
      scrollController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final list = widget.list;
    final items = list.toList(growable: false);
    final fetchData = widget.fetchData;
    final hasNextPage = widget.hasNextPage;

    if (list.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          controller: scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Obx(() {
                final isSearching = Get.find<Controller>().isSearching.value;
                final isLoading =
                    isSearching || (hasNextPage && fetchData != null);
                if (isLoading) {
                  return const DiscussionEmptyState(
                    message: '正在和绳网系统建立联系...',
                    imageAsset: 'assets/images/Bangboo.gif',
                    imageSize: 120,
                    textStyle: TextStyle(
                      color: Color(0xff808080),
                      fontSize: 14,
                    ),
                  );
                }
                return DiscussionEmptyState(
                  message: widget.emptyMessage ?? '- 暂无相关帖子 -',
                  textStyle: TextStyle(
                    color: Color.fromARGB(255, 233, 233, 233),
                    fontSize: 16,
                  ),
                );
              }),
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, con) {
        final width = MediaQuery.of(context).size.width;
        final isCompact = width < 640;
        final mainAxisSpacing = widget.mainAxisSpacing ??
            (isCompact ? 10.0 : 12.0);
        final crossAxisSpacing = widget.crossAxisSpacing ??
            (isCompact ? 8.0 : 10.0);
        final padding = widget.gridPadding ??
            const EdgeInsets.fromLTRB(10, 16, 10, 10);
        final physics = widget.physics ??
            (widget.shrinkWrap
                ? const NeverScrollableScrollPhysics()
                : (!isCompact
                    ? const NeverScrollableScrollPhysics()
                    : const BouncingScrollPhysics()));

        final maxCrossAxisExtent = widget.crossAxisCount == null
            ? (isCompact
                ? (widget.compactMaxCrossAxisExtent ?? 273.0)
                : (widget.desktopMaxCrossAxisExtent ?? 264.0))
            : null;

        final gridDelegate = widget.crossAxisCount != null
            ? SliverWaterfallFlowDelegateWithFixedCrossAxisCount(
                crossAxisCount: widget.crossAxisCount!,
                mainAxisSpacing: mainAxisSpacing,
                crossAxisSpacing: crossAxisSpacing,
                lastChildLayoutTypeBuilder: (index) => index == items.length
                    ? LastChildLayoutType.foot
                    : LastChildLayoutType.none,
              )
            : SliverWaterfallFlowDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: maxCrossAxisExtent!,
                mainAxisSpacing: mainAxisSpacing,
                crossAxisSpacing: crossAxisSpacing,
                lastChildLayoutTypeBuilder: (index) => index == items.length
                    ? LastChildLayoutType.foot
                    : LastChildLayoutType.none,
              );

        final child = Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1450),
            child: NotificationListener<ScrollNotification>(
              onNotification: (ScrollNotification notification) {
                if (notification.depth == 0 &&
                    notification.metrics.extentAfter < 500 &&
                    hasNextPage) {
                  fetchData?.call();
                }
                return false;
              },
              child: WaterfallFlow.builder(
                controller: scrollController,
                cacheExtent: 0.0,
                shrinkWrap: widget.shrinkWrap,
                physics: physics,
                padding: padding,
                gridDelegate: gridDelegate,
                itemCount: items.length + 1,
                itemBuilder: (context, index) {
                  if (index == items.length) {
                    if (hasNextPage) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Image.asset(
                            'assets/images/Bangboo.gif',
                            width: 80,
                            height: 80,
                          ),
                        ),
                      );
                    }
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(8),
                        child: Text('已经到底啦…\ [ O_X ] /'),
                      ),
                    );
                  }
                  final item = items[index];

                  final cachedDiscussion = item.cachedDiscussion;
                  if (cachedDiscussion != null) {
                    return RepaintBoundary(
                      child: _buildInsertedPostAnimation(
                        item.id,
                        KeyedSubtree(
                          key: ValueKey(item.id),
                          child: _buildCard(context, item, cachedDiscussion),
                        ),
                      ),
                    );
                  }

                  return RepaintBoundary(
                    child: _buildInsertedPostAnimation(
                      item.id,
                      FutureBuilder(
                        key: ValueKey(item.id),
                        future: item.discussion,
                        builder: (context, snaphost) {
                          if (snaphost.hasData) {
                            return _buildCard(context, item, snaphost.data!);
                          }
                          if (snaphost.hasError) {
                            return Card(
                              clipBehavior: Clip.antiAlias,
                              color: const Color(0xff222222),
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(24),
                                  topRight: Radius.circular(24),
                                  bottomLeft: Radius.circular(24),
                                ),
                              ),
                              child: AspectRatio(
                                aspectRatio: 5 / 6,
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Center(
                                      child:
                                          SelectableText('${snaphost.error}')),
                                ),
                              ),
                            );
                          }
                          if (snaphost.connectionState ==
                              ConnectionState.done) {
                            return Card(
                              clipBehavior: Clip.antiAlias,
                              color: const Color(0xff222222),
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(24),
                                  topRight: Radius.circular(24),
                                  bottomLeft: Radius.circular(24),
                                ),
                              ),
                              child: InkWell(
                                splashColor: Colors.transparent,
                                highlightColor: Colors.transparent,
                                onTap: () => launchUrlString(item.url),
                                child: const AspectRatio(
                                  aspectRatio: 5 / 6,
                                  child: Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Center(child: Text('帖子已删除')),
                                  ),
                                ),
                              ),
                            );
                          }
                          return const DiscussionCardSkeleton();
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );

        if (!isCompact) {
          return SmoothScroll(
            controller: scrollController,
            child: DraggableScrollbar(
              controller: scrollController,
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(
                  scrollbars: false,
                ),
                child: child,
              ),
            ),
          );
        }
        return child;
      },
    );
  }
}
