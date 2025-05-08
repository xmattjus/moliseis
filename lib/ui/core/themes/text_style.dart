import 'package:flutter/material.dart';

class CustomTextStyles {
  const CustomTextStyles._();

  static TextStyle? paragraphHeading(BuildContext context) {
    final theme = Theme.of(context);

    return theme.textTheme.titleMedium?.copyWith(
      color: theme.colorScheme.primary,
    );
  }

  static TextStyle? paragraphSubheading(BuildContext context) {
    final theme = Theme.of(context);

    return theme.textTheme.titleSmall?.copyWith(
      color: theme.colorScheme.tertiary,
    );
  }

  /// The style appropriate for a secondary text, e.g. the name of a place
  /// below an attraction name in a list/grid view attraction card.
  static TextStyle? subtitle(BuildContext context) =>
      Theme.of(context).textTheme.bodyMedium;

  /// The style appropriate for a small text used as a divider, e.g. the name of
  /// a section in the post screen.
  static TextStyle? section(BuildContext context) => paragraphHeading(context);

  /// The style appropriate for a primary text, e.g. the name of an attraction
  /// in the post screen.
  static TextStyle? title(BuildContext context) =>
      Theme.of(context).textTheme.titleLarge;

  /// The style appropriate for a primary text to be used in situations where
  /// [title] is too big.
  static TextStyle? titleSmaller(BuildContext context) =>
      Theme.of(context).textTheme.titleMedium;
}
