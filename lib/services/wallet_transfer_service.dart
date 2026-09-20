import 'package:blockchain_utils/blockchain_utils.dart';
import 'package:aco_chat/services/wallet_identity.dart';
import 'package:aco_chat/services/wallet_rpc_client.dart';
import 'package:aco_chat/services/wallet_portfolio_models.dart';

class WalletTransferResult {
  const WalletTransferResult({required this.hash, required this.status});
  final String hash;
  final String status;
}

/// Builds and signs an EVM native transfer. Broadcasting is injected so the
/// same signing path can be used by production RPC clients and tests.
class WalletTransferService {
  const WalletTransferService({this.broadcast});
  final Future<String> Function(String rawTransaction)? broadcast;

  /// Signs and broadcasts the EVM transaction returned by a LI.FI quote.
  /// The caller must have shown the exact transaction request to the user.
  Future<WalletTransferResult> executeTransactionRequestWithRpc({
    required String mnemonic,
    required String from,
    required WalletNetwork network,
    required String accessToken,
    required WalletRpcClient rpc,
    required Map<String, dynamic> transactionRequest,
  }) async {
    final to = transactionRequest['to'] as String?;
    if (to == null || !to.startsWith('0x')) {
      throw const FormatException('LI.FI 交易目标地址无效');
    }
    final endpoints = await rpc.loadEndpoints(
      network: network.name,
      accessToken: accessToken,
    );
    Future<Map<String, dynamic>> call(String method, List<Object> params) {
      return rpc.postJson(endpoints, {
        'jsonrpc': '2.0',
        'id': 1,
        'method': method,
        'params': params,
      });
    }

    final nonceHex =
        (await call('eth_getTransactionCount', [from, 'pending']))['result']
            as String;
    final gasPriceHex =
        transactionRequest['gasPrice'] as String? ??
        (await call('eth_gasPrice', const []))['result'] as String;
    final chainHex = (await call('eth_chainId', const []))['result'] as String;
    final valueHex = transactionRequest['value'] as String? ?? '0x0';
    final dataHex = transactionRequest['data'] as String? ?? '0x';
    final gasLimitHex =
        transactionRequest['gasLimit'] as String? ??
        transactionRequest['gas'] as String? ??
        '0x186a0';
    final result = await execute(
      mnemonic: mnemonic,
      from: from,
      to: to,
      amount: _weiToDecimal(_hexToBigInt(valueHex)),
      chainId: _hexToBigInt(chainHex).toInt(),
      nonce: _hexToBigInt(nonceHex).toInt(),
      gasPriceWei: _hexToBigInt(gasPriceHex).toInt(),
      gasLimit: _hexToBigInt(gasLimitHex).toInt(),
      data: _hexToBytes(dataHex),
      broadcast: (raw) async =>
          (await call('eth_sendRawTransaction', [raw]))['result'] as String,
    );
    return result;
  }

  /// Ensures an ERC-20 allowance for a LI.FI spender. Returns null when the
  /// existing allowance is already sufficient.
  Future<WalletTransferResult?> ensureErc20AllowanceWithRpc({
    required String mnemonic,
    required String from,
    required WalletNetwork network,
    required String accessToken,
    required WalletRpcClient rpc,
    required String tokenAddress,
    required String spender,
    required String requiredAmount,
  }) async {
    final endpoints = await rpc.loadEndpoints(
      network: network.name,
      accessToken: accessToken,
    );
    Future<Map<String, dynamic>> call(String method, List<Object> params) =>
        rpc.postJson(endpoints, {
          'jsonrpc': '2.0',
          'id': 1,
          'method': method,
          'params': params,
        });
    final owner = _encodeAddress(from);
    final spenderEncoded = _encodeAddress(spender);
    final allowanceResult = await call('eth_call', [
      {'to': tokenAddress, 'data': '0xdd62ed3e$owner$spenderEncoded'},
      'latest',
    ]);
    final current = _hexToBigInt(allowanceResult['result'] as String? ?? '0x0');
    final required = BigInt.parse(requiredAmount);
    if (current >= required) return null;

    final approvalData = '0x095ea7b3$spenderEncoded${_encodeUint(required)}';
    final nonceHex =
        (await call('eth_getTransactionCount', [from, 'pending']))['result']
            as String;
    final gasPriceHex =
        (await call('eth_gasPrice', const []))['result'] as String;
    final chainHex = (await call('eth_chainId', const []))['result'] as String;
    return execute(
      mnemonic: mnemonic,
      from: from,
      to: tokenAddress,
      amount: '0',
      chainId: _hexToBigInt(chainHex).toInt(),
      nonce: _hexToBigInt(nonceHex).toInt(),
      gasPriceWei: _hexToBigInt(gasPriceHex).toInt(),
      gasLimit: 100000,
      data: _hexToBytes(approvalData),
      broadcast: (raw) async =>
          (await call('eth_sendRawTransaction', [raw]))['result'] as String,
    );
  }

  Future<WalletTransferResult> executeWithRpc({
    required String mnemonic,
    required String from,
    required String to,
    required String amount,
    required WalletNetwork network,
    required String accessToken,
    required WalletRpcClient rpc,
    List<int> data = const [],
    int gasLimit = 21000,
  }) async {
    final endpoints = await rpc.loadEndpoints(
      network: network.name,
      accessToken: accessToken,
    );
    Future<Map<String, dynamic>> call(String method, List<Object> params) {
      return rpc.postJson(endpoints, {
        'jsonrpc': '2.0',
        'id': 1,
        'method': method,
        'params': params,
      });
    }

    final nonceHex =
        (await call('eth_getTransactionCount', [from, 'pending']))['result']
            as String;
    final gasHex = (await call('eth_gasPrice', const []))['result'] as String;
    final chainHex = (await call('eth_chainId', const []))['result'] as String;
    final nonce = int.parse(nonceHex.substring(2), radix: 16);
    final gasPrice = int.parse(gasHex.substring(2), radix: 16);
    final chainId = int.parse(chainHex.substring(2), radix: 16);
    return execute(
      mnemonic: mnemonic,
      from: from,
      to: to,
      amount: amount,
      chainId: chainId,
      nonce: nonce,
      gasPriceWei: gasPrice,
      data: data,
      gasLimit: gasLimit,
      broadcast: (raw) async =>
          (await call('eth_sendRawTransaction', [raw]))['result'] as String,
    );
  }

  Future<WalletTransferResult> execute({
    required String mnemonic,
    required String from,
    required String to,
    required String amount,
    required int chainId,
    int nonce = 0,
    int gasPriceWei = 1,
    int gasLimit = 21000,
    List<int> data = const [],
    Future<String> Function(String rawTransaction)? broadcast,
  }) async {
    final value = int.parse(decimalToBaseUnits(amount));
    final privateKey = WalletIdentity.privateKeyFromMnemonic(mnemonic);
    final unsigned = _rlp([
      _intBytes(nonce),
      _intBytes(gasPriceWei),
      _intBytes(gasLimit),
      _addressBytes(to),
      _intBytes(value),
      data,
      _intBytes(chainId),
      <int>[],
      <int>[],
    ]);
    final signature = ETHSigner.fromKeyBytes(
      _hexBytes(privateKey),
    ).sign(QuickCrypto.keccack256Hash(unsigned), hashMessage: false);
    final raw = _rlp([
      _intBytes(nonce),
      _intBytes(gasPriceWei),
      _intBytes(gasLimit),
      _addressBytes(to),
      _intBytes(value),
      data,
      _intBytes(signature.v + 8 + chainId * 2),
      _bigIntBytes(signature.r),
      _bigIntBytes(signature.s),
    ]);
    final rawHex = '0x${_hex(raw)}';
    final sender = broadcast ?? this.broadcast;
    final hash = sender == null
        ? '0x${_hex(QuickCrypto.keccack256Hash(raw))}'
        : await sender(rawHex);
    return WalletTransferResult(
      hash: hash,
      status: sender == null ? '已签名' : '已广播',
    );
  }

  static String decimalToBaseUnits(String value, {int decimals = 18}) {
    if (decimals < 0 || decimals > 36) {
      throw const FormatException('代币精度无效');
    }
    final parts = value.trim().split('.');
    if (parts.length > 2 || parts.first.isEmpty) {
      throw const FormatException('金额格式无效');
    }
    final whole = BigInt.parse(parts.first);
    final fractionText = parts.length > 1 ? parts[1] : '';
    if (fractionText.length > decimals) {
      throw FormatException('金额精度最多 $decimals 位');
    }
    final paddedFraction = fractionText.padRight(decimals, '0');
    final fraction = BigInt.parse(
      paddedFraction.isEmpty ? '0' : paddedFraction,
    );
    return (whole * BigInt.from(10).pow(decimals) + fraction).toString();
  }

  static BigInt _hexToBigInt(String value) {
    final normalized = value.startsWith('0x') ? value.substring(2) : value;
    return normalized.isEmpty
        ? BigInt.zero
        : BigInt.parse(normalized, radix: 16);
  }

  static List<int> _hexToBytes(String value) {
    final normalized = value.startsWith('0x') ? value.substring(2) : value;
    if (normalized.isEmpty) return const [];
    final padded = normalized.length.isOdd ? '0$normalized' : normalized;
    return List<int>.generate(
      padded.length ~/ 2,
      (index) =>
          int.parse(padded.substring(index * 2, index * 2 + 2), radix: 16),
    );
  }

  static String _encodeAddress(String value) {
    final normalized = value.toLowerCase().replaceFirst('0x', '');
    if (normalized.length != 40 ||
        !RegExp(r'^[0-9a-f]+$').hasMatch(normalized)) {
      throw const FormatException('EVM 地址无效');
    }
    return normalized.padLeft(64, '0');
  }

  static String _encodeUint(BigInt value) =>
      value.toRadixString(16).padLeft(64, '0');

  static String _weiToDecimal(BigInt value) {
    final whole = value ~/ BigInt.from(10).pow(18);
    final fraction = value
        .remainder(BigInt.from(10).pow(18))
        .toString()
        .padLeft(18, '0')
        .replaceFirst(RegExp(r'0+$'), '');
    return fraction.isEmpty ? whole.toString() : '$whole.$fraction';
  }

  static List<int> _addressBytes(String value) => _hexBytes(value.substring(2));
  static List<int> _hexBytes(String value) => List.generate(
    value.length ~/ 2,
    (i) => int.parse(value.substring(i * 2, i * 2 + 2), radix: 16),
  );
  static List<int> _intBytes(int value) =>
      value == 0 ? <int>[] : _bigIntBytes(BigInt.from(value));
  static List<int> _bigIntBytes(BigInt value) {
    if (value == BigInt.zero) return <int>[];
    final out = <int>[];
    var n = value;
    while (n > BigInt.zero) {
      out.insert(0, (n & BigInt.from(255)).toInt());
      n >>= 8;
    }
    return out;
  }

  static List<int> _rlp(List<List<int>> values) {
    final body = values.expand((v) => [..._rlpItem(v)]).toList();
    return [..._rlpPrefix(192, body.length), ...body];
  }

  static List<int> _rlpItem(List<int> value) =>
      value.length == 1 && value.first < 128
      ? value
      : [..._rlpPrefix(128, value.length), ...value];
  static List<int> _rlpPrefix(int offset, int length) {
    if (length < 56) return [offset + length];
    final bytes = _bigIntBytes(BigInt.from(length));
    return [offset + 55 + bytes.length, ...bytes];
  }

  static String _hex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
