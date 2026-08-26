import 'package:aco_chat/services/wallet_chain_registry.dart';
import 'package:aco_chat/services/wallet_portfolio_models.dart';
import 'package:aco_chat/services/wallet_rpc_client.dart';

/// Reads native and ERC-20 balances from an EVM JSON-RPC endpoint.
///
/// Transport failover is delegated to [WalletRpcClient]. Individual balance
/// requests deliberately resolve to a zero balance with the failure attached,
/// so a token failure never hides the chain's native balance (and vice versa).
class EvmBalanceReader {
  const EvmBalanceReader(this._rpcClient);

  final WalletRpcClient _rpcClient;

  Future<List<WalletBalance>> loadBalances({
    required WalletChainDefinition chain,
    required String address,
    required List<Uri> rpcEndpoints,
  }) => Future.wait([
    _loadNativeBalance(chain, address, rpcEndpoints),
    if (chain.usdt != null) _loadUsdtBalance(chain, address, rpcEndpoints),
  ]);

  Future<WalletBalance> _loadNativeBalance(
    WalletChainDefinition chain,
    String address,
    List<Uri> rpcEndpoints,
  ) => loadWalletBalance(
    chain: chain.name,
    symbol: chain.symbol,
    assetName: chain.nativeAssetName,
    isNative: true,
    address: address,
    decimals: 18,
    request: () => _nativeBalance(address, rpcEndpoints),
  );

  Future<WalletBalance> _loadUsdtBalance(
    WalletChainDefinition chain,
    String address,
    List<Uri> rpcEndpoints,
  ) {
    final usdt = chain.usdt!;
    return loadWalletBalance(
      chain: chain.name,
      symbol: usdt.symbol,
      assetName: usdt.name,
      isNative: false,
      address: address,
      decimals: usdt.decimals,
      tokenAddress: usdt.address,
      request: () => _erc20Balance(usdt.address, address, rpcEndpoints),
    );
  }

  Future<BigInt> _nativeBalance(String address, List<Uri> rpcEndpoints) async {
    final body = await _rpcClient.postJson(rpcEndpoints, {
      'jsonrpc': '2.0',
      'id': 1,
      'method': 'eth_getBalance',
      'params': [address, 'latest'],
    });
    return _hexBalance(body);
  }

  Future<BigInt> _erc20Balance(
    String tokenAddress,
    String walletAddress,
    List<Uri> rpcEndpoints,
  ) async {
    final callData = '0x70a08231${walletAddress.substring(2).padLeft(64, '0')}';
    final body = await _rpcClient.postJson(rpcEndpoints, {
      'jsonrpc': '2.0',
      'id': 2,
      'method': 'eth_call',
      'params': [
        {'to': tokenAddress, 'data': callData},
        'latest',
      ],
    });
    return _hexBalance(body);
  }

  BigInt _hexBalance(Map<String, dynamic> body) {
    final result = body['result'];
    if (result == '0x') return BigInt.zero;
    if (result is! String || !result.startsWith('0x')) {
      throw const FormatException('Missing RPC result');
    }
    return BigInt.parse(result.substring(2), radix: 16);
  }
}
