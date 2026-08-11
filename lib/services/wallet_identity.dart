import 'package:bip39/bip39.dart' as bip39;
import 'package:blockchain_utils/blockchain_utils.dart';

/// Public address for the first Ethereum account of a BIP-39 wallet.
class WalletIdentity {
  const WalletIdentity({required this.address});

  final String address;

  factory WalletIdentity.fromMnemonic(String mnemonic) {
    final seed = bip39.mnemonicToSeed(mnemonic);
    return WalletIdentity(
      address: _addressFor(seed, Bip44Coins.ethereum).toLowerCase(),
    );
  }

  factory WalletIdentity.fromJson(Map<String, dynamic> json) =>
      WalletIdentity(address: (json['address'] ?? json['evm']) as String);

  Map<String, String> toJson() => {'address': address};

  static String _addressFor(List<int> seed, Bip44Coins coin) =>
      Bip44.fromSeed(seed, coin).deriveDefaultPath.publicKey.toAddress;
}
