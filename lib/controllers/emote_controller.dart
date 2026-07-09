import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:inter_knot/api/api.dart';
import 'package:inter_knot/constants/api_config.dart';
import 'package:inter_knot/helpers/box.dart';
import 'package:inter_knot/models/emote.dart';

const _emoteManifestCacheKey = 'emote_manifest_v1';
const _emoteStaleTime = Duration(seconds: 60);

/// 负责表情清单（manifest）的拉取与缓存。
class EmoteController extends GetxController {
  final emotes = <EmoteModel>[].obs;
  final groups = <EmoteGroupModel>[].obs;
  final isLoading = false.obs;

  final _lastFetchedAt = Rxn<DateTime>();
  final Api _api = Get.find<Api>();

  Map<String, EmoteModel> get emoteMap {
    final map = <String, EmoteModel>{};
    for (final e in emotes) {
      if (e.code.isNotEmpty) {
        map[e.code] = e;
      }
    }
    return map;
  }

  bool get isStale {
    final last = _lastFetchedAt.value;
    if (last == null) return true;
    return DateTime.now().difference(last) > _emoteStaleTime;
  }

  Future<void> refreshIfStale() async {
    if (!isStale) return;
    await fetchManifest();
  }

  Future<void> fetchManifest({bool force = false}) async {
    if (isLoading.isTrue) return;
    if (!force && !isStale) return;

    isLoading(true);
    try {
      final result = await _api.getEmoteManifest();
      final normalizedEmotes = result.emotes.map((e) {
        final normalized = normalizeEmoteUrl(e.url);
        return normalized != null && normalized != e.url
            ? e.copyWith(url: normalized)
            : e;
      }).toList();
      final normalizedGroups = result.groups.map((g) {
        final normalized = normalizeEmoteUrl(g.iconUrl);
        return normalized != null && normalized != g.iconUrl
            ? g.copyWith(iconUrl: normalized)
            : g;
      }).toList();
      groups.assignAll(normalizedGroups);
      emotes.assignAll(normalizedEmotes);
      _lastFetchedAt.value = DateTime.now();
      update();
      await _persistCache();
    } catch (e) {
      debugPrint('Failed to fetch emote manifest: $e');
      await _loadCache();
    } finally {
      isLoading(false);
    }
  }

  /// 把相对路径补成完整 URL；绝对路径/CDN 原样返回。
  String? normalizeEmoteUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('http://') ||
        url.startsWith('https://') ||
        url.startsWith('//')) {
      return url;
    }
    final base = ApiConfig.baseUrl;
    if (url.startsWith('/')) return '$base$url';
    return '$base/$url';
  }

  Future<void> _persistCache() async {
    try {
      await box.write(
        _emoteManifestCacheKey,
        jsonEncode({
          'groups': groups.map((g) => g.toJson()).toList(),
          'emotes': emotes.map((e) => e.toJson()).toList(),
          'fetchedAt': _lastFetchedAt.value?.toIso8601String(),
        }),
      );
    } catch (e) {
      debugPrint('Failed to persist emote cache: $e');
    }
  }

  Future<void> _loadCache() async {
    try {
      final raw = box.read<String>(_emoteManifestCacheKey);
      if (raw == null || raw.isEmpty) return;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final groupsRaw = data['groups'];
      final emotesRaw = data['emotes'];
      if (groupsRaw is List) {
        groups.assignAll(
          groupsRaw
              .whereType<Map<String, dynamic>>()
              .map(EmoteGroupModel.fromJson)
              .map((g) {
                final normalized = normalizeEmoteUrl(g.iconUrl);
                return normalized != null && normalized != g.iconUrl
                    ? g.copyWith(iconUrl: normalized)
                    : g;
              })
              .toList(),
        );
      }
      if (emotesRaw is List) {
        emotes.assignAll(
          emotesRaw
              .whereType<Map<String, dynamic>>()
              .map(EmoteModel.fromJson)
              .map((e) {
                final normalized = normalizeEmoteUrl(e.url);
                return normalized != null && normalized != e.url
                    ? e.copyWith(url: normalized)
                    : e;
              })
              .toList(),
        );
      }
      if (emotes.isNotEmpty || groups.isNotEmpty) {
        update();
      }
      final fetchedAt = data['fetchedAt'];
      if (fetchedAt is String) {
        _lastFetchedAt.value = DateTime.tryParse(fetchedAt);
      }
    } catch (e) {
      debugPrint('Failed to load emote cache: $e');
      await box.remove(_emoteManifestCacheKey);
    }
  }

  @override
  Future<void> onInit() async {
    super.onInit();
    await _loadCache();
    if (emotes.isEmpty || isStale) {
      unawaited(fetchManifest());
    }
  }
}
