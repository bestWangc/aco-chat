import 'package:aco_chat/services/wallet_chain_registry.dart';
import 'package:aco_chat/services/wallet_portfolio_models.dart';
import 'package:aco_chat/services/wallet_rpc_client.dart';

/// Reads native SOL and SPL token balances for one account.
class SolanaBalanceReader {
  const SolanaBalanceReader(this._rpcClient);

  final WalletRpcClient _rpcClient;

  Future<List<WalletBalance>> loadBalances({
    required WalletChainDefinition chain,
    required String address,
    required List<Uri> rpcEndpoints,
  }) async {
    final nativeBalance = _loadNativeBalance(chain, address, rpcEndpoints);
    final tokenBalances = await _loadTokenBalances(
      chain,
      address,
      rpcEndpoints,
    );
    return [
      await nativeBalance,
      ...tokenBalances,
      if (!tokenBalances.any(
        (balance) => balance.symbol == WalletChainRegistry.solanaUsdt.symbol,
      ))
        _zeroTokenBalance(chain, WalletChainRegistry.solanaUsdt, address),
    ];
  }

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
    decimals: chain.decimals,
    request: () => _nativeBalance(address, rpcEndpoints),
  );

  Future<BigInt> _nativeBalance(String address, List<Uri> rpcEndpoints) async {
    final body = await _rpcClient.postJson(rpcEndpoints, {
      'jsonrpc': '2.0',
      'id': 1,
      'method': 'getBalance',
      'params': [address],
    });
    final result = body['result'];
    if (result is! Map || result['value'] is! num) {
      throw const FormatException('Missing RPC result');
    }
    return BigInt.from(result['value'] as num);
  }

  Future<List<WalletBalance>> _loadTokenBalances(
    WalletChainDefinition chain,
    String address,
    List<Uri> rpcEndpoints,
  ) async {
    try {
      final responses = await Future.wait([
        for (final programId in WalletChainRegistry.solanaTokenProgramIds)
          _rpcClient.postJson(rpcEndpoints, {
            'jsonrpc': '2.0',
            'id': 2,
            'method': 'getTokenAccountsByOwner',
            'params': [
              address,
              {'programId': programId},
              {'encoding': 'jsonParsed'},
            ],
          }),
      ]);
      return [
        for (final response in responses)
          ..._parseTokenBalances(chain, address, response),
      ];
    } catch (_) {
      // A token-account lookup failure must not hide the SOL balance.
      return const [];
    }
  }

  List<WalletBalance> _parseTokenBalances(
    WalletChainDefinition chain,
    String address,
    Map<String, dynamic> response,
  ) {
    final result = response['result'];
    if (result is! Map || result['value'] is! List) {
      throw const FormatException('Missing SPL token accounts');
    }
    return [
      for (final account in result['value'])
        if (account is Map) _parseTokenBalance(chain, address, account),
    ];
  }

  WalletBalance _parseTokenBalance(
    WalletChainDefinition chain,
    String ownerAddress,
    Map account,
  ) {
    final accountData = account['account'];
    if (accountData is! Map) {
      throw const FormatException('Missing SPL token account data');
    }
    final data = accountData['data'];
    if (data is! Map) {
      throw const FormatException('Missing SPL token account payload');
    }
    final parsed = data['parsed'];
    if (parsed is! Map) {
      throw const FormatException('Missing SPL token account details');
    }
    final info = parsed['info'];
    if (info is! Map) throw const FormatException('Missing SPL token info');
    final tokenAmount = info['tokenAmount'];
    final mint = info['mint'];
    if (tokenAmount is! Map || mint is! String) {
      throw const FormatException('Missing SPL token amount');
    }
    final amount = tokenAmount['amount'];
    final decimals = tokenAmount['decimals'];
    if (amount is! String || decimals is! num) {
      throw const FormatException('Invalid SPL token amount');
    }
    final token = WalletChainRegistry.solanaKnownTokens[mint];
    return WalletBalance(
      chain: chain.name,
      symbol: token?.symbol ?? 'SPL',
      assetName: token?.name ?? 'SPL Token ${_shortAddress(mint)}',
      isNative: false,
      address: ownerAddress,
      decimals: decimals.toInt(),
      tokenAddress: mint,
      balance: BigInt.parse(amount),
    );
  }

  WalletBalance _zeroTokenBalance(
    WalletChainDefinition chain,
    WalletTokenDefinition token,
    String address,
  ) => WalletBalance(
    chain: chain.name,
    symbol: token.symbol,
    assetName: token.name,
    isNative: false,
    address: address,
    decimals: token.decimals,
    tokenAddress: token.address,
    balance: BigInt.zero,
  );
}

String _shortAddress(String address) =>
    '${address.substring(0, 4)}...${address.substring(address.length - 4)}';
