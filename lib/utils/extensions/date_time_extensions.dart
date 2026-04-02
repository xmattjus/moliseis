extension DateTimeExtensions on DateTime {
  /// Returns a new [DateTime] instance with the same date but the time set to 23:59:59.999999.
  DateTime get endOfDay => DateTime(year, month, day, 23, 59, 59, 999, 999);

  /// Returns a new [DateTime] instance with the same date but the time set to 00:00:00.000000.
  DateTime get startOfDay => DateTime(year, month, day);

  /// Returns whether this [DateTime] instance is before the current date and time.
  bool get isBeforeNow => isBefore(DateTime.now());

  /// Returns whether this [DateTime] instance is after the current date and time.
  bool get isAfterNow => isAfter(DateTime.now());
}
