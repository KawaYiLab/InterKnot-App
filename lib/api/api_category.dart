part of 'api.dart';

extension CategoryApi on Api {
  /// 拉取所有「已上架」频道（公开只读），按 order 升序。
  /// 后端 /api/categories/list 返回 { data: [{ documentId, name, slug, order, adminOnly }] }。
  Future<List<CategoryModel>> getCategories() async {
    final res = await get('/api/categories/list');
    if (res.hasError) {
      debugPrint('GetCategories Error: ${res.statusCode} - ${res.bodyString}');
      return const <CategoryModel>[];
    }

    try {
      final list = unwrapData<List<dynamic>>(res);
      return list
          .whereType<Map>()
          .map((e) => CategoryModel.fromJson(Map<String, dynamic>.from(e)))
          .where((c) => c.slug.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('GetCategories Parse Error: $e');
      return const <CategoryModel>[];
    }
  }
}
