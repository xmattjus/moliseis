import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/data/core/relation_update.dart';
import 'package:moliseis/data/data-sources/media_entity.dart';
import 'package:moliseis/data/dtos/media_dto.dart';
import 'package:moliseis/data/mappers/media_dto_mapper.dart';

import '../../support/fixtures.dart';

void main() {
  final now = DateTime.utc(2026);

  MediaDto dto({
    RelationUpdate<int> eventId = const Keep<int>(),
    RelationUpdate<int> placeId = const Keep<int>(),
  }) => MediaDto(
    id: 3,
    title: 'Updated title',
    url: 'https://example.com/media.jpg',
    width: 800,
    height: 600,
    eventId: eventId,
    placeId: placeId,
    createdAt: now,
    modifiedAt: now,
  );

  void expectRelations(
    MediaEntity entity, {
    required int? eventId,
    required int? placeId,
  }) {
    expect(entity.eventToOneId, eventId);
    expect(entity.placeToOneId, placeId);
    expect(entity.event.targetId, eventId ?? 0);
    expect(entity.place.targetId, placeId ?? 0);
  }

  group('MediaDtoExtensions', () {
    test('decodes backend description into the client title field', () {
      final decoded = MediaDtoMapper.fromMap(<String, dynamic>{
        'id': 3,
        'description': 'Backend description',
        'url': 'https://example.com/media.jpg',
        'width': 800,
        'height': 600,
        'event_id': 7,
        'place_id': null,
        'created_at': now.toIso8601String(),
        'modified_at': now.toIso8601String(),
      });

      expect(decoded.title, 'Backend description');
    });

    test('creates an entity with an event parent from an assignment', () {
      final entity = dto(eventId: const Assign<int>(7)).toEntity();

      expectRelations(entity, eventId: 7, placeId: null);
    });

    test('creates an entity with a place parent from an assignment', () {
      final entity = dto(placeId: const Assign<int>(7)).toEntity();

      expectRelations(entity, eventId: null, placeId: 7);
    });

    test('rejects a new entity without a parent', () {
      expect(
        () => dto().toEntity(),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => dto(
          eventId: const Clear<int>(),
          placeId: const Clear<int>(),
        ).toEntity(),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects a new entity with both parents', () {
      expect(
        () => dto(
          eventId: const Assign<int>(99),
          placeId: const Assign<int>(8),
        ).toEntity(),
        throwsA(isA<FormatException>()),
      );
    });

    test('preserves valid parent relations for Keep updates', () {
      final merged = dto().mergeInto(
        makeMediaEntity(remoteId: 3, eventId: 7),
      );

      expectRelations(merged, eventId: 7, placeId: null);
    });

    test('switches from an event parent to a place parent', () {
      final merged = dto(
        eventId: const Clear<int>(),
        placeId: const Assign<int>(99),
      ).mergeInto(makeMediaEntity(remoteId: 3, eventId: 7));

      expectRelations(merged, eventId: null, placeId: 99);
    });

    test('switches from a place parent to an event parent', () {
      final merged = dto(
        eventId: const Assign<int>(99),
        placeId: const Clear<int>(),
      ).mergeInto(makeMediaEntity(remoteId: 3, placeId: 7));

      expectRelations(merged, eventId: 99, placeId: null);
    });

    test('rejects a merge with neither parent', () {
      expect(
        () => dto(
          eventId: const Clear<int>(),
          placeId: const Clear<int>(),
        ).mergeInto(makeMediaEntity(remoteId: 3, eventId: 7)),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects a merge with both parents', () {
      expect(
        () => dto(
          eventId: const Assign<int>(99),
          placeId: const Assign<int>(8),
        ).mergeInto(makeMediaEntity(remoteId: 3, eventId: 7)),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
