import 'package:flutter/widgets.dart';

/// Finds a leaf's effective style by applying its inherited span styles.
///
/// Rich text renderers put paragraph properties on ancestors and inline
/// attributes on leaves; reading only the leaf would miss preserved font axes.
TextStyle? effectiveSpanStyle(
  InlineSpan span,
  String text, [
  TextStyle? inherited,
]) {
  if (span is! TextSpan) return null;
  final style = inherited?.merge(span.style) ?? span.style;
  if (span.text == text) return style;
  for (final child in span.children ?? const <InlineSpan>[]) {
    final result = effectiveSpanStyle(child, text, style);
    if (result != null) return result;
  }
  return null;
}
