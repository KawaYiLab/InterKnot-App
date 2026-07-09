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

  bool canTriple(DiscussionModel discussion) {
    if (!_controller.isLogin.isTrue) return false;
    final user = _controller.user.value;
    if (user == null) return false;
    if (user.login == discussion.author.login) return false;
    if (discussion.isAnonymous) return false;
    return true;
  }

  Future<void> tripleArticle(
      DiscussionModel discussion, HDataModel hData) async {
    if (!_controller.isLogin.isTrue) {
      if (!await _controller.ensureLogin()) return;
    }

    final articleId = discussion.id;
    if (articleId.isEmpty) return;

    if (discussion.isAnonymous) {
      showToast('匿名帖不能三连', isError: true);
      return;
    }

    final user = _controller.user.value;
    if (user == null) {
      showToast('请先登录', isError: true);
      return;
    }
    if (user.login == discussion.author.login) {
      showToast('不能给自己的帖子三连', isError: true);
      return;
    }

    final oldLiked = discussion.liked;
    final oldLikesCount = discussion.likesCount;
    final oldHDataLiked = hData.liked;
    final oldHDataLikesCount = hData.likesCount;
    final oldFavorited = discussion.favorited;
    final oldFavoritesCount = discussion.favoritesCount;
    final oldHDataFavorited = hData.favorited;
    final oldHDataFavoritesCount = hData.favoritesCount;
    final oldDennyCount = discussion.dennyCount;
    final oldHasGivenDenny = discussion.hasGivenDenny;
    final oldHDataDennyCount = hData.dennyCount;
    final oldHDataHasGivenDenny = hData.hasGivenDenny;

    // 三连 = 点赞 + 收藏 + 投币（幂等/软失败）
    discussion.liked = true;
    if (!oldLiked) discussion.likesCount++;
    hData.liked = true;
    if (!oldHDataLiked) hData.likesCount++;
    discussion.favorited = true;
    if (!oldFavorited) discussion.favoritesCount++;
    hData.favorited = true;
    if (!oldHDataFavorited) hData.favoritesCount++;
    if (!oldHasGivenDenny) {
      discussion.hasGivenDenny = true;
      discussion.dennyCount++;
    }
    if (!oldHDataHasGivenDenny) {
      hData.hasGivenDenny = true;
      hData.dennyCount++;
    }

    // 同步详情页缓存的 DiscussionModel
    final cached = hData.cachedDiscussion;
    if (cached != null && cached != discussion) {
      cached.liked = hData.liked;
      cached.likesCount = hData.likesCount;
      cached.favorited = discussion.favorited;
      cached.favoritesCount = discussion.favoritesCount;
      cached.dennyCount = discussion.dennyCount;
      cached.hasGivenDenny = discussion.hasGivenDenny;
    }
    HDataModel.upsertCachedDiscussion(discussion);

    if (hData.favorited) {
      if (!bookmarks.any((e) => e.id == articleId)) bookmarks.add(hData);
    } else {
      bookmarks.removeWhere((e) => e.id == articleId);
    }

    _controller.searchResult.refresh();
    bookmarks.refresh();
    _controller.history.refresh();

    try {
      final result = await _api.tripleAction(articleId);

      // 与后端状态对齐（投币失败不阻断点赞+收藏）
      discussion.liked = result.liked;
      discussion.likesCount = result.likesCount;
      hData.liked = result.liked;
      hData.likesCount = result.likesCount;
      discussion.favorited = result.favorited;
      discussion.favoritesCount = result.favoritesCount;
      hData.favorited = result.favorited;
      hData.favoritesCount = result.favoritesCount;
      discussion.dennyCount = result.dennyCount;
      hData.dennyCount = result.dennyCount;

      if (result.coinGiven || result.coinReason == 'ALREADY_GIVEN') {
        discussion.hasGivenDenny = true;
        hData.hasGivenDenny = true;
      } else {
        // 非 GIVEN / ALREADY_GIVEN 的 coinReason 均回滚本地投币状态
        discussion.hasGivenDenny = oldHasGivenDenny;
        hData.hasGivenDenny = oldHDataHasGivenDenny;
        // 若此前未给过币，本地乐观 +1 需要回滚；已给过币则状态与后端一致。
        discussion.dennyCount =
            oldHasGivenDenny ? oldDennyCount : result.dennyCount;
        hData.dennyCount =
            oldHDataHasGivenDenny ? oldHDataDennyCount : result.dennyCount;
      }

      if (result.favorited) {
        if (!bookmarks.any((e) => e.id == articleId)) bookmarks.add(hData);
      } else {
        bookmarks.removeWhere((e) => e.id == articleId);
      }

      final cached = hData.cachedDiscussion;
      if (cached != null) {
        cached.liked = hData.liked;
        cached.likesCount = hData.likesCount;
        cached.favorited = discussion.favorited;
        cached.favoritesCount = discussion.favoritesCount;
        cached.dennyCount = discussion.dennyCount;
        cached.hasGivenDenny = discussion.hasGivenDenny;
        HDataModel.upsertCachedDiscussion(cached);
      }

      _controller.searchResult.refresh();
      bookmarks.refresh();
      _controller.history.refresh();

      _showTripleResultToast(result.coinGiven, result.coinReason);
    } catch (e) {
      // 回滚全部状态
      discussion.liked = oldLiked;
      discussion.likesCount = oldLikesCount;
      hData.liked = oldHDataLiked;
      hData.likesCount = oldHDataLikesCount;
      discussion.favorited = oldFavorited;
      discussion.favoritesCount = oldFavoritesCount;
      hData.favorited = oldHDataFavorited;
      hData.favoritesCount = oldHDataFavoritesCount;
      discussion.dennyCount = oldDennyCount;
      discussion.hasGivenDenny = oldHasGivenDenny;
      hData.dennyCount = oldHDataDennyCount;
      hData.hasGivenDenny = oldHDataHasGivenDenny;

      if (oldHDataFavorited) {
        if (!bookmarks.any((e) => e.id == articleId)) bookmarks.add(hData);
      } else {
        bookmarks.removeWhere((e) => e.id == articleId);
      }

      final cached = hData.cachedDiscussion;
      if (cached != null) {
        cached.liked = oldLiked;
        cached.likesCount = oldLikesCount;
        cached.favorited = oldFavorited;
        cached.favoritesCount = oldFavoritesCount;
        cached.dennyCount = oldDennyCount;
        cached.hasGivenDenny = oldHasGivenDenny;
        HDataModel.upsertCachedDiscussion(cached);
      }

      _controller.searchResult.refresh();
      bookmarks.refresh();
      _controller.history.refresh();
      showToast('三连失败: $e', isError: true);
    }
  }

  void _showTripleResultToast(bool coinGiven, String coinReason) {
    if (coinGiven || coinReason == 'ALREADY_GIVEN') {
      showToast('三连成功！');
      return;
    }

    final message = switch (coinReason) {
      'SELF_GIVE' => '不能给自己的帖子投币，已点赞+收藏',
      'ANONYMOUS_ARTICLE' => '匿名帖不能投币，已点赞+收藏',
      'INSUFFICIENT_BALANCE' => '丁尼不足，已点赞+收藏',
      _ => '投币失败，已点赞+收藏',
    };
    showToast(message, isError: true);
  }

  void clearBookmarks() {
    bookmarks.clear();
  }

  @override
  Future<void> onInit() async {
    super.onInit();

    // 跟随登录态整体切换即可；用户字段的日常刷新（如头像、等级）不应触发收藏刷新。
    ever(_controller.isLogin, (v) {
      if (!v) {
        bookmarks.clear();
      }
    });
  }
}
