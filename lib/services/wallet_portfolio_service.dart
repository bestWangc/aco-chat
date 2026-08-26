import 'dart:async';

import 'package:aco_chat/core/config/app_config.dart';
import 'package:aco_chat/services/wallet_identity.dart';
import 'package:http/http.dart' as http;

export 'wallet_portfolio_models.dart';
import 'package:aco_chat/services/wallet_portfolio_models.dart';
import 'package:aco_chat/services/wallet_chain_registry.dart';
import 'package:aco_chat/services/evm_balance_reader.dart';
import 'package:aco_chat/services/solana_balance_reader.dart';
import 'package:aco_chat/services/tron_balance_reader.dart';
import 'package:aco_chat/services/wallet_rpc_client.dart';

/// Fetches wallet balances from public JSON-RPC nodes.
///
/// Fiat valuation and token metadata need an indexer or price feed. Every
/// reported balance remains authoritative on-chain. The app API authenticates
/// requests for node URLs; the client then queries those public nodes directly.
class WalletPortfolioService {
  WalletPortfolioService({http.Client? client, Uri? rpcDirectoryBaseUri})
    : _rpcClient = WalletRpcClient(
        client: client ?? http.Client(),
        directoryBaseUri:
            rpcDirectoryBaseUri ?? Uri.parse(const AppConfig().apiBaseUrl),
        ownsClient: client == null,
      );

  final WalletRpcClient _rpcClient;
  late final EvmBalanceReader _evmReader = EvmBalanceReader(_rpcClient);
  late final SolanaBalanceReader _solanaReader = SolanaBalanceReader(
    _rpcClient,
  );
  late final TronBalanceReader _tronReader = TronBalanceReader(_rpcClient);

  Future<List<WalletBalance>> loadBalances({
    required WalletNetwork network,
    required WalletIdentity identity,
    required Map<String, String> derivedAddresses,
    required String accessToken,
  }) async {
    final chain = WalletChainRegistry.chains[network]!;
    final rpcEndpoints = await _rpcClient.loadEndpoints(
      network: chain.network.name,
      accessToken: accessToken,
    );
    if (chain.isEvm) {
      return _evmReader.loadBalances(
        chain: chain,
        address: identity.address,
        rpcEndpoints: rpcEndpoints,
      );
    }
    final address = derivedAddresses[chain.addressKey];
    if (address == null) {
      return [
        WalletBalance(
          chain: chain.name,
          symbol: chain.symbol,
          assetName: chain.nativeAssetName,
          isNative: true,
          address: '',
          decimals: chain.decimals,
          balance: BigInt.zero,
        ),
        if (network == WalletNetwork.tron)
          _zeroTokenBalance(chain, WalletChainRegistry.tronUsdt),
        if (network == WalletNetwork.solana)
          _zeroTokenBalance(chain, WalletChainRegistry.solanaUsdt),
      ];
    }
    if (network == WalletNetwork.solana) {
      return _solanaReader.loadBalances(
        chain: chain,
        address: address,
        rpcEndpoints: rpcEndpoints,
      );
    }
    if (network == WalletNetwork.tron) {
      return _tronReader.loadBalances(
        chain: chain,
        address: address,
        rpcEndpoints: rpcEndpoints,
      );
    }
    throw StateError('Unsupported wallet network: $network');
  }

  void close() {
    _rpcClient.close();
  }

  WalletBalance _zeroTokenBalance(
    WalletChainDefinition chain,
    WalletTokenDefinition token, {
    String address = '',
  }) => WalletBalance(
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
