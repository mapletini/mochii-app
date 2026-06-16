import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../state/collar_state_notifier.dart';

class CollarService {
  CollarService(this._ref);

  final Ref _ref;
  final StreamController<Map<String, dynamic>> _eventController =
      StreamController<Map<String, dynamic>>.broadcast();
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _heartbeatTimer;

  static const Duration _heartbeatInterval = Duration(seconds: 30);
  static const Uuid _uuid = Uuid();

  bool get isConnected => _channel != null;
  Stream<Map<String, dynamic>> get events => _eventController.stream;

  Future<void> connect({
    required String serverUrl,
    required String deviceId,
  }) async {
    await disconnect();

    final Uri uri = _buildSocketUri(serverUrl: serverUrl, deviceId: deviceId);
    _channel = WebSocketChannel.connect(uri);

    _subscription = _channel!.stream.listen(
      _onMessage,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('WebSocket error: $error');
      },
      onDone: () {
        _stopHeartbeat();
      },
    );

    _startHeartbeat();
  }

  Uri _buildSocketUri({required String serverUrl, required String deviceId}) {
    final Uri parsed = Uri.parse(serverUrl);
    if (parsed.hasScheme) {
      final String socketScheme = parsed.scheme == 'https' ? 'wss' : 'ws';
      return parsed.replace(scheme: socketScheme, path: '/ws/puppy/$deviceId');
    }

    return Uri.parse('ws://$serverUrl/ws/puppy/$deviceId');
  }

  void _onMessage(dynamic rawMessage) {
    try {
      final Map<String, dynamic> payload =
          jsonDecode(rawMessage as String) as Map<String, dynamic>;

      _eventController.add(payload);

      _ref.read(collarStateProvider.notifier).updateFromPayload(payload);

      final String? action = payload['action'] as String?;
      if (action != null) {
        debugPrint('Received collar action: $action');
      }
    } catch (error) {
      debugPrint('Failed to parse WebSocket payload: $error');
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      sendJson(<String, dynamic>{
        'type': 'heartbeat',
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      });
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  void sendJson(Map<String, dynamic> body) {
    final WebSocketChannel? activeChannel = _channel;
    if (activeChannel == null) {
      return;
    }

    activeChannel.sink.add(jsonEncode(body));
  }

  String sendCommand({
    required String action,
    required String targetDeviceId,
    String? message,
  }) {
    final String requestId = _uuid.v4();

    sendJson(<String, dynamic>{
      'type': 'command',
      'action': action,
      'target_device_id': targetDeviceId,
      'message': message,
      'request_id': requestId,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    });

    return requestId;
  }

  Future<void> disconnect() async {
    _stopHeartbeat();
    await _subscription?.cancel();
    await _channel?.sink.close();
    _subscription = null;
    _channel = null;
  }

  Future<void> dispose() async {
    await disconnect();
    await _eventController.close();
  }
}

final collarServiceProvider = Provider<CollarService>((ref) {
  final CollarService service = CollarService(ref);
  ref.onDispose(service.dispose);
  return service;
});
