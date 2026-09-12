import 'package:aco_chat/services/wallet_identity.dart';
import 'package:aco_chat/services/wallet_metadata_store.dart';
import 'package:aco_chat/services/wallet_portfolio_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('saves the first custom token for a wallet', () async {
    const identity = WalletIdentity(
      address: '0x0000000000000000000000000000000000000001',
    );
    const token = CustomTokenDefinition(
      network: 'ethereum',
      address: '0xToken',
      symbol: 'TKN',
      decimals: 18,
    );
    final store = WalletMetadataStore();

    await store.saveCustomToken(identity, token);

    final saved = await store.customTokens(identity);
    expect(saved, hasLength(1));
    expect(saved.single.network, token.network);
    expect(saved.single.address, token.address);
    expect(saved.single.symbol, token.symbol);
    expect(saved.single.decimals, token.decimals);
  });
}
