import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:inter_knot/constants/api_config.dart';
import 'package:inter_knot/helpers/box.dart';
import 'package:inter_knot/models/knock_sse_event.dart';

/// 敲敲 SSE 连接：保持前台连通，退后台断开，回前台重连+全量刷新。
class KnockSseService {
  http.Client? _client;
  StreamSubscription<String>? _subscription;
  bool _active = false;

  final _eventController = StreamController<KnockSseEvent>.broadcast();
  Stream<KnockSseEvent> get eventStream => _eventController.stream;

  /// 启动 SSE（若已存在则先关闭）
  void start() {
    _disconnect();
    _active = true;
    _connect();
  }

  void stop() {
    _active = false;
    _disconnect();
  }

  /// 关闭当前连接但不重置 _active 状态，便于重连逻辑复用
  void _disconnect() {
    _subscription?.cancel();
    _subscription = null;
    _client?.close();
    _client = null;
  }

  Future<void> _connect() async {
    if (!_active) return;
    final token = box.read<String>('access_token');
    if (token == null || token.isEmpty) {
      // 未登录时延迟后重试
      await Future.delayed(const Duration(seconds: 5));
      if (!_active) return;
      _connect();
      return;
    }

    final base = ApiConfig.baseUrl.replaceAll(RegExp(r'/+$'), '');
    final url = '$base/api/knock/stream?token=${Uri.encodeComponent(token)}';

    _client = http.Client();
    final request = http.Request('GET', Uri.parse(url));
    request.headers['Accept'] = 'text/event-stream';
    request.headers['Cache-Control'] = 'no-cache';

    try {
      final streamedResponse = await _client!.send(request);
      if (streamedResponse.statusCode != 200) {
        throw HttpException('SSE ${streamedResponse.statusCode}');
      }

      final lineStream = streamedResponse.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      final buffer = <String>[];
      _subscription = lineStream.listen(
        (line) {
          if (line.isEmpty) {
            _flushEvent(buffer);
            buffer.clear();
          } else if (line.startsWith('data:')) {
            final value = line.length > 5 ? line.substring(5).trimLeft() : '';
            buffer.add(value);
          } else if (line.startsWith('event:')) {
            // 缓存 event 字段，可通过需要扩展
            final value = line.length > 6 ? line.substring(6).trim() : '';
            if (value.isNotEmpty) buffer.add('__event:$value');
          }
        },
        onError: (_) => _scheduleReconnect(),
        onDone: () => _scheduleReconnect(),
        cancelOnError: true,
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _flushEvent(List<String> buffer) {
    if (buffer.isEmpty) return;
    final dataLines = <String>[];
    for (final line in buffer) {
      if (line.startsWith('__event:')) {
        // SSE event name is embedded in decoded payload; no need to store it
      } else {
        dataLines.add(line);
      }
    }
    final raw = dataLines.join('\n');
    if (raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return;
      final event = KnockSseEvent.fromJson(decoded);
      _eventController.add(event);
    } catch (_) {}
  }

  void _scheduleReconnect() {
    _disconnect();
    if (!_active) return;
    Future.delayed(const Duration(seconds: 5), () {
      if (_active) start();
    });
  }
}
