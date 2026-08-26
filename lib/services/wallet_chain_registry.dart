import 'package:aco_chat/services/wallet_portfolio_models.dart';

class WalletChainDefinition {
  const WalletChainDefinition.evm(
    this.network,
    this.name,
    this.symbol,
    this.nativeAssetName,
    this.usdt,
  ) : addressKey = null,
      decimals = 18;

  const WalletChainDefinition.nonEvm(
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
  final WalletTokenDefinition? usdt;
  final WalletNetwork network;
  final String? addressKey;
  final int decimals;

  bool get isEvm => addressKey == null;
}

class WalletTokenDefinition {
  const WalletTokenDefinition(
    this.address,
    this.decimals,
    this.name, {
    this.symbol = 'USDT',
  });

  final String address;
  final int decimals;
  final String name;
  final String symbol;
}

abstract final class WalletChainRegistry {
  static const chains = <WalletNetwork, WalletChainDefinition>{
    WalletNetwork.ethereum: WalletChainDefinition.evm(
      WalletNetwork.ethereum,
      'Ethereum',
      'ETH',
      'Ethereum',
      WalletTokenDefinition(
        '0xdAC17F958D2ee523a2206206994597C13D831ec7',
        6,
        'Tether USD',
      ),
    ),
    WalletNetwork.bsc: WalletChainDefinition.evm(
      WalletNetwork.bsc,
      'BNB Smart Chain',
      'BNB',
      'BNB',
      WalletTokenDefinition(
        '0x55d398326f99059fF775485246999027B3197955',
        18,
        'Tether USD',
      ),
    ),
    WalletNetwork.polygon: WalletChainDefinition.evm(
      WalletNetwork.polygon,
      'Polygon',
      'POL',
      'Polygon Ecosystem Token',
      WalletTokenDefinition(
        '0xc2132D05D31c914a87C6611C10748AEb04B58e8F',
        6,
        'Tether USD',
      ),
    ),
    WalletNetwork.base: WalletChainDefinition.evm(
      WalletNetwork.base,
      'Base',
      'ETH',
      'Ethereum',
      WalletTokenDefinition(
        '0xfde4c96c8593536e31f229ea8f37b2ada2699bb2',
        6,
        'Tether USD',
      ),
    ),
    WalletNetwork.arbitrum: WalletChainDefinition.evm(
      WalletNetwork.arbitrum,
      'Arbitrum One',
      'ETH',
      'Ethereum',
      WalletTokenDefinition(
        '0xfd086bc7cd5c481dcc9c85ebe478a1c0b69fcbb9',
        6,
        'Tether USD',
      ),
    ),
    WalletNetwork.optimism: WalletChainDefinition.evm(
      WalletNetwork.optimism,
      'Optimism',
      'ETH',
      'Ethereum',
      WalletTokenDefinition(
        '0x94b008aA00579c1307B0EF2C499aD98a8ce58e58',
        6,
        'Tether USD',
      ),
    ),
    WalletNetwork.tron: WalletChainDefinition.nonEvm(
      WalletNetwork.tron,
      'TRON',
      'TRX',
      'TRON',
      'tron',
      6,
    ),
    WalletNetwork.solana: WalletChainDefinition.nonEvm(
      WalletNetwork.solana,
      'Solana',
      'SOL',
      'Solana',
      'solana',
      9,
    ),
  };

  static const solanaTokenProgramIds = [
    'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA',
    'TokenzQdBNbLqP5VEhdkAS6EPFwh6G9s34M3iKkj1P',
  ];

  static const tronUsdt = WalletTokenDefinition(
    'TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t',
    6,
    'Tether USD',
  );
  static const solanaUsdt = WalletTokenDefinition(
    'Es9vMFrzaCERmJfrF4H2FYD4KCoNkY11McCe8BenwNYB',
    6,
    'Tether USD',
  );

  static final solanaKnownTokens = {
    'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v': const WalletTokenDefinition(
      'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v',
      6,
      'USD Coin',
      symbol: 'USDC',
    ),
    solanaUsdt.address: solanaUsdt,
  };
}
