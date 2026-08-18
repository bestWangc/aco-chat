import 'package:aco_chat/features/legal/presentation/legal_document_page.dart';
import 'package:aco_chat/shared/widgets/aco_page_header.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the user agreement document', (tester) async {
    await tester.pumpWidget(
      const CupertinoApp(
        home: LegalDocumentPage(document: LegalDocument.userAgreement),
      ),
    );

    expect(find.text('用户协议'), findsAtLeastNWidgets(1));
    expect(find.text('一、协议说明'), findsOneWidget);
    expect(find.textContaining('钱包与账号安全'), findsOneWidget);
    _expectDocumentContentBelowHeader(tester);
  });

  testWidgets('renders the privacy policy document', (tester) async {
    await tester.pumpWidget(
      const CupertinoApp(
        home: LegalDocumentPage(document: LegalDocument.privacyPolicy),
      ),
    );

    expect(find.text('隐私政策'), findsAtLeastNWidgets(1));
    expect(find.text('一、我们收集的信息'), findsOneWidget);
    expect(find.textContaining('设备权限'), findsOneWidget);
    _expectDocumentContentBelowHeader(tester);
  });
}

void _expectDocumentContentBelowHeader(WidgetTester tester) {
  final header = find.byType(AcoPageHeader);
  final intro = find.text('适用于 Aco Chat 的移动端服务');

  expect(header, findsOneWidget);
  expect(
    tester.getTopLeft(intro).dy,
    greaterThanOrEqualTo(tester.getBottomLeft(header).dy),
  );
}
