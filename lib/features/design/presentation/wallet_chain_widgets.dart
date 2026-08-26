part of 'aco_design_shell.dart';

class _WalletChainLogo extends StatelessWidget {
  const _WalletChainLogo({
    required this.asset,
    this.muted = false,
    this.backgroundColor,
    this.size = 40,
  });

  final String asset;
  final bool muted;
  final Color? backgroundColor;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: Opacity(
      opacity: muted ? .58 : 1,
      child: ClipOval(
        child: ColoredBox(
          color: backgroundColor ?? _transparent,
          child: asset.endsWith('.svg')
              ? SvgPicture.asset(asset, fit: BoxFit.cover)
              : Image.asset(asset, fit: BoxFit.cover),
        ),
      ),
    ),
  );
}
