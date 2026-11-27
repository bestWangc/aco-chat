import 'package:aco_chat/core/config/app_config.dart';

String? meetingNumberFromLink(String location) {
  final uri = Uri.tryParse(location);
  if (uri == null) return null;
  final parts = switch (uri.scheme) {
    'aco-chat' when uri.host == 'meeting' => uri.pathSegments,
    '' when !uri.hasAuthority && uri.path.startsWith('/') => uri.pathSegments,
    'https' when uri.host == Uri.parse(AppConfig.websiteUrl).host =>
      uri.pathSegments,
    _ => const <String>[],
  };
  final validParts = uri.scheme == 'aco-chat'
      ? parts.length == 1
      : parts.length == 2 && parts.first == 'meeting';
  if (!validParts || !RegExp(r'^[1-9][0-9]*$').hasMatch(parts.last)) {
    return null;
  }
  return uri.scheme == 'aco-chat' ? parts.first : parts.last;
}
