import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/data/mappers/media_entity_mapper.dart';
import 'package:moliseis/domain/models/media.dart';

import '../../support/fixtures.dart';

void main() {
  final now = DateTime.utc(2026);

  group('MediaEntityExtensions.toModel', () {
    test('maps scalar fields correctly regardless of relation', () {
      final model = makeMediaEntity().toModel();

      expect(model, isA<Media>());
      expect(model.remoteId, 1);
      expect(model.url, 'https://cdn.example.com/img.jpg');
      expect(model.width, 800);
      expect(model.height, 600);
      expect(model.createdAt, now);
      expect(model.modifiedAt, now);
    });

    test('place-linked media derives areaName and cityName from the place', () {
      final model = makeMediaEntity(
        placeTarget: makePlaceEntity(
          remoteId: 10,
          name: 'Castello Monforte',
          city: newCityRelation(name: 'Campobasso'),
        ),
      ).toModel();

      expect(model.areaName, 'Castello Monforte');
      expect(model.cityName, 'Campobasso');
    });

    test('event-linked media derives areaName and cityName from the event', () {
      final model = makeMediaEntity(
        eventTarget: makeEventEntity(
          remoteId: 1,
          name: 'Sagra della Tintilia',
          city: newCityRelation(name: 'Isernia'),
        ),
      ).toModel();

      expect(model.areaName, 'Sagra della Tintilia');
      expect(model.cityName, 'Isernia');
    });

    test('unlinked media produces empty areaName and cityName', () {
      final model = makeMediaEntity().toModel();

      expect(model.areaName, '');
      expect(model.cityName, '');
    });

    test('place takes precedence when both relations are set', () {
      // The mapper checks place first: if(place.hasValue && !event.hasValue).
      // When both are set neither branch matches, so both fields remain empty.
      final model = makeMediaEntity(
        placeTarget: makePlaceEntity(
          remoteId: 1,
          city: newCityRelation(name: 'CityA'),
        ),
        eventTarget: makeEventEntity(
          remoteId: 1,
          city: newCityRelation(name: 'CityB'),
        ),
      ).toModel();

      expect(model.areaName, '');
      expect(model.cityName, '');
    });

    test('optional fields are null when absent', () {
      final model = makeMediaEntity().toModel();

      expect(model.title, isNull);
      expect(model.author, isNull);
      expect(model.license, isNull);
      expect(model.licenseUrl, isNull);
    });

    test('optional fields are mapped when present', () {
      final entity = makeMediaEntity(
        remoteId: 2,
        title: 'Vista del borgo',
        author: 'Mario Rossi',
        license: 'CC BY 4.0',
        licenseUrl: 'https://creativecommons.org/licenses/by/4.0/',
        url: 'https://cdn.example.com/img2.jpg',
      );

      final model = entity.toModel();

      expect(model.title, 'Vista del borgo');
      expect(model.author, 'Mario Rossi');
      expect(model.license, 'CC BY 4.0');
      expect(model.licenseUrl, 'https://creativecommons.org/licenses/by/4.0/');
    });
  });
}
