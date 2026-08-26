part of 'aco_design_shell.dart';

class _MiningPage extends StatelessWidget {
  const _MiningPage({required this.palette});

  final AcoPalette palette;

  @override
  Widget build(BuildContext context) => _DetailScaffold(
    palette: palette,
    title: '挖矿',
    right: AcoIconButton(
      icon: CupertinoIcons.bell,
      palette: palette,
      label: '挖矿通知',
      onPressed: () {},
    ),
    child: ListView(
      children: [
        AcoSurface(
          palette: palette,
          radius: 16,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
          child: Text(
            '质押仅支持Donmi Chain，请在钱包中手动切换后继续。',
            style: TextStyle(
              color: palette.mutedText,
              fontSize: AcoTypography.body,
            ),
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.60,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          children: [
            _MiningTile(
              palette: palette,
              icon: CupertinoIcons.flame,
              label: '挖矿状态',
              value: '已激活',
            ),
            _MiningTile(
              palette: palette,
              icon: CupertinoIcons.chart_bar,
              label: '年化收益率',
              value: '10%',
            ),
            _MiningTile(
              palette: palette,
              icon: CupertinoIcons.creditcard,
              label: '已质押',
              value: '100DMT',
            ),
            _MiningTile(
              palette: palette,
              icon: CupertinoIcons.hand_raised,
              label: '待领取',
              value: '100DMT',
            ),
          ],
        ),
        const SizedBox(height: 22),
        AcoLimeButton(
          label: '领取收益',
          onPressed: () => _showNotice(context, '领取成功', '100DMT 已进入钱包。'),
        ),
      ],
    ),
  );
}

class _MiningTile extends StatelessWidget {
  const _MiningTile({
    required this.palette,
    required this.icon,
    required this.label,
    required this.value,
  });

  final AcoPalette palette;
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => AcoSurface(
    palette: palette,
    radius: 24,
    padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            Icon(icon, color: palette.primaryText, size: 30),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: palette.primaryText,
                fontSize: AcoTypography.bodyEmphasis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            value,
            style: TextStyle(
              color: palette.primaryText,
              fontSize: AcoTypography.headline,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}
