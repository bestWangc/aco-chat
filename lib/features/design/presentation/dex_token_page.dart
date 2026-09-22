part of 'aco_design_shell.dart';

class _DexTokenPage extends StatefulWidget {
  const _DexTokenPage({
    required this.palette,
    required this.selectedChain,
    required this.onOpen,
  });
  final AcoPalette palette;
  final _WalletChain selectedChain;
  final ValueChanged<AcoScreen> onOpen;
  @override
  State<_DexTokenPage> createState() => _DexTokenPageState();
}

class _DexTokenPageState extends State<_DexTokenPage> {
  bool showSwap = false;
  bool ethFirst = true;
  String _selectedRange = '5分';
  DexRankingToken? _selectedToken;
  List<DexRankingToken> _hotTokens = const [];
  bool _loadingTokens = true;
  String _rankingChain = 'all';
  List<KLineEntity> _chartData = const [];
  final _chartController = KChartController();

  @override
  void initState() {
    super.initState();
    _loadMockCandles(_selectedRange);
    _loadHotTokens();
  }

  Future<void> _loadHotTokens() async {
    final client = DexRankingApiClient();
    try {
      final tokens = await client.hotTokens(chain: _rankingChain);
      if (mounted && tokens.isNotEmpty) setState(() => _hotTokens = tokens);
    } catch (_) {
      // The page remains usable while a network request is unavailable.
    } finally {
      client.close();
      if (mounted) setState(() => _loadingTokens = false);
    }
  }

  void _loadMockCandles(String range) {
    final intervalMinutes = switch (range) {
      '5分' => 5,
      '15分' => 15,
      '1小时' => 60,
      '4小时' => 240,
      '12小时' => 720,
      '1天' => 1440,
      _ => 15,
    };
    final data = List.generate(96, (index) {
      final base = 3320 + math.sin(index / 7) * 44 + index * .28;
      final open = base + math.sin(index * 1.7) * 14;
      final close = base + math.cos(index * 1.3) * 17;
      return KLineEntity.fromCustom(
        open: open,
        close: close,
        high: math.max(open, close) + 8 + (index % 5) * 2,
        low: math.min(open, close) - 8 - (index % 4) * 2,
        vol: 180 + (index % 12) * 24,
        time: DateTime.now()
            .subtract(Duration(minutes: (95 - index) * intervalMinutes))
            .millisecondsSinceEpoch,
      );
    });
    DataUtil.calculate(data);
    _chartData = data;
  }

  void _selectRange(String range) {
    if (_selectedRange == range) return;
    setState(() {
      _selectedRange = range;
      _loadMockCandles(range);
    });
  }

  void _openToken(DexRankingToken token) {
    setState(() {
      _selectedToken = token;
      _loadMockCandles(_selectedRange);
    });
  }

  void _selectRankingChain(String chain) {
    if (_rankingChain == chain) return;
    setState(() {
      _rankingChain = chain;
      _loadingTokens = true;
      _hotTokens = const [];
    });
    _loadHotTokens();
  }

  Widget _buildSectionTabs(AcoPalette palette) => Transform.translate(
    offset: Offset(showSwap ? 16 : 0, 0),
    child: _SectionTabs(
      palette: palette,
      labels: const ['闪兑', '代币', '合约'],
      selected: showSwap ? 0 : 1,
      itemSpacing: 12,
      fontSize: 18,
      horizontalPadding: 8,
      showSelectedIndicator: true,
      onChanged: (index) => setState(() => showSwap = index == 0),
    ),
  );

  Widget _buildHotTokenList(AcoPalette palette) {
    final horizontalPadding = showSwap ? 10.0 : 15.0;
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            20,
            horizontalPadding,
            0,
          ),
          sliver: SliverToBoxAdapter(child: _buildSectionTabs(palette)),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            8,
            horizontalPadding,
            24,
          ),
          sliver: _DexHotTokenList(
            palette: palette,
            tokens: _hotTokens,
            loading: _loadingTokens,
            onRefresh: _loadHotTokens,
            selectedChain: _rankingChain,
            onChainSelected: _selectRankingChain,
            onSelected: _openToken,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    return Column(
      children: [
        Expanded(
          child: !showSwap && _selectedToken == null
              ? _buildHotTokenList(palette)
              : ListView(
                  padding: EdgeInsets.fromLTRB(
                    showSwap ? 10 : 15,
                    20,
                    showSwap ? 10 : 15,
                    24,
                  ),
                  children: [
                    _buildSectionTabs(palette),
                    if (!showSwap) ...[
                      const SizedBox(height: 12),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(() => _selectedToken = null),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _DexTokenDisplayIcon(
                              token: _selectedToken!,
                              size: 40,
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      _selectedToken!.symbol,
                                      style: TextStyle(
                                        color: palette.primaryText,
                                        fontSize: AcoTypography.title,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Image.asset(
                                      'assets/icons/dex_dropdown_arrow.png',
                                      width: 8,
                                      fit: BoxFit.contain,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  '${_shortDexAddress(_selectedToken!.address)}   ${_selectedToken!.chain}',
                                  style: TextStyle(
                                    color: palette.mutedText,
                                    fontSize: AcoTypography.caption,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final marketWidth = (constraints.maxWidth * .28)
                              .clamp(135.0, 180.0);
                          final priceWidth =
                              constraints.maxWidth - marketWidth - 12;
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: priceWidth,
                                child: Align(
                                  alignment: Alignment.bottomLeft,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _displayValue(_selectedToken!.change),
                                        style: TextStyle(
                                          color: _lime,
                                          fontSize: AcoTypography.body,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      Row(
                                        children: [
                                          Text(
                                            '\$',
                                            style: TextStyle(
                                              color: palette.primaryText,
                                              fontSize: AcoTypography.metric,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Flexible(
                                            child: FittedBox(
                                              alignment: Alignment.centerLeft,
                                              fit: BoxFit.scaleDown,
                                              child: Text(
                                                _detailPrice(
                                                  _selectedToken!.price,
                                                ),
                                                style: TextStyle(
                                                  color: palette.primaryText,
                                                  fontSize:
                                                      AcoTypography.metric,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  _MarketStat(
                                    label: '市值',
                                    value: _displayValue(
                                      _selectedToken!.marketCap,
                                    ),
                                    palette: palette,
                                    width: marketWidth,
                                  ),
                                  const SizedBox(height: 10),
                                  _MarketStat(
                                    label: '流动性',
                                    value: _displayValue(_selectedToken!.dex),
                                    palette: palette,
                                    width: marketWidth,
                                  ),
                                  const SizedBox(height: 10),
                                  _MarketStat(
                                    label: '24h交易额',
                                    value: _displayValue(
                                      _selectedToken!.volume,
                                    ),
                                    palette: palette,
                                    width: marketWidth,
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 32),
                      _TimeRangeSelector(
                        palette: palette,
                        ranges: const ['5分', '15分', '1小时', '4小时', '12小时', '1天'],
                        selectedRange: _selectedRange,
                        onChanged: _selectRange,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 260,
                        child: KChartWidget(
                          _chartData,
                          controller: _chartController,
                          isTrendLine: false,
                          mainState: MainState.MA,
                          secondaryState: SecondaryState.NONE,
                          volHidden: true,
                          showInfoDialog: false,
                          hideGrid: false,
                          enableTheme: false,
                          enablePerformanceMode: true,
                          chartColors: ChartColors.dark().copyWith(
                            bgColor: [palette.background, palette.background],
                            gridColor: palette.border,
                            defaultTextColor: palette.mutedText,
                            nowPriceUpColor: _lime,
                            nowPriceTextColor: _black,
                          ),
                          chartStyle: ChartStyle().copyWith(
                            topPadding: 12,
                            bottomPadding: 18,
                            childPadding: 8,
                            gridRows: 3,
                            gridColumns: 4,
                          ),
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 24),
                      _DexSwapContent(
                        palette: palette,
                        selectedChain: widget.selectedChain,
                        onOpen: widget.onOpen,
                        ethFirst: ethFirst,
                        onEthFirstChanged: (value) =>
                            setState(() => ethFirst = value),
                        recentRecord: null,
                      ),
                    ],
                  ],
                ),
        ),
        if (!showSwap && _selectedToken != null) const _DexTradeActions(),
      ],
    );
  }
}

class _DexHotTokenList extends StatelessWidget {
  const _DexHotTokenList({
    required this.palette,
    required this.tokens,
    required this.loading,
    required this.selectedChain,
    required this.onRefresh,
    required this.onChainSelected,
    required this.onSelected,
  });

  final AcoPalette palette;
  final List<DexRankingToken> tokens;
  final bool loading;
  final String selectedChain;
  final Future<void> Function() onRefresh;
  final ValueChanged<String> onChainSelected;
  final ValueChanged<DexRankingToken> onSelected;

  static const _categories = ['热门', 'Meme', '主流', 'Alpha'];
  static const _chains = <(String, String)>[
    ('all', '全部'),
    ('eth', 'Ethereum'),
    ('sol', 'Solana'),
    ('bsc', 'BSC'),
  ];

  @override
  Widget build(BuildContext context) => SliverList.builder(
    itemCount: tokens.isEmpty ? 1 : tokens.length + 1,
    itemBuilder: (context, index) {
      if (index == 0) return _buildHeader();
      final token = tokens[index - 1];
      return _DexHotTokenRow(
        token: token,
        palette: palette,
        onTap: () => onSelected(token),
      );
    },
  );

  Widget _buildHeader() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        height: 38,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _categories.length,
          separatorBuilder: (_, _) => const SizedBox(width: 20),
          itemBuilder: (context, index) {
            final selected = index == 0;
            return Align(
              child: Text(
                _categories[index],
                style: TextStyle(
                  color: selected ? palette.primaryText : palette.mutedText,
                  fontSize: 18,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 14),
      SizedBox(
        height: 38,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _chains.length,
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemBuilder: (context, index) {
            final chain = _chains[index];
            final selected = chain.$1 == selectedChain;
            return CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              minimumSize: Size.zero,
              color: selected ? palette.surfaceRaised : Colors.transparent,
              borderRadius: BorderRadius.circular(18),
              onPressed: () => onChainSelected(chain.$1),
              child: Text(
                chain.$2,
                style: TextStyle(
                  color: palette.primaryText,
                  fontSize: 17,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 22),
      Row(
        children: [
          Text(
            '市值｜成交额',
            style: TextStyle(color: palette.mutedText, fontSize: 14),
          ),
          const Spacer(),
          Text(
            '价格｜涨跌幅',
            style: TextStyle(color: palette.mutedText, fontSize: 14),
          ),
        ],
      ),
      const SizedBox(height: 12),
      if (loading && tokens.isEmpty)
        const Padding(
          padding: EdgeInsets.only(top: 88),
          child: Center(child: CupertinoActivityIndicator()),
        )
      else if (tokens.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 88),
          child: Center(
            child: Column(
              children: [
                Text('暂无热门代币', style: TextStyle(color: palette.mutedText)),
                const SizedBox(height: 12),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: onRefresh,
                  child: const Text('重新加载'),
                ),
              ],
            ),
          ),
        ),
    ],
  );
}

class _DexHotTokenRow extends StatelessWidget {
  const _DexHotTokenRow({
    required this.token,
    required this.palette,
    required this.onTap,
  });

  final DexRankingToken token;
  final AcoPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => CupertinoButton(
    padding: const EdgeInsets.symmetric(vertical: 8),
    minimumSize: Size.zero,
    onPressed: onTap,
    child: Row(
      children: [
        _DexTokenDisplayIcon(token: token, size: 44),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      token.symbol,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.primaryText,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (token.verified) ...[
                    const SizedBox(width: 4),
                    const _VerifiedTokenBadge(),
                  ],
                ],
              ),
              const SizedBox(height: 3),
              Text(
                '${formatDexCompactCurrency(token.marketCap)}  |  ${formatDexCompactCurrency(token.volume)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: palette.mutedText, fontSize: 14),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 110,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FittedBox(
                alignment: Alignment.centerRight,
                fit: BoxFit.scaleDown,
                child: Text(
                  formatDexPrice(token.price),
                  style: TextStyle(
                    color: palette.primaryText,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _displayValue(token.change),
                style: TextStyle(
                  color: token.change.startsWith('-')
                      ? const Color(0xFFFF5A5F)
                      : _lime,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _VerifiedTokenBadge extends StatelessWidget {
  const _VerifiedTokenBadge();

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/icons/dex_verified_badge.png',
    width: 16,
    height: 16,
    fit: BoxFit.contain,
  );
}

class _DexTokenDisplayIcon extends StatefulWidget {
  const _DexTokenDisplayIcon({required this.token, required this.size});

  final DexRankingToken token;
  final double size;

  @override
  State<_DexTokenDisplayIcon> createState() => _DexTokenDisplayIconState();
}

class _DexTokenDisplayIconState extends State<_DexTokenDisplayIcon> {
  bool _loggedLoaded = false;
  bool _loggedFailure = false;

  @override
  void initState() {
    super.initState();
    _startLogoLoad();
  }

  @override
  void didUpdateWidget(covariant _DexTokenDisplayIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.token.logoUri != widget.token.logoUri) {
      _startLogoLoad();
    }
  }

  void _startLogoLoad() {
    _loggedLoaded = false;
    _loggedFailure = false;
    _logRequest();
  }

  void _logRequest() {
    final uri = widget.token.logoUri;
    final requestUri = _normalizedDexLogoUrl(uri);
    if (uri.isEmpty) {
      debugPrint('[DexLogo] missing url symbol=${widget.token.symbol}');
    } else if (uri.startsWith('http://') || uri.startsWith('https://')) {
      debugPrint(
        '[DexLogo] request symbol=${widget.token.symbol} url=$requestUri',
      );
      if (requestUri != uri) {
        debugPrint('[DexLogo] original url=$uri');
      }
    } else {
      debugPrint(
        '[DexLogo] unsupported url symbol=${widget.token.symbol} url=$uri',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final uri = widget.token.logoUri;
    if (!(uri.startsWith('http://') || uri.startsWith('https://'))) {
      return _unknownTokenIcon();
    }

    final requestUri = _normalizedDexLogoUrl(uri);
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: requestUri,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.cover,
        placeholder: (context, url) => _loadingTokenIcon(),
        imageBuilder: (_, imageProvider) {
          if (!_loggedLoaded) {
            _loggedLoaded = true;
            debugPrint(
              '[DexLogo] loaded symbol=${widget.token.symbol} url=$requestUri',
            );
          }
          return Image(
            image: imageProvider,
            width: widget.size,
            height: widget.size,
            fit: BoxFit.cover,
          );
        },
        errorWidget: (context, url, error) {
          if (!_loggedFailure) {
            _loggedFailure = true;
            debugPrint(
              '[DexLogo] bitmap failed symbol=${widget.token.symbol} '
              'url=$url error=$error; fallback=svg',
            );
          }
          return SvgPicture.network(
            url,
            width: widget.size,
            height: widget.size,
            fit: BoxFit.cover,
            placeholderBuilder: (_) => _loadingTokenIcon(),
            errorBuilder: (_, svgError, stackTrace) {
              debugPrint(
                '[DexLogo] svg failed symbol=${widget.token.symbol} '
                'url=$url error=$svgError',
              );
              return _unknownTokenIcon();
            },
          );
        },
      ),
    );
  }

  Widget _unknownTokenIcon() => Container(
    width: widget.size,
    height: widget.size,
    decoration: const BoxDecoration(
      color: Color(0xFF303030),
      shape: BoxShape.circle,
    ),
    child: Icon(
      CupertinoIcons.question,
      color: const Color(0xFF9A9A9A),
      size: widget.size * .52,
    ),
  );

  Widget _loadingTokenIcon() => Container(
    width: widget.size,
    height: widget.size,
    decoration: const BoxDecoration(
      color: Color(0xFF303030),
      shape: BoxShape.circle,
    ),
    child: const CupertinoActivityIndicator(color: CupertinoColors.white),
  );
}

String _shortDexAddress(String address) {
  if (address.length <= 10) return address;
  return '${address.substring(0, 6)}..${address.substring(address.length - 4)}';
}

String _normalizedDexLogoUrl(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null ||
      uri.host != 'cdn.dexscreener.com' ||
      uri.queryParameters['format'] != 'auto') {
    return value;
  }
  return uri
      .replace(queryParameters: {...uri.queryParameters, 'format': 'png'})
      .toString();
}

String formatDexCompactCurrency(String value) {
  final parsed = double.tryParse(value.trim());
  if (parsed == null) return value.isEmpty ? '--' : '\$$value';

  final absolute = parsed.abs();
  final (divisor, suffix) = absolute >= 1e9
      ? (1e9, 'B')
      : absolute >= 1e6
      ? (1e6, 'M')
      : absolute >= 1e3
      ? (1e3, 'K')
      : (1, '');
  final number = _trimTrailingZeros((absolute / divisor).toStringAsFixed(2));
  final sign = parsed < 0 ? '-' : '';
  return '\$$sign$number$suffix';
}

String formatDexPrice(String value) {
  var normalized = value.trim();
  if (normalized.isEmpty) return '--';
  if (normalized.startsWith('\$')) normalized = normalized.substring(1);

  final parsed = double.tryParse(normalized);
  if (parsed == null || !parsed.isFinite) return '\$$normalized';
  if (parsed == 0) return '\$0';

  final sign = parsed < 0 ? '-' : '';
  final absolute = parsed.abs();
  if (absolute < 0.001) {
    final decimalDigits = _priceDecimalDigits(normalized, absolute);
    final firstNonZero = decimalDigits.indexOf(RegExp(r'[1-9]'));
    if (firstNonZero >= 2) {
      var significant = decimalDigits.substring(firstNonZero);
      significant = significant.replaceFirst(RegExp(r'0+$'), '');
      significant = significant.substring(0, significant.length.clamp(0, 4));
      return '\$${sign}0.0${_toSubscript(firstNonZero - 1)}$significant';
    }
  }

  final decimals = absolute >= 1 ? 2 : 5;
  final number = _trimTrailingZeros(absolute.toStringAsFixed(decimals));
  return '\$$sign$number';
}

String _priceDecimalDigits(String value, double absolute) {
  final exponent = value.indexOf(RegExp(r'[eE]'));
  if (exponent >= 0) {
    return absolute.toStringAsFixed(20).split('.').last;
  }
  final decimalPoint = value.indexOf('.');
  return decimalPoint < 0 ? '' : value.substring(decimalPoint + 1);
}

String _toSubscript(int value) {
  const digits = {
    '0': '₀',
    '1': '₁',
    '2': '₂',
    '3': '₃',
    '4': '₄',
    '5': '₅',
    '6': '₆',
    '7': '₇',
    '8': '₈',
    '9': '₉',
  };
  return value.toString().split('').map((digit) => digits[digit]!).join();
}

String _trimTrailingZeros(String value) {
  if (!value.contains('.')) return value;
  return value
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

String _displayValue(String value) => value.isEmpty ? '--' : value;

String _detailPrice(String value) {
  if (value.isEmpty) return '3,347.03';
  if (value.startsWith('\$')) return value.substring(1);
  return value;
}

class _DexTradeActions extends StatelessWidget {
  const _DexTradeActions();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(28, 8, 28, 16),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final buttonWidth = ((constraints.maxWidth - 32) / 2).clamp(
          125.0,
          150.0,
        );
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: buttonWidth,
              child: const _DexTradeButton(
                label: '买入',
                color: Color(0xFF25A957),
              ),
            ),
            const SizedBox(width: 32),
            SizedBox(
              width: buttonWidth,
              child: const _DexTradeButton(
                label: '卖出',
                color: Color(0xFFEB456C),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _DexTradeButton extends StatelessWidget {
  const _DexTradeButton({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 40,
    child: CupertinoButton(
      padding: EdgeInsets.zero,
      color: color,
      borderRadius: BorderRadius.circular(10),
      onPressed: () {},
      child: Text(
        label,
        style: const TextStyle(
          color: CupertinoColors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}

class _MarketStat extends StatelessWidget {
  const _MarketStat({
    required this.label,
    required this.value,
    required this.palette,
    required this.width,
  });

  final String label;
  final String value;
  final AcoPalette palette;
  final double width;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: palette.mutedText,
            fontSize: AcoTypography.bodySmall,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: palette.primaryText,
            fontSize: AcoTypography.bodySmall,
          ),
        ),
      ],
    ),
  );
}
