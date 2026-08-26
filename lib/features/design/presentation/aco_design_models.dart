part of 'aco_design_shell.dart';

enum AcoScreen {
  walletHome,
  walletChains,
  walletSwitcher,
  walletSetupCreate,
  walletSetupImport,
  assetDetail,
  backupMnemonic,
  exportPrivateKey,
  send,
  receive,
  scan,
  addTokenV1,
  addTokenV2,
  dexToken,
  dexSwap,
  browserDiscover,
  marketOverview,
  squareFeed,
  socialMessages,
  chatV1,
  chatV2,
  liveStream,
  voiceRoom,
  mining,
  profile,
  profileQr,
  profileEdit,
  profileTheme,
  profileLanguage,
  comingSoon,
  createLive,
}

class _WalletToken {
  const _WalletToken(this.symbol, this.title);

  final String symbol;
  final String title;
}

class _WalletChain {
  const _WalletChain({
    required this.asset,
    required this.label,
    required this.nativeToken,
    required this.network,
    this.backgroundColor,
    this.derivedAddressKey,
  });

  final String asset;
  final String label;
  final _WalletToken nativeToken;
  final WalletNetwork network;
  final Color? backgroundColor;
  final String? derivedAddressKey;

  String get displayLabel =>
      network == WalletNetwork.ethereum ? 'Ethereum' : label;
}

const _supportedWalletChains = [
  _WalletChain(
    asset: 'assets/icons/crypto/domi/chains/network-ethereum.png',
    label: '以太坊',
    nativeToken: _WalletToken('ETH', 'Ethereum'),
    network: WalletNetwork.ethereum,
  ),
  _WalletChain(
    asset: 'assets/icons/crypto/domi/chains/network-bsc.png',
    label: 'BSC',
    nativeToken: _WalletToken('BNB', 'BNB'),
    network: WalletNetwork.bsc,
  ),
  _WalletChain(
    asset: 'assets/icons/crypto/domi/chains/network-polygon.png',
    label: 'Polygon',
    nativeToken: _WalletToken('POL', 'Polygon Ecosystem Token'),
    network: WalletNetwork.polygon,
  ),
  _WalletChain(
    asset: 'assets/icons/crypto/domi/chains/network-arbitrum.png',
    label: 'Arbitrum',
    nativeToken: _WalletToken('ETH', 'Ethereum'),
    network: WalletNetwork.arbitrum,
  ),
  _WalletChain(
    asset: 'assets/icons/crypto/domi/chains/network-optimism.png',
    label: 'Optimism',
    nativeToken: _WalletToken('ETH', 'Ethereum'),
    network: WalletNetwork.optimism,
  ),
  _WalletChain(
    asset: 'assets/icons/crypto/domi/chains/tron.svg',
    label: 'Tron',
    nativeToken: _WalletToken('TRX', 'TRON'),
    network: WalletNetwork.tron,
    derivedAddressKey: 'tron',
  ),
  _WalletChain(
    asset: 'assets/icons/crypto/domi/chains/network-solana.png',
    label: 'Solana',
    nativeToken: _WalletToken('SOL', 'Solana'),
    network: WalletNetwork.solana,
    derivedAddressKey: 'solana',
  ),
  _WalletChain(
    asset: 'assets/icons/crypto/domi/chains/network-base.png',
    label: 'Base',
    nativeToken: _WalletToken('ETH', 'Ethereum'),
    network: WalletNetwork.base,
    backgroundColor: Color(0xFF0052FF),
  ),
];

Future<String?> _addressForChain(
  WalletIdentity? identity,
  _WalletChain chain,
) async {
  if (identity == null || identity.address.isEmpty) return null;
  final derivedAddressKey = chain.derivedAddressKey;
  if (derivedAddressKey == null) return identity.address;
  return (await WalletPreferences.derivedAddresses(
    identity,
  ))[derivedAddressKey];
}

class TransferToken {
  const TransferToken({
    required this.symbol,
    required this.name,
    required this.chain,
    required this.iconAsset,
    required this.feeSymbol,
    this.availableAmount = '0',
  });

  final String symbol;
  final String name;
  final String chain;
  final String iconAsset;
  final String feeSymbol;
  final String availableAmount;
}

List<TransferToken> _transferTokensForChain(_WalletChain chain) {
  final nativeToken = TransferToken(
    symbol: chain.nativeToken.symbol,
    name: chain.nativeToken.title,
    chain: chain.label,
    feeSymbol: chain.nativeToken.symbol,
    iconAsset: switch (chain.network) {
      WalletNetwork.ethereum ||
      WalletNetwork.base ||
      WalletNetwork.arbitrum ||
      WalletNetwork.optimism => 'assets/icons/crypto/tokens/eth.svg',
      WalletNetwork.bsc => 'assets/icons/crypto/tokens/bnb.svg',
      WalletNetwork.polygon => 'assets/icons/crypto/tokens/matic.svg',
      WalletNetwork.tron => 'assets/icons/crypto/tokens/trx.svg',
      WalletNetwork.solana => 'assets/icons/crypto/tokens/sol.svg',
    },
  );
  return [
    nativeToken,
    TransferToken(
      symbol: 'USDT',
      name: 'Tether USD',
      chain: chain.label,
      iconAsset: 'assets/icons/crypto/domi/tokens/usdt.png',
      feeSymbol: chain.nativeToken.symbol,
    ),
  ];
}
