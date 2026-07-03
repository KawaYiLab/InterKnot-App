import 'package:get/get.dart';
import 'package:inter_knot/api/api.dart';
import 'package:inter_knot/helpers/use.dart';
import 'package:inter_knot/models/author.dart';
import 'package:inter_knot/models/discussion.dart';

class HDataModel {
  static final _zeroDate = DateTime.fromMillisecondsSinceEpoch(0);
  static Api get api => Get.find<Api>();
  static final discussionsCache = <String, Future<DiscussionModel?>>{};
  static final _valueCache = <String, DiscussionModel>{};
  static const int _maxCacheSize =
      200; // Increased cache size for better performance
  static DiscussionModel? getCachedDiscussionById(String id) => _valueCache[id];

  static void upsertCachedDiscussion(DiscussionModel discussion) {
    final id = discussion.id;
    if (discussionsCache.containsKey(id)) {
      discussionsCache.remove(id);
    }
    if (!discussionsCache.containsKey(id) &&
        discussionsCache.length >= _maxCacheSize) {
      final keyToRemove = discussionsCache.keys.first;
      discussionsCache.remove(keyToRemove);
      _valueCache.remove(keyToRemove);
    }
    _valueCache[id] = discussion;
    discussionsCache[id] = Future.value(discussion);
  }

  static void updateCachedDiscussion(
    String id, {
    bool? isRead,
    int? views,
  }) {
    final cached = _valueCache[id];
    if (cached == null) return;
    if (isRead != null) cached.isRead = isRead;
    if (views != null) cached.views = views;
    if (discussionsCache.containsKey(id)) {
      discussionsCache[id] = Future.value(cached);
    }
  }

  String id;
  DateTime updatedAt;
  DateTime createdAt;
  bool isPinned;
  bool isEditableDraft;
  bool hasPublishedVersion;
  bool isAnonymous;
  bool liked;
  bool favorited;
  int likesCount;
  int commentsCount;
  int favoritesCount;
  int dennyCount;
  bool hasGivenDenny;
  bool isHidden;
  String? title;
  int? views;
  AuthorModel? author;
  PostCategory? category;
  bool get isPin => isPinned;
  String get url => '';

  DiscussionModel? get cachedDiscussion => _valueCache[id];

  // 临时存储原始 documentId，以便 API 调用
  // String? documentId; // 不需要了，id 就是 documentId

  HDataModel({
    required this.id,
    required DateTime? updatedAt,
    required DateTime? createdAt,
    required this.isPinned,
    this.isEditableDraft = false,
    this.hasPublishedVersion = false,
    this.isAnonymous = false,
    this.liked = false,
    this.favorited = false,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.favoritesCount = 0,
    this.dennyCount = 0,
    this.hasGivenDenny = false,
    this.isHidden = false,
    this.title,
    this.views,
    this.author,
    this.category,
  })  : updatedAt = updatedAt ?? _zeroDate,
        createdAt = createdAt ?? _zeroDate;

  Future<DiscussionModel?> get discussion {
    // Check synchronous cache first (optional, but good for immediate return if we change return type)
    if (_valueCache.containsKey(id)) {
      // Refresh LRU order in future cache
      if (discussionsCache.containsKey(id)) {
        final future = discussionsCache.remove(id)!;
        discussionsCache[id] = future;
        return future;
      }
      return Future.value(_valueCache[id]);
    }

    if (discussionsCache.containsKey(id)) {
      // LRU: Move to end
      final future = discussionsCache.remove(id)!;
      discussionsCache[id] = future;
      return future;
    }

    if (discussionsCache.length >= _maxCacheSize) {
      final keyToRemove = discussionsCache.keys.first;
      discussionsCache.remove(keyToRemove);
      _valueCache.remove(keyToRemove);
    }

    final future =
        (isEditableDraft ? api.getMyDraftDetail(id) : api.getDiscussion(id))
            .then((value) {
      _valueCache[id] = value;
      return value;
    });

    return discussionsCache[id] = future;
  }

  factory HDataModel.fromMap(
    Map<String, dynamic> json, {
    bool isEditableDraft = false,
  }) {
    // 优先取 documentId，其次是 id (转 String)，最后 fallback 到 number (转 String)
    final docId = json['documentId'] as String? ??
        json['id']?.toString() ??
        json['number']?.toString() ??
        '';
    final categoryRaw = json['category'];
    PostCategory? category;
    if (categoryRaw is Map) {
      final name = categoryRaw['name']?.toString() ?? '';
      final slug = categoryRaw['slug']?.toString() ?? '';
      if (name.isNotEmpty || slug.isNotEmpty) {
        category = PostCategory(name: name, slug: slug);
      }
    }

    final authorRaw = json['author'];
    final author = authorRaw is Map<String, dynamic>
        ? AuthorModel.fromJson(authorRaw)
        : null;

    final updatedAt =
        (json['updatedAt'] as String?).use((v) => DateTime.parse(v));
    final createdAt =
        (json['createdAt'] as String?).use((v) => DateTime.parse(v)) ??
            updatedAt;

    return HDataModel(
      id: docId,
      updatedAt: updatedAt,
      createdAt: createdAt,
      isPinned: false,
      isEditableDraft: isEditableDraft,
      hasPublishedVersion: json['hasPublishedVersion'] == true,
      isAnonymous: json['isAnonymous'] == true,
      liked: json['liked'] == true,
      favorited: json['favorited'] == true,
      likesCount: (json['likesCount'] ?? json['likescount']) is int
          ? (json['likesCount'] ?? json['likescount']) as int
          : int.tryParse(
                (json['likesCount'] ?? json['likescount'] ?? 0).toString(),
              ) ??
              0,
      commentsCount: (json['commentsCount'] ?? json['commentscount']) is int
          ? (json['commentsCount'] ?? json['commentscount']) as int
          : int.tryParse(
                (json['commentsCount'] ?? json['commentscount'] ?? 0)
                    .toString(),
              ) ??
              0,
      favoritesCount: (json['favoritesCount'] ?? json['favoritescount']) is int
          ? (json['favoritesCount'] ?? json['favoritescount']) as int
          : int.tryParse(
                (json['favoritesCount'] ?? json['favoritescount'] ?? 0)
                    .toString(),
              ) ??
              0,
      dennyCount: (json['dennyCount'] ?? json['dennycount']) is int
          ? (json['dennyCount'] ?? json['dennycount']) as int
          : int.tryParse(
                (json['dennyCount'] ?? json['dennycount'] ?? 0).toString(),
              ) ??
              0,
      hasGivenDenny: json['hasGivenDenny'] == true,
      isHidden: json['isHidden'] == true,
      title: json['title']?.toString(),
      views: (json['views'] as num?)?.toInt(),
      author: author,
      category: category,
    );
  }

  factory HDataModel.fromJson(
    Map<String, dynamic> json, {
    bool isEditableDraft = false,
  }) {
    final hData = HDataModel.fromMap(
      json,
      isEditableDraft: isEditableDraft,
    );
    final docId = hData.id;

    // Optimization: If json contains title, it might be a full object.
    // Try to parse it and seed the cache to avoid N+1 requests.
    if (json['title'] != null) {
      try {
        final discussion = DiscussionModel.fromJson(
          json,
          isEditableDraft: isEditableDraft,
        );
        discussionsCache[docId] = Future.value(discussion);
        _valueCache[docId] = discussion;
      } catch (e) {
        // parsing failed, ignore
      }
    }

    return hData;
  }

  factory HDataModel.fromPinnedJson(Map<String, dynamic> json) {
    final docId = json['documentId'] as String? ??
        json['id']?.toString() ??
        json['number']?.toString() ??
        '';

    final updatedAt =
        (json['updatedAt'] as String?).use((v) => DateTime.parse(v));
    final createdAt =
        (json['createdAt'] as String?).use((v) => DateTime.parse(v)) ??
            updatedAt;

    return HDataModel(
      id: docId,
      updatedAt: updatedAt,
      createdAt: createdAt,
      isPinned: true,
      hasPublishedVersion: json['hasPublishedVersion'] == true,
      isAnonymous: json['isAnonymous'] == true,
      liked: json['liked'] == true,
      favorited: json['favorited'] == true,
      likesCount: (json['likesCount'] ?? json['likescount']) is int
          ? (json['likesCount'] ?? json['likescount']) as int
          : int.tryParse(
                (json['likesCount'] ?? json['likescount'] ?? 0).toString(),
              ) ??
              0,
      commentsCount: (json['commentsCount'] ?? json['commentscount']) is int
          ? (json['commentsCount'] ?? json['commentscount']) as int
          : int.tryParse(
                (json['commentsCount'] ?? json['commentscount'] ?? 0)
                    .toString(),
              ) ??
              0,
      favoritesCount: (json['favoritesCount'] ?? json['favoritescount']) is int
          ? (json['favoritesCount'] ?? json['favoritescount']) as int
          : int.tryParse(
                (json['favoritesCount'] ?? json['favoritescount'] ?? 0)
                    .toString(),
              ) ??
              0,
      dennyCount: (json['dennyCount'] ?? json['dennycount']) is int
          ? (json['dennyCount'] ?? json['dennycount']) as int
          : int.tryParse(
                (json['dennyCount'] ?? json['dennycount'] ?? 0).toString(),
              ) ??
              0,
      hasGivenDenny: json['hasGivenDenny'] == true,
      isHidden: json['isHidden'] == true,
      title: json['title']?.toString(),
      views: (json['views'] as num?)?.toInt(),
      author: json['author'] is Map<String, dynamic>
          ? AuthorModel.fromJson(json['author'] as Map<String, dynamic>)
          : null,
      category: json['category'] is Map
          ? PostCategory(
              name: json['category']['name']?.toString() ?? '',
              slug: json['category']['slug']?.toString() ?? '',
            )
          : null,
    );
  }

  factory HDataModel.fromStr(String str) {
    final s = str.split(',');
    final updatedAt = DateTime.parse(s[1]);
    final createdAt = s.length > 2 ? DateTime.parse(s[2]) : updatedAt;
    return HDataModel(
      id: s[0],
      updatedAt: updatedAt,
      createdAt: createdAt,
      isPinned: false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'documentId': id,
      'updatedAt': updatedAt.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'isPinned': isPinned,
      'isEditableDraft': isEditableDraft,
      'hasPublishedVersion': hasPublishedVersion,
      'isAnonymous': isAnonymous,
      'liked': liked,
      'favorited': favorited,
      'likesCount': likesCount,
      'commentsCount': commentsCount,
      'favoritesCount': favoritesCount,
      'dennyCount': dennyCount,
      'hasGivenDenny': hasGivenDenny,
      'isHidden': isHidden,
      if (title != null) 'title': title,
      if (views != null) 'views': views,
      if (author != null) 'author': author!.toJson(),
      if (category != null)
        'category': {
          'name': category!.name,
          'slug': category!.slug,
        },
      // We might want to cache title/cover for offline display if available in valueCache
      if (_valueCache.containsKey(id)) ..._valueCache[id]!.toJson(),
    };
  }

  @override
  bool operator ==(Object other) => other is HDataModel && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
