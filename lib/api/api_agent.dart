part of 'api.dart';

/// AI 角色（Agent）接口（阶段 2 实现）。
/// 后端参考：ikserver src/api/agent/controllers/agent.ts
extension AgentApi on Api {
  /// 获取可对话的 AI 角色列表
  Future<List<AiRoleCard>> getAgentCharacters() async {
    final res = await getWithRetry('/api/agent/characters');
    final body = res.body;
    if (body is! Map<String, dynamic>) return [];
    final data = body['data'];
    if (data is! List) return [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(AiRoleCard.fromJson)
        .toList();
  }
}
