/// 表情清单中的单个表情。
class EmoteModel {
  final String code;
  final String name;
  final String group;
  final String url;
  final int? width;
  final int? height;

  const EmoteModel({
    required this.code,
    required this.name,
    this.group = '通用',
    required this.url,
    this.width,
    this.height,
  });

  factory EmoteModel.fromJson(Map<String, dynamic> json) {
    return EmoteModel(
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      group: json['group']?.toString() ?? '通用',
      url: json['url']?.toString() ?? '',
      width: (json['width'] as num?)?.toInt(),
      height: (json['height'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'code': code,
        'name': name,
        'group': group,
        'url': url,
        'width': width,
        'height': height,
      };

  EmoteModel copyWith({
    String? code,
    String? name,
    String? group,
    String? url,
    int? width,
    int? height,
  }) {
    return EmoteModel(
      code: code ?? this.code,
      name: name ?? this.name,
      group: group ?? this.group,
      url: url ?? this.url,
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }
}

/// 表情分组。
class EmoteGroupModel {
  final String name;
  final int order;
  final String? iconUrl;

  const EmoteGroupModel({
    required this.name,
    this.order = 0,
    this.iconUrl,
  });

  factory EmoteGroupModel.fromJson(Map<String, dynamic> json) {
    return EmoteGroupModel(
      name: json['name']?.toString() ?? '通用',
      order: (json['order'] as num?)?.toInt() ?? 0,
      iconUrl: json['iconUrl']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'order': order,
        'iconUrl': iconUrl,
      };

  EmoteGroupModel copyWith({
    String? name,
    int? order,
    String? iconUrl,
  }) {
    return EmoteGroupModel(
      name: name ?? this.name,
      order: order ?? this.order,
      iconUrl: iconUrl ?? this.iconUrl,
    );
  }
}
