/// 频道/分区模型，对应后端 /api/categories/list 的精简结构。
class CategoryModel {
  final String documentId;
  final String name;
  final String slug;
  final int order;

  /// 仅管理员可在此分区发帖（如公告、更新日志）。
  final bool adminOnly;

  const CategoryModel({
    required this.documentId,
    required this.name,
    required this.slug,
    this.order = 0,
    this.adminOnly = false,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      documentId: json['documentId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      order: json['order'] is int
          ? json['order'] as int
          : int.tryParse(json['order']?.toString() ?? '') ?? 0,
      adminOnly: json['adminOnly'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'documentId': documentId,
        'name': name,
        'slug': slug,
        'order': order,
        'adminOnly': adminOnly,
      };
}
