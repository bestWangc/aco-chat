import 'dart:convert';

import 'package:bip39/bip39.dart' as bip39;
import 'package:blockchain_utils/blockchain_utils.dart';

/// Public address for the first Ethereum account of a BIP-39 wallet.
class WalletIdentity {
  const WalletIdentity({required this.address});

  final String address;

  factory WalletIdentity.fromMnemonic(String mnemonic) {
    return WalletIdentity(
      address: _ethereumAccountFromMnemonic(
        mnemonic,
      ).publicKey.toAddress.toLowerCase(),
    );
  }

  /// Private key for the first Ethereum account at m/44'/60'/0'/0/0.
  static String privateKeyFromMnemonic(String mnemonic) {
    final key = _ethereumAccountFromMnemonic(mnemonic).privateKey.raw;
    return key.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }

  factory WalletIdentity.fromJson(Map<String, dynamic> json) =>
      WalletIdentity(address: (json['address'] ?? json['evm']) as String);

  Map<String, String> toJson() => {'address': address};

  static WalletLoginProof signLoginChallenge({
    required String mnemonic,
    required String challenge,
  }) {
    final key = _ethereumAccountFromMnemonic(mnemonic);
    return WalletLoginProof(
      challenge: challenge,
      publicKey: base64UrlEncode(
        key.publicKey.uncompressed,
      ).replaceAll('=', ''),
      signature: base64UrlEncode(
        ETHSigner.fromKeyBytes(
          key.privateKey.raw,
        ).signProsonalMessage(utf8.encode(challenge)),
      ).replaceAll('=', ''),
    );
  }

  static Bip44 _ethereumAccountFromMnemonic(String mnemonic) => Bip44.fromSeed(
    bip39.mnemonicToSeed(mnemonic),
    Bip44Coins.ethereum,
  ).deriveDefaultPath;
}

class WalletLoginProof {
  const WalletLoginProof({
    required this.challenge,
    required this.publicKey,
    required this.signature,
  });
  final String challenge;
  final String publicKey;
  final String signature;
}
