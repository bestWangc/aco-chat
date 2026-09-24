import 'package:aco_chat/services/hyperliquid_agent_store.dart';
import 'package:aco_chat/services/wallet_identity.dart';
import 'package:aco_chat/services/wallet_security.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'stores an encrypted agent and approval state without the mnemonic in prefs',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = HyperliquidAgentStore(
        secretStore: InMemoryWalletSecretStore(),
      );

      final agent = await store.create('0xmaster');
      final prefs = await SharedPreferences.getInstance();
      final encoded = prefs.getString('hyperliquid.agent.0xmaster')!;

      expect(agent.approved, isFalse);
      expect(encoded, isNot(contains('mnemonic')));
      expect(
        WalletIdentity.fromMnemonic(await store.unlock(agent)).address,
        agent.address,
      );

      await store.markApproved('0xmaster', agent);
      expect((await store.read('0xmaster'))?.approved, isTrue);
    },
  );
}
