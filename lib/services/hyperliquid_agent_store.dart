import 'dart:convert';

import 'package:aco_chat/services/wallet_identity.dart';
import 'package:aco_chat/services/wallet_security.dart';
import 'package:aco_chat/core/config/app_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HyperliquidAgent {
  const HyperliquidAgent({
    required this.address,
    required this.name,
    required this.approved,
  });

  final String address;
  final String name;
  final bool approved;
}

/// Stores only the agent address in preferences. The agent mnemonic is kept
/// in the same device-protected secret store as the user's wallet.
class HyperliquidAgentStore {
  HyperliquidAgentStore({
    WalletSecretStore? secretStore,
    WalletSecurity? security,
    Future<SharedPreferences>? preferences,
  }) : _secretStore = secretStore ?? SecureWalletSecretStore(),
       _security = security ?? WalletSecurity(),
       _preferences = preferences ?? SharedPreferences.getInstance();

  static const _prefix = 'hyperliquid.agent.';

  final WalletSecretStore _secretStore;
  final WalletSecurity _security;
  final Future<SharedPreferences> _preferences;

  Future<HyperliquidAgent?> read(String masterAddress) async {
    final prefs = await _preferences;
    final encoded = prefs.getString('$_prefix${masterAddress.toLowerCase()}');
    if (encoded == null || encoded.isEmpty) return null;
    try {
      final json = Map<String, dynamic>.from(
        (jsonDecode(encoded) as Map).cast<String, dynamic>(),
      );
      final address = '${json['address'] ?? ''}';
      if (address.isEmpty) return null;
      final network = '${json['network'] ?? ''}';
      final currentNetwork = AppConfig.hyperliquidTestnet
          ? 'testnet'
          : 'mainnet';
      if (network != currentNetwork) return null;
      return HyperliquidAgent(
        address: address,
        name: '${json['name'] ?? 'ACO Agent'}',
        approved: json['approved'] == true,
      );
    } catch (_) {
      return null;
    }
  }

  Future<HyperliquidAgent> create(String masterAddress) async {
    final existing = await read(masterAddress);
    if (existing != null) return existing;
    final mnemonic = _security.createMnemonic();
    final identity = WalletIdentity.fromMnemonic(mnemonic);
    await _security.saveMnemonicWithDeviceProtection(
      store: _secretStore,
      walletAddress: identity.address,
      mnemonic: mnemonic,
    );
    final agent = HyperliquidAgent(
      address: identity.address,
      name: 'ACO Agent',
      approved: false,
    );
    await _write(masterAddress, agent);
    return agent;
  }

  Future<void> markApproved(String masterAddress, HyperliquidAgent agent) =>
      _write(
        masterAddress,
        HyperliquidAgent(
          address: agent.address,
          name: agent.name,
          approved: true,
        ),
      );

  Future<String> unlock(HyperliquidAgent agent) =>
      _security.unlockMnemonicWithDeviceProtection(
        store: _secretStore,
        walletAddress: agent.address,
      );

  Future<void> _write(String masterAddress, HyperliquidAgent agent) async {
    final prefs = await _preferences;
    await prefs.setString(
      '$_prefix${masterAddress.toLowerCase()}',
      jsonEncode({
        'address': agent.address,
        'name': agent.name,
        'approved': agent.approved,
        'network': AppConfig.hyperliquidTestnet ? 'testnet' : 'mainnet',
      }),
    );
  }
}
