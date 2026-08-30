import 'dart:async';

import 'package:aco_chat/features/account/data/account_api_client.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

typedef LiveRealtimeTicketLoader = Future<String> Function();
typedef LiveRealtimeEventHandler = void Function(Object? event);

/// Owns the auxiliary live-room WebSocket and its bounded reconnect policy.
class LiveRealtimeClient {
  LiveRealtimeClient({
    required this.onEvent,
    required this.onReconnectingChanged,
    required this.onReconnectStopped,
  });

  final LiveRealtimeEventHandler onEvent;
  final void Function(bool reconnecting) onReconnectingChanged;
  final void Function() onReconnectStopped;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnectTimer;
  int _reconnectAttempt = 0;
  bool _reconnectScheduled = false;
  bool _stopped = false;
  bool _disposed = false;

  Future<void> connect({
    required Uri uri,
    required LiveRealtimeTicketLoader ticketLoader,
  }) async {
    if (_disposed) return;
    try {
      final ticket = await ticketLoader();
      if (_disposed) return;
      final channel = WebSocketChannel.connect(
        uri.replace(queryParameters: {'ticket': ticket}),
      );
      await _subscription?.cancel();
      await _channel?.sink.close();
      _channel = channel;
      _subscription = channel.stream.listen(
        _handleIncomingEvent,
        onError: (_) =>
            _scheduleReconnect(uri: uri, ticketLoader: ticketLoader),
        onDone: () => _scheduleReconnect(uri: uri, ticketLoader: ticketLoader),
      );
      _reconnectTimer?.cancel();
      _reconnectScheduled = false;
      _reconnectAttempt = 0;
      _stopped = false;
      onReconnectingChanged(false);
    } on AccountApiException catch (error) {
      if (error.statusCode == 404 || error.statusCode == 409) {
        _reconnectTimer?.cancel();
        _reconnectScheduled = false;
        onReconnectingChanged(false);
        return;
      }
      _scheduleReconnect(uri: uri, ticketLoader: ticketLoader);
    } catch (_) {
      _scheduleReconnect(uri: uri, ticketLoader: ticketLoader);
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    _reconnectTimer?.cancel();
    _reconnectScheduled = false;
    await _subscription?.cancel();
    await _channel?.sink.close();
    _subscription = null;
    _channel = null;
  }

  void _scheduleReconnect({
    required Uri uri,
    required LiveRealtimeTicketLoader ticketLoader,
  }) {
    if (_disposed || _stopped || _reconnectScheduled) return;
    const retryDelays = [3, 6, 12, 30, 60];
    if (_reconnectAttempt >= retryDelays.length) {
      _stopped = true;
      onReconnectingChanged(false);
      onReconnectStopped();
      return;
    }
    _reconnectScheduled = true;
    _reconnectTimer?.cancel();
    onReconnectingChanged(true);
    final delay = Duration(seconds: retryDelays[_reconnectAttempt++]);
    _reconnectTimer = Timer(delay, () {
      _reconnectScheduled = false;
      unawaited(connect(uri: uri, ticketLoader: ticketLoader));
    });
  }

  void _handleIncomingEvent(dynamic event) => onEvent(event);
}
