extension DateTimeExtensions on DateTime {
  /// Returns a new [DateTime] instance with the same date but the time set to
  /// 23:59:59.999999.
  DateTime get endOfDay => DateTime(year, month, day, 23, 59, 59, 999, 999);

  /// Returns a new [DateTime] instance with the same date but the time set to
  /// 00:00:00.000000.
  DateTime get startOfDay => DateTime(year, month, day);

  /// Whether this [DateTime] instance is before the current date and time
  /// or not.
  bool get isBeforeNow => isBefore(DateTime.now());

  /// Whether this [DateTime] instance is after the current date and time
  /// or not.
  bool get isAfterNow => isAfter(DateTime.now());
}

// TODO(xmattjus): convert to non-nullable after backend table schema rewrite.
extension DateTimeNullableExtensions on DateTime? {
  /// Whether this [DateTime] instance is after or at same time as [other]
  /// or not.
  /// Both instances are converted to milliseconds since epoch before
  /// comparing them.
  ///
  /// Returns false if any of the instances is null.
  bool maybeGreaterOrEqualDate(DateTime? other) {
    final self = this;

    if (self == null || other == null) {
      return false;
    }

    final thisDate = self.millisecondsSinceEpoch;
    final otherDate = other.millisecondsSinceEpoch;

    return thisDate >= otherDate;
  }

  /// Whether this [DateTime] instance is before or at same time as [other]
  /// or not.
  /// Both instances are converted to milliseconds since epoch before
  /// comparing them.
  ///
  /// Returns false if any of the instances is null.
  bool maybeLessOrEqualDate(DateTime? other) {
    final self = this;

    if (self == null || other == null) {
      return false;
    }

    final thisDate = self.millisecondsSinceEpoch;
    final otherDate = other.millisecondsSinceEpoch;

    return thisDate <= otherDate;
  }
}
