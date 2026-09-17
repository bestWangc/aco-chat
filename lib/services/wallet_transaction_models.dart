import 'package:aco_chat/services/wallet_portfolio_models.dart';

enum WalletTransactionDirection { all, incoming, outgoing }

extension WalletTransactionDirectionQuery on WalletTransactionDirection {
  String get queryValue => switch (this) {
    WalletTransactionDirection.all => 'all',
    WalletTransactionDirection.incoming => 'in',
    WalletTransactionDirection.outgoing => 'out',
  };
}

class WalletTransaction {
  const WalletTransaction({
    required this.hash,
    required this.direction,
    required this.amountRaw,
    required this.decimals,
    required this.symbol,
    required this.from,
    required this.to,
    required this.timestamp,
    required this.blockNumber,
    required this.tokenAddress,
    required this.fee,
    required this.status,
  });

  final String hash;
  final String direction;
  final String amountRaw;
  final int decimals;
  final String symbol;
  final String from;
  final String to;
  final int timestamp;
  final int blockNumber;
  final String tokenAddress;
  final String fee;
  final String status;

  factory WalletTransaction.fromJson(Map<String, dynamic> json) =>
      WalletTransaction(
        hash: _string(json['hash']),
        direction: _string(json['direction']),
        amountRaw: _string(json['amount_raw'] ?? json['amount']),
        decimals: _int(json['decimals']),
        symbol: _string(json['symbol']),
        from: _string(json['from']),
        to: _string(json['to']),
        timestamp: _int(json['timestamp']),
        blockNumber: _int(json['block_number']),
        tokenAddress: _string(json['token_address']),
        fee: _string(json['fee']),
        status: _string(json['status']),
      );

  String get displayAmount {
    final raw = BigInt.tryParse(amountRaw);
    if (raw == null) return amountRaw;
    return formatChainAmount(raw, decimals: decimals);
  }

  bool get isIncoming => direction == 'in';

  bool get isSuccessful => status == 'success';

  static String _string(Object? value) => value?.toString() ?? '';

  static int _int(Object? value) => switch (value) {
    int number => number,
    num number => number.toInt(),
    String text => int.tryParse(text) ?? 0,
    _ => 0,
  };
}

class WalletTransactionPage {
  const WalletTransactionPage({
    required this.items,
    required this.nextPage,
    required this.hasMore,
  });

  final List<WalletTransaction> items;
  final int nextPage;
  final bool hasMore;

  factory WalletTransactionPage.fromJson(Map<String, dynamic> json) {
    final rawItems = json['data'];
    final items = rawItems is List
        ? rawItems
              .whereType<Map<String, dynamic>>()
              .map(WalletTransaction.fromJson)
              .toList(growable: false)
        : const <WalletTransaction>[];
    return WalletTransactionPage(
      items: items,
      nextPage: _int(json['next_page']),
      hasMore: json['has_more'] == true,
    );
  }

  static int _int(Object? value) => switch (value) {
    int number => number,
    num number => number.toInt(),
    String text => int.tryParse(text) ?? 0,
    _ => 0,
  };
}
