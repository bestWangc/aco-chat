import 'package:aco_chat/core/localization/app_localization.dart';
import 'package:flutter/widgets.dart' as fw;

/// Text widget that translates exact UI strings using the active app locale.
class Text extends fw.StatelessWidget {
  const Text(
    this.data, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  }) : textSpan = null;

  const Text.rich(
    this.textSpan, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  }) : data = null;

  final String? data;
  final fw.InlineSpan? textSpan;
  final fw.TextStyle? style;
  final fw.StrutStyle? strutStyle;
  final fw.TextAlign? textAlign;
  final fw.TextDirection? textDirection;
  final fw.Locale? locale;
  final bool? softWrap;
  final fw.TextOverflow? overflow;
  final fw.TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final fw.TextWidthBasis? textWidthBasis;
  final fw.TextHeightBehavior? textHeightBehavior;
  final fw.Color? selectionColor;

  @override
  fw.Widget build(fw.BuildContext context) {
    final value = data;
    if (value != null) {
      return fw.Text(
        appText(context, value),
        style: style,
        strutStyle: strutStyle,
        textAlign: textAlign,
        textDirection: textDirection,
        locale: locale,
        softWrap: softWrap,
        overflow: overflow,
        textScaler: textScaler,
        maxLines: maxLines,
        semanticsLabel: semanticsLabel,
        textWidthBasis: textWidthBasis,
        textHeightBehavior: textHeightBehavior,
        selectionColor: selectionColor,
      );
    }
    return fw.Text.rich(
      _localizedSpan(context, textSpan!),
      style: style,
      strutStyle: strutStyle,
      textAlign: textAlign,
      textDirection: textDirection,
      locale: locale,
      softWrap: softWrap,
      overflow: overflow,
      textScaler: textScaler,
      maxLines: maxLines,
      semanticsLabel: semanticsLabel,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      selectionColor: selectionColor,
    );
  }

  fw.InlineSpan _localizedSpan(fw.BuildContext context, fw.InlineSpan span) {
    if (span is! fw.TextSpan) return span;
    return fw.TextSpan(
      text: span.text == null ? null : appText(context, span.text!),
      style: span.style,
      children: span.children
          ?.map((child) => _localizedSpan(context, child))
          .toList(growable: false),
      recognizer: span.recognizer,
      semanticsLabel: span.semanticsLabel,
      locale: span.locale,
      spellOut: span.spellOut,
    );
  }
}
