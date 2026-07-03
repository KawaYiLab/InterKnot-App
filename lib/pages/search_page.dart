import 'package:flutter/material.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:get/get.dart';
import 'package:inter_knot/components/category_tab_bar.dart';
import 'package:inter_knot/components/discussions_grid.dart';
import 'package:inter_knot/components/zzz_desktop_action_button.dart';
import 'package:inter_knot/controllers/data.dart';
import 'package:inter_knot/helpers/throttle.dart';
import 'package:inter_knot/pages/create_discussion_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage>
    with AutomaticKeepAliveClientMixin {
  final c = Get.find<Controller>();

  final keyboardVisibilityController = KeyboardVisibilityController();
  late final keyboardSubscription =
      keyboardVisibilityController.onChange.listen((visible) {
    if (!visible) FocusManager.instance.primaryFocus?.unfocus();
  });

  late final fetchData = retryThrottle(
    c.searchData,
    const Duration(milliseconds: 500),
  );

  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    keyboardSubscription.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 640;

    return Stack(
      children: [
        Column(
          children: [
            const CategoryTabBar(),
            Expanded(
              child: Stack(
                children: [
                  isCompact
                      ? RefreshIndicator(
                          edgeOffset: 0,
                          displacement: 56,
                          onRefresh: () async {
                            await c.refreshSearchData();
                          },
                          child: Obx(() {
                            return DiscussionGrid(
                              list: c.searchResult(),
                              hasNextPage: c.searchHasNextPage(),
                              fetchData: fetchData,
                              controller: _scrollController,
                            );
                          }),
                        )
                      : Obx(() {
                          return DiscussionGrid(
                            list: c.searchResult(),
                            hasNextPage: c.searchHasNextPage(),
                            fetchData: fetchData,
                            controller: _scrollController,
                          );
                        }),
                  Positioned(
                    top: 16,
                    left: 0,
                    right: 0,
                    child: Obx(() {
                      final count = c.newPostCount.value;
                      final hasChange = c.hasContentChange.value;
                      final shouldShow = count > 0 || hasChange;

                      String message = '帖子列表有更新';
                      if (count > 0) {
                        message = '有 $count 个新帖子';
                      }

                      return AnimatedSwitcher(
                        duration: const Duration(milliseconds: 320),
                        reverseDuration: const Duration(milliseconds: 220),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) {
                          final slide = Tween<Offset>(
                            begin: const Offset(0, -0.2),
                            end: Offset.zero,
                          ).animate(CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOutCubic,
                          ));
                          final scale = Tween<double>(
                            begin: 0.96,
                            end: 1.0,
                          ).animate(CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOutBack,
                          ));
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: slide,
                              child: ScaleTransition(
                                scale: scale,
                                child: child,
                              ),
                            ),
                          );
                        },
                        child: shouldShow
                            ? Center(
                                key: ValueKey(
                                    'new-post-banner-$count-$hasChange'),
                                child: Material(
                                  color: const Color(0xffD7FF00),
                                  borderRadius: BorderRadius.circular(24),
                                  elevation: 10,
                                  shadowColor: const Color(0xffD7FF00)
                                      .withValues(alpha: 0.45),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(24),
                                    onTap: () async {
                                      await c.showNewPosts();
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                        if (_scrollController.hasClients) {
                                          _scrollController.animateTo(
                                            0,
                                            duration: const Duration(
                                                milliseconds: 500),
                                            curve: Curves.easeOutQuart,
                                          );
                                        }
                                      });
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 18,
                                        vertical: 10,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.north_rounded,
                                            size: 18,
                                            color: Colors.black,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            message,
                                            style: const TextStyle(
                                              color: Colors.black,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            : const SizedBox(
                                key: ValueKey('new-post-banner-hidden'),
                              ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (!isCompact)
          Positioned(
            bottom: 24,
            right: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                ZzzDesktopActionButton(
                  icon: Icons.refresh_rounded,
                  label: '刷新',
                  width: 48,
                  iconOnly: true,
                  enableClickFlash: true,
                  onTap: () async {
                    c.refreshSearchData();
                  },
                ),
                const SizedBox(height: 12),
                ZzzDesktopActionButton(
                  icon: Icons.add,
                  label: '发布委托',
                  width: 188,
                  onTap: () async {
                    if (await c.ensureLogin()) {
                      CreateDiscussionPage.show(context);
                    }
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;
}
