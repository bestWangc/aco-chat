import 'package:aco_chat/features/live/domain/meeting_link.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepts only meeting links for the configured site', () {
    expect(meetingNumberFromLink('https://aco.chat/meeting/123'), '123');
    expect(meetingNumberFromLink('/meeting/123'), '123');
    expect(meetingNumberFromLink('https://example.com/meeting/123'), isNull);
    expect(meetingNumberFromLink('http://aco.chat/meeting/123'), isNull);
    expect(meetingNumberFromLink('/meeting/0'), isNull);
    expect(meetingNumberFromLink('/meeting/abc'), isNull);
    expect(meetingNumberFromLink('/meeting/123/extra'), isNull);
  });
}
