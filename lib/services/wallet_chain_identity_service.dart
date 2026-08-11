import 'dart:isolate';

import 'package:aco_chat/services/wallet_identity.dart';
import 'package:aco_chat/services/wallet_preferences.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'package:blockchain_utils/blockchain_utils.dart';

/// Derives non-EVM public addresses after the default EVM address is ready.
///
/// Only public addresses are cached. The mnemonic remains in encrypted secure
/// storage and is never written to preferences.
class WalletChainIdentityService {
  static const _nonEvmChains = <String, Bip44Coins>{
    'bitcoin': Bip44Coins.bitcoin,
    'solana': Bip44Coins.solana,
    'tron': Bip44Coins.tron,
    'cosmos': Bip44Coins.cosmos,
  };

  /// Caches the first account for supported non-EVM chains off the UI isolate.
  Future<void> cacheNonEvmAddresses({
    required String mnemonic,
    required WalletIdentity identity,
  }) async {
    final addresses = await Isolate.run(() => deriveNonEvmAddresses(mnemonic));
    await WalletPreferences.saveDerivedAddresses(identity, addresses);
  }

  /// Exposed for deterministic tests and future on-demand derivation.
  static Map<String, String> deriveNonEvmAddresses(String mnemonic) {
    final seed = bip39.mnemonicToSeed(mnemonic);
    return {
      for (final entry in _nonEvmChains.entries)
        entry.key: Bip44.fromSeed(
          seed,
          entry.value,
        ).deriveDefaultPath.publicKey.toAddress,
    };
  }
}
