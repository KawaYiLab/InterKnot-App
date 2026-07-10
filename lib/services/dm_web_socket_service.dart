import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:inter_knot/api/api.dart';
import 'package:inter_knot/constants/api_config.dart';
import 'package:inter_knot/helpers/box.dart';
import 'package:inter_knot/models/dm_event.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// DM WebSocket 连接管理。
/// 协议参考 InterKnot-Web app/composables/useDmStream.ts
class DmWebSocketService {
  DmWebSocketService({required this.api});

  final Api api;

  WebSocketChannel? _channel;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  bool _stopping = false;
  bool _connecting = false;

  int _attempts = 0;
  static const _maxAttempts = 6;
  static const _maxDelaySeconds = 32;

  final _eventController = StreamController<DmEvent>.broadcast();
  Stream<DmEvent> get eventStream => _eventController.stream;

  /// 启动 WebSocket：重置停止标志与重试计数，然后尝试连接。
  void start() {
    _stopping = false;
    _attempts = 0;
    connect();
  }

  Future<void> connect() async {
    if (_stopping || _connecting) return;
    if (_channel != null) return;
    _connecting = true;

    try {
      final token = box.read<String>('access_token');
      if (token == null || token.isEmpty) {
        scheduleReconnect();
        return;
      }

      try {
        final ticketRes = await api.getDmSocketTicket();
        final url = _buildWsUrl(api, ticketRes.ticket);

        _channel = IOWebSocketChannel.connect(
          Uri.parse(url),
          pingInterval: const Duration(seconds: 20),
        );

        _channel!.stream.listen(
          _onMessage,
          onError: (Object e) {
            _disposeChannel();
            scheduleReconnect();
          },
          onDone: () {
            _disposeChannel();
            scheduleReconnect();
          },
        );

        _startPingTimer();
        _attempts = 0;
      } catch (e) {
        _disposeChannel();
        scheduleReconnect();
      }
    } finally {
      _connecting = false;
    }
  }

  String _buildWsUrl(Api api, String ticket) {
    final base = ApiConfig.baseUrl;
    final trimmed = base.replaceAll(RegExp(r'/+$'), '');
    final origin = trimmed.startsWith('https://')
        ? 'wss://${trimmed.substring(8)}'
        : trimmed.startsWith('http://')
            ? 'ws://${trimmed.substring(7)}'
            : trimmed;
    return '$origin/dm/socket?ticket=${Uri.encodeComponent(ticket)}';
  }

  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (_channel != null) {
        try {
          _channel!.sink.add(jsonEncode({'type': 'ping'}));
        } catch (_) {
          _disposeChannel();
          scheduleReconnect();
        }
      }
    });
  }

  void _onMessage(dynamic message) {
    if (message is! String) return;
    try {
      final decoded = jsonDecode(message);
      if (decoded is! Map<String, dynamic>) return;
      final event = DmEvent.fromJson(decoded);
      if (event.type == 'pong') return;
      _eventController.add(event);
    } catch (_) {}
  }

  void scheduleReconnect() {
    _disposeChannel();
    if (_stopping) return;
    if (_attempts >= _maxAttempts) {
      // 停止重连，等待下次主动触发
      return;
    }
    _attempts++;
    final delaySeconds = math.min(math.pow(2, _attempts).toInt(), _maxDelaySeconds);
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      connect();
    });
  }

  void sendTyping(String conversationId) {
    if (_channel == null) return;
    try {
      _channel!.sink.add(jsonEncode({
        'type': 'typing',
        'conversationId': conversationId,
      }));
    } catch (_) {}
  }

  void stop() {
    _stopping = true;
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    _disposeChannel();
  }

  void _disposeChannel() {
    _channel?.sink.close();
    _channel = null;
    _pingTimer?.cancel();
    _pingTimer = null;
  }
}
