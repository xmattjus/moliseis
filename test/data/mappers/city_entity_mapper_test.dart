import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/data/data-sources/city_entity.dart';
import 'package:moliseis/data/mappers/city_entity_mapper.dart';
import 'package:moliseis/domain/models/city.dart';
import 'package:objectbox/objectbox.dart';

void main() {
  final created = DateTime.utc(2025);
  final modified = DateTime.utc(2025, 6);

  CityEntity entity() => CityEntity(
    remoteId: 7,
    name: 'Campobasso',
    createdAt: created,
    modifiedAt: modified,
    places: ToMany(),
    events: ToMany(),
  );

  group('CityEntityExtensions.toModel', () {
    test('maps all fields from a non-null entity', () {
      final model = entity().toModel()!;

      expect(model, isA<City>());
      expect(model.remoteId, 7);
      expect(model.name, 'Campobasso');
      expect(model.createdAt, created);
      expect(model.modifiedAt, modified);
    });

    test('null receiver returns null', () {
      const CityEntity? nullEntity = null;

      expect(nullEntity.toModel(), isNull);
    });
  });
}
