import 'dart:convert';

import 'package:aco_chat/services/wallet_identity.dart';
import 'package:aco_chat/services/wallet_portfolio_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists display-only wallet metadata separately from wallet identities.
class WalletMetadataStore {
  static const walletNameMaxLength = 12;
  static const _derivedAddressesKeyPrefix = 'wallet.derived-addresses.';
  static const _walletNameKeyPrefix = 'wallet.name.';
  static const _hiddenTokenSymbolsKeyPrefix = 'wallet.hidden-token-symbols.';
  static const _customTokensKeyPrefix = 'wallet.custom-tokens.';
  static final Map<String, Set<String>> _hiddenTokenCache = {};

  Future<List<CustomTokenDefinition>> customTokens(
    WalletIdentity identity,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_customTokensKey(identity));
    if (encoded == null) return const [];
    try {
      final values = jsonDecode(encoded) as List<dynamic>;
      return values
          .whereType<Map<String, dynamic>>()
          .map(CustomTokenDefinition.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveCustomToken(
    WalletIdentity identity,
    CustomTokenDefinition token,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    final tokens = await customTokens(identity);
    final index = tokens.indexWhere(
      (item) =>
          item.network == token.network &&
          item.address.toLowerCase() == token.address.toLowerCase(),
    );
    if (index >= 0) {
      tokens[index] = token;
    } else {
      tokens.add(token);
    }
    await preferences.setString(
      _customTokensKey(identity),
      jsonEncode(tokens.map((item) => item.toJson()).toList()),
    );
  }

  Future<String> walletName(
    WalletIdentity identity, {
    String fallback = 'Wallet1',
  }) async {
    final preferences = await SharedPreferences.getInstance();
    return normalizeWalletName(
      preferences.getString(_walletNameKey(identity)) ?? fallback,
    );
  }

  Future<String> saveWalletName(WalletIdentity identity, String name) async {
    final normalizedName = normalizeWalletName(name);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_walletNameKey(identity), normalizedName);
    return normalizedName;
  }

  Future<Map<String, String>> derivedAddresses(WalletIdentity identity) async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_derivedAddressesKey(identity));
    if (encoded == null) return const {};
    try {
      return (jsonDecode(encoded) as Map<String, dynamic>).map(
        (chain, address) => MapEntry(chain, address as String),
      );
    } on FormatException {
      return const {};
    } on TypeError {
      return const {};
    }
  }

  Future<void> saveDerivedAddresses(
    WalletIdentity identity,
    Map<String, String> addresses,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _derivedAddressesKey(identity),
      jsonEncode(addresses),
    );
  }

  Future<Set<String>> hiddenTokenSymbols(
    WalletIdentity identity,
    String network,
  ) async {
    final key = _hiddenTokenSymbolsKey(identity, network);
    final cached = _hiddenTokenCache[key];
    if (cached != null) return {...cached};
    final preferences = await SharedPreferences.getInstance();
    final symbols = (preferences.getStringList(key) ?? const <String>[])
        .toSet();
    _hiddenTokenCache[key] = symbols;
    return {...symbols};
  }

  Set<String> cachedHiddenTokenSymbols(
    WalletIdentity identity,
    String network,
  ) => {...?_hiddenTokenCache[_hiddenTokenSymbolsKey(identity, network)]};

  Future<void> setTokenHidden(
    WalletIdentity identity,
    String network,
    String symbol,
    bool hidden,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    final key = _hiddenTokenSymbolsKey(identity, network);
    final symbols = _hiddenTokenCache[key] ??
        (preferences.getStringList(key) ?? const <String>[]).toSet();
    if (hidden) {
      symbols.add(symbol);
    } else {
      symbols.remove(symbol);
    }
    _hiddenTokenCache[key] = symbols;
    await preferences.setStringList(key, symbols.toList());
  }

  static String normalizeWalletName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'Wallet1';
    if (trimmed.length <= walletNameMaxLength) return trimmed;
    return trimmed.substring(0, walletNameMaxLength);
  }

  static String _derivedAddressesKey(WalletIdentity identity) =>
      '$_derivedAddressesKeyPrefix${identity.address.toLowerCase()}';

  static String _walletNameKey(WalletIdentity identity) =>
      '$_walletNameKeyPrefix${identity.address.toLowerCase()}';

  static String _hiddenTokenSymbolsKey(
    WalletIdentity identity,
    String network,
  ) =>
      '$_hiddenTokenSymbolsKeyPrefix${identity.address.toLowerCase()}.$network';

  static String _customTokensKey(WalletIdentity identity) =>
      '$_customTokensKeyPrefix${identity.address.toLowerCase()}';
}
