import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/data/data-sources/event_entity.dart';
import 'package:moliseis/data/data-sources/media_entity.dart';
import 'package:moliseis/data/data-sources/place_entity.dart';
import 'package:moliseis/data/mappers/media_entity_mapper.dart';
import 'package:moliseis/domain/models/media.dart';
import 'package:objectbox/objectbox.dart';

import '../../support/fixtures.dart';

void main() {
  final now = DateTime.utc(2026);

  MediaEntity mediaEntity({
    PlaceEntity? placeTarget,
    EventEntity? eventTarget,
  }) => MediaEntity(
    remoteId: 1,
    url: 'https://cdn.example.com/img.jpg',
    width: 1920,
    height: 1080,
    createdAt: now,
    modifiedAt: now,
    place: placeTarget != null
        ? ToOne<PlaceEntity>(target: placeTarget)
        : ToOne<PlaceEntity>(),
    event: eventTarget != null
        ? ToOne<EventEntity>(target: eventTarget)
        : ToOne<EventEntity>(),
  );

  group('MediaEntityExtensions.toModel', () {
    test('maps scalar fields correctly regardless of relation', () {
      final model = mediaEntity().toModel();

      expect(model, isA<Media>());
      expect(model.remoteId, 1);
      expect(model.url, 'https://cdn.example.com/img.jpg');
      expect(model.width, 1920);
      expect(model.height, 1080);
      expect(model.createdAt, now);
      expect(model.modifiedAt, now);
    });

    test('place-linked media derives areaName and cityName from the place', () {
      final model = mediaEntity(
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
      final model = mediaEntity(
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
      final model = mediaEntity().toModel();

      expect(model.areaName, '');
      expect(model.cityName, '');
    });

    test('place takes precedence when both relations are set', () {
      // The mapper checks place first: if(place.hasValue && !event.hasValue).
      // When both are set neither branch matches, so both fields remain empty.
      final model = mediaEntity(
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
      final model = mediaEntity().toModel();

      expect(model.title, isNull);
      expect(model.author, isNull);
      expect(model.license, isNull);
      expect(model.licenseUrl, isNull);
    });

    test('optional fields are mapped when present', () {
      final entity = MediaEntity(
        remoteId: 2,
        title: 'Vista del borgo',
        author: 'Mario Rossi',
        license: 'CC BY 4.0',
        licenseUrl: 'https://creativecommons.org/licenses/by/4.0/',
        url: 'https://cdn.example.com/img2.jpg',
        width: 800,
        height: 600,
        createdAt: now,
        modifiedAt: now,
        place: ToOne<PlaceEntity>(),
        event: ToOne<EventEntity>(),
      );

      final model = entity.toModel();

      expect(model.title, 'Vista del borgo');
      expect(model.author, 'Mario Rossi');
      expect(model.license, 'CC BY 4.0');
      expect(model.licenseUrl, 'https://creativecommons.org/licenses/by/4.0/');
    });
  });
}
