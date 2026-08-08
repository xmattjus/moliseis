import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:moliseis/data/core/relation_update.dart';
import 'package:moliseis/data/data-sources/city_entity.dart';
import 'package:moliseis/data/data-sources/event_entity.dart';
import 'package:moliseis/data/dtos/event_dto.dart';
import 'package:moliseis/data/mappers/event_dto_mapper.dart';
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
    List<Map<String, dynamic>>? descriptionDelta,
    DateTime? startDate,
    DateTime? endDate,
    ContentCategory category = ContentCategory.folklore,
    bool withCity = true,
  }) => makeEventEntity(
    remoteId: 3,
    name: name,
    description: description,
    descriptionDelta: descriptionDelta,
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

  EventDto dto({
    List<Map<String, dynamic>>? descriptionDelta,
    RelationUpdate<int> cityId = const Keep<int>(),
  }) => EventDto(
    id: 3,
    name: 'Sagra della Tintilia',
    description: 'A local festival',
    descriptionDelta: descriptionDelta,
    startDate: start,
    latitude: 41.5,
    longitude: 14.2,
    category: ContentCategory.folklore,
    cityId: cityId,
    createdAt: now,
    modifiedAt: now,
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

    test('maps descriptionDelta through a defensive copy', () {
      final source = <Map<String, dynamic>>[
        {
          'insert': 'Sagra\n',
          'attributes': <String, dynamic>{'italic': true},
        },
      ];
      final model = entity(descriptionDelta: source).toModel();

      source[0]['insert'] = 'Mutated\n';
      (source[0]['attributes']! as Map<String, dynamic>)['italic'] = false;

      expect(model.descriptionDelta, [
        {
          'insert': 'Sagra\n',
          'attributes': {'italic': true},
        },
      ]);
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

  group('EventDtoExtensions', () {
    test('copyWith preserves an omitted city scalar relation id', () {
      final copy = makeEventEntity(remoteId: 3, cityId: 7).copyWith(
        isDeleted: true,
      );

      expect(copy.cityToOneId, 7);
      expect(copy.city.targetId, 7);
    });

    test('copyWith clears a city scalar relation id explicitly', () {
      final copy = makeEventEntity(remoteId: 3, cityId: 7).copyWith(
        cityToOneId: null,
      );

      expect(copy.cityToOneId, isNull);
    });

    test('merge keeps, clears, and assigns city scalar and target ids', () {
      final kept = dto().mergeInto(
        makeEventEntity(remoteId: 3, cityId: 7),
      );
      final cleared = dto(cityId: const Clear<int>()).mergeInto(
        makeEventEntity(remoteId: 3, cityId: 7),
      );
      final assigned = dto(cityId: const Assign<int>(99)).mergeInto(
        makeEventEntity(remoteId: 3, cityId: 7),
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
          'insert': 'Sagra\n',
          'attributes': <String, dynamic>{'bold': true},
        },
      ];
      final mapped = dto(descriptionDelta: source).toEntity();

      source[0]['insert'] = 'Mutated\n';
      (source[0]['attributes']! as Map<String, dynamic>)['bold'] = false;

      expect(mapped.descriptionDelta, [
        {
          'insert': 'Sagra\n',
          'attributes': {'bold': true},
        },
      ]);
    });

    test('replaces and clears Delta during merge', () {
      final existing = entity(
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
      final decoded = EventDtoMapper.fromMap(<String, dynamic>{
        'id': 3,
        'name': 'Sagra della Tintilia',
        'description': 'A local festival',
        'start_date': start.toIso8601String(),
        'latitude': 41.5,
        'longitude': 14.2,
        'category': ContentCategory.folklore.name,
        'created_at': now.toIso8601String(),
        'modified_at': now.toIso8601String(),
      });

      expect(decoded.descriptionDelta, isNull);
    });

    test('decodes description_delta from remote data', () {
      final descriptionDelta = <Map<String, dynamic>>[
        {'insert': 'Sagra\n'},
      ];
      final decoded = EventDtoMapper.fromMap(<String, dynamic>{
        'id': 3,
        'name': 'Sagra della Tintilia',
        'description': 'A local festival',
        'description_delta': descriptionDelta,
        'start_date': start.toIso8601String(),
        'latitude': 41.5,
        'longitude': 14.2,
        'category': ContentCategory.folklore.name,
        'created_at': now.toIso8601String(),
        'modified_at': now.toIso8601String(),
      });

      expect(decoded.descriptionDelta, descriptionDelta);
    });
  });
}
