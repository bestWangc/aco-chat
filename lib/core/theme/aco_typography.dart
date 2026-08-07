import 'package:flutter/cupertino.dart';

/// Shared typography scale for the Aco mobile surfaces.
///
/// Values are Flutter logical pixels. Keeping the scale in one place avoids
/// individual pages drifting apart while still allowing each screen to apply
/// its own color and weight.
abstract final class AcoTypography {
  static const caption = 12.0;
  static const bodySmall = 14.0;
  static const body = 16.0;
  static const bodyEmphasis = 18.0;
  static const title = 20.0;
  static const titleLarge = 22.0;
  static const headline = 24.0;
  static const displaySmall = 28.0;
  static const display = 32.0;
  static const metric = 40.0;
  static const balance = 52.0;

  static TextStyle withColor(
    Color color, {
    double size = body,
    FontWeight weight = FontWeight.w400,
    double? height,
  }) => TextStyle(
    color: color,
    fontSize: size,
    fontWeight: weight,
    height: height,
  );
}
