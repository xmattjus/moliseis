import 'package:flutter/material.dart';

class AppTextStyles {
  const AppTextStyles._();

  static TextStyle? subtitle(BuildContext context) =>
      Theme.of(context).textTheme.bodyMedium;

  static TextStyle? section(BuildContext context) {
    final theme = Theme.of(context);

    return theme.textTheme.titleMedium?.copyWith(
      color: theme.colorScheme.primary,
    );
  }

  static TextStyle? title(BuildContext context) =>
      Theme.of(context).textTheme.titleLarge;

  static TextStyle? titleSmaller(BuildContext context) =>
      Theme.of(context).textTheme.titleMedium;

  static TextStyle? calendarWeekDay(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return DatePickerTheme.defaults(context).weekdayStyle?.copyWith(
      color: brightness == Brightness.light ? Colors.black45 : Colors.white54,
    );
  }

  static TextStyle? calendarMonthSection(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return section(context)?.copyWith(
      color: brightness == Brightness.light ? Colors.black87 : Colors.white70,
    );
  }
}
