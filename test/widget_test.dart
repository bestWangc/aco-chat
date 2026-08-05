import 'package:flutter_test/flutter_test.dart';

import 'package:aco_chat/main.dart';

void main() {
  testWidgets('renders the Aco home page', (WidgetTester tester) async {
    await tester.pumpWidget(const AcoApp());

    expect(find.text('Aco'), findsOneWidget);
    expect(find.text('Welcome to Aco'), findsOneWidget);
    expect(find.text('Start a conversation'), findsOneWidget);
  });
}
