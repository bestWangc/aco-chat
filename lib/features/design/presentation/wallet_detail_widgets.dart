part of 'aco_design_shell.dart';

class _WalletDetailDeleteButton extends StatelessWidget {
  const _WalletDetailDeleteButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '删除钱包',
    child: SizedBox(
      width: double.infinity,
      height: 38,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        color: _walletDetailDeleteColor,
        borderRadius: BorderRadius.circular(19),
        onPressed: onPressed,
        child: const Text(
          '删除钱包',
          style: TextStyle(
            color: _white,
            fontSize: AcoTypography.body,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    ),
  );
}

class _WalletDetailAction extends StatelessWidget {
  const _WalletDetailAction({
    required this.label,
    required this.palette,
    required this.onPressed,
  });

  final String label;
  final AcoPalette palette;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => CupertinoButton(
    padding: const EdgeInsets.symmetric(horizontal: 18),
    minimumSize: const Size.fromHeight(60),
    onPressed: onPressed,
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: palette.primaryText,
              fontSize: AcoTypography.body,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        _WalletDetailChevron(color: palette.mutedText),
      ],
    ),
  );
}

class _WalletDetailChevron extends StatelessWidget {
  const _WalletDetailChevron({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 24,
    height: 24,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Icon(CupertinoIcons.chevron_right, color: color, size: 24),
        Transform.translate(
          offset: const Offset(-0.75, 0),
          child: Icon(CupertinoIcons.chevron_right, color: color, size: 24),
        ),
      ],
    ),
  );
}

class _WalletDetailActionCard extends StatelessWidget {
  const _WalletDetailActionCard({required this.palette, required this.child});

  final AcoPalette palette;
  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 121,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: palette.dark ? palette.background : palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: palette.dark ? _walletDetailBorderColor : palette.border,
        ),
      ),
      child: child,
    ),
  );
}
