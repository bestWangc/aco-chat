/// Networks supported by the wallet portfolio reader.
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
  final String? tokenAddress;
  final BigInt? balance;
  final Object? error;

  bool get isAvailable => balance != null;
}

/// Runs one asset lookup while preserving the portfolio's partial-failure
/// contract: unavailable assets are represented by a zero balance and error.
Future<WalletBalance> loadWalletBalance({
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
