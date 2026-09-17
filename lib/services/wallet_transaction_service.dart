import 'package:aco_chat/features/account/data/account_api_client.dart';
import 'package:aco_chat/features/account/data/account_token_store.dart';
import 'package:aco_chat/services/wallet_portfolio_models.dart';
import 'package:aco_chat/services/wallet_transaction_models.dart';

class WalletTransactionService {
  WalletTransactionService({
    AccountApiClient? apiClient,
    AccountTokenStore? tokenStore,
  }) : _apiClient = apiClient ?? AccountApiClient(),
       _tokenStore = tokenStore ?? SecureAccountTokenStore(),
       _ownsApiClient = apiClient == null;

  final AccountApiClient _apiClient;
  final AccountTokenStore _tokenStore;
  final bool _ownsApiClient;

  Future<WalletTransactionPage> loadPage({
    required WalletNetwork network,
    required WalletBalance asset,
    required WalletTransactionDirection direction,
    required int page,
    int limit = 20,
  }) async {
    final tokens = await _tokenStore.read();
    if (tokens == null) throw StateError('No access token is available');
    return _apiClient.listWalletTransactions(
      network: network,
      address: asset.address,
      contractAddress: asset.tokenAddress,
      direction: direction,
      page: page,
      limit: limit,
      token: tokens.accessToken,
    );
  }

  void close() {
    if (_ownsApiClient) _apiClient.close();
  }
}
