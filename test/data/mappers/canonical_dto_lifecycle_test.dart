import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/data/core/relation_update.dart';
import 'package:moliseis/data/dtos/event_dto.dart';
import 'package:moliseis/data/dtos/media_dto.dart';
import 'package:moliseis/data/dtos/place_dto.dart';
import 'package:moliseis/data/mappers/event_dto_mapper.dart';
import 'package:moliseis/data/mappers/media_dto_mapper.dart';
import 'package:moliseis/data/mappers/place_dto_mapper.dart';
import 'package:moliseis/domain/models/content_category.dart';

import '../../support/fixtures.dart';

void main() {
  final marker = DateTime.utc(2027);
  test('nullable copy fields distinguish omission from explicit null', () {
    final event = makeEventEntity(remoteId: 71, description: 'Old');
    final place = makePlaceEntity(remoteId: 72, description: 'Old');
    final media = makeMediaEntity(
      remoteId: 73,
      eventId: 71,
      title: 'Old title',
      author: 'Old author',
      license: 'Old license',
      licenseUrl: 'Old url',
    );
    expect(event.copyWith(isSaved: true).description, 'Old');
    expect(place.copyWith(isSaved: true).description, 'Old');
    expect(event.copyWith(description: null).description, isNull);
    expect(place.copyWith(description: null).description, isNull);
    final retained = media.copyWith(isDeleted: true);
    expect(retained.title, media.title);
    expect(retained.author, media.author);
    expect(retained.license, media.license);
    expect(retained.licenseUrl, media.licenseUrl);
    final cleared = media.copyWith(
      title: null,
      author: null,
      license: null,
      licenseUrl: null,
    );
    expect(cleared.title, isNull);
    expect(cleared.author, isNull);
    expect(cleared.license, isNull);
    expect(cleared.licenseUrl, isNull);
  });

  for (final deleted in [false, true]) {
    test('authoritative null mapper fields clear deleted=$deleted state', () {
      final event = makeEventEntity(
        remoteId: 71,
        description: 'Old',
        isDeleted: !deleted,
      ).copyWith(isSaved: true);
      final place = makePlaceEntity(
        remoteId: 72,
        description: 'Old',
        isDeleted: !deleted,
        isSaved: true,
      );
      final media = makeMediaEntity(
        remoteId: 73,
        eventId: 71,
        title: 'Old title',
        author: 'Old author',
        license: 'Old license',
        licenseUrl: 'Old url',
        isDeleted: !deleted,
      );
      final eventDto = EventDto(
        id: 71,
        name: 'Remote',
        description: null,
        startDate: marker,
        latitude: 41,
        longitude: 14,
        category: ContentCategory.unknown,
        createdAt: DateTime.utc(2024),
        modifiedAt: marker,
        deletedAt: deleted ? marker : null,
      );
      final placeDto = PlaceDto(
        id: 72,
        name: 'Remote',
        description: null,
        latitude: 41,
        longitude: 14,
        category: ContentCategory.unknown,
        createdAt: DateTime.utc(2024),
        modifiedAt: marker,
        deletedAt: deleted ? marker : null,
      );
      final mediaDto = MediaDto(
        id: 73,
        url: 'https://example.com/new.jpg',
        width: 900,
        height: 600,
        eventId: const Assign<int>(71),
        placeId: const Clear<int>(),
        createdAt: DateTime.utc(2024),
        modifiedAt: marker,
        deletedAt: deleted ? marker : null,
      );
      final mergedEvent = eventDto.mergeInto(event);
      final mergedPlace = placeDto.mergeInto(place);
      final mergedMedia = mediaDto.mergeInto(media);
      expect(mergedEvent.description, isNull);
      expect(mergedPlace.description, isNull);
      expect(mergedEvent.isSaved, isTrue);
      expect(mergedPlace.isSaved, isTrue);
      expect(mergedMedia.title, isNull);
      expect(mergedMedia.author, isNull);
      expect(mergedMedia.license, isNull);
      expect(mergedMedia.licenseUrl, isNull);
      expect(mergedEvent.isDeleted, deleted);
      expect(mergedPlace.isDeleted, deleted);
      expect(mergedMedia.isDeleted, deleted);
    });
  }

  for (final deleted in [false, true]) {
    test('Event full lifecycle deleted=$deleted retains saved identity', () {
      final existing = makeEventEntity(
        remoteId: 71,
        cityId: 7,
        isDeleted: !deleted,
      ).copyWith(isSaved: true);
      final dto = EventDto(
        id: 71,
        name: 'Remote event',
        description: 'Remote description',
        descriptionDelta: const [
          {'insert': 'Remote\n'},
        ],
        startDate: marker,
        endDate: marker.add(const Duration(hours: 3)),
        allDay: true,
        latitude: 41,
        longitude: 14,
        category: ContentCategory.unknown,
        cityId: const Assign<int>(8),
        createdAt: DateTime.utc(2024),
        modifiedAt: marker,
        deletedAt: deleted ? marker : null,
      );
      final merged = dto.mergeInto(existing);
      expect(merged.remoteId, existing.remoteId);
      expect(merged.isSaved, isTrue);
      expect(merged.isDeleted, deleted);
      expect(merged.modifiedAt, marker);
      expect(merged.name, dto.name);
      expect(merged.description, dto.description);
      expect(merged.descriptionDelta, dto.descriptionDelta);
      expect(merged.startDate, dto.startDate);
      expect(merged.endDate, dto.endDate);
      expect(merged.allDay, isTrue);
      expect(merged.coordinates, [41, 14]);
      expect(merged.city.targetId, 8);
      expect(merged.media, same(existing.media));
    });

    test('Place full lifecycle deleted=$deleted retains saved identity', () {
      final existing = makePlaceEntity(
        remoteId: 72,
        cityId: 7,
        isDeleted: !deleted,
        isSaved: true,
      );
      final dto = PlaceDto(
        id: 72,
        name: 'Remote place',
        description: 'Remote description',
        descriptionDelta: const [
          {'insert': 'Remote\n'},
        ],
        latitude: 41,
        longitude: 14,
        category: ContentCategory.unknown,
        cityId: const Clear<int>(),
        createdAt: DateTime.utc(2024),
        modifiedAt: marker,
        deletedAt: deleted ? marker : null,
      );
      final merged = dto.mergeInto(existing);
      expect(merged.remoteId, existing.remoteId);
      expect(merged.isSaved, isTrue);
      expect(merged.isDeleted, deleted);
      expect(merged.modifiedAt, marker);
      expect(merged.name, dto.name);
      expect(merged.description, dto.description);
      expect(merged.descriptionDelta, dto.descriptionDelta);
      expect(merged.coordinates, [41, 14]);
      expect(merged.cityToOneId, isNull);
      expect(merged.city.targetId, 0);
      expect(merged.media, same(existing.media));
    });

    test(
      'Media full lifecycle deleted=$deleted merges remote parent and fields',
      () {
        final existing = makeMediaEntity(
          remoteId: 73,
          eventId: 71,
          isDeleted: !deleted,
        );
        final dto = MediaDto(
          id: 73,
          title: 'Remote description',
          author: 'Remote author',
          license: 'CC',
          licenseUrl: 'https://example.com/license',
          url: 'https://example.com/new.jpg',
          width: 900,
          height: 600,
          eventId: const Clear<int>(),
          placeId: const Assign<int>(72),
          createdAt: DateTime.utc(2024),
          modifiedAt: marker,
          deletedAt: deleted ? marker : null,
        );
        final merged = dto.mergeInto(existing);
        expect(merged.remoteId, existing.remoteId);
        expect(merged.isDeleted, deleted);
        expect(merged.modifiedAt, marker);
        expect(merged.title, dto.title);
        expect(merged.author, dto.author);
        expect(merged.license, dto.license);
        expect(merged.licenseUrl, dto.licenseUrl);
        expect(merged.url, dto.url);
        expect(merged.width, dto.width);
        expect(merged.height, dto.height);
        expect(merged.eventToOneId, isNull);
        expect(merged.event.targetId, 0);
        expect(merged.placeToOneId, 72);
        expect(merged.place.targetId, 72);
      },
    );
  }
}
