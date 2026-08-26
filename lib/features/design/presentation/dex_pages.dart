part of 'aco_design_shell.dart';

class _DexTokenPage extends StatelessWidget {
  const _DexTokenPage({required this.palette, required this.onOpen});
  final AcoPalette palette;
  final ValueChanged<AcoScreen> onOpen;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(51, 20, 51, 24),
    children: [
      AcoRootHeader(palette: palette, onOpen: onOpen, title: 'DEX'),
      const SizedBox(height: 32),
      _SectionTabs(
        palette: palette,
        labels: const ['闪兑', '代币', '合约'],
        selected: 1,
        onChanged: (index) {
          if (index == 0) onOpen(AcoScreen.dexSwap);
        },
      ),
      const SizedBox(height: 38),
      Row(
        children: [
          const _TokenMark(),
          const SizedBox(width: 10),
          Text(
            'ETH',
            style: TextStyle(
              color: palette.primaryText,
              fontSize: AcoTypography.title,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Icon(CupertinoIcons.chevron_down, color: _lime, size: 15),
          const Spacer(),
          const Icon(CupertinoIcons.sparkles, color: _lime, size: 24),
          const SizedBox(width: 24),
          const _NetworkGlyph(color: _lime),
        ],
      ),
      const SizedBox(height: 10),
      Text(
        '023sdS2..324d   4个月',
        style: TextStyle(
          color: palette.mutedText,
          fontSize: AcoTypography.caption,
        ),
      ),
      const SizedBox(height: 72),
      Row(
        children: [
          Text(
            'Today',
            style: TextStyle(
              color: palette.mutedText,
              fontSize: AcoTypography.body,
            ),
          ),
          const SizedBox(width: 20),
          const Text(
            '+2.34%',
            style: TextStyle(
              color: _lime,
              fontSize: AcoTypography.body,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      const SizedBox(height: 20),
      Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Row(
              children: [
                Text(
                  'USD',
                  style: TextStyle(
                    color: palette.mutedText,
                    fontSize: AcoTypography.bodyEmphasis,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: FittedBox(
                    alignment: Alignment.centerLeft,
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '--',
                      style: TextStyle(
                        color: palette.primaryText,
                        fontSize: AcoTypography.balance,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '市值   \$4M',
                style: TextStyle(
                  color: palette.primaryText,
                  fontSize: AcoTypography.bodySmall,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '流动性   1.6M USDT',
                style: TextStyle(
                  color: palette.mutedText,
                  fontSize: AcoTypography.bodySmall,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '24h交易额   \$11.6M',
                style: TextStyle(
                  color: palette.mutedText,
                  fontSize: AcoTypography.bodySmall,
                ),
              ),
            ],
          ),
        ],
      ),
      const SizedBox(height: 104),
      _TimeRangeSelector(palette: palette),
      const SizedBox(height: 38),
      AcoLimeButton(
        label: '前往闪兑',
        icon: CupertinoIcons.arrow_right_arrow_left,
        onPressed: () => onOpen(AcoScreen.dexSwap),
      ),
    ],
  );
}

class _DexSwapPage extends StatefulWidget {
  const _DexSwapPage({required this.palette});
  final AcoPalette palette;
  @override
  State<_DexSwapPage> createState() => _DexSwapPageState();
}

class _DexSwapPageState extends State<_DexSwapPage> {
  bool ethFirst = true;
  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    return ListView(
      padding: const EdgeInsets.fromLTRB(43, 20, 28, 28),
      children: [
        AcoRootHeader(
          palette: palette,
          onOpen: (_) {},
          title: 'DEX',
          onLeadingPressed: () => Navigator.of(context).maybePop(),
          leadingButtonOffset: const Offset(-23, 0),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AcoIconButton(
                icon: CupertinoIcons.slider_horizontal_3,
                palette: palette,
                label: '筛选',
                onPressed: () {},
                size: 23,
              ),
              Text(
                '••',
                style: TextStyle(
                  color: palette.primaryText,
                  fontSize: AcoTypography.bodyEmphasis,
                ),
              ),
              const Icon(CupertinoIcons.sparkles, color: _lime, size: 16),
            ],
          ),
        ),
        const SizedBox(height: 38),
        _SectionTabs(
          palette: palette,
          labels: const ['闪兑', '代币', '合约'],
          selected: 0,
        ),
        const SizedBox(height: 24),
        _SectionTabs(palette: palette, labels: const ['市价', '限价'], selected: 0),
        const SizedBox(height: 28),
        _SwapField(
          palette: palette,
          label: '兑换货币',
          symbol: ethFirst ? 'ETH' : 'USDT',
          value: '35.68',
        ),
        Center(
          child: AcoIconButton(
            icon: CupertinoIcons.arrow_down,
            palette: palette,
            label: '切换币种',
            onPressed: () => setState(() => ethFirst = !ethFirst),
            size: 22,
          ),
        ),
        _SwapField(
          palette: palette,
          label: '收到货币',
          symbol: ethFirst ? 'USDT' : 'ETH',
          value: '0.00',
        ),
        const SizedBox(height: 20),
        AcoLimeButton(
          label: '连接钱包',
          onPressed: () => _showNotice(context, '连接钱包', '请选择一个钱包继续交易。'),
        ),
        const SizedBox(height: 24),
        Text(
          '交易信息',
          style: TextStyle(
            color: palette.primaryText,
            fontWeight: FontWeight.w700,
            fontSize: AcoTypography.body,
          ),
        ),
        const SizedBox(height: 10),
        _InfoLine(palette: palette, label: '预计收到', value: '0.00 USDT'),
        _InfoLine(palette: palette, label: '滑点容差', value: '0.5%'),
      ],
    );
  }
}
