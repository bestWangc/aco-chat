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

  Future<WalletTransferResult> executeWithRpc({
    required String mnemonic,
    required String from,
    required String to,
    required String amount,
    required WalletNetwork network,
    required String accessToken,
    required WalletRpcClient rpc,
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
    Future<String> Function(String rawTransaction)? broadcast,
  }) async {
    final value = _decimalToWei(amount);
    final privateKey = WalletIdentity.privateKeyFromMnemonic(mnemonic);
    final unsigned = _rlp([
      _intBytes(nonce),
      _intBytes(gasPriceWei),
      _intBytes(gasLimit),
      _addressBytes(to),
      _intBytes(value),
      <int>[],
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
      <int>[],
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

  static int _decimalToWei(String value) {
    final parts = value.trim().split('.');
    final whole = int.parse(parts.first);
    final fraction = (parts.length > 1 ? parts[1] : '').padRight(18, '0');
    if (fraction.length > 18) throw const FormatException('金额精度最多 18 位');
    return whole * 1000000000000000000 +
        int.parse(fraction.isEmpty ? '0' : fraction);
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
