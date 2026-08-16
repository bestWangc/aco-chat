import 'dart:async';
import 'dart:convert';

import 'package:aco_chat/core/config/app_config.dart';
import 'package:aco_chat/services/wallet_identity.dart';
import 'package:http/http.dart' as http;

enum WalletNetwork {
  ethereum,
  bsc,
  polygon,
  arbitrum,
  optimism,
  tron,
  solana,
  base,
}

class WalletBalance {
  const WalletBalance({
    required this.chain,
    required this.symbol,
    required this.assetName,
    required this.isNative,
    required this.address,
    required this.decimals,
    this.tokenAddress,
    this.balance,
    this.error,
  });

  final String chain;
  final String symbol;
  final String assetName;
  final bool isNative;
  final String address;
  final int decimals;

  /// ERC-20/TRC-20 contract address or SPL mint address. Native assets have
  /// no token contract and therefore use `null`.
  final String? tokenAddress;
  final BigInt? balance;
  final Object? error;

  bool get isAvailable => balance != null;
}

/// Fetches wallet balances from public JSON-RPC nodes.
///
/// Fiat valuation and token metadata need an indexer or price feed. Every
/// reported balance remains authoritative on-chain. The app API proxies every
/// request, so endpoint selection and failover stay server-side.
class WalletPortfolioService {
  WalletPortfolioService({http.Client? client, Uri? rpcProxyBaseUri})
    : _rpcProxyBaseUri =
          rpcProxyBaseUri ?? Uri.parse(const AppConfig().apiBaseUrl),
      _client = client ?? http.Client(),
      _ownsClient = client == null;

  static const _requestTimeout = Duration(seconds: 5);
  final http.Client _client;
  final bool _ownsClient;
  final Uri _rpcProxyBaseUri;

  Future<List<WalletBalance>> loadBalances({
    required WalletNetwork network,
    required WalletIdentity identity,
    required Map<String, String> derivedAddresses,
  }) {
    final chain = _chains[network]!;
    if (chain.isEvm) {
      return Future.wait([
        _loadNativeBalance(chain, identity.address),
        if (chain.usdt != null) _loadUsdtBalance(chain, identity.address),
      ]);
    }
    final address = derivedAddresses[chain.addressKey];
    if (address == null) {
      return Future.value([
        WalletBalance(
          chain: chain.name,
          symbol: chain.symbol,
          assetName: chain.nativeAssetName,
          isNative: true,
          address: '',
          decimals: chain.decimals,
          balance: BigInt.zero,
        ),
        if (network == WalletNetwork.tron) _zeroTokenBalance(chain, _tronUsdt),
        if (network == WalletNetwork.solana)
          _zeroTokenBalance(chain, _solanaUsdt),
      ]);
    }
    if (network == WalletNetwork.solana) {
      return _loadSolanaBalances(chain, address);
    }
    if (network == WalletNetwork.tron) {
      return _loadTronBalances(chain, address);
    }
    return Future.wait([_loadNonEvmBalance(chain, address)]);
  }

  Future<WalletBalance> _loadNativeBalance(_Chain chain, String address) =>
      _load(
        chain: chain.name,
        symbol: chain.symbol,
        assetName: chain.nativeAssetName,
        isNative: true,
        address: address,
        decimals: 18,
        request: () => _nativeBalance(chain, address),
      );

  Future<WalletBalance> _loadUsdtBalance(_Chain chain, String address) {
    final usdt = chain.usdt!;
    return _load(
      chain: chain.name,
      symbol: 'USDT',
      assetName: usdt.name,
      isNative: false,
      address: address,
      decimals: usdt.decimals,
      tokenAddress: usdt.address,
      request: () async {
        final callData = '0x70a08231${address.substring(2).padLeft(64, '0')}';
        final body = await _postJson(chain, {
          'jsonrpc': '2.0',
          'id': 2,
          'method': 'eth_call',
          'params': [
            {'to': usdt.address, 'data': callData},
            'latest',
          ],
        });
        return _hexBalance(body);
      },
    );
  }

  Future<BigInt> _nativeBalance(_Chain chain, String address) async {
    final body = await _postJson(chain, {
      'jsonrpc': '2.0',
      'id': 1,
      'method': 'eth_getBalance',
      'params': [address, 'latest'],
    });
    return _hexBalance(body);
  }

  Future<WalletBalance> _loadNonEvmBalance(_Chain chain, String address) =>
      _load(
        chain: chain.name,
        symbol: chain.symbol,
        assetName: chain.nativeAssetName,
        isNative: true,
        address: address,
        decimals: chain.decimals,
        request: () => switch (chain.network) {
          WalletNetwork.tron => _tronBalance(chain, address),
          WalletNetwork.solana => _solanaBalance(chain, address),
          _ => throw StateError('Unsupported non-EVM network'),
        },
      );

  Future<BigInt> _tronBalance(_Chain chain, String address) async {
    final body = await _tronAccount(chain, address);
    return _tronNativeBalance(body);
  }

  Future<Map<String, dynamic>> _tronAccount(_Chain chain, String address) =>
      _postJson(chain, {'address': address, 'visible': true});

  BigInt _tronNativeBalance(Map<String, dynamic> body) =>
      BigInt.from((body['balance'] as num?) ?? 0);

  Future<List<WalletBalance>> _loadTronBalances(_Chain chain, String address) {
    final account = _tronAccount(chain, address);
    return Future.wait([
      _load(
        chain: chain.name,
        symbol: chain.symbol,
        assetName: chain.nativeAssetName,
        isNative: true,
        address: address,
        decimals: chain.decimals,
        request: () async => _tronNativeBalance(await account),
      ),
      _loadTronUsdtBalance(chain, address, account),
    ]);
  }

  Future<WalletBalance> _loadTronUsdtBalance(
    _Chain chain,
    String address,
    Future<Map<String, dynamic>> account,
  ) => _load(
    chain: chain.name,
    symbol: _tronUsdt.symbol,
    assetName: _tronUsdt.name,
    isNative: false,
    address: address,
    decimals: _tronUsdt.decimals,
    tokenAddress: _tronUsdt.address,
    request: () async => _tronTrc20Balance(await account, _tronUsdt.address),
  );

  BigInt _tronTrc20Balance(Map<String, dynamic> body, String contract) {
    final trc20 = body['trc20'];
    if (trc20 is! List) return BigInt.zero;
    for (final token in trc20) {
      if (token is! Map) continue;
      final balance = token[contract];
      if (balance is String) return BigInt.parse(balance);
      if (balance is num) return BigInt.from(balance);
    }
    return BigInt.zero;
  }

  Future<BigInt> _solanaBalance(_Chain chain, String address) async {
    final body = await _postJson(chain, {
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

  Future<List<WalletBalance>> _loadSolanaBalances(
    _Chain chain,
    String address,
  ) async {
    final nativeBalance = _loadNonEvmBalance(chain, address);
    final tokenBalances = _loadSolanaTokenBalances(chain, address);
    final loadedTokens = await tokenBalances;
    return [
      await nativeBalance,
      ...loadedTokens,
      if (!loadedTokens.any((balance) => balance.symbol == _solanaUsdt.symbol))
        _zeroTokenBalance(chain, _solanaUsdt, address: address),
    ];
  }

  Future<List<WalletBalance>> _loadSolanaTokenBalances(
    _Chain chain,
    String address,
  ) async {
    try {
      final responses = await Future.wait([
        for (final programID in _solanaTokenProgramIDs)
          _postJson(chain, {
            'jsonrpc': '2.0',
            'id': 2,
            'method': 'getTokenAccountsByOwner',
            'params': [
              address,
              {'programId': programID},
              {'encoding': 'jsonParsed'},
            ],
          }),
      ]);
      return [
        for (final response in responses)
          ..._parseSolanaTokenBalances(chain, address, response),
      ];
    } catch (_) {
      // A token-account lookup failure must not hide the SOL balance.
      return const [];
    }
  }

  List<WalletBalance> _parseSolanaTokenBalances(
    _Chain chain,
    String address,
    Map<String, dynamic> response,
  ) {
    final result = response['result'];
    if (result is! Map || result['value'] is! List) {
      throw const FormatException('Missing SPL token accounts');
    }
    return [
      for (final account in result['value'])
        if (account is Map) _parseSolanaTokenBalance(chain, address, account),
    ];
  }

  WalletBalance _parseSolanaTokenBalance(
    _Chain chain,
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
    if (info is! Map) {
      throw const FormatException('Missing SPL token info');
    }
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
    final token = _solanaKnownTokens[mint];
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

  static const _chains = <WalletNetwork, _Chain>{
    WalletNetwork.ethereum: _Chain.evm(
      WalletNetwork.ethereum,
      'Ethereum',
      'ETH',
      'Ethereum',
      _Token('0xdAC17F958D2ee523a2206206994597C13D831ec7', 6, 'Tether USD'),
    ),
    WalletNetwork.bsc: _Chain.evm(
      WalletNetwork.bsc,
      'BNB Smart Chain',
      'BNB',
      'BNB',
      _Token('0x55d398326f99059fF775485246999027B3197955', 18, 'Tether USD'),
    ),
    WalletNetwork.polygon: _Chain.evm(
      WalletNetwork.polygon,
      'Polygon',
      'POL',
      'Polygon Ecosystem Token',
      _Token('0xc2132D05D31c914a87C6611C10748AEb04B58e8F', 6, 'Tether USD'),
    ),
    WalletNetwork.base: _Chain.evm(
      WalletNetwork.base,
      'Base',
      'ETH',
      'Ethereum',
      _Token('0xfde4c96c8593536e31f229ea8f37b2ada2699bb2', 6, 'Tether USD'),
    ),
    WalletNetwork.arbitrum: _Chain.evm(
      WalletNetwork.arbitrum,
      'Arbitrum One',
      'ETH',
      'Ethereum',
      _Token('0xfd086bc7cd5c481dcc9c85ebe478a1c0b69fcbb9', 6, 'Tether USD'),
    ),
    WalletNetwork.optimism: _Chain.evm(
      WalletNetwork.optimism,
      'Optimism',
      'ETH',
      'Ethereum',
      _Token('0x94b008aA00579c1307B0EF2C499aD98a8ce58e58', 6, 'Tether USD'),
    ),
    WalletNetwork.tron: _Chain.nonEvm(
      WalletNetwork.tron,
      'TRON',
      'TRX',
      'TRON',
      'tron',
      6,
    ),
    WalletNetwork.solana: _Chain.nonEvm(
      WalletNetwork.solana,
      'Solana',
      'SOL',
      'Solana',
      'solana',
      9,
    ),
  };

  static const _solanaTokenProgramIDs = [
    'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA',
    'TokenzQdBNbLqP5VEhdkAS6EPFwh6G9s34M3iKkj1P',
  ];

  // Official Tether USD mainnet identifiers for their native token programs.
  static const _tronUsdt = _Token(
    'TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t',
    6,
    'Tether USD',
  );
  static const _solanaUsdt = _Token(
    'Es9vMFrzaCERmJfrF4H2FYD4KCoNkY11McCe8BenwNYB',
    6,
    'Tether USD',
  );

  static final _solanaKnownTokens = {
    'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v': _Token(
      'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v',
      6,
      'USD Coin',
      symbol: 'USDC',
    ),
    'Es9vMFrzaCERmJfrF4H2FYD4KCoNkY11McCe8BenwNYB': _solanaUsdt,
  };

  BigInt _hexBalance(Map<String, dynamic> body) {
    final result = body['result'];
    if (result == '0x') return BigInt.zero;
    if (result is! String || !result.startsWith('0x')) {
      throw const FormatException('Missing RPC result');
    }
    return BigInt.parse(result.substring(2), radix: 16);
  }

  void close() {
    if (_ownsClient) {
      _client.close();
    }
  }

  Future<WalletBalance> _load({
    required String chain,
    required String symbol,
    required String assetName,
    required bool isNative,
    required String address,
    required int decimals,
    String? tokenAddress,
    required Future<BigInt> Function() request,
  }) async {
    try {
      return WalletBalance(
        chain: chain,
        symbol: symbol,
        assetName: assetName,
        isNative: isNative,
        address: address,
        decimals: decimals,
        tokenAddress: tokenAddress,
        balance: await request(),
      );
    } catch (error) {
      return WalletBalance(
        chain: chain,
        symbol: symbol,
        assetName: assetName,
        isNative: isNative,
        address: address,
        decimals: decimals,
        tokenAddress: tokenAddress,
        balance: BigInt.zero,
        error: error,
      );
    }
  }

  WalletBalance _zeroTokenBalance(
    _Chain chain,
    _Token token, {
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

  Future<Map<String, dynamic>> _postJson(
    _Chain chain,
    Map<String, Object> request,
  ) async {
    return _postJsonToUri(_rpcUri(chain), request);
  }

  Future<Map<String, dynamic>> _postJsonToUri(
    Uri uri,
    Map<String, Object> request,
  ) async {
    final response = await _client
        .post(
          uri,
          headers: const {'content-type': 'application/json'},
          body: jsonEncode(request),
        )
        .timeout(_requestTimeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('RPC request failed: ${response.statusCode}');
    }
    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic> || body['error'] != null) {
      throw const FormatException('Invalid RPC response');
    }
    return body;
  }

  Uri _rpcUri(_Chain chain) {
    final basePath = _rpcProxyBaseUri.path.endsWith('/')
        ? _rpcProxyBaseUri.path.substring(0, _rpcProxyBaseUri.path.length - 1)
        : _rpcProxyBaseUri.path;
    return _rpcProxyBaseUri.replace(
      path: '$basePath/wallets/rpc/${chain.network.name}',
    );
  }
}

class _Chain {
  const _Chain.evm(
    this.network,
    this.name,
    this.symbol,
    this.nativeAssetName,
    this.usdt,
  ) : addressKey = null,
      decimals = 18;

  const _Chain.nonEvm(
    this.network,
    this.name,
    this.symbol,
    this.nativeAssetName,
    this.addressKey,
    this.decimals,
  ) : usdt = null;

  final String name;
  final String symbol;
  final String nativeAssetName;
  final _Token? usdt;
  final WalletNetwork network;
  final String? addressKey;
  final int decimals;

  bool get isEvm => addressKey == null;
}

class _Token {
  const _Token(this.address, this.decimals, this.name, {this.symbol = 'USDT'});

  final String address;
  final int decimals;
  final String name;
  final String symbol;
}

String _shortAddress(String address) =>
    '${address.substring(0, 4)}...${address.substring(address.length - 4)}';

String formatChainAmount(BigInt amount, {required int decimals}) {
  final whole = amount ~/ BigInt.from(10).pow(decimals);
  final fraction = (amount % BigInt.from(10).pow(decimals))
      .toString()
      .padLeft(decimals, '0')
      .replaceFirst(RegExp(r'0+$'), '');
  final visibleFraction = fraction.length > 6
      ? fraction.substring(0, 6)
      : fraction;
  return fraction.isEmpty ? whole.toString() : '$whole.$visibleFraction';
}

class HttpException implements Exception {
  const HttpException(this.message);
  final String message;
}
