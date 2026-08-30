import 'package:meta/meta.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// A Gregorian calendar day used for event editing in Europe/Rome.
///
/// This is deliberately a civil date rather than a [DateTime], so it cannot
/// accidentally acquire the device time zone or represent an instant.
@immutable
final class EventCalendarDate {
  /// Creates a validated Gregorian calendar date.
  EventCalendarDate(this.year, this.month, this.day) {
    final normalized = DateTime.utc(year, month, day);
    if (normalized.year != year ||
        normalized.month != month ||
        normalized.day != day) {
      throw ArgumentError.value(this, 'date', 'Must be a Gregorian date.');
    }
  }

  /// Calendar year.
  final int year;

  /// Calendar month from 1 through 12.
  final int month;

  /// Calendar day valid for [year] and [month].
  final int day;

  @override
  bool operator ==(Object other) =>
      other is EventCalendarDate &&
      year == other.year &&
      month == other.month &&
      day == other.day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() =>
      '$year-${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';
}

/// An hour-and-minute civil clock selection used for event editing.
@immutable
final class EventClockTime {
  /// Creates a validated 24-hour clock time.
  EventClockTime(this.hour, this.minute) {
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      throw ArgumentError.value(this, 'time', 'Must be an hour and minute.');
    }
  }

  /// Hour from 0 through 23.
  final int hour;

  /// Minute from 0 through 59.
  final int minute;

  @override
  bool operator ==(Object other) =>
      other is EventClockTime && hour == other.hour && minute == other.minute;

  @override
  int get hashCode => Object.hash(hour, minute);

  @override
  String toString() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

/// Immutable event temporal state used while an editor is being changed.
///
/// Exact values are always UTC. An enabled draft with [startCalendarDate] but
/// no [startInstantUtc] is an incomplete, date-selected draft.
@immutable
final class EventDateDraft {
  const EventDateDraft._({
    required this.enabled,
    required this.startCalendarDate,
    required this.startInstantUtc,
    required this.endInstantUtc,
  });

  /// Creates a disabled event state with no temporal values.
  const EventDateDraft.disabled()
    : this._(
        enabled: false,
        startCalendarDate: null,
        startInstantUtc: null,
        endInstantUtc: null,
      );

  /// Creates an enabled event with no selected start calendar date or time.
  ///
  /// This represents switching event mode on before the user selects either
  /// temporal component. It intentionally does not invent a calendar day or
  /// timestamp.
  const EventDateDraft.enabledEmpty()
    : this._(
        enabled: true,
        startCalendarDate: null,
        startInstantUtc: null,
        endInstantUtc: null,
      );

  /// Creates an enabled draft with a selected day and no exact start time.
  const EventDateDraft.unresolvedStart(EventCalendarDate startCalendarDate)
    : this._(
        enabled: true,
        startCalendarDate: startCalendarDate,
        startInstantUtc: null,
        endInstantUtc: null,
      );

  /// Creates an enabled draft with its exact UTC start and optional UTC end.
  factory EventDateDraft.exact({
    required EventCalendarDate startCalendarDate,
    required DateTime startInstantUtc,
    DateTime? endInstantUtc,
  }) => EventDateDraft._(
    enabled: true,
    startCalendarDate: startCalendarDate,
    startInstantUtc: startInstantUtc.toUtc(),
    endInstantUtc: endInstantUtc?.toUtc(),
  );

  /// Whether the event is enabled.
  final bool enabled;

  /// Selected start day, including an unresolved date-only edit.
  final EventCalendarDate? startCalendarDate;

  /// Exact UTC start, when a valid civil start date and time were resolved.
  final DateTime? startInstantUtc;

  /// Exact UTC end, when present.
  final DateTime? endInstantUtc;

  @override
  bool operator ==(Object other) =>
      other is EventDateDraft &&
      enabled == other.enabled &&
      startCalendarDate == other.startCalendarDate &&
      startInstantUtc == other.startInstantUtc &&
      endInstantUtc == other.endInstantUtc;

  @override
  int get hashCode =>
      Object.hash(enabled, startCalendarDate, startInstantUtc, endInstantUtc);
}

/// A recoverable civil-time or persistence validation issue.
enum EventTimeIssue {
  /// The selected Rome wall time occurs in the spring DST gap.
  nonexistentLocalTime,

  /// The selected Rome wall time occurs twice in the autumn DST overlap.
  ambiguousLocalTime,

  /// An enabled draft has no selected start calendar day.
  missingStartDate,

  /// An enabled draft has a date but no exact resolved start time.
  missingStartTime,

  /// An end instant precedes its start instant.
  invalidRange,
}

/// A successful or rejected edit that always retains a caller-selectable draft.
final class EventTimeEditResult {
  const EventTimeEditResult._(this.draft, this.issue);

  /// Creates a successful edit result.
  const EventTimeEditResult.success(EventDateDraft draft) : this._(draft, null);

  /// Creates a rejected edit result retaining the prior [draft].
  const EventTimeEditResult.rejected(EventDateDraft draft, EventTimeIssue issue)
    : this._(draft, issue);

  /// The changed draft on success, or the original draft on rejection.
  final EventDateDraft draft;

  /// The recoverable issue, if the edit was rejected.
  final EventTimeIssue? issue;

  /// Whether the edit was applied.
  bool get isSuccess => issue == null;
}

/// The inclusive UTC instant range corresponding to one Rome calendar day.
final class EventUtcRange {
  const EventUtcRange({required this.startUtc, required this.endUtc});

  /// First instant of the Rome day.
  final DateTime startUtc;

  /// Last microsecond of the Rome day.
  final DateTime endUtc;
}

/// Exact candidate instants for a requested Europe/Rome wall time.
final class EventWallTimeResolution {
  const EventWallTimeResolution(this.candidatesUtc);

  /// UTC candidates that exactly round-trip to the requested wall time.
  final List<DateTime> candidatesUtc;

  /// The explicit issue when no unique candidate exists.
  EventTimeIssue? get issue => switch (candidatesUtc.length) {
    0 => EventTimeIssue.nonexistentLocalTime,
    1 => null,
    _ => EventTimeIssue.ambiguousLocalTime,
  };

  /// The sole exact UTC instant, or null when the wall time is not unique.
  DateTime? get uniqueUtc =>
      candidatesUtc.length == 1 ? candidatesUtc.single : null;
}

/// Fixed Europe/Rome civil-time policy for all event editing semantics.
///
/// The policy initializes the packaged IANA data only when no database exists
/// in this isolate. It never reads or mutates the package-global local zone.
final class EventTimePolicy {
  /// Fixed IANA location used for all event time conversions.
  static const locationName = 'Europe/Rome';

  static tz.Location? _rome;

  tz.Location get _romeLocation {
    final cached = _rome;
    if (cached != null) return cached;

    if (!tz.timeZoneDatabase.isInitialized) {
      tz_data.initializeTimeZones();
    }

    return _rome = tz.getLocation(locationName);
  }

  /// Returns the Rome calendar day containing [instant].
  EventCalendarDate calendarDateForUtc(DateTime instant) {
    final local = tz.TZDateTime.from(instant.toUtc(), _romeLocation);
    return EventCalendarDate(local.year, local.month, local.day);
  }

  /// Returns the Rome hour and minute containing [instant].
  EventClockTime clockTimeForUtc(DateTime instant) {
    final local = tz.TZDateTime.from(instant.toUtc(), _romeLocation);
    return EventClockTime(local.hour, local.minute);
  }

  /// Returns the current Rome calendar day for deterministic supplied UTC
  /// [now].
  EventCalendarDate currentCalendarDate(DateTime now) =>
      calendarDateForUtc(now);

  /// Returns the current Rome clock for deterministic supplied UTC [now].
  EventClockTime currentClockTime(DateTime now) => clockTimeForUtc(now);

  /// Resolves every exact UTC candidate for a requested Rome wall time.
  EventWallTimeResolution resolveRomeWallTime(
    EventCalendarDate date,
    EventClockTime time, {
    int second = 0,
    int millisecond = 0,
    int microsecond = 0,
  }) {
    if (second < 0 ||
        second > 59 ||
        millisecond < 0 ||
        millisecond > 999 ||
        microsecond < 0 ||
        microsecond > 999) {
      throw ArgumentError('Invalid sub-minute clock components.');
    }

    final carrier = DateTime.utc(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
      second,
      millisecond,
      microsecond,
    );
    final location = _romeLocation;
    final offsets = <int>{
      for (final zone in location.zones) zone.offset.inMicroseconds,
    };
    final candidates = <DateTime>[];

    for (final offset in offsets) {
      final candidate = DateTime.fromMicrosecondsSinceEpoch(
        carrier.microsecondsSinceEpoch - offset,
        isUtc: true,
      );
      final local = tz.TZDateTime.fromMicrosecondsSinceEpoch(
        location,
        candidate.microsecondsSinceEpoch,
      );
      if (local.year == date.year &&
          local.month == date.month &&
          local.day == date.day &&
          local.hour == time.hour &&
          local.minute == time.minute &&
          local.second == second &&
          local.millisecond == millisecond &&
          local.microsecond == microsecond &&
          local.timeZoneOffset.inMicroseconds == offset) {
        candidates.add(candidate);
      }
    }

    candidates.sort((a, b) => a.compareTo(b));
    return EventWallTimeResolution(List<DateTime>.unmodifiable(candidates));
  }

  /// Returns the inclusive UTC bounds for a Rome calendar [date].
  EventUtcRange utcRangeForCalendarDate(EventCalendarDate date) {
    final start = resolveRomeWallTime(date, EventClockTime(0, 0)).uniqueUtc;
    final end = resolveRomeWallTime(
      date,
      EventClockTime(23, 59),
      second: 59,
      millisecond: 999,
      microsecond: 999,
    ).uniqueUtc;
    if (start == null || end == null) {
      throw StateError('Rome calendar-day boundary must resolve uniquely.');
    }
    return EventUtcRange(startUtc: start, endUtc: end);
  }

  /// Enables [draft] without inventing a calendar date or timestamp.
  EventDateDraft enable(EventDateDraft draft) {
    if (draft.enabled) return draft;
    return const EventDateDraft.enabledEmpty();
  }

  /// Disables an event and clears every temporal value.
  EventDateDraft disable(EventDateDraft _) => const EventDateDraft.disabled();

  /// Changes the start day while preserving the existing Rome clock precision.
  EventTimeEditResult changeStartCalendarDate(
    EventDateDraft draft,
    EventCalendarDate date,
  ) {
    final start = draft.startInstantUtc;
    if (start == null) {
      return EventTimeEditResult.success(EventDateDraft.unresolvedStart(date));
    }

    final local = tz.TZDateTime.from(start, _romeLocation);
    return _replaceStart(
      draft,
      date,
      EventClockTime(local.hour, local.minute),
      second: local.second,
      millisecond: local.millisecond,
      microsecond: local.microsecond,
    );
  }

  /// Changes the start clock while preserving existing seconds and subseconds.
  EventTimeEditResult changeStartClockTime(
    EventDateDraft draft,
    EventClockTime time,
  ) {
    final date = draft.startCalendarDate;
    if (date == null) {
      return EventTimeEditResult.rejected(
        draft,
        EventTimeIssue.missingStartDate,
      );
    }
    final start = draft.startInstantUtc;
    final local = start == null
        ? null
        : tz.TZDateTime.from(start, _romeLocation);
    return _replaceStart(
      draft,
      date,
      time,
      second: local?.second ?? 0,
      millisecond: local?.millisecond ?? 0,
      microsecond: local?.microsecond ?? 0,
    );
  }

  /// Selects an end day at its inclusive final microsecond in Rome time.
  EventTimeEditResult changeEndCalendarDate(
    EventDateDraft draft,
    EventCalendarDate date,
  ) {
    final startCalendarDate = draft.startCalendarDate;
    if (startCalendarDate == null) {
      return EventTimeEditResult.rejected(
        draft,
        EventTimeIssue.missingStartDate,
      );
    }
    final startInstantUtc = draft.startInstantUtc;
    if (startInstantUtc == null) {
      return EventTimeEditResult.rejected(
        draft,
        EventTimeIssue.missingStartTime,
      );
    }
    final end = resolveRomeWallTime(
      date,
      EventClockTime(23, 59),
      second: 59,
      millisecond: 999,
      microsecond: 999,
    );
    final issue = end.issue;
    if (issue != null) return EventTimeEditResult.rejected(draft, issue);
    final changed = EventDateDraft.exact(
      startCalendarDate: startCalendarDate,
      startInstantUtc: startInstantUtc,
      endInstantUtc: end.uniqueUtc,
    );
    return end.uniqueUtc!.isBefore(startInstantUtc)
        ? EventTimeEditResult.rejected(draft, EventTimeIssue.invalidRange)
        : EventTimeEditResult.success(changed);
  }

  /// Validates whether [draft] can be persisted without changing it.
  EventTimeIssue? validateForPersistence(EventDateDraft draft) {
    if (!draft.enabled) return null;
    if (draft.startCalendarDate == null) return EventTimeIssue.missingStartDate;
    if (draft.startInstantUtc == null) return EventTimeIssue.missingStartTime;
    final end = draft.endInstantUtc;
    if (end != null && end.isBefore(draft.startInstantUtc!)) {
      return EventTimeIssue.invalidRange;
    }
    return null;
  }

  EventTimeEditResult _replaceStart(
    EventDateDraft draft,
    EventCalendarDate date,
    EventClockTime time, {
    required int second,
    required int millisecond,
    required int microsecond,
  }) {
    final resolution = resolveRomeWallTime(
      date,
      time,
      second: second,
      millisecond: millisecond,
      microsecond: microsecond,
    );
    final issue = resolution.issue;
    if (issue != null) return EventTimeEditResult.rejected(draft, issue);
    return _withEndRepair(
      EventDateDraft.exact(
        startCalendarDate: date,
        startInstantUtc: resolution.uniqueUtc!,
        endInstantUtc: draft.endInstantUtc,
      ),
    );
  }

  EventTimeEditResult _withEndRepair(EventDateDraft draft) {
    final start = draft.startInstantUtc!;
    final end = draft.endInstantUtc;
    if (end == null || !end.isBefore(start)) {
      return EventTimeEditResult.success(draft);
    }
    return EventTimeEditResult.success(
      EventDateDraft.exact(
        startCalendarDate: draft.startCalendarDate!,
        startInstantUtc: start,
        endInstantUtc: utcRangeForCalendarDate(
          calendarDateForUtc(start),
        ).endUtc,
      ),
    );
  }
}
