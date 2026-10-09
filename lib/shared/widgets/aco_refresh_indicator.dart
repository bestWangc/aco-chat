import 'package:aco_chat/shared/widgets/aco_page_header.dart';
import 'package:flutter/material.dart';

/// App-wide pull-to-refresh indicator with the Aco palette and sizing.
class AcoRefreshIndicator extends StatelessWidget {
  const AcoRefreshIndicator({
    required this.palette,
    required this.onRefresh,
    required this.child,
    this.enabled = true,
    super.key,
  });

  final AcoPalette palette;
  final Future<void> Function() onRefresh;
  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: palette.accent,
      backgroundColor: palette.surfaceRaised,
      strokeWidth: 2.5,
      displacement: 40,
      edgeOffset: 0,
      child: child,
    );
  }
}
