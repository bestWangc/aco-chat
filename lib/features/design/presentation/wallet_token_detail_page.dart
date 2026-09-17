part of 'aco_design_shell.dart';

const _tokenDetailBlue = Color(0xFF2F80ED);
const _tokenDetailEmptyIcon = Color(0xFFB8BEC7);

class _TokenDetailPage extends StatefulWidget {
  const _TokenDetailPage({
    required this.palette,
    required this.balance,
    required this.selectedChain,
    required this.onOpen,
    this.transactionService,
    this.onSendTokenSelected,
  });

  final AcoPalette palette;
  final WalletBalance balance;
  final _WalletChain selectedChain;
  final ValueChanged<AcoScreen> onOpen;
  final WalletTransactionService? transactionService;
  final ValueChanged<TransferToken>? onSendTokenSelected;

  @override
  State<_TokenDetailPage> createState() => _TokenDetailPageState();
}

class _TokenDetailPageState extends State<_TokenDetailPage> {
  static const _transactionPageSize = 20;

  int _selectedTab = 0;
  final _transactionBuckets =
      <WalletTransactionDirection, _TransactionBucket>{};
  late final ScrollController _transactionScrollController;

  String get _symbol => widget.balance.symbol.toUpperCase();

  String get _title => widget.balance.assetName.trim().isEmpty
      ? widget.balance.symbol
      : widget.balance.assetName;

  String get _amount {
    final balance = widget.balance.balance ?? BigInt.zero;
    if (balance == BigInt.zero) return '0';
    return formatChainAmount(balance, decimals: widget.balance.decimals);
  }

  String _tokenIconAsset() => switch (_symbol) {
    'USDT' => 'assets/icons/crypto/domi/tokens/usdt.png',
    'USDC' => 'assets/icons/crypto/domi/tokens/usdc.png',
    _ => 'assets/icons/crypto/tokens/${_symbol.toLowerCase()}.svg',
  };

  @override
  void initState() {
    super.initState();
    _transactionScrollController = ScrollController()
      ..addListener(_loadMoreTransactionsIfNeeded);
    if (widget.transactionService != null) {
      unawaited(_loadTransactions(_selectedDirection, reset: true));
    }
  }

  @override
  void dispose() {
    _transactionScrollController
      ..removeListener(_loadMoreTransactionsIfNeeded)
      ..dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _TokenDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final assetChanged =
        oldWidget.balance.address != widget.balance.address ||
        oldWidget.balance.tokenAddress != widget.balance.tokenAddress ||
        oldWidget.balance.symbol != widget.balance.symbol ||
        oldWidget.selectedChain.network != widget.selectedChain.network;
    if (assetChanged) {
      _transactionBuckets.clear();
      if (widget.transactionService != null) {
        unawaited(_loadTransactions(_selectedDirection, reset: true));
      }
    }
  }

  WalletTransactionDirection get _selectedDirection => switch (_selectedTab) {
    1 => WalletTransactionDirection.incoming,
    2 => WalletTransactionDirection.outgoing,
    _ => WalletTransactionDirection.all,
  };

  _TransactionBucket _bucketFor(WalletTransactionDirection direction) =>
      _transactionBuckets.putIfAbsent(direction, _TransactionBucket.new);

  void _selectTransactionTab(int index) {
    if (_selectedTab == index) return;
    setState(() => _selectedTab = index);
    if (widget.transactionService != null) {
      unawaited(_loadTransactions(_selectedDirection, reset: false));
    }
  }

  Future<void> _loadTransactions(
    WalletTransactionDirection direction, {
    required bool reset,
    bool loadMore = false,
  }) async {
    final service = widget.transactionService;
    if (service == null) return;
    final bucket = _bucketFor(direction);
    if (bucket.isLoading ||
        (loadMore && (!bucket.loaded || !bucket.hasMore)) ||
        (!reset && !loadMore && bucket.loaded)) {
      return;
    }
    if (reset) {
      bucket
        ..items = const []
        ..nextPage = 1
        ..hasMore = true
        ..loaded = false
        ..error = null;
    }
    bucket.isLoading = true;
    if (mounted) setState(() {});
    try {
      final page = bucket.nextPage;
      final result = await service.loadPage(
        network: widget.selectedChain.network,
        asset: widget.balance,
        direction: direction,
        page: page,
        limit: _transactionPageSize,
      );
      if (!mounted) return;
      bucket
        ..items = [...bucket.items, ...result.items]
        ..nextPage = result.nextPage > page ? result.nextPage : page + 1
        ..hasMore = result.hasMore
        ..loaded = true
        ..error = null;
    } catch (error) {
      if (mounted) _bucketFor(direction).error = error;
    } finally {
      bucket.isLoading = false;
      if (mounted) setState(() {});
    }
  }

  void _loadMoreTransactionsIfNeeded() {
    if (!_transactionScrollController.hasClients ||
        _transactionScrollController.position.extentAfter > 320) {
      return;
    }
    final bucket = _bucketFor(_selectedDirection);
    if (bucket.loaded && bucket.hasMore && !bucket.isLoading) {
      unawaited(
        _loadTransactions(_selectedDirection, reset: false, loadMore: true),
      );
    }
  }

  Widget _buildTransactionSliver() {
    final service = widget.transactionService;
    if (service == null) {
      return SliverToBoxAdapter(
        child: _TokenDetailEmptyState(
          palette: widget.palette,
          onOpenBrowser: () => widget.onOpen(AcoScreen.browserDiscover),
        ),
      );
    }
    final bucket = _bucketFor(_selectedDirection);
    if (bucket.items.isEmpty && bucket.isLoading) {
      return const SliverToBoxAdapter(child: _TokenTransactionLoading());
    }
    if (bucket.items.isEmpty && bucket.error != null) {
      return SliverToBoxAdapter(
        child: _TokenTransactionError(
          palette: widget.palette,
          onRetry: () => _loadTransactions(_selectedDirection, reset: true),
        ),
      );
    }
    if (bucket.items.isEmpty) {
      return SliverToBoxAdapter(
        child: _TokenDetailEmptyState(
          palette: widget.palette,
          onOpenBrowser: () => widget.onOpen(AcoScreen.browserDiscover),
        ),
      );
    }
    final itemCount = bucket.items.length + (bucket.isLoading ? 1 : 0);
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index == bucket.items.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: CupertinoActivityIndicator(),
            );
          }
          final transaction = bucket.items[index];
          return Column(
            key: ValueKey(transaction.hash),
            children: [
              _TokenTransactionTile(
                palette: widget.palette,
                transaction: transaction,
              ),
              if (index < bucket.items.length - 1)
                Container(height: 1, color: widget.palette.border),
            ],
          );
        },
        childCount: itemCount,
        addAutomaticKeepAlives: false,
        addRepaintBoundaries: true,
      ),
    );
  }

  void _sendToken() {
    final token = TransferToken(
      symbol: widget.balance.symbol,
      name: _title,
      chain: widget.balance.chain,
      iconAsset: _tokenIconAsset(),
      feeSymbol: widget.selectedChain.nativeToken.symbol,
      availableAmount: _amount,
    );
    if (widget.onSendTokenSelected == null) {
      widget.onOpen(AcoScreen.send);
    } else {
      widget.onSendTokenSelected!(token);
    }
  }

  @override
  Widget build(BuildContext context) {
    final background = widget.palette.dark
        ? widget.palette.background
        : const Color(0xFFF5F6FB);
    return ColoredBox(
      color: background,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 16, 0),
            child: AcoPageHeader(
              palette: widget.palette,
              title: _title,
              onBack: () => Navigator.of(context).maybePop(),
              backButtonOffset: Offset.zero,
            ),
          ),
          Expanded(
            child: CustomScrollView(
              controller: _transactionScrollController,
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(22, 24, 22, 0),
                  sliver: SliverToBoxAdapter(
                    child: _TokenBalanceSummary(
                      palette: widget.palette,
                      balance: _amount,
                      symbol: widget.balance.symbol,
                      iconSymbol: widget.balance.symbol,
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  sliver: const SliverToBoxAdapter(child: SizedBox(height: 30)),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      children: [
                        for (var index = 0; index < 3; index++) ...[
                          _TokenDetailTab(
                            label: ['全部', '转入', '转出'][index],
                            selected: _selectedTab == index,
                            palette: widget.palette,
                            onPressed: () => _selectTransactionTab(index),
                          ),
                          if (index < 2) const SizedBox(width: 12),
                        ],
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  sliver: const SliverToBoxAdapter(child: SizedBox(height: 3)),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
                  sliver: _buildTransactionSliver(),
                ),
              ],
            ),
          ),
          _TokenDetailActions(
            palette: widget.palette,
            onSend: _sendToken,
            onReceive: () => widget.onOpen(AcoScreen.receive),
          ),
        ],
      ),
    );
  }
}

class _TransactionBucket {
  List<WalletTransaction> items = const [];
  int nextPage = 1;
  bool hasMore = true;
  bool isLoading = false;
  bool loaded = false;
  Object? error;
}

class _TokenBalanceSummary extends StatelessWidget {
  const _TokenBalanceSummary({
    required this.palette,
    required this.balance,
    required this.symbol,
    required this.iconSymbol,
  });

  final AcoPalette palette;
  final String balance;
  final String symbol;
  final String iconSymbol;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, constraints) {
      final compact = constraints.maxWidth < 360;
      final iconSize = compact ? 44.0 : 50.0;
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _WalletAssetIcon(symbol: iconSymbol, size: iconSize),
          SizedBox(width: compact ? 16 : 20),
          Expanded(
            child: Text(
              symbol,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.primaryText,
                fontSize: compact ? 22 : 24,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(width: compact ? 6 : 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                balance,
                style: TextStyle(
                  color: palette.primaryText,
                  fontSize: compact ? 24 : 27,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
}

class _TokenDetailTab extends StatelessWidget {
  const _TokenDetailTab({
    required this.label,
    required this.selected,
    required this.palette,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final AcoPalette palette;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: label,
    child: CupertinoButton(
      padding: const EdgeInsets.only(bottom: 8),
      minimumSize: const Size(64, 44),
      onPressed: onPressed,
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: selected ? palette.accent : palette.mutedText,
              fontSize: AcoTypography.bodyEmphasis,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          const SizedBox(height: 7),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            width: 40,
            height: 3,
            decoration: BoxDecoration(
              color: selected ? palette.accent : const Color(0x00000000),
              borderRadius: BorderRadius.circular(1.5),
            ),
          ),
        ],
      ),
    ),
  );
}

class _TokenDetailEmptyState extends StatelessWidget {
  const _TokenDetailEmptyState({
    required this.palette,
    required this.onOpenBrowser,
  });

  final AcoPalette palette;
  final VoidCallback onOpenBrowser;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, constraints) {
      final compact = constraints.maxWidth < 400;
      final illustrationSize = compact ? 88.0 : 104.0;
      final documentSize = compact ? 72.0 : 86.0;
      final refreshSize = compact ? 28.0 : 32.0;
      final textSize = compact ? 16.0 : 17.0;
      return SizedBox(
        height: compact ? 280 : 310,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: illustrationSize,
              height: illustrationSize,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    CupertinoIcons.doc_text,
                    color: _tokenDetailEmptyIcon,
                    size: documentSize,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 2,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: palette.dark
                            ? palette.background
                            : const Color(0xFFF5F6FB),
                        shape: BoxShape.circle,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(3),
                        child: Icon(
                          CupertinoIcons.refresh,
                          color: _tokenDetailEmptyIcon,
                          size: refreshSize,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '没有找到您的交易？',
                  style: TextStyle(
                    color: palette.mutedText,
                    fontSize: textSize,
                  ),
                ),
                CupertinoButton(
                  padding: const EdgeInsets.only(left: 5),
                  minimumSize: const Size(44, 44),
                  onPressed: onOpenBrowser,
                  child: Text(
                    '查看浏览器',
                    style: TextStyle(
                      color: _tokenDetailBlue,
                      fontSize: textSize,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}

class _TokenTransactionLoading extends StatelessWidget {
  const _TokenTransactionLoading();

  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 280,
    child: Center(child: CupertinoActivityIndicator(radius: 12)),
  );
}

class _TokenTransactionError extends StatelessWidget {
  const _TokenTransactionError({required this.palette, required this.onRetry});

  final AcoPalette palette;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 280,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '交易记录加载失败',
          style: TextStyle(color: palette.mutedText, fontSize: 16),
        ),
        CupertinoButton(
          minimumSize: const Size(44, 44),
          onPressed: onRetry,
          child: Text(
            '重试',
            style: TextStyle(color: _tokenDetailBlue, fontSize: 16),
          ),
        ),
      ],
    ),
  );
}

class _TokenTransactionTile extends StatelessWidget {
  const _TokenTransactionTile({
    required this.palette,
    required this.transaction,
  });

  final AcoPalette palette;
  final WalletTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final incoming = transaction.isIncoming;
    final direction = incoming ? '转入' : '转出';
    final amountColor = incoming ? _tokenDetailBlue : palette.accent;
    final amountPrefix = incoming ? '+' : '-';
    final counterparty = _shortWalletAddress(
      incoming ? transaction.from : transaction.to,
    );
    final status = transaction.isSuccessful ? '' : ' · $_statusLabel';
    return Semantics(
      label: '$direction ${transaction.displayAmount} ${transaction.symbol}',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: amountColor,
                shape: BoxShape.circle,
              ),
              child: SizedBox(
                width: 36,
                height: 36,
                child: Icon(
                  incoming
                      ? CupertinoIcons.arrow_down_left
                      : CupertinoIcons.arrow_up_right,
                  color: incoming ? _white : _black,
                  size: 18,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    counterparty,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: palette.primaryText, fontSize: 16),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$direction$status',
                    style: TextStyle(color: palette.mutedText, fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$amountPrefix${transaction.displayAmount} ${transaction.symbol}',
                  style: TextStyle(color: amountColor, fontSize: 16),
                ),
                const SizedBox(height: 3),
                Text(
                  _formatTransactionTime(transaction.timestamp),
                  style: TextStyle(color: palette.mutedText, fontSize: 14),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String get _statusLabel => switch (transaction.status) {
    'failed' => '失败',
    'pending' => '处理中',
    _ => '未知状态',
  };
}

String _shortWalletAddress(String address) {
  if (address.length <= 12) return address;
  return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
}

String _formatTransactionTime(int timestamp) {
  if (timestamp <= 0) return '--';
  final time = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000).toLocal();
  String pad(int value) => value.toString().padLeft(2, '0');
  return '${pad(time.month)}-${pad(time.day)} ${pad(time.hour)}:${pad(time.minute)}:${pad(time.second)}';
}

class _TokenDetailActions extends StatelessWidget {
  const _TokenDetailActions({
    required this.palette,
    required this.onSend,
    required this.onReceive,
  });

  final AcoPalette palette;
  final VoidCallback onSend;
  final VoidCallback onReceive;

  @override
  Widget build(BuildContext context) {
    final receiveBackground = palette.surfaceRaised;
    return AcoSafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: LayoutBuilder(
        builder: (_, constraints) {
          final compact = constraints.maxWidth < 360;
          return Row(
            children: [
              Expanded(
                flex: 6,
                child: _TokenActionButton(
                  label: '转账',
                  icon: CupertinoIcons.arrow_up,
                  background: palette.accent,
                  foreground: _walletActionForeground,
                  compact: compact,
                  onPressed: onSend,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 6,
                child: _TokenActionButton(
                  label: '收款',
                  icon: CupertinoIcons.arrow_down,
                  background: receiveBackground,
                  foreground: palette.primaryText,
                  borderColor: palette.border,
                  compact: compact,
                  onPressed: onReceive,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TokenActionButton extends StatelessWidget {
  const _TokenActionButton({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onPressed,
    this.compact = false,
    this.borderColor,
  });

  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  final Color? borderColor;
  final VoidCallback onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    excludeSemantics: true,
    label: label,
    child: SizedBox(
      height: 50,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        borderRadius: BorderRadius.circular(16),
        onPressed: onPressed,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(16),
            border: borderColor == null
                ? null
                : Border.all(color: borderColor!),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: foreground, size: compact ? 18 : 20),
              SizedBox(width: compact ? 4 : 6),
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontSize: compact ? 16 : 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
