import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:moliseis/data/data-sources/city_entity.dart';
import 'package:moliseis/data/data-sources/place_entity.dart';
import 'package:moliseis/data/mappers/place_entity_mapper.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/place.dart';
import 'package:objectbox/objectbox.dart';

void main() {
  final now = DateTime.utc(2026);

  CityEntity cityEntity({String name = 'Campobasso'}) => CityEntity(
    remoteId: 1,
    name: name,
    createdAt: now,
    modifiedAt: now,
    places: ToMany(),
    events: ToMany(),
  );

  PlaceEntity entity({
    String? description = 'A scenic location',
    bool isSaved = false,
    CityEntity? city,
  }) => PlaceEntity(
    remoteId: 5,
    name: 'Castello Monforte',
    description: description,
    coordinates: [41.5633, 14.6564],
    category: ContentCategory.history,
    createdAt: now,
    modifiedAt: now,
    city: ToOne<CityEntity>(target: city ?? cityEntity()),
    media: ToMany(),
    isSaved: isSaved,
  );

  group('PlaceEntityExtensions.toModel', () {
    test('maps all populated fields correctly', () {
      final model = entity().toModel();

      expect(model, isA<Place>());
      expect(model.remoteId, 5);
      expect(model.name, 'Castello Monforte');
      expect(model.description, 'A scenic location');
      expect(model.category, ContentCategory.history);
      expect(model.coordinates, const LatLng(41.5633, 14.6564));
      expect(model.createdAt, now);
      expect(model.modifiedAt, now);
      expect(model.city!.name, 'Campobasso');
      expect(model.media, isEmpty);
      expect(model.isSaved, isFalse);
    });

    test('null description falls back to empty string', () {
      final model = entity(description: null).toModel();
      expect(model.description, '');
    });

    test('isSaved propagates true', () {
      expect(entity(isSaved: true).toModel().isSaved, isTrue);
    });

    test('isSaved propagates false', () {
      expect(entity().toModel().isSaved, isFalse);
    });

    test('unresolved city relation produces null city', () {
      final noCity = PlaceEntity(
        remoteId: 1,
        name: 'Place',
        createdAt: now,
        modifiedAt: now,
        city: ToOne<CityEntity>(),
        media: ToMany(),
      );

      expect(noCity.toModel().city, isNull);
    });
  });
}
