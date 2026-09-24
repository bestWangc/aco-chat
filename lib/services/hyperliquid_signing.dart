import 'dart:convert';

import 'package:aco_chat/services/wallet_identity.dart';
import 'package:blockchain_utils/blockchain_utils.dart';
import 'package:on_chain/solidity/solidity.dart';

/// The signature returned by Hyperliquid's /exchange endpoint.
class HyperliquidSignature {
  const HyperliquidSignature({
    required this.r,
    required this.s,
    required this.v,
  });

  final String r;
  final String s;
  final int v;

  Map<String, dynamic> toJson() => {'r': r, 's': s, 'v': v};

  String toHex() =>
      '0x${r.substring(2)}${s.substring(2)}${v.toRadixString(16).padLeft(2, '0')}';
}

/// Hyperliquid's signing format.
///
/// Hyperliquid does not sign the JSON request directly. L1 actions are first
/// encoded with MessagePack and then wrapped in the phantom-agent EIP-712
/// payload. User-signed actions use Hyperliquid's EIP-712 domain directly.
class HyperliquidSigner {
  HyperliquidSigner._();

  static const _zeroAddress = '0x0000000000000000000000000000000000000000';
  static const _userDomainName = 'HyperliquidSignTransaction';
  static const _domainTypes = [
    {'name': 'name', 'type': 'string'},
    {'name': 'version', 'type': 'string'},
    {'name': 'chainId', 'type': 'uint256'},
    {'name': 'verifyingContract', 'type': 'address'},
  ];

  static const approveAgentTypes = [
    {'name': 'hyperliquidChain', 'type': 'string'},
    {'name': 'agentAddress', 'type': 'address'},
    {'name': 'agentName', 'type': 'string'},
    {'name': 'nonce', 'type': 'uint64'},
  ];

  static const approveBuilderFeeTypes = [
    {'name': 'hyperliquidChain', 'type': 'string'},
    {'name': 'maxFeeRate', 'type': 'string'},
    {'name': 'builder', 'type': 'address'},
    {'name': 'nonce', 'type': 'uint64'},
  ];

  static const usdClassTransferTypes = [
    {'name': 'hyperliquidChain', 'type': 'string'},
    {'name': 'amount', 'type': 'string'},
    {'name': 'toPerp', 'type': 'bool'},
    {'name': 'nonce', 'type': 'uint64'},
  ];

  static const withdrawTypes = [
    {'name': 'hyperliquidChain', 'type': 'string'},
    {'name': 'destination', 'type': 'string'},
    {'name': 'amount', 'type': 'string'},
    {'name': 'time', 'type': 'uint64'},
  ];

  static const _agentTypes = [
    {'name': 'source', 'type': 'string'},
    {'name': 'connectionId', 'type': 'bytes32'},
  ];

  static const _l1Domain = {
    'name': 'Exchange',
    'version': '1',
    'chainId': 1337,
    'verifyingContract': _zeroAddress,
  };

  static String privateKeyFromMnemonic(String mnemonic) =>
      WalletIdentity.privateKeyFromMnemonic(mnemonic);

  static HyperliquidSignature signL1Action({
    required String privateKeyHex,
    required Map<String, dynamic> action,
    required int nonce,
    required bool isMainnet,
    String? vaultAddress,
    int? expiresAfter,
  }) {
    final hash = _actionHash(
      action: action,
      nonce: nonce,
      vaultAddress: vaultAddress,
      expiresAfter: expiresAfter,
    );
    final typedData = Eip712TypedData.fromJson({
      'domain': _l1Domain,
      'types': {'Agent': _agentTypes, 'EIP712Domain': _domainTypes},
      'primaryType': 'Agent',
      'message': {'source': isMainnet ? 'a' : 'b', 'connectionId': _hex(hash)},
    });
    return _signDigest(privateKeyHex, typedData.encode());
  }

  static HyperliquidSignature signUserAction({
    required String privateKeyHex,
    required Map<String, dynamic> action,
    required String primaryType,
    required List<Map<String, String>> fields,
    required bool isMainnet,
  }) {
    final signedAction = <String, dynamic>{...action};
    signedAction['signatureChainId'] = '0x66eee';
    signedAction['hyperliquidChain'] = isMainnet ? 'Mainnet' : 'Testnet';
    final typedData = Eip712TypedData.fromJson({
      'domain': {
        'name': _userDomainName,
        'version': '1',
        'chainId': int.parse('66eee', radix: 16),
        'verifyingContract': _zeroAddress,
      },
      'types': {primaryType: fields, 'EIP712Domain': _domainTypes},
      'primaryType': primaryType,
      'message': signedAction,
    });
    return _signDigest(privateKeyHex, typedData.encode());
  }

  static HyperliquidSignature signTypedData({
    required String privateKeyHex,
    required Map<String, dynamic> typedData,
  }) {
    final data = Eip712TypedData.fromJson(typedData);
    return _signDigest(privateKeyHex, data.encode());
  }

  static HyperliquidSignature signApproveAgent({
    required String privateKeyHex,
    required String agentAddress,
    required String agentName,
    required int nonce,
    required bool isMainnet,
  }) => signUserAction(
    privateKeyHex: privateKeyHex,
    action: {
      'type': 'approveAgent',
      'agentAddress': agentAddress,
      'agentName': agentName,
      'nonce': nonce,
    },
    primaryType: 'HyperliquidTransaction:ApproveAgent',
    fields: approveAgentTypes,
    isMainnet: isMainnet,
  );

  static HyperliquidSignature signUsdClassTransfer({
    required String privateKeyHex,
    required String amount,
    required bool toPerp,
    required int nonce,
    required bool isMainnet,
  }) => signUserAction(
    privateKeyHex: privateKeyHex,
    action: {
      'type': 'usdClassTransfer',
      'amount': amount,
      'toPerp': toPerp,
      'nonce': nonce,
    },
    primaryType: 'HyperliquidTransaction:UsdClassTransfer',
    fields: usdClassTransferTypes,
    isMainnet: isMainnet,
  );

  static HyperliquidSignature signWithdraw({
    required String privateKeyHex,
    required String destination,
    required String amount,
    required int time,
    required bool isMainnet,
  }) => signUserAction(
    privateKeyHex: privateKeyHex,
    action: {
      'destination': destination,
      'amount': amount,
      'time': time,
      'type': 'withdraw3',
    },
    primaryType: 'HyperliquidTransaction:Withdraw',
    fields: withdrawTypes,
    isMainnet: isMainnet,
  );

  static Map<String, dynamic> orderAction({
    required int asset,
    required bool isBuy,
    required String price,
    required String size,
    required bool reduceOnly,
    bool market = false,
    String tif = 'Gtc',
    String grouping = 'na',
  }) => {
    'type': 'order',
    'orders': [
      orderWire(
        asset: asset,
        isBuy: isBuy,
        price: price,
        size: size,
        reduceOnly: reduceOnly,
        market: market,
        tif: tif,
      ),
    ],
    'grouping': grouping,
  };

  static Map<String, dynamic> orderWire({
    required int asset,
    required bool isBuy,
    required String price,
    required String size,
    required bool reduceOnly,
    bool market = false,
    String tif = 'Gtc',
    double? triggerPrice,
    String? tpsl,
  }) {
    final type = <String, dynamic>{};
    if (triggerPrice == null) {
      type['limit'] = {'tif': market ? 'Ioc' : tif};
    } else {
      type['trigger'] = {
        'triggerPx': _wireNumber(triggerPrice),
        'isMarket': true,
        'tpsl': tpsl ?? 'tp',
      };
    }
    return {
      'a': asset,
      'b': isBuy,
      'p': price,
      's': size,
      'r': reduceOnly,
      't': type,
    };
  }

  static Map<String, dynamic> cancelAction({
    required int asset,
    required int orderId,
  }) => {
    'type': 'cancel',
    'cancels': [
      {'a': asset, 'o': orderId},
    ],
  };

  static Map<String, dynamic> updateLeverageAction({
    required int asset,
    required int leverage,
    bool isCross = true,
  }) => {
    'type': 'updateLeverage',
    'asset': asset,
    'isCross': isCross,
    'leverage': leverage,
  };

  static List<int> _actionHash({
    required Map<String, dynamic> action,
    required int nonce,
    required String? vaultAddress,
    required int? expiresAfter,
  }) {
    final data = <int>[..._MessagePack.encode(action), ..._uint64(nonce)];
    if (vaultAddress == null) {
      data.add(0);
    } else {
      data.add(1);
      data.addAll(_hexBytes(vaultAddress));
    }
    if (expiresAfter != null) {
      data.add(0);
      data.addAll(_uint64(expiresAfter));
    }
    return QuickCrypto.keccack256Hash(data);
  }

  static HyperliquidSignature _signDigest(
    String privateKeyHex,
    List<int> digest,
  ) {
    final signature = ETHSigner.fromKeyBytes(
      _hexBytes(privateKeyHex),
    ).sign(digest, hashMessage: false);
    return HyperliquidSignature(
      r: _hex(signature.rBytes),
      s: _hex(signature.sBytes),
      v: signature.v,
    );
  }

  static List<int> _hexBytes(String value) {
    final normalized = value.startsWith('0x') ? value.substring(2) : value;
    if (normalized.length.isOdd || normalized.isEmpty) {
      throw const FormatException('十六进制数据格式无效');
    }
    return [
      for (var index = 0; index < normalized.length; index += 2)
        int.parse(normalized.substring(index, index + 2), radix: 16),
    ];
  }

  static String _hex(List<int> bytes) =>
      '0x${bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join()}';

  static String _wireNumber(double value) {
    final normalized = value.toStringAsFixed(8);
    return normalized
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  static List<int> _uint64(int value) {
    if (value < 0) throw const FormatException('nonce 不能为负数');
    return [
      for (var shift = 56; shift >= 0; shift -= 8) (value >> shift) & 0xff,
    ];
  }
}

class _MessagePack {
  _MessagePack._();

  static List<int> encode(Object? value) {
    final output = <int>[];
    _write(value, output);
    return output;
  }

  static void _write(Object? value, List<int> output) {
    if (value == null) {
      output.add(0xc0);
    } else if (value is bool) {
      output.add(value ? 0xc3 : 0xc2);
    } else if (value is int) {
      _writeInt(value, output);
    } else if (value is double) {
      _write(value.toInt(), output);
    } else if (value is String) {
      final bytes = utf8.encode(value);
      _writeString(bytes, output);
    } else if (value is List) {
      _writeLength(value.length, output, 0x90, 0xdc, 0xdd);
      for (final item in value) {
        _write(item, output);
      }
    } else if (value is Map) {
      _writeLength(value.length, output, 0x80, 0xde, 0xdf);
      for (final entry in value.entries) {
        _write(entry.key, output);
        _write(entry.value, output);
      }
    } else {
      throw UnsupportedError('MessagePack 不支持 ${value.runtimeType}');
    }
  }

  static void _writeInt(int value, List<int> output) {
    if (value >= 0 && value < 0x80) {
      output.add(value);
    } else if (value >= -32 && value < 0) {
      output.add(0x100 + value);
    } else if (value >= 0 && value <= 0xff) {
      output
        ..add(0xcc)
        ..add(value);
    } else if (value >= 0 && value <= 0xffff) {
      output.add(0xcd);
      _writeUint(value, 2, output);
    } else if (value >= 0 && value <= 0xffffffff) {
      output.add(0xce);
      _writeUint(value, 4, output);
    } else if (value >= 0) {
      output.add(0xcf);
      _writeUint(value, 8, output);
    } else if (value >= -0x80) {
      output
        ..add(0xd0)
        ..add(value & 0xff);
    } else if (value >= -0x8000) {
      output.add(0xd1);
      _writeUint(value & 0xffff, 2, output);
    } else if (value >= -0x80000000) {
      output.add(0xd2);
      _writeUint(value & 0xffffffff, 4, output);
    } else {
      output.add(0xd3);
      _writeUint(value, 8, output);
    }
  }

  static void _writeString(List<int> bytes, List<int> output) {
    if (bytes.length < 32) {
      output.add(0xa0 | bytes.length);
    } else if (bytes.length <= 0xff) {
      output
        ..add(0xd9)
        ..add(bytes.length);
    } else if (bytes.length <= 0xffff) {
      output.add(0xda);
      _writeUint(bytes.length, 2, output);
    } else {
      output.add(0xdb);
      _writeUint(bytes.length, 4, output);
    }
    output.addAll(bytes);
  }

  static void _writeLength(
    int length,
    List<int> output,
    int fix,
    int array16,
    int array32,
  ) {
    if (length < 16) {
      output.add(fix | length);
    } else if (length <= 0xffff) {
      output.add(array16);
      _writeUint(length, 2, output);
    } else {
      output.add(array32);
      _writeUint(length, 4, output);
    }
  }

  static void _writeUint(int value, int bytes, List<int> output) {
    for (var shift = (bytes - 1) * 8; shift >= 0; shift -= 8) {
      output.add((value >> shift) & 0xff);
    }
  }
}
