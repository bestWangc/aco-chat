import 'dart:convert';

import 'package:aco_chat/core/config/app_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HyperliquidBuilderApproval {
  const HyperliquidBuilderApproval({
    required this.builderAddress,
    required this.maxFeeRate,
  });

  final String builderAddress;
  final String maxFeeRate;
}

class HyperliquidBuilderApprovalStore {
  HyperliquidBuilderApprovalStore({Future<SharedPreferences>? preferences})
    : _preferences = preferences ?? SharedPreferences.getInstance();

  static const _prefix = 'hyperliquid.builder-approval.';

  final Future<SharedPreferences> _preferences;

  Future<HyperliquidBuilderApproval?> read(String masterAddress) async {
    final prefs = await _preferences;
    final encoded = prefs.getString(_key(masterAddress));
    if (encoded == null || encoded.isEmpty) return null;
    try {
      final json = Map<String, dynamic>.from(
        (jsonDecode(encoded) as Map).cast<String, dynamic>(),
      );
      final builderAddress = '${json['builderAddress'] ?? ''}';
      final maxFeeRate = '${json['maxFeeRate'] ?? ''}';
      if (builderAddress.isEmpty || maxFeeRate.isEmpty) return null;
      return HyperliquidBuilderApproval(
        builderAddress: builderAddress,
        maxFeeRate: maxFeeRate,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> markApproved(
    String masterAddress,
    HyperliquidBuilderApproval approval,
  ) async {
    final prefs = await _preferences;
    await prefs.setString(
      _key(masterAddress),
      jsonEncode({
        'builderAddress': approval.builderAddress,
        'maxFeeRate': approval.maxFeeRate,
      }),
    );
  }

  String _key(String masterAddress) {
    final network = AppConfig.hyperliquidTestnet ? 'testnet' : 'mainnet';
    return '$_prefix$network.${masterAddress.toLowerCase()}';
  }
}
