part of 'aco_design_shell.dart';

class _TransferSectionLabel extends StatelessWidget {
  const _TransferSectionLabel({
    required this.palette,
    required this.label,
    this.action,
  });

  final AcoPalette palette;
  final String label;
  final String? action;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(
        label,
        style: TextStyle(
          color: palette.primaryText,
          fontSize: AcoTypography.bodyEmphasis,
          fontWeight: FontWeight.w600,
        ),
      ),
      const Spacer(),
      if (action case final action?)
        CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: const Size(48, 28),
          onPressed: null,
          child: Text(
            action,
            style: TextStyle(
              color: palette.mutedText,
              fontSize: AcoTypography.bodySmall,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
    ],
  );
}

class _TransferInputSurface extends StatelessWidget {
  const _TransferInputSurface({required this.palette, required this.child});

  final AcoPalette palette;
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: palette.surface,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: palette.border),
    ),
    child: child,
  );
}
