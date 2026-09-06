import 'package:aco_chat/core/theme/aco_typography.dart';
import 'package:flutter/cupertino.dart';

class AcoPalette {
  const AcoPalette(this.dark);

  final bool dark;

  Color get accent => const Color(0xFFA6DE00);
  Color get background =>
      dark ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
  Color get surface => dark ? const Color(0xFF3A3A3A) : const Color(0xFFF4F4F4);
  Color get surfaceRaised =>
      dark ? const Color(0xFF222222) : const Color(0xFFEDEDED);
  Color get inputSurface =>
      dark ? const Color(0xFF161616) : const Color(0xFFF4F4F4);
  Color get primaryText =>
      dark ? const Color(0xFFF7F7F7) : const Color(0xFF151515);
  Color get mutedText =>
      dark ? const Color(0xFF929292) : const Color(0xFF939393);
  Color get border => dark ? const Color(0xFF2D2D2D) : const Color(0xFFE2E2E2);
  Color get navInactive =>
      dark ? const Color(0xFF9E9E9E) : const Color(0xFFC4C4C4);
}

class AcoPageHeader extends StatelessWidget {
  const AcoPageHeader({
    required this.palette,
    this.title,
    this.titleWidget,
    this.onBack,
    this.right,
    this.backButtonKey,
    this.titleFollowsBack = false,
    this.titleFontSize = AcoTypography.bodyEmphasis,
    this.backButtonOffset = const Offset(-8, 0),
    super.key,
  });

  final AcoPalette palette;
  final String? title;
  final Widget? titleWidget;
  final VoidCallback? onBack;
  final Widget? right;
  final Key? backButtonKey;
  final bool titleFollowsBack;
  final double titleFontSize;
  final Offset backButtonOffset;

  @override
  Widget build(BuildContext context) {
    final titleText =
        titleWidget ??
        (title == null
            ? null
            : Text(
                title!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.primaryText,
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.w600,
                ),
              ));
    final backButton = onBack == null
        ? null
        : Transform.translate(
            offset: backButtonOffset,
            child: AcoIconButton(
              key: backButtonKey,
              icon: CupertinoIcons.back,
              palette: palette,
              label: '返回',
              onPressed: onBack!,
            ),
          );

    if (titleFollowsBack) {
      return SizedBox(
        width: double.infinity,
        height: 48,
        child: Row(
          children: [
            if (backButton != null) SizedBox(width: 44, child: backButton),
            if (titleText != null) Expanded(child: titleText),
            right ?? const SizedBox.shrink(),
          ],
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (backButton != null)
            Align(alignment: Alignment.centerLeft, child: backButton),
          if (titleText != null) Align(child: titleText),
          if (right != null)
            Align(alignment: Alignment.centerRight, child: right!),
        ],
      ),
    );
  }
}

class AcoIconButton extends StatelessWidget {
  const AcoIconButton({
    required this.icon,
    required this.palette,
    required this.label,
    required this.onPressed,
    this.size = 25,
    super.key,
  });

  final IconData icon;
  final AcoPalette palette;
  final String label;
  final VoidCallback onPressed;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    button: true,
    label: label,
    child: SizedBox(
      width: 44,
      height: 44,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: const Size(44, 44),
        onPressed: onPressed,
        child: Icon(icon, color: palette.primaryText, size: size),
      ),
    ),
  );
}
