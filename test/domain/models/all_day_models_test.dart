import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/domain/models/content_submission.dart';

import '../../support/fixtures.dart';

void main() {
  test('event equality distinguishes mode without inferring real midnight', () {
    final timed = makeEvent(startDate: DateTime.utc(2026, 10, 12));
    final allDay = makeEvent(
      startDate: timed.startDate,
      allDay: true,
      city: timed.city,
    );
    expect(timed.allDay, isFalse);
    expect(allDay.allDay, isTrue);
    expect(timed, isNot(allDay));
    expect(
      allDay,
      makeEvent(startDate: timed.startDate, allDay: true, city: timed.city),
    );
  });
  test('captured submission equality includes source-owned mode', () {
    final timed = ContentSubmission(
      city: 'Campobasso',
      name: 'Event',
      userEmail: 'a@example.test',
      userName: 'A',
    );
    final allDay = ContentSubmission(
      city: 'Campobasso',
      name: 'Event',
      userEmail: 'a@example.test',
      userName: 'A',
      allDay: true,
    );
    expect(timed.allDay, isFalse);
    expect(timed, isNot(allDay));
  });
}
