import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/constants/api_constants.dart';

/// Hand-rolled minimal client for the subset of the Pusher wire protocol
/// Reverb speaks - connect, subscribe to a private channel (with a
/// Bearer-token-authenticated /broadcasting/auth handshake), listen for
/// one named event per channel, and send client (`client-*`) events for
/// typing indicators. No presence channels, no encrypted channels, no
/// exponential-backoff reconnect - "thin" push/realtime scope, not a
/// general-purpose Pusher client.
///
/// Reuses the app's existing [Dio] instance for the auth handshake, so
/// the Bearer token attachment already handled by `AuthInterceptor` for
/// every other API call applies here too, for free.
class ReverbSocketService {
  ReverbSocketService(this._dio);

  final Dio _dio;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  String? _socketId;
  bool _disposed = false;

  final Set<String> _subscribedChannels = {};
  final Map<String, void Function(dynamic data)> _eventHandlers = {};

  Future<void> connect() async {
    final scheme = ApiConstants.reverbUseTls ? 'wss' : 'ws';
    final uri = Uri(
      scheme: scheme,
      host: ApiConstants.reverbHost,
      port: ApiConstants.reverbPort,
      path: '/app/${ApiConstants.reverbAppKey}',
      queryParameters: const {
        'protocol': '7',
        'client': 'lainted-mobile',
        'version': '1.0',
        'flash': 'false',
      },
    );

    _channel = WebSocketChannel.connect(uri);
    _subscription = _channel!.stream.listen(
      _handleMessage,
      onDone: _handleDisconnect,
      onError: (_) => _handleDisconnect(),
      cancelOnError: true,
    );
  }

  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    _channel?.sink.close();
  }

  /// Registers interest in [eventName] on [channelName] - subscribes to
  /// the channel (if not already) and authorizes it via
  /// /broadcasting/auth. Only one handler per (channel, event) pair.
  Future<void> listen({
    required String channelName,
    required String eventName,
    required void Function(dynamic data) onEvent,
  }) async {
    _eventHandlers['$channelName:$eventName'] = onEvent;

    if (_subscribedChannels.contains(channelName)) return;
    _subscribedChannels.add(channelName);

    if (_socketId != null) {
      await _sendSubscribe(channelName);
    }
    // else: connection isn't established yet - _handleMessage resubscribes
    // every pending channel once `pusher:connection_established` arrives.
  }

  void unsubscribe(String channelName) {
    _subscribedChannels.remove(channelName);
    _eventHandlers.removeWhere((key, _) => key.startsWith('$channelName:'));
    _send({
      'event': 'pusher:unsubscribe',
      'data': {'channel': channelName},
    });
  }

  /// Ephemeral typing-indicator style signal - no persistence, only valid
  /// on a private/presence channel the client is already subscribed to.
  void whisper(String channelName, String eventName, Map<String, dynamic> data) {
    _send({
      'event': 'client-$eventName',
      'channel': channelName,
      'data': data,
    });
  }

  Future<void> _sendSubscribe(String channelName) async {
    final auth = await _authorize(channelName);
    _send({
      'event': 'pusher:subscribe',
      'data': {'channel': channelName, 'auth': auth},
    });
  }

  Future<String> _authorize(String channelName) async {
    final response = await _dio.post(
      ApiConstants.broadcastingAuthUrl,
      data: {'socket_id': _socketId, 'channel_name': channelName},
    );

    return (response.data as Map)['auth'] as String;
  }

  void _handleMessage(dynamic raw) {
    final message = jsonDecode(raw as String) as Map<String, dynamic>;
    final event = message['event'] as String?;
    final channel = message['channel'] as String?;
    final rawData = message['data'];
    final data = rawData is String && rawData.isNotEmpty
        ? jsonDecode(rawData)
        : rawData;

    switch (event) {
      case 'pusher:connection_established':
        _socketId = (data as Map)['socket_id'] as String;
        for (final pending in _subscribedChannels) {
          _sendSubscribe(pending);
        }
      case 'pusher:ping':
        _send({'event': 'pusher:pong', 'data': <String, dynamic>{}});
      case 'pusher:error':
        break;
      default:
        if (channel != null && event != null) {
          _eventHandlers['$channel:$event']?.call(data);
        }
    }
  }

  void _handleDisconnect() {
    _socketId = null;
    if (_disposed) return;

    // Simple fixed-delay reconnect - no exponential backoff, matching
    // this feature's deliberately thin scope. Re-subscribing to every
    // previously-registered channel happens automatically once
    // connection_established fires again.
    Future.delayed(const Duration(seconds: 3), () {
      if (!_disposed) connect();
    });
  }

  void _send(Map<String, dynamic> payload) {
    _channel?.sink.add(jsonEncode(payload));
  }
}
