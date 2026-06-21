import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:moliseis/data/data-sources/city_entity.dart';
import 'package:moliseis/data/data-sources/event_entity.dart';
import 'package:moliseis/data/mappers/event_entity_mapper.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/event.dart';
import 'package:objectbox/objectbox.dart';

import '../../support/fixtures.dart';

void main() {
  final now = DateTime.utc(2026, 4);
  final start = DateTime.utc(2026, 5, 10);
  final end = DateTime.utc(2026, 5, 12);

  CityEntity cityEntity() => makeCityEntity(remoteId: 1, name: 'Isernia');

  EventEntity entity({
    String name = 'Sagra della Tintilia',
    String? description = 'A local festival',
    DateTime? startDate,
    DateTime? endDate,
    ContentCategory category = ContentCategory.folklore,
    bool withCity = true,
  }) => makeEventEntity(
    remoteId: 3,
    name: name,
    description: description,
    startDate: startDate ?? start,
    endDate: endDate,
    coordinates: [41.5, 14.2],
    contentCategoryIndex: category.index,
    createdAt: now,
    modifiedAt: now,
    city: withCity
        ? ToOne<CityEntity>(target: cityEntity())
        : ToOne<CityEntity>(),
  );

  group('EventEntityExtensions.toModel', () {
    test('maps all populated fields correctly', () {
      final model = entity(endDate: end).toModel();

      expect(model, isA<Event>());
      expect(model.remoteId, 3);
      expect(model.name, 'Sagra della Tintilia');
      expect(model.description, 'A local festival');
      expect(model.startDate, start);
      expect(model.endDate, end);
      expect(model.category, ContentCategory.folklore);
      expect(model.coordinates, const LatLng(41.5, 14.2));
      expect(model.createdAt, now);
      expect(model.modifiedAt, now);
      expect(model.city!.name, 'Isernia');
      expect(model.media, isEmpty);
      expect(model.isSaved, isFalse);
    });

    test('null endDate produces null in domain model', () {
      expect(entity().toModel().endDate, isNull);
    });

    test('null description falls back to empty string', () {
      expect(entity(description: null).toModel().description, '');
    });

    test('null startDate falls back to a non-null DateTime', () {
      // Documents the current ?? DateTime.now() fallback in the mapper.
      final entityWithNullStart = makeEventEntity(
        remoteId: 1,
        city: ToOne<CityEntity>(target: cityEntity()),
      );
      expect(entityWithNullStart.toModel().startDate, isNotNull);
    });

    test('unresolved city relation produces null city', () {
      final model = entity(withCity: false).toModel();

      expect(model.city, isNull);
    });
  });
}
