part of 'aco_design_shell.dart';

const _tokenDetailBlue = Color(0xFF2F80ED);
const _tokenDetailGreen = Color(0xFF52C7A0);
const _tokenDetailEmptyIcon = Color(0xFFB8BEC7);

class _TokenDetailPage extends StatefulWidget {
  const _TokenDetailPage({
    required this.palette,
    required this.balance,
    required this.selectedChain,
    required this.onOpen,
    this.onSendTokenSelected,
  });

  final AcoPalette palette;
  final WalletBalance balance;
  final _WalletChain selectedChain;
  final ValueChanged<AcoScreen> onOpen;
  final ValueChanged<TransferToken>? onSendTokenSelected;

  @override
  State<_TokenDetailPage> createState() => _TokenDetailPageState();
}

class _TokenDetailPageState extends State<_TokenDetailPage> {
  int _selectedTab = 0;

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

  Future<void> _copyTokenAddress() async {
    final text = widget.balance.tokenAddress ?? widget.balance.address;
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) showAcoAlertNotice(context, '已复制', '代币地址已复制到剪贴板。');
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
              titleFontSize: 22,
              onBack: () => Navigator.of(context).maybePop(),
              backButtonOffset: Offset.zero,
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
              child: Column(
                children: [
                  _TokenBalanceSummary(
                    palette: widget.palette,
                    balance: _amount,
                    symbol: widget.balance.symbol,
                    iconSymbol: widget.balance.symbol,
                    copyAvailable:
                        (widget.balance.tokenAddress ?? widget.balance.address)
                            .isNotEmpty,
                    onCopy: _copyTokenAddress,
                  ),
                  const SizedBox(height: 30),
                  Row(
                    children: [
                      for (var index = 0; index < 3; index++) ...[
                        _TokenDetailTab(
                          label: ['全部', '转入', '转出'][index],
                          selected: _selectedTab == index,
                          palette: widget.palette,
                          onPressed: () => setState(() => _selectedTab = index),
                        ),
                        if (index < 2) const SizedBox(width: 28),
                      ],
                      const Spacer(),
                      Semantics(
                        button: true,
                        label: '筛选交易记录',
                        child: CupertinoButton(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(40, 40),
                          onPressed: () => showAcoAlertNotice(
                            context,
                            '筛选交易记录',
                            '交易筛选功能即将开放。',
                          ),
                          child: Icon(
                            CupertinoIcons.line_horizontal_3_decrease,
                            color: widget.palette.primaryText,
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  _TokenDetailEmptyState(
                    palette: widget.palette,
                    onOpenBrowser: () =>
                        widget.onOpen(AcoScreen.browserDiscover),
                  ),
                ],
              ),
            ),
          ),
          _TokenDetailActions(
            palette: widget.palette,
            onSend: _sendToken,
            onReceive: () => widget.onOpen(AcoScreen.receive),
            onSwap: () => showAcoAlertNotice(context, '提示', '闪兑功能即将开放。'),
          ),
        ],
      ),
    );
  }
}

class _TokenBalanceSummary extends StatelessWidget {
  const _TokenBalanceSummary({
    required this.palette,
    required this.balance,
    required this.symbol,
    required this.iconSymbol,
    required this.copyAvailable,
    required this.onCopy,
  });

  final AcoPalette palette;
  final String balance;
  final String symbol;
  final String iconSymbol;
  final bool copyAvailable;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, constraints) {
      final compact = constraints.maxWidth < 360;
      final iconSize = compact ? 44.0 : 50.0;
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _WalletAssetIcon(symbol: iconSymbol, size: iconSize),
          SizedBox(width: compact ? 8 : 12),
          Expanded(
            child: Row(
              children: [
                Flexible(
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
                const SizedBox(width: 5),
                Semantics(
                  button: copyAvailable,
                  label: '复制代币地址',
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(30, 30),
                    onPressed: copyAvailable ? onCopy : null,
                    child: Icon(
                      CupertinoIcons.doc_on_doc,
                      color: palette.mutedText,
                      size: compact ? 18 : 20,
                    ),
                  ),
                ),
              ],
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
              Text(
                '≈ \$$balance',
                style: TextStyle(
                  color: palette.mutedText,
                  fontSize: compact ? 15 : 17,
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
  Widget build(BuildContext context) => CupertinoButton(
    padding: const EdgeInsets.only(bottom: 8),
    minimumSize: Size.zero,
    onPressed: onPressed,
    child: Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: selected ? palette.primaryText : palette.mutedText,
            fontSize: 18,
            fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
          ),
        ),
        const SizedBox(height: 7),
        Container(
          width: selected ? 64 : 0,
          height: 4,
          decoration: BoxDecoration(
            color: palette.primaryText,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
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

class _TokenDetailActions extends StatelessWidget {
  const _TokenDetailActions({
    required this.palette,
    required this.onSend,
    required this.onReceive,
    required this.onSwap,
  });

  final AcoPalette palette;
  final VoidCallback onSend;
  final VoidCallback onReceive;
  final VoidCallback onSwap;

  @override
  Widget build(BuildContext context) {
    final surface = palette.dark ? palette.surfaceRaised : palette.background;
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
                  background: _tokenDetailGreen,
                  foreground: _white,
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
                  background: _tokenDetailBlue,
                  foreground: _white,
                  compact: compact,
                  onPressed: onReceive,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: compact ? 5 : 4,
                child: _TokenActionButton(
                  label: '闪兑',
                  icon: CupertinoIcons.arrow_right_arrow_left,
                  background: surface,
                  foreground: palette.primaryText,
                  borderColor: palette.border,
                  compact: compact,
                  onPressed: onSwap,
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
      height: 58,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        borderRadius: BorderRadius.circular(18),
        onPressed: onPressed,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(18),
            border: borderColor == null
                ? null
                : Border.all(color: borderColor!),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: foreground, size: compact ? 20 : 24),
              SizedBox(width: compact ? 4 : 8),
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontSize: compact ? 18 : 21,
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
