import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:moliseis/data/data-sources/city_entity.dart';
import 'package:moliseis/data/data-sources/place_entity.dart';
import 'package:moliseis/data/mappers/place_entity_mapper.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/place.dart';
import 'package:objectbox/objectbox.dart';

import '../../support/fixtures.dart';

void main() {
  final now = DateTime.utc(2026);

  PlaceEntity placeEntity({
    String? description = 'A scenic location',
    bool isSaved = false,
    CityEntity? city,
  }) => makePlaceEntity(
    remoteId: 5,
    name: 'Castello Monforte',
    description: description,
    contentCategoryIndex: ContentCategory.history.index,
    coordinates: [41.5633, 14.6564],
    createdAt: now,
    modifiedAt: now,
    city: ToOne<CityEntity>(
      target: city ?? makeCityEntity(remoteId: 1, name: 'Campobasso'),
    ),
    isSaved: isSaved,
  );

  group('PlaceEntityExtensions.toModel', () {
    test('maps all populated fields correctly', () {
      final model = placeEntity().toModel();

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
      final model = placeEntity(description: null).toModel();
      expect(model.description, '');
    });

    test('isSaved propagates true', () {
      expect(placeEntity(isSaved: true).toModel().isSaved, isTrue);
    });

    test('isSaved propagates false', () {
      expect(placeEntity().toModel().isSaved, isFalse);
    });

    test('unresolved city relation produces null city', () {
      final noCity = makePlaceEntity(remoteId: 1);

      expect(noCity.toModel().city, isNull);
    });
  });
}
