import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:moliseis/data/core/relation_update.dart';
import 'package:moliseis/data/data-sources/city_entity.dart';
import 'package:moliseis/data/data-sources/place_entity.dart';
import 'package:moliseis/data/dtos/place_dto.dart';
import 'package:moliseis/data/mappers/place_dto_mapper.dart';
import 'package:moliseis/data/mappers/place_entity_mapper.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/place.dart';
import 'package:objectbox/objectbox.dart';

import '../../support/fixtures.dart';

void main() {
  final now = DateTime.utc(2026);

  PlaceEntity placeEntity({
    String? description = 'A scenic location',
    List<Map<String, dynamic>>? descriptionDelta,
    bool isSaved = false,
    CityEntity? city,
  }) => makePlaceEntity(
    remoteId: 5,
    name: 'Castello Monforte',
    description: description,
    descriptionDelta: descriptionDelta,
    contentCategoryIndex: ContentCategory.history.index,
    coordinates: [41.5633, 14.6564],
    createdAt: now,
    modifiedAt: now,
    city: ToOne<CityEntity>(
      target: city ?? makeCityEntity(remoteId: 1, name: 'Campobasso'),
    ),
    isSaved: isSaved,
  );

  PlaceDto dto({
    List<Map<String, dynamic>>? descriptionDelta,
    RelationUpdate<int> cityId = const Keep<int>(),
  }) => PlaceDto(
    id: 5,
    name: 'Castello Monforte',
    description: 'A scenic location',
    descriptionDelta: descriptionDelta,
    latitude: 41.5633,
    longitude: 14.6564,
    category: ContentCategory.history,
    cityId: cityId,
    createdAt: now,
    modifiedAt: now,
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

    test('maps descriptionDelta through a defensive copy', () {
      final source = <Map<String, dynamic>>[
        {
          'insert': 'Castello\n',
          'attributes': <String, dynamic>{'underline': true},
        },
      ];
      final model = placeEntity(descriptionDelta: source).toModel();

      source[0]['insert'] = 'Mutated\n';
      (source[0]['attributes']! as Map<String, dynamic>)['underline'] = false;

      expect(model.descriptionDelta, [
        {
          'insert': 'Castello\n',
          'attributes': {'underline': true},
        },
      ]);
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

  group('PlaceDtoExtensions', () {
    test('copyWith preserves an omitted city scalar relation id', () {
      final copy = makePlaceEntity(remoteId: 5, cityId: 7).copyWith(
        isSaved: true,
      );

      expect(copy.cityToOneId, 7);
      expect(copy.city.targetId, 7);
    });

    test('copyWith clears a city scalar relation id explicitly', () {
      final copy = makePlaceEntity(remoteId: 5, cityId: 7).copyWith(
        cityToOneId: null,
      );

      expect(copy.cityToOneId, isNull);
    });

    test('merge keeps, clears, and assigns city scalar and target ids', () {
      final kept = dto().mergeInto(
        makePlaceEntity(remoteId: 5, cityId: 7),
      );
      final cleared = dto(cityId: const Clear<int>()).mergeInto(
        makePlaceEntity(remoteId: 5, cityId: 7),
      );
      final assigned = dto(cityId: const Assign<int>(99)).mergeInto(
        makePlaceEntity(remoteId: 5, cityId: 7),
      );

      expect(kept.cityToOneId, 7);
      expect(kept.city.targetId, 7);
      expect(cleared.cityToOneId, isNull);
      expect(cleared.city.targetId, 0);
      expect(assigned.cityToOneId, 99);
      expect(assigned.city.targetId, 99);
    });

    test('carries Delta into a new entity through a defensive copy', () {
      final source = <Map<String, dynamic>>[
        {
          'insert': 'Castello\n',
          'attributes': <String, dynamic>{'bold': true},
        },
      ];
      final mapped = dto(descriptionDelta: source).toEntity();

      source[0]['insert'] = 'Mutated\n';
      (source[0]['attributes']! as Map<String, dynamic>)['bold'] = false;

      expect(mapped.descriptionDelta, [
        {
          'insert': 'Castello\n',
          'attributes': {'bold': true},
        },
      ]);
    });

    test('replaces and clears Delta during merge', () {
      final existing = placeEntity(
        descriptionDelta: [
          {'insert': 'Previous\n'},
        ],
      );
      final merged = dto(
        descriptionDelta: [
          {'insert': 'Updated\n'},
        ],
      ).mergeInto(existing);
      final cleared = dto().mergeInto(merged);

      expect(merged.descriptionDelta, [
        {'insert': 'Updated\n'},
      ]);
      expect(cleared.descriptionDelta, isNull);
      expect(
        existing.copyWith(descriptionDelta: null).descriptionDelta,
        isNull,
      );
    });

    test('decodes a missing description_delta key as null', () {
      final decoded = PlaceDtoMapper.fromMap(<String, dynamic>{
        'id': 5,
        'name': 'Castello Monforte',
        'description': 'A scenic location',
        'latitude': 41.5633,
        'longitude': 14.6564,
        'category': ContentCategory.history.name,
        'created_at': now.toIso8601String(),
        'modified_at': now.toIso8601String(),
      });

      expect(decoded.descriptionDelta, isNull);
    });

    test('decodes description_delta from remote data', () {
      final descriptionDelta = <Map<String, dynamic>>[
        {'insert': 'Castello\n'},
      ];
      final decoded = PlaceDtoMapper.fromMap(<String, dynamic>{
        'id': 5,
        'name': 'Castello Monforte',
        'description': 'A scenic location',
        'description_delta': descriptionDelta,
        'latitude': 41.5633,
        'longitude': 14.6564,
        'category': ContentCategory.history.name,
        'created_at': now.toIso8601String(),
        'modified_at': now.toIso8601String(),
      });

      expect(decoded.descriptionDelta, descriptionDelta);
    });
  });
}
