import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/domain/core/event_time.dart';

void main() {
  final policy = EventTimePolicy();

  group('EventTimePolicy', () {
    test('uses Europe/Rome safely on repeated policy use', () {
      expect(
        policy.calendarDateForUtc(DateTime.utc(2026, 7)),
        EventCalendarDate(2026, 7, 1),
      );
      expect(
        EventTimePolicy().clockTimeForUtc(DateTime.utc(2026, 7)),
        EventClockTime(2, 0),
      );
    });

    test('uses summer and winter Rome offsets and rolls over UTC dates', () {
      expect(
        policy.clockTimeForUtc(DateTime.utc(2026, 7)),
        EventClockTime(2, 0),
      );
      expect(policy.clockTimeForUtc(DateTime.utc(2026)), EventClockTime(1, 0));
      expect(
        policy.currentCalendarDate(DateTime.utc(2026, 7, 1, 22, 30)),
        EventCalendarDate(2026, 7, 2),
      );
    });

    test('maps a Rome day to an inclusive UTC range', () {
      final range = policy.utcRangeForCalendarDate(
        EventCalendarDate(2026, 7, 1),
      );

      expect(range.startUtc, DateTime.utc(2026, 6, 30, 22));
      expect(range.endUtc, DateTime.utc(2026, 7, 1, 21, 59, 59, 999, 999));
    });

    test('preserves precision across start day and clock edits', () {
      final original = EventDateDraft.exact(
        startCalendarDate: EventCalendarDate(2026, 3, 28),
        startInstantUtc: DateTime.utc(2026, 3, 28, 9, 30, 15, 123, 456),
      );
      final moved = policy.changeStartCalendarDate(
        original,
        EventCalendarDate(2026, 3, 29),
      );
      final clockChanged = policy.changeStartClockTime(
        moved.draft,
        EventClockTime(10, 45),
      );

      expect(moved.isSuccess, isTrue);
      expect(
        moved.draft.startInstantUtc,
        DateTime.utc(2026, 3, 29, 8, 30, 15, 123, 456),
      );
      expect(
        clockChanged.draft.startInstantUtc,
        DateTime.utc(2026, 3, 29, 8, 45, 15, 123, 456),
      );
    });

    test(
      'repairs an overtaken end to the final microsecond of the start day',
      () {
        final draft = EventDateDraft.exact(
          startCalendarDate: EventCalendarDate(2026, 7, 2),
          startInstantUtc: DateTime.utc(2026, 7, 2, 10),
          endInstantUtc: DateTime.utc(2026, 7, 2, 10, 30),
        );
        final result = policy.changeStartClockTime(
          draft,
          EventClockTime(13, 0),
        );

        expect(result.isSuccess, isTrue);
        expect(
          result.draft.endInstantUtc,
          DateTime.utc(2026, 7, 2, 21, 59, 59, 999, 999),
        );
      },
    );

    test('represents disabled and incomplete drafts', () {
      final disabled = policy.disable(
        EventDateDraft.unresolvedStart(EventCalendarDate(2026, 7, 1)),
      );
      final incomplete = EventDateDraft.unresolvedStart(
        EventCalendarDate(2026, 7, 1),
      );

      expect(disabled.enabled, isFalse);
      expect(disabled.startInstantUtc, isNull);
      expect(policy.validateForPersistence(disabled), isNull);
      expect(
        policy.validateForPersistence(incomplete),
        EventTimeIssue.missingStartTime,
      );
    });

    test('enables an empty draft without inventing a start date or time', () {
      final enabled = policy.enable(const EventDateDraft.disabled());

      expect(enabled.enabled, isTrue);
      expect(enabled.startCalendarDate, isNull);
      expect(enabled.startInstantUtc, isNull);
      expect(enabled.endInstantUtc, isNull);
      expect(
        policy.validateForPersistence(enabled),
        EventTimeIssue.missingStartDate,
      );
    });

    test('rejects invalid end edits without replacing the prior draft', () {
      final exact = EventDateDraft.exact(
        startCalendarDate: EventCalendarDate(2026, 7, 2),
        startInstantUtc: DateTime.utc(2026, 7, 2, 10),
      );
      final incomplete = EventDateDraft.unresolvedStart(
        EventCalendarDate(2026, 7, 2),
      );
      final invalidEnd = policy.changeEndCalendarDate(
        exact,
        EventCalendarDate(2026, 7, 1),
      );
      final missingTime = policy.changeEndCalendarDate(
        incomplete,
        EventCalendarDate(2026, 7, 2),
      );

      expect(invalidEnd.issue, EventTimeIssue.invalidRange);
      expect(invalidEnd.draft, same(exact));
      expect(missingTime.issue, EventTimeIssue.missingStartTime);
      expect(missingTime.draft, same(incomplete));
    });

    test('rejects Rome DST gaps and overlaps without replacing the draft', () {
      final draft = EventDateDraft.unresolvedStart(
        EventCalendarDate(2026, 3, 29),
      );
      final gap = policy.resolveRomeWallTime(
        EventCalendarDate(2026, 3, 29),
        EventClockTime(2, 30),
      );
      final overlap = policy.resolveRomeWallTime(
        EventCalendarDate(2026, 10, 25),
        EventClockTime(2, 30),
      );
      final rejectedGap = policy.changeStartClockTime(
        draft,
        EventClockTime(2, 30),
      );
      final overlapDraft = EventDateDraft.unresolvedStart(
        EventCalendarDate(2026, 10, 25),
      );
      final rejectedOverlap = policy.changeStartClockTime(
        overlapDraft,
        EventClockTime(2, 30),
      );

      expect(gap.candidatesUtc, isEmpty);
      expect(overlap.candidatesUtc, hasLength(2));
      expect(rejectedGap.issue, EventTimeIssue.nonexistentLocalTime);
      expect(rejectedGap.draft, same(draft));
      expect(rejectedOverlap.issue, EventTimeIssue.ambiguousLocalTime);
      expect(rejectedOverlap.draft, same(overlapDraft));
    });
  });
  test(
    'all-day bounds include DST-safe single, same-day and multi-day dates',
    () {
      for (final date in [
        EventCalendarDate(2026, 3, 29),
        EventCalendarDate(2026, 10, 25),
      ]) {
        final draft = policy
            .changeAllDay(EventDateDraft.unresolvedStart(date), allDay: true)
            .draft;
        expect(draft.allDay, isTrue);
        expect(policy.validateForPersistence(draft), isNull);
        expect(
          draft.startInstantUtc,
          policy.utcRangeForCalendarDate(date).startUtc,
        );
        expect(draft.endInstantUtc, isNull);
        final finalDay = policy.changeEndCalendarDate(draft, date).draft;
        expect(
          finalDay.endInstantUtc,
          policy.utcRangeForCalendarDate(date).endUtc,
        );
        expect(finalDay.endCalendarDate, date);
        expect(finalDay.endInstantUtc!.microsecond, 999);
      }
    },
  );

  test(
    'toggle discards clock, retains civil days and requires a new timed clock',
    () {
      final original = EventDateDraft.exact(
        startCalendarDate: EventCalendarDate(2026, 12, 31),
        startInstantUtc: DateTime.utc(2026, 12, 31, 10, 15),
        endInstantUtc: DateTime.utc(2027, 1, 1, 22, 59, 59, 999, 999),
      );
      final allDay = policy.changeAllDay(original, allDay: true).draft;
      expect(allDay.startInstantUtc, DateTime.utc(2026, 12, 30, 23));
      expect(allDay.endCalendarDate, EventCalendarDate(2027, 1, 1));
      final timed = policy.changeAllDay(allDay, allDay: false).draft;
      expect(timed.startInstantUtc, isNull);
      expect(timed.endInstantUtc, isNull);
      expect(timed.endCalendarDate, allDay.endCalendarDate);
      expect(
        policy.validateForPersistence(timed),
        EventTimeIssue.missingStartTime,
      );
      final resolved = policy
          .changeStartClockTime(timed, EventClockTime(18, 30))
          .draft;
      expect(resolved.startInstantUtc, DateTime.utc(2026, 12, 31, 17, 30));
      expect(resolved.endInstantUtc, original.endInstantUtc);
      expect(resolved.allDay, isFalse);
      expect(policy.disable(allDay), const EventDateDraft.disabled());
    },
  );

  test(
    'all-day date changes rematerialize and repair an overtaken final day',
    () {
      final draft = policy
          .changeAllDay(
            EventDateDraft.unresolvedStart(
              EventCalendarDate(2026, 3, 28),
              endCalendarDate: EventCalendarDate(2026, 3, 29),
            ),
            allDay: true,
          )
          .draft;
      final changed = policy
          .changeStartCalendarDate(draft, EventCalendarDate(2026, 3, 30))
          .draft;
      expect(changed.endCalendarDate, EventCalendarDate(2026, 3, 30));
      expect(policy.validateForPersistence(changed), isNull);
      expect(
        policy
            .changeEndCalendarDate(changed, EventCalendarDate(2026, 3, 29))
            .issue,
        EventTimeIssue.invalidRange,
      );
    },
  );

  test('unresolved moved start cannot materialize inverted all-day range', () {
    final unresolved = EventDateDraft.unresolvedStart(
      EventCalendarDate(2026, 10, 12),
      endCalendarDate: EventCalendarDate(2026, 10, 14),
    );
    final moved = policy
        .changeStartCalendarDate(unresolved, EventCalendarDate(2026, 10, 15))
        .draft;
    expect(policy.validateForPersistence(moved), EventTimeIssue.invalidRange);
    expect(
      policy.changeAllDay(moved, allDay: true).issue,
      EventTimeIssue.invalidRange,
    );
    final repaired = policy
        .changeStartClockTime(moved, EventClockTime(18, 0))
        .draft;
    expect(repaired.endCalendarDate, EventCalendarDate(2026, 10, 15));
    expect(policy.validateForPersistence(repaired), isNull);
  });

  test('all-day empty edit still requires a civil start', () {
    final empty = policy
        .changeAllDay(const EventDateDraft.enabledEmpty(), allDay: true)
        .draft;
    expect(empty.allDay, isTrue);
    expect(
      policy.validateForPersistence(empty),
      EventTimeIssue.missingStartDate,
    );
    final selected = policy
        .changeStartCalendarDate(empty, EventCalendarDate(2026, 10, 12))
        .draft;
    expect(policy.validateForPersistence(selected), isNull);
  });
}
