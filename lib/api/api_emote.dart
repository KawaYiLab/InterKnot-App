part of 'api.dart';

/// 表情包接口（阶段 1 实现）。
/// 后端参考：ikserver src/api/emote、emote-group（manifest API）。
extension EmoteApi on Api {
  Future<({List<EmoteGroupModel> groups, List<EmoteModel> emotes})>
      getEmoteManifest() async {
    final res = await get(
      '/api/emotes/manifest',
      query: {'ts': DateTime.now().millisecondsSinceEpoch.toString()},
    );

    final data = unwrapData<Map<String, dynamic>>(res);
    final emotesRaw = data['emotes'];
    final groupsRaw = data['groups'];

    final emotes = <EmoteModel>[];
    if (emotesRaw is List) {
      for (final e in emotesRaw) {
        if (e is Map<String, dynamic>) {
          emotes.add(EmoteModel.fromJson(e));
        }
      }
    }

    final groups = <EmoteGroupModel>[];
    if (groupsRaw is List) {
      for (final g in groupsRaw) {
        if (g is Map<String, dynamic>) {
          groups.add(EmoteGroupModel.fromJson(g));
        }
      }
    }

    return (groups: groups, emotes: emotes);
  }
}
