import 'package:aco_chat/features/account/domain/account_models.dart';
import 'package:aco_chat/features/live/domain/live_chat_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('chat buffer de-duplicates messages and retains the newest 200', () {
    var refreshes = 0;
    final buffer = LiveChatBuffer(onChanged: () => refreshes++);
    final createdAt = DateTime(2026);

    buffer.appendAll([
      for (var id = 0; id < 201; id++)
        LiveMessage(
          id: id,
          nickname: 'member',
          text: '$id',
          createdAt: createdAt,
        ),
      LiveMessage(
        id: 200,
        nickname: 'member',
        text: 'duplicate',
        createdAt: createdAt,
      ),
    ]);

    expect(buffer.messages, hasLength(200));
    expect(buffer.messages.first.id, 1);
    expect(buffer.messages.last.text, '200');
    expect(refreshes, 0);
    buffer.dispose();
  });

  test('chat rate limiter enforces byte and interval limits', () {
    final limiter = LiveChatRateLimiter();
    final startedAt = DateTime(2026);

    expect(
      limiter.check(513, now: startedAt),
      LiveChatSendLimit.payloadTooLarge,
    );
    expect(limiter.check(1, now: startedAt), LiveChatSendLimit.allowed);
    expect(
      limiter.check(1, now: startedAt.add(const Duration(milliseconds: 249))),
      LiveChatSendLimit.sentTooRecently,
    );
    expect(
      limiter.check(1, now: startedAt.add(const Duration(milliseconds: 250))),
      LiveChatSendLimit.allowed,
    );
  });
}
