import 'package:aco_chat/features/design/presentation/aco_design_shell.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart' as shad;

const _legacyAccountId = 'aco_8aca72086c10c6bf5e22a6eadbf27adc';
const _displayAccountId = 'aco_8aca72086c10c';

Widget _profileScreen(AcoScreen screen) => shad.ShadApp.custom(
  theme: shad.ShadThemeData(
    brightness: Brightness.dark,
    colorScheme: shad.ShadSlateColorScheme.dark(),
  ),
  appBuilder: (_) => CupertinoApp(
    home: AcoScreenPage(
      screen: screen,
      dark: true,
      isRoot: true,
      onOpen: (_) {},
      onThemeToggle: () {},
      displayName: 'Marry',
      accountId: _legacyAccountId,
    ),
  ),
);

void main() {
  testWidgets('shows a compact legacy UID on the profile page', (tester) async {
    await tester.pumpWidget(_profileScreen(AcoScreen.profile));

    expect(find.text('UID:$_displayAccountId'), findsOneWidget);
    expect(find.textContaining(_legacyAccountId), findsNothing);
  });

  testWidgets('shows a compact legacy UID on the profile edit page', (
    tester,
  ) async {
    await tester.pumpWidget(_profileScreen(AcoScreen.profileEdit));

    expect(find.text(_displayAccountId), findsOneWidget);
    expect(find.text(_legacyAccountId), findsNothing);
  });
}
