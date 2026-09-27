import 'package:web_socket_channel/web_socket_channel.dart';

import 'live_realtime_connector_stub.dart'
    if (dart.library.io) 'live_realtime_connector_io.dart'
    as platform;

WebSocketChannel connectLiveRealtime(Uri uri) {
  return platform.connectLiveRealtime(uri);
}
