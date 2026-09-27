import 'package:web_socket_channel/web_socket_channel.dart';

WebSocketChannel connectLiveRealtime(Uri uri) {
  // Browsers do not expose protocol Ping; the server-side Ping keeps web
  // clients alive and the browser handles Pong automatically.
  return WebSocketChannel.connect(uri);
}
