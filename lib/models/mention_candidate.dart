/// @提及选人搜索结果。
class MentionCandidateModel {
  final String documentId;
  final String name;
  final String? username;
  final int? level;
  final String? avatar;

  MentionCandidateModel({
    required this.documentId,
    required this.name,
    this.username,
    this.level,
    this.avatar,
  });

  factory MentionCandidateModel.fromJson(Map<String, dynamic> json) {
    return MentionCandidateModel(
      documentId: json['documentId']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      username: json['username']?.toString(),
      level: (json['level'] as num?)?.toInt(),
      avatar: json['avatar']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'documentId': documentId,
        'name': name,
        'username': username,
        'level': level,
        'avatar': avatar,
      };
}
