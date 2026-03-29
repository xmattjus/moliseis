extension DateTimeExtensions on DateTime {
  /// Returns a new [DateTime] instance with the same date but the time set to 23:59:59.999999.
  DateTime get endOfDay => DateTime(year, month, day, 23, 59, 59, 999, 999);

  /// Returns a new [DateTime] instance with the same date but the time set to 00:00:00.000000.
  DateTime get startOfDay => DateTime(year, month, day);
}
