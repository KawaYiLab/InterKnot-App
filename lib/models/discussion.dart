import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:html/parser.dart' show parseFragment;
import 'package:inter_knot/api/api.dart';
import 'package:inter_knot/constants/api_config.dart';
import 'package:inter_knot/helpers/normalize_markdown.dart';
import 'package:inter_knot/helpers/parse_html.dart';
import 'package:inter_knot/helpers/use.dart';
import 'package:inter_knot/models/author.dart';
import 'package:inter_knot/models/comment.dart';
import 'package:inter_knot/models/pagination.dart';
import 'package:markdown/markdown.dart' as md;

class CoverImage {
  final String? id;
  final String url;
  final int? width;
  final int? height;

  CoverImage({
    this.id,
    required this.url,
    this.width,
    this.height,
  });
}

class PostCategory {
  final String name;
  final String slug;

  const PostCategory({
    required this.name,
    required this.slug,
  });
}

DiscussionModel parseDiscussionData(
  Map<String, dynamic> json, {
  bool isEditableDraft = false,
}) {
  final textVal = json['text'];
  String rawBody = textVal is String ? textVal : '';

  if (json['blocks'] != null) {
    final blocks = json['blocks'] as List<dynamic>;
    for (final block in blocks) {
      if (block is! Map<String, dynamic>) continue;
      final type = block['__typename'] as String?;
      // ComponentSharedRichText -> body
      if (type == 'ComponentSharedRichText' && block['body'] != null) {
        rawBody += '\n\n${block['body'] as String}';
      }
      // ComponentSharedQuote -> body
      else if (type == 'ComponentSharedQuote' && block['body'] != null) {
        rawBody += '\n\n> ${block['body'] as String}';
      }
    }
  }

  final normalized = normalizeMarkdown(rawBody);

  // Convert Markdown to HTML
  final htmlBody = md.markdownToHtml(
    normalized,
    extensionSet: md.ExtensionSet.gitHubWeb,
  );

  final (:cover, :html) = parseHtml(htmlBody);
  final List<CoverImage> parsedCovers = [];
  int? parsedCoverWidth;
  int? parsedCoverHeight;

  PostCategory? parseCategory(dynamic raw) {
    if (raw is! Map) return null;
    final name = raw['name']?.toString() ?? '';
    final slug = raw['slug']?.toString() ?? '';
    if (name.isEmpty && slug.isEmpty) return null;
    return PostCategory(name: name, slug: slug);
  }

  CoverImage? normalizeCover(
    String? url,
    int? width,
    int? height, {
    String? id,
  }) {
    if (url == null || url.isEmpty) return null;
    String finalUrl = url;
    if (url.startsWith('http://') || url.startsWith('https://')) {
      finalUrl = url;
    } else if (url.startsWith('/')) {
      finalUrl = '${ApiConfig.baseUrl}$url';
    } else {
      finalUrl = '${ApiConfig.baseUrl}/$url';
    }
    return CoverImage(
      id: id,
      url: finalUrl,
      width: width,
      height: height,
    );
  }

  int? parseDimension(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  final coverData = json['cover'];
  if (coverData is List) {
    for (final item in coverData) {
      if (item is Map<String, dynamic> && item['url'] != null) {
        final width = parseDimension(item['width']);
        final height = parseDimension(item['height']);
        final cover = normalizeCover(
          item['url'] as String?,
          width,
          height,
          id: item['documentId']?.toString() ?? item['id']?.toString(),
        );
        if (cover != null) parsedCovers.add(cover);
      }
    }
  } else if (coverData is Map<String, dynamic> && coverData['url'] != null) {
    final width = parseDimension(coverData['width']);
    final height = parseDimension(coverData['height']);
    final cover = normalizeCover(
      coverData['url'] as String?,
      width,
      height,
      id: coverData['documentId']?.toString() ?? coverData['id']?.toString(),
    );
    if (cover != null) parsedCovers.add(cover);
  } else if (coverData is String && coverData.isNotEmpty) {
    final width = parseDimension(json['coverWidth']);
    final height = parseDimension(json['coverHeight']);
    parsedCoverWidth = width;
    parsedCoverHeight = height;
    final cover = normalizeCover(
      coverData,
      width,
      height,
    );
    if (cover != null) parsedCovers.add(cover);
  }

  final List<CoverImage> covers = [];

  if (parsedCovers.isNotEmpty) {
    covers.addAll(parsedCovers);
  } else {
    final fragment = parseFragment(htmlBody);
    final firstImg = fragment.querySelector('img');
    final src = firstImg?.attributes['src'];
    // Try to parse width/height from img attributes if available (often not reliable in HTML strings but worth a try)
    final width = int.tryParse(firstImg?.attributes['width'] ?? '');
    final height = int.tryParse(firstImg?.attributes['height'] ?? '');

    final firstCover = normalizeCover(src ?? cover, width, height);
    if (firstCover != null) covers.add(firstCover);
  }

  final firstParsedCover = covers.isNotEmpty ? covers.first : null;
  final coverWidth =
      parsedCoverWidth ?? firstParsedCover?.width ?? parseDimension(json['coverWidth']);
  final coverHeight = parsedCoverHeight ??
      firstParsedCover?.height ??
      parseDimension(json['coverHeight']);

  final commentsJson = json['comments'] as Map<String, dynamic>?;
  final hasPublishedVersion = json['hasPublishedVersion'] == true;

  final authorData = json['author'];
  final author = authorData is Map<String, dynamic>
      ? AuthorModel.fromJson(authorData)
      : AuthorModel(
          login: 'unknown',
          avatar: '',
          name: 'Unknown',
        );
  final category = parseCategory(json['category']);

  // Pre-calculate bodyText here to avoid regex overhead during rendering
  var bodyText =
      normalized.replaceAll(RegExp(r'!\[.*?\]\(.*?\)', dotAll: true), '');
  bodyText = bodyText.replaceAll(
      RegExp('<img[^>]*>', caseSensitive: false, dotAll: true), '');
  bodyText = bodyText.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  // Limit body text length to avoid huge strings in memory if not needed full
  if (bodyText.length > 500) {
    bodyText = bodyText.substring(0, 500);
  }

  return DiscussionModel(
    title: json['title'] is String
        ? json['title'] as String
        : (json['title']?.toString() ?? ''),
    bodyHTML: html,
    bodyText: bodyText,
    coverImages: covers,
    rawBodyText: normalized,
    editorState: json['editorState'] is List
        ? List<dynamic>.from(json['editorState'] as List)
        : null,
    // number: ... Removed
    id: json['documentId'] as String? ??
        json['id']?.toString() ??
        '', // 优先 documentId
    createdAt: json['createdAt'] is String
        ? DateTime.parse(json['createdAt'] as String)
        : DateTime.now(),
    commentsCount: (json['commentsCount'] ?? json['commentscount']) is int
        ? (json['commentsCount'] ?? json['commentscount']) as int
        : int.tryParse(
              (json['commentsCount'] ?? json['commentscount']).toString(),
            ) ??
            0,
    lastEditedAt:
        (json['updatedAt'] is String ? json['updatedAt'] as String : null)
            .use((v) => DateTime.parse(v)),
    author: author,
    likesCount: (json['likescount'] ?? json['likesCount']) is int
        ? (json['likescount'] ?? json['likesCount']) as int
        : int.tryParse(
              (json['likescount'] ?? json['likesCount'] ?? 0).toString(),
            ) ??
            0,
    liked: json['liked'] == true,
    favorited: json['favorited'] == true,
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
    isRead: json['isRead'] == true,
    isPinned: json['isPinned'] == true,
    isAnonymous: json['isAnonymous'] == true,
    category: category,
    isEditableDraft: isEditableDraft,
    hasPublishedVersion: hasPublishedVersion,
    coverWidth: coverWidth,
    coverHeight: coverHeight,
    comments: commentsJson != null
        ? [
            PaginationModel.fromJson(
              commentsJson,
              CommentModel.fromJson,
            ),
          ]
        : [],
    views: json['views'] is int ? json['views'] as int : 0,
    databaseId: json['id'] is int
        ? json['id'] as int
        : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
  );
}

class DiscussionModel {
  String title;
  bool isRead;
  bool isPinned;
  int views;
  int databaseId;
  String bodyHTML;
  String rawBodyText;
  List<dynamic>? editorState;
  String bodyText; // Cached body text
  List<CoverImage> coverImages;
  int? coverWidth;
  int? coverHeight;
  List<String> get covers => coverImages.map((e) => e.url).toList();
  String? get cover => covers.isNotEmpty ? covers.first : null;
  String id;
  // int number; // Removed, merged into id
  DateTime createdAt;
  DateTime? lastEditedAt;
  int commentsCount;
  int likesCount;
  bool liked;
  bool isEditableDraft;
  bool hasPublishedVersion;
  bool isAnonymous;
  bool favorited;
  int favoritesCount;
  int dennyCount;
  bool hasGivenDenny;
  bool isHidden;
  PostCategory? category;
  AuthorModel author;
  List<PaginationModel<CommentModel>> comments;

  String get url => ''; // Placeholder

  Api? _api;
  Api get api => _api ??= Get.find<Api>();

  bool hasNextPage() {
    if (comments.isEmpty) return true;

    return comments.last.hasNextPage;
  }

  bool _isLoadingComments = false;

  bool _hasMeaningfulAuthorName(String value) {
    final normalized = value.trim();
    return normalized.isNotEmpty && normalized != 'Unknown';
  }

  bool _hasMeaningfulAuthorLogin(String value) {
    final normalized = value.trim();
    return normalized.isNotEmpty && normalized != 'unknown';
  }

  void updateFrom(DiscussionModel other) {
    title = other.title;
    bodyHTML = other.bodyHTML;
    rawBodyText = other.rawBodyText;
    editorState = other.editorState == null
        ? null
        : List<dynamic>.from(other.editorState!);
    bodyText = other.bodyText;
    coverImages = other.coverImages;
    createdAt = other.createdAt;
    lastEditedAt = other.lastEditedAt;
    author
      ..name = _hasMeaningfulAuthorName(other.author.name)
          ? other.author.name
          : author.name
      ..login = _hasMeaningfulAuthorLogin(other.author.login)
          ? other.author.login
          : author.login
      ..avatar =
          other.author.avatar.isNotEmpty ? other.author.avatar : author.avatar
      ..email = other.author.email ?? author.email
      ..userId = other.author.userId ?? author.userId
      ..authorId = (other.author.authorId?.isNotEmpty ?? false)
          ? other.author.authorId
          : author.authorId
      ..createdAt = other.author.createdAt ?? author.createdAt
      ..exp = other.author.exp ?? author.exp
      ..level = other.author.level ?? author.level
      ..lastCheckInDate = other.author.lastCheckInDate ?? author.lastCheckInDate
      ..consecutiveCheckInDays =
          other.author.consecutiveCheckInDays ?? author.consecutiveCheckInDays
      ..canCheckIn = other.author.canCheckIn;
    likesCount = other.likesCount;
    commentsCount = other.commentsCount;
    views = other.views;
    liked = other.liked;
    isEditableDraft = other.isEditableDraft;
    hasPublishedVersion = other.hasPublishedVersion;
    isAnonymous = other.isAnonymous;
    favorited = other.favorited;
    favoritesCount = other.favoritesCount;
    dennyCount = other.dennyCount;
    hasGivenDenny = other.hasGivenDenny;
    isHidden = other.isHidden;
    category = other.category;
    coverWidth = other.coverWidth;
    coverHeight = other.coverHeight;
    // updated fields from detail api
  }

  Future<void> fetchComments() async {
    if (_isLoadingComments) return;
    if (comments.isNotEmpty && !comments.last.hasNextPage) return;

    _isLoadingComments = true;
    final lastPage = comments.isEmpty ? null : comments.last;
    final endCur = lastPage?.endCursor ?? '0';

    try {
      final pagination = await api.getComments(id, endCur);

      if (comments.isEmpty) {
        comments = [pagination];
      } else {
        // Filter out duplicates based on id
        final existingIds = comments.last.nodes.map((e) => e.id).toSet();
        final newNodes =
            pagination.nodes.where((e) => !existingIds.contains(e.id)).toList();

        comments.last.nodes.addAll(newNodes);
        comments.last.hasNextPage = pagination.hasNextPage;
        comments.last.endCursor = pagination.endCursor;
      }
    } catch (e) {
      debugPrint('Failed to fetch comments: $e');
      rethrow;
    } finally {
      _isLoadingComments = false;
    }
  }

  DiscussionModel({
    required this.title,
    required this.bodyHTML,
    required this.bodyText,
    required this.rawBodyText,
    this.editorState,
    required this.coverImages,
    // required this.number, // Removed
    required this.id,
    required this.createdAt,
    required this.commentsCount,
    this.likesCount = 0,
    this.liked = false,
    this.isEditableDraft = false,
    this.hasPublishedVersion = false,
    this.isAnonymous = false,
    this.favorited = false,
    this.favoritesCount = 0,
    this.dennyCount = 0,
    this.hasGivenDenny = false,
    this.isHidden = false,
    this.category,
    this.coverWidth,
    this.coverHeight,
    required this.lastEditedAt,
    required this.author,
    this.isRead = false,
    this.isPinned = false,
    required this.comments,
    this.views = 0,
    required this.databaseId,
  });

  factory DiscussionModel.fromJson(
    Map<String, dynamic> json, {
    bool isEditableDraft = false,
  }) =>
      parseDiscussionData(
        json,
        isEditableDraft: isEditableDraft,
      );

  @override
  bool operator ==(Object other) => other is DiscussionModel && other.id == id;

  @override
  int get hashCode => id.hashCode;

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'isRead': isRead,
      'isPinned': isPinned,
      'views': views,
      'id': databaseId,
      'bodyHTML': bodyHTML,
      'rawBodyText': rawBodyText, // Store raw text for reconstruction
      'editorState': editorState,
      'text': rawBodyText, // Compatible with parseDiscussionData
      'cover': coverImages
          .map((e) => {
                if (e.id != null) 'documentId': e.id,
                'url': e.url,
                'width': e.width,
                'height': e.height,
              })
          .toList(),
      'documentId': id,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': lastEditedAt?.toIso8601String(),
      if (coverWidth != null) 'coverWidth': coverWidth,
      if (coverHeight != null) 'coverHeight': coverHeight,
      'commentsCount': commentsCount,
      'likesCount': likesCount,
      'likescount': likesCount,
      'liked': liked,
      'favorited': favorited,
      'favoritesCount': favoritesCount,
      'dennyCount': dennyCount,
      'hasGivenDenny': hasGivenDenny,
      'isHidden': isHidden,
      'hasPublishedVersion': hasPublishedVersion,
      'isAnonymous': isAnonymous,
      if (category != null)
        'category': {
          'name': category!.name,
          'slug': category!.slug,
        },
      'isEditableDraft': isEditableDraft,
      'author': author.toJson(),
    };
  }
}
