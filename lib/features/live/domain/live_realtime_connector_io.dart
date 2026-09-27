import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

WebSocketChannel connectLiveRealtime(Uri uri) {
  // dart:io sends protocol Ping frames and closes the socket if Pong is not
  // received within the interval.
  return IOWebSocketChannel.connect(
    uri,
    pingInterval: const Duration(seconds: 30),
  );
}
