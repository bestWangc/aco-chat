import 'package:aco_chat/core/config/app_config.dart';

String? meetingNumberFromLink(String location) {
  final uri = Uri.tryParse(location);
  if (uri == null ||
      (!uri.hasAuthority && (uri.hasScheme || !uri.path.startsWith('/'))) ||
      (uri.hasAuthority &&
          (uri.scheme != 'https' ||
              uri.host != Uri.parse(AppConfig.websiteUrl).host))) {
    return null;
  }
  final parts = uri.pathSegments;
  if (parts.length != 2 ||
      parts.first != 'meeting' ||
      !RegExp(r'^[1-9][0-9]*$').hasMatch(parts[1])) {
    return null;
  }
  return parts[1];
}
