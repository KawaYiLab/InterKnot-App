import 'dart:async';

import 'package:get/get.dart';
import 'package:inter_knot/api/api.dart';
import 'package:inter_knot/controllers/data.dart';
import 'package:inter_knot/helpers/toast.dart';
import 'package:inter_knot/models/comment.dart';
import 'package:inter_knot/models/discussion.dart';
import 'package:inter_knot/models/h_data.dart';

/// 负责点赞、收藏、三连等交互状态，支持乐观更新。
class InteractionController extends GetxController {
  InteractionController(this._controller);

  final Controller _controller;
  final Api _api = Get.find<Api>();

  final bookmarks = <HDataModel>{}.obs;

  Future<void> refreshFavorites() async {
    final username = _controller.user.value?.login ?? '';
    if (!_controller.isLogin.isTrue || username.isEmpty) {
      bookmarks.clear();
      return;
    }

    final result = await _api.getFavorites(username, '');
    bookmarks(result.items.toSet());
  }

  Future<void> toggleFavorite(HDataModel hData) async {
    if (!_controller.isLogin.isTrue) {
      showToast('请先登录', isError: true);
      return;
    }

    final articleId = hData.id;
    if (articleId.isEmpty) return;

    final oldFavorited = hData.favorited;
    final oldCount = hData.favoritesCount;

    // 乐观更新
    hData.favorited = !oldFavorited;
    hData.favoritesCount = oldFavorited
        ? (oldCount > 0 ? oldCount - 1 : 0)
        : oldCount + 1;

    if (hData.favorited) {
      bookmarks.add(hData);
    } else {
      bookmarks.removeWhere((e) => e.id == articleId);
    }

    // 同步详情页缓存的 DiscussionModel
    final cached = hData.cachedDiscussion;
    if (cached != null) {
      cached.favorited = hData.favorited;
      cached.favoritesCount = hData.favoritesCount;
      HDataModel.upsertCachedDiscussion(cached);
    }

    _controller.searchResult.refresh();
    bookmarks.refresh();
    _controller.history.refresh();

    try {
      final result = await _api.toggleFavorite(articleId);

      // 与后端状态对齐
      hData.favorited = result.favorited;
      hData.favoritesCount = result.favoritesCount;

      if (result.favorited) {
        if (!bookmarks.any((e) => e.id == articleId)) {
          bookmarks.add(hData);
        }
      } else {
        bookmarks.removeWhere((e) => e.id == articleId);
      }

      if (cached != null) {
        cached.favorited = result.favorited;
        cached.favoritesCount = result.favoritesCount;
        HDataModel.upsertCachedDiscussion(cached);
      }

      _controller.searchResult.refresh();
      bookmarks.refresh();
      _controller.history.refresh();
    } catch (e) {
      // 回滚
      hData.favorited = oldFavorited;
      hData.favoritesCount = oldCount;

      if (oldFavorited) {
        bookmarks.add(hData);
      } else {
        bookmarks.removeWhere((e) => e.id == articleId);
      }

      if (cached != null) {
        cached.favorited = oldFavorited;
        cached.favoritesCount = oldCount;
        HDataModel.upsertCachedDiscussion(cached);
      }

      _controller.searchResult.refresh();
      bookmarks.refresh();
      _controller.history.refresh();
      showToast('收藏操作失败: $e', isError: true);
    }
  }

  Future<void> toggleArticleLike(DiscussionModel discussion) async {
    if (!_controller.isLogin.isTrue) {
      if (!await _controller.ensureLogin()) return;
    }

    final oldLiked = discussion.liked;
    final oldCount = discussion.likesCount;

    // 乐观更新
    discussion.liked = !oldLiked;
    discussion.likesCount = oldLiked
        ? (oldCount > 0 ? oldCount - 1 : 0)
        : oldCount + 1;

    // 更新缓存详情
    HDataModel.upsertCachedDiscussion(discussion);
    _controller.searchResult.refresh();
    bookmarks.refresh();
    _controller.history.refresh();

    try {
      final result = await _api.toggleLike(
        targetType: 'article',
        targetId: discussion.id,
      );
      // 与后端状态对齐
      discussion.liked = result.liked;
      discussion.likesCount = result.likesCount;
      HDataModel.upsertCachedDiscussion(discussion);
      _controller.searchResult.refresh();
      bookmarks.refresh();
      _controller.history.refresh();
    } catch (e) {
      // 回滚
      discussion.liked = oldLiked;
      discussion.likesCount = oldCount;
      HDataModel.upsertCachedDiscussion(discussion);
      _controller.searchResult.refresh();
      bookmarks.refresh();
      _controller.history.refresh();
      showToast('操作失败: $e', isError: true);
    }
  }

  Future<void> toggleCommentLike(CommentModel comment) async {
    if (!_controller.isLogin.isTrue) {
      if (!await _controller.ensureLogin()) return;
    }

    final oldLiked = comment.liked;
    final oldCount = comment.likesCount;

    // 乐观更新
    comment.liked = !oldLiked;
    comment.likesCount = oldLiked
        ? (oldCount > 0 ? oldCount - 1 : 0)
        : oldCount + 1;

    try {
      final result = await _api.toggleLike(
        targetType: 'comment',
        targetId: comment.id,
      );
      // 与后端状态对齐
      comment.liked = result.liked;
      comment.likesCount = result.likesCount;
    } catch (e) {
      // 回滚
      comment.liked = oldLiked;
      comment.likesCount = oldCount;
      showToast('操作失败: $e', isError: true);
    }
  }

  void clearBookmarks() {
    bookmarks.clear();
  }

  @override
  Future<void> onInit() async {
    super.onInit();

    if (_controller.isLogin.isTrue && _controller.user.value != null) {
      unawaited(refreshFavorites());
    }

    ever(_controller.user, (u) {
      if (u != null && _controller.isLogin.isTrue) {
        unawaited(refreshFavorites());
      } else {
        bookmarks.clear();
      }
    });
  }
}
