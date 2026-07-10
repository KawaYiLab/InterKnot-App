class KnockSseEvent {
  final String type;
  final String? conversationId;
  final String? notificationId;
  final int? count;
  final DateTime? at;

  KnockSseEvent({
    required this.type,
    this.conversationId,
    this.notificationId,
    this.count,
    this.at,
  });

  factory KnockSseEvent.fromJson(Map<String, dynamic> json) {
    final atRaw = json['at'] as String?;
    return KnockSseEvent(
      type: json['type'] as String? ?? '',
      conversationId: json['conversationId'] as String?,
      notificationId: json['notificationId'] as String?,
      count: json['count'] as int?,
      at: atRaw != null ? DateTime.tryParse(atRaw) : null,
    );
  }
}
