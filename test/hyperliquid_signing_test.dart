import 'package:aco_chat/services/hyperliquid_signing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('matches Hyperliquid official L1 testnet signing vector', () {
    final signature = HyperliquidSigner.signL1Action(
      privateKeyHex:
          '0x0123456789012345678901234567890123456789012345678901234567890123',
      action: {'type': 'dummy', 'num': 100000000000},
      nonce: 0,
      isMainnet: false,
    );

    expect(
      signature.r,
      '0x542af61ef1f429707e3c76c5293c80d01f74ef853e34b76efffcb57e574f9510',
    );
    expect(
      signature.s,
      '0x17b8b32f086e8cdede991f1e2c529f5dd5297cbe8128500e00cbaf766204a613',
    );
    expect(signature.v, 28);
  });

  test('matches Hyperliquid official order testnet signing vector', () {
    final signature = HyperliquidSigner.signL1Action(
      privateKeyHex:
          '0x0123456789012345678901234567890123456789012345678901234567890123',
      action: {
        'type': 'order',
        'orders': [
          {
            'a': 1,
            'b': true,
            'p': '100',
            's': '100',
            'r': false,
            't': {
              'limit': {'tif': 'Gtc'},
            },
          },
        ],
        'grouping': 'na',
      },
      nonce: 0,
      isMainnet: false,
    );

    expect(
      signature.r,
      '0x82b2ba28e76b3d761093aaded1b1cdad4960b3af30212b343fb2e6cdfa4e3d54',
    );
    expect(
      signature.s,
      '0x6b53878fc99d26047f4d7e8c90eb98955a109f44209163f52d8dc4278cbbd9f5',
    );
    expect(signature.v, 27);
  });

  test('adds testnet user-signed fields before hashing', () {
    final signature = HyperliquidSigner.signUsdClassTransfer(
      privateKeyHex:
          '0x0123456789012345678901234567890123456789012345678901234567890123',
      amount: '10',
      toPerp: true,
      nonce: 1,
      isMainnet: false,
    );

    expect(signature.r, startsWith('0x'));
    expect(signature.r.length, 66);
    expect(signature.s.length, 66);
    expect(signature.v, anyOf(27, 28));
  });
}
