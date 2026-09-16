import 'package:aco_chat/features/design/presentation/aco_design_shell.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart' as shad;

const _legacyAccountId = 'aco_8aca72086c10c6bf5e22a6eadbf27adc';
const _displayAccountId = '872086106522627';

Widget _profileScreen(
  AcoScreen screen, {
  int identity = 0,
  int staffIdentity = 0,
}) => shad.ShadApp.custom(
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
      username: 'aco',
      identity: identity,
      staffIdentity: staffIdentity,
    ),
  ),
);

void main() {
  testWidgets('shows a numeric UID on the profile page', (tester) async {
    await tester.pumpWidget(_profileScreen(AcoScreen.profile));

    expect(find.text('UID:$_displayAccountId'), findsOneWidget);
    expect(find.textContaining(_legacyAccountId), findsNothing);
  });

  testWidgets('keeps full-width profile badges on their own row', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _profileScreen(AcoScreen.profile, identity: 1, staffIdentity: 1),
    );

    expect(tester.takeException(), isNull);
    final identityBadge = find.image(
      const AssetImage(
        'assets/images/identity_badges/identity_long_shareholder_purple.png',
      ),
    );
    final staffBadge = find.image(
      const AssetImage('assets/images/staff_badges/staff_long_1.png'),
    );
    expect(identityBadge, findsOneWidget);
    expect(staffBadge, findsOneWidget);
    expect(tester.getSize(identityBadge).width, 75);
    expect(tester.getSize(staffBadge).width, 75);
    expect(
      tester.getTopLeft(identityBadge).dy,
      tester.getTopLeft(staffBadge).dy,
    );
  });

  testWidgets('shows a numeric UID on the profile edit page', (tester) async {
    await tester.pumpWidget(_profileScreen(AcoScreen.profileEdit));

    expect(find.text(_displayAccountId), findsOneWidget);
    expect(find.text(_legacyAccountId), findsNothing);
  });

  testWidgets('shows a numeric UID on the profile QR page', (tester) async {
    await tester.pumpWidget(_profileScreen(AcoScreen.profileQr));

    expect(find.text('UID:$_displayAccountId'), findsOneWidget);
    expect(find.textContaining(_legacyAccountId), findsNothing);
  });
}
