import 'package:aco_chat/services/wallet_chain_registry.dart';
import 'package:aco_chat/services/wallet_portfolio_models.dart';
import 'package:aco_chat/services/wallet_rpc_client.dart';

/// Reads the native TRX and configured TRC-20 balances for one account.
class TronBalanceReader {
  const TronBalanceReader(this._rpcClient);

  final WalletRpcClient _rpcClient;

  Future<WalletBalance> loadAssetBalance({
    required WalletAsset asset,
    required WalletChainDefinition chain,
    required String address,
    required List<Uri> rpcEndpoints,
  }) => loadWalletBalance(
    chain: chain.name,
    symbol: asset.symbol,
    assetName: asset.name,
    isNative: asset.isNative,
    address: address,
    decimals: asset.decimals,
    tokenAddress: asset.tokenAddress,
    request: () async {
      final account = await _rpcClient.postJson(rpcEndpoints, {
        'address': address,
        'visible': true,
      });
      return asset.isNative
          ? _nativeBalance(account)
          : _trc20Balance(account, asset.tokenAddress!);
    },
  );

  Future<List<WalletBalance>> loadBalances({
    required WalletChainDefinition chain,
    required String address,
    required List<Uri> rpcEndpoints,
  }) {
    final account = _rpcClient.postJson(rpcEndpoints, {
      'address': address,
      'visible': true,
    });
    return Future.wait([
      loadWalletBalance(
        chain: chain.name,
        symbol: chain.symbol,
        assetName: chain.nativeAssetName,
        isNative: true,
        address: address,
        decimals: chain.decimals,
        request: () async => _nativeBalance(await account),
      ),
      loadWalletBalance(
        chain: chain.name,
        symbol: WalletChainRegistry.tronUsdt.symbol,
        assetName: WalletChainRegistry.tronUsdt.name,
        isNative: false,
        address: address,
        decimals: WalletChainRegistry.tronUsdt.decimals,
        tokenAddress: WalletChainRegistry.tronUsdt.address,
        request: () async =>
            _trc20Balance(await account, WalletChainRegistry.tronUsdt.address),
      ),
      loadWalletBalance(
        chain: chain.name,
        symbol: WalletChainRegistry.tronUsdc.symbol,
        assetName: WalletChainRegistry.tronUsdc.name,
        isNative: false,
        address: address,
        decimals: WalletChainRegistry.tronUsdc.decimals,
        tokenAddress: WalletChainRegistry.tronUsdc.address,
        request: () async =>
            _trc20Balance(await account, WalletChainRegistry.tronUsdc.address),
      ),
    ]);
  }

  BigInt _nativeBalance(Map<String, dynamic> account) =>
      BigInt.from((account['balance'] as num?) ?? 0);

  BigInt _trc20Balance(Map<String, dynamic> account, String contract) {
    final trc20 = account['trc20'];
    if (trc20 is! List) return BigInt.zero;
    for (final token in trc20) {
      if (token is! Map) continue;
      final balance = token[contract];
      if (balance is String) return BigInt.parse(balance);
      if (balance is num) return BigInt.from(balance);
    }
    return BigInt.zero;
  }
}
