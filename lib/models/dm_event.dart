class DmEvent {
  final String type;
  final String? conversationId;
  final String? messageId;
  final Map<String, dynamic>? data;
  final DateTime? at;

  DmEvent({
    required this.type,
    this.conversationId,
    this.messageId,
    this.data,
    this.at,
  });

  factory DmEvent.fromJson(Map<String, dynamic> json) {
    final atRaw = json['at'] as String?;
    return DmEvent(
      type: json['type'] as String? ?? '',
      conversationId: json['conversationId'] as String?,
      messageId: json['messageId'] as String?,
      data: json['data'] is Map<String, dynamic> ? json['data'] as Map<String, dynamic> : null,
      at: atRaw != null ? DateTime.tryParse(atRaw) : null,
    );
  }

  T? dataValue<T>(String key) {
    final d = data;
    if (d == null) return null;
    final value = d[key];
    if (value is T) return value;
    return null;
  }
}
