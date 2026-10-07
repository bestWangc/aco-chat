import 'package:blockchain_utils/blockchain_utils.dart';
import 'package:aco_chat/services/wallet_identity.dart';
import 'package:aco_chat/services/wallet_rpc_client.dart';
import 'package:aco_chat/services/wallet_portfolio_models.dart';

class WalletTransferResult {
  const WalletTransferResult({required this.hash, required this.status});
  final String hash;
  final String status;
}

class WalletFeeEstimate {
  const WalletFeeEstimate({
    required this.gasLimit,
    required this.gasPriceWei,
    required this.feeWei,
    required this.nativeBalanceWei,
    required this.assetBalanceWei,
  });

  final BigInt gasLimit;
  final BigInt gasPriceWei;
  final BigInt feeWei;
  final BigInt nativeBalanceWei;
  final BigInt assetBalanceWei;

  bool get hasSufficientNativeBalance => nativeBalanceWei >= feeWei;
}

/// Builds and signs an EVM native transfer. Broadcasting is injected so the
/// same signing path can be used by production RPC clients and tests.
class WalletTransferService {
  const WalletTransferService({this.broadcast});
  final Future<String> Function(String rawTransaction)? broadcast;

  /// Estimates a native or ERC-20 EVM transfer using the configured RPC.
  /// The estimate includes the current native balance and the asset balance,
  /// so the caller can keep the submit action disabled until both checks pass.
  Future<WalletFeeEstimate> estimateEvmTransfer({
    required String from,
    required String to,
    required WalletNetwork network,
    required String accessToken,
    required WalletRpcClient rpc,
    required BigInt amountRaw,
    String? tokenAddress,
  }) async {
    if (tokenAddress != null && tokenAddress.isNotEmpty) {
      _validateEvmAddress(tokenAddress);
    }
    _validateEvmAddress(from);
    _validateEvmAddress(to);
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

    final isToken = tokenAddress != null && tokenAddress.isNotEmpty;
    final data = isToken ? _transferData(to, amountRaw) : '0x';
    final target = isToken ? tokenAddress : to;
    final value = isToken ? '0x0' : _quantity(amountRaw);
    final gasResponse = await call('eth_estimateGas', [
      {'from': from, 'to': target, 'value': value, 'data': data},
    ]);
    final gasLimit = _hexToBigInt(gasResponse['result'] as String? ?? '0x0');
    if (gasLimit <= BigInt.zero) {
      throw const FormatException('节点无法估算网络费');
    }
    final gasPrice = _hexToBigInt(
      (await call('eth_gasPrice', const []))['result'] as String? ?? '0x0',
    );
    final nativeBalance = _hexToBigInt(
      (await call('eth_getBalance', [from, 'latest']))['result'] as String? ??
          '0x0',
    );
    final assetBalance = isToken
        ? _hexToBigInt(
            (await call('eth_call', [
                      {
                        'to': tokenAddress,
                        'data': '0x70a08231${_encodeAddress(from)}',
                      },
                      'latest',
                    ]))['result']
                    as String? ??
                '0x0',
          )
        : nativeBalance;
    return WalletFeeEstimate(
      gasLimit: gasLimit,
      gasPriceWei: gasPrice,
      feeWei: gasLimit * gasPrice,
      nativeBalanceWei: nativeBalance,
      assetBalanceWei: assetBalance,
    );
  }

  /// Signs and broadcasts either a native EVM transfer or an ERC-20 transfer.
  Future<WalletTransferResult> executeEvmTransferWithRpc({
    required String mnemonic,
    required String from,
    required String to,
    required WalletNetwork network,
    required String accessToken,
    required WalletRpcClient rpc,
    required BigInt amountRaw,
    String? tokenAddress,
  }) async {
    final estimate = await estimateEvmTransfer(
      from: from,
      to: to,
      network: network,
      accessToken: accessToken,
      rpc: rpc,
      amountRaw: amountRaw,
      tokenAddress: tokenAddress,
    );
    final isToken = tokenAddress != null && tokenAddress.isNotEmpty;
    if (estimate.assetBalanceWei < amountRaw) {
      throw const FormatException('资产余额不足');
    }
    if (estimate.nativeBalanceWei < estimate.feeWei) {
      throw const FormatException('原生币余额不足以支付网络费');
    }
    if (!isToken && estimate.nativeBalanceWei < amountRaw + estimate.feeWei) {
      throw const FormatException('余额不足（包含网络费）');
    }

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
    final nonce = _hexToBigInt(
      (await call('eth_getTransactionCount', [from, 'pending']))['result']
              as String? ??
          '0x0',
    );
    final chainId = _hexToBigInt(
      (await call('eth_chainId', const []))['result'] as String? ?? '0x0',
    );
    return execute(
      mnemonic: mnemonic,
      from: from,
      to: isToken ? tokenAddress : to,
      amount: '0',
      valueBaseUnits: isToken ? BigInt.zero : amountRaw,
      chainId: chainId.toInt(),
      nonce: nonce.toInt(),
      gasPriceWei: estimate.gasPriceWei.toInt(),
      gasLimit: estimate.gasLimit.toInt(),
      data: isToken ? _hexToBytes(_transferData(to, amountRaw)) : const [],
      broadcast: (raw) async =>
          (await call('eth_sendRawTransaction', [raw]))['result'] as String,
    );
  }

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

  /// Waits until an ERC-20 allowance is visible on the chain after approval.
  Future<bool> waitForErc20AllowanceWithRpc({
    required WalletNetwork network,
    required String accessToken,
    required WalletRpcClient rpc,
    required String owner,
    required String tokenAddress,
    required String spender,
    required String requiredAmount,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final endpoints = await rpc.loadEndpoints(
      network: network.name,
      accessToken: accessToken,
    );
    final data = '0xdd62ed3e${_encodeAddress(owner)}${_encodeAddress(spender)}';
    final required = BigInt.parse(requiredAmount);
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final response = await rpc.postJson(endpoints, {
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'eth_call',
        'params': [
          {'to': tokenAddress, 'data': data},
          'latest',
        ],
      });
      final allowance = _hexToBigInt(response['result'] as String? ?? '0x0');
      if (allowance >= required) return true;
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    return false;
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
    BigInt? valueBaseUnits,
    Future<String> Function(String rawTransaction)? broadcast,
  }) async {
    final value = valueBaseUnits ?? BigInt.parse(decimalToBaseUnits(amount));
    final privateKey = WalletIdentity.privateKeyFromMnemonic(mnemonic);
    final unsigned = _rlp([
      _intBytes(nonce),
      _intBytes(gasPriceWei),
      _intBytes(gasLimit),
      _addressBytes(to),
      _bigIntBytes(value),
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
      _bigIntBytes(value),
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

  static void _validateEvmAddress(String value) {
    if (!RegExp(r'^0x[0-9a-fA-F]{40}$').hasMatch(value)) {
      throw const FormatException('EVM 地址无效');
    }
  }

  static String _transferData(String recipient, BigInt amount) =>
      '0xa9059cbb${_encodeAddress(recipient)}${_encodeUint(amount)}';

  static String _quantity(BigInt value) => '0x${value.toRadixString(16)}';

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
