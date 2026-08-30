import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/data/mappers/content_submission_mapper.dart';
import 'package:moliseis/domain/models/content_submission.dart';

void main() {
  ContentSubmission submission({
    required List<Map<String, dynamic>>? descriptionDelta,
  }) => ContentSubmission(
    city: 'Isernia',
    name: 'Visita guidata',
    description: 'Visita guidata',
    descriptionDelta: descriptionDelta,
    userEmail: 'author@example.com',
    userName: 'Author',
  );

  test('maps a defensive Delta copy', () {
    final source = <Map<String, dynamic>>[
      {
        'insert': 'Visita ',
        'attributes': <String, dynamic>{'bold': true},
      },
      {'insert': 'guidata\n'},
    ];
    final dto = submission(descriptionDelta: source).toDto(userId: 'user-id');

    source[0]['insert'] = 'Mutated ';
    (source[0]['attributes']! as Map<String, dynamic>)['bold'] = false;

    const expected = <Map<String, dynamic>>[
      {
        'insert': 'Visita ',
        'attributes': {'bold': true},
      },
      {'insert': 'guidata\n'},
    ];
    expect(dto.descriptionDelta, expected);
  });

  test('uses description_delta as the wire key', () {
    const descriptionDelta = <Map<String, dynamic>>[
      {'insert': 'Visita guidata\n'},
    ];
    final dto = submission(descriptionDelta: descriptionDelta).toDto(
      userId: 'user-id',
    );

    expect(dto.toMap()['description_delta'], descriptionDelta);
  });

  test('serializes event instants as UTC ISO strings', () {
    final start = DateTime.fromMicrosecondsSinceEpoch(
      DateTime.utc(2026, 7, 25, 10, 30).microsecondsSinceEpoch,
    );
    final end = DateTime.fromMicrosecondsSinceEpoch(
      DateTime.utc(2026, 7, 26, 21, 59, 59).microsecondsSinceEpoch,
    );
    final dto = ContentSubmission(
      city: 'Isernia',
      name: 'Visita guidata',
      startDate: start,
      endDate: end,
      userEmail: 'author@example.com',
      userName: 'Author',
    ).toDto(userId: 'user-id');

    final map = dto.toMap();

    expect(start.isUtc, isFalse);
    expect(end.isUtc, isFalse);
    expect(map['start_date'], '2026-07-25T10:30:00.000Z');
    expect(map['end_date'], '2026-07-26T21:59:59.000Z');
  });
}
