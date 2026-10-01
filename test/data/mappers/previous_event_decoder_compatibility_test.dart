import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/data/dtos/event_dto.dart';
import 'package:moliseis/data/mappers/event_dto_mapper.dart';

void main() {
  // First executed against the unchanged pre-allDay DTO/mapper at d7f7477.
  // This preceding supported shape is representative, not a release artifact.
  test('event decoding tolerates an additive remote all_day field', () {
    final dto = EventDtoMapper.fromMap({
      'id': 71,
      'name': 'Date-only event',
      'description': '',
      'start_date': '2026-10-11T22:00:00Z',
      'end_date': null,
      'latitude': 41.56,
      'longitude': 14.66,
      'category': 'unknown',
      'created_at': '2026-01-01T00:00:00Z',
      'modified_at': '2026-01-01T00:00:00Z',
      'all_day': true,
    });

    expect(dto.id, 71);
    expect(dto.toEntity().startDate, DateTime.utc(2026, 10, 11, 22));
  });
}
