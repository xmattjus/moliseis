import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/data/dtos/city_dto.dart';
import 'package:moliseis/data/mappers/city_dto_mapper.dart';

import '../../support/fixtures.dart';

void main() {
  for (final deleted in [false, true]) {
    test(
      'City create and merge derive deleted=$deleted preserving identity',
      () {
        final marker = DateTime.utc(2026);
        final dto = CityDto(
          id: 7,
          name: 'Updated',
          createdAt: DateTime.utc(2025),
          modifiedAt: marker,
          deletedAt: deleted ? marker : null,
        );
        final existing = makeCityEntity(remoteId: 7, isDeleted: !deleted);
        final created = dto.toEntity();
        final merged = dto.mergeInto(existing);
        expect(created.isDeleted, deleted);
        expect(merged.isDeleted, deleted);
        expect(merged.remoteId, existing.remoteId);
        expect(merged.modifiedAt, marker);
        expect(merged.name, dto.name);
        expect(merged.places, same(existing.places));
        expect(merged.events, same(existing.events));
      },
    );
  }
}
