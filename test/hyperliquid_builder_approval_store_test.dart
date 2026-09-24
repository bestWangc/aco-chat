import 'package:aco_chat/services/hyperliquid_builder_approval_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('persists builder approval metadata without private keys', () async {
    SharedPreferences.setMockInitialValues({});
    final store = HyperliquidBuilderApprovalStore();
    const approval = HyperliquidBuilderApproval(
      builderAddress: '0xBuilder',
      maxFeeRate: '0.01%',
    );

    await store.markApproved('0xMaster', approval);

    final saved = await store.read('0xmaster');
    expect(saved?.builderAddress, approval.builderAddress);
    expect(saved?.maxFeeRate, approval.maxFeeRate);
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString('hyperliquid.builder-approval.mainnet.0xmaster'),
      isNot(contains('private')),
    );
  });
}
