import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/data/dtos/event_dto.dart';
import 'package:moliseis/data/mappers/event_dto_mapper.dart';
import 'package:moliseis/domain/models/content_category.dart';

void main() {
  test('normalizes create and merge event instants to UTC', () {
    final dto = EventDto(
      id: 1,
      name: 'Festival',
      description: '',
      startDate: DateTime(2026, 8, 20, 21),
      endDate: DateTime(2026, 8, 20, 23),
      latitude: 0,
      longitude: 0,
      category: ContentCategory.unknown,
      createdAt: DateTime.utc(2026),
      modifiedAt: DateTime.utc(2026),
    );
    final created = dto.toEntity();
    final merged = dto.mergeInto(created);

    expect(created.startDate, dto.startDate.toUtc());
    expect(created.endDate, dto.endDate!.toUtc());
    expect(merged.startDate, dto.startDate.toUtc());
    expect(merged.endDate, dto.endDate!.toUtc());
    expect(
      created.startDate!.microsecondsSinceEpoch,
      dto.startDate.microsecondsSinceEpoch,
    );
    expect(
      merged.endDate!.microsecondsSinceEpoch,
      dto.endDate!.microsecondsSinceEpoch,
    );
  });

  test(
    'clears a persisted end when an authoritative remote event is start-only',
    () {
      final existing = EventDto(
        id: 1,
        name: 'Festival',
        description: '',
        startDate: DateTime.utc(2026, 8, 20, 21),
        endDate: DateTime.utc(2026, 8, 20, 23),
        latitude: 0,
        longitude: 0,
        category: ContentCategory.unknown,
        createdAt: DateTime.utc(2026),
        modifiedAt: DateTime.utc(2026),
      ).toEntity();
      final startOnlyDto = EventDto(
        id: 1,
        name: 'Festival',
        description: '',
        startDate: DateTime.utc(2026, 8, 20, 21),
        latitude: 0,
        longitude: 0,
        category: ContentCategory.unknown,
        createdAt: DateTime.utc(2026),
        modifiedAt: DateTime.utc(2026),
      );

      expect(startOnlyDto.mergeInto(existing).endDate, isNull);
    },
  );
}
