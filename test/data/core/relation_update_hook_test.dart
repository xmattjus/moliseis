import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/data/core/event_dto_patch_encoding.dart';
import 'package:moliseis/data/core/media_dto_patch_encoding.dart';
import 'package:moliseis/data/core/place_dto_patch_encoding.dart';
import 'package:moliseis/data/core/relation_update.dart';
import 'package:moliseis/data/core/relation_update_hook.dart';
import 'package:moliseis/data/dtos/event_dto.dart';
import 'package:moliseis/data/dtos/media_dto.dart';
import 'package:moliseis/data/dtos/place_dto.dart';
import 'package:moliseis/domain/models/content_category.dart';

void main() {
  group('RelationUpdateHook.beforeDecode', () {
    const hook = RelationUpdateHook<int>(
      decoder: relationUpdateDecodeInt,
    );

    test(
      'returns Clear when backend explicitly sends null',
      () {
        final result = hook.beforeDecode(null);

        expect(result, isA<Clear<int>>());
      },
    );

    test(
      'returns Assign when backend sends a concrete value',
      () {
        final result = hook.beforeDecode(42);

        expect(result, isA<Assign<int>>());

        final assign = result! as Assign<int>;

        expect(assign.value, 42);
      },
    );

    test(
      'uses the provided decoder function',
      () {
        const stringHook = RelationUpdateHook<int>(
          decoder: _parseInt,
        );

        final result = stringHook.beforeDecode('42');

        expect(result, isA<Assign<int>>());

        final assign = result! as Assign<int>;

        expect(assign.value, 42);
      },
    );

    test(
      'does not create Keep because omitted fields bypass the hook',
      () {
        final eventDto = _eventDtoFromMap();
        final mediaDto = _mediaDtoFromMap();
        final placeDto = _placeDtoFromMap();

        expect(eventDto.cityId, isA<Keep<int>>());
        expect(mediaDto.eventId, isA<Keep<int>>());
        expect(mediaDto.placeId, isA<Keep<int>>());
        expect(placeDto.cityId, isA<Keep<int>>());
      },
    );
  });

  group('EventDtoPatchEncoding.toPatchJson', () {
    test(
      'omits EventDto cityId field when relation should remain unchanged',
      () {
        final dto = _eventDto(cityId: const Keep<int>());

        final json = dto.toPatchJson();

        expect(json.containsKey('city_id'), isFalse);
        expect(json, isEmpty);
      },
    );

    test(
      'encodes EventDto cityId as null when relation should be cleared',
      () {
        final dto = _eventDto(cityId: const Clear<int>());

        final json = dto.toPatchJson();

        expect(json, {
          'city_id': null,
        });
      },
    );

    test(
      'encodes EventDto cityId primitive value when relation should be updated',
      () {
        final dto = _eventDto(cityId: const Assign<int>(96));

        final json = dto.toPatchJson();

        expect(json, {
          'city_id': 96,
        });
      },
    );

    test(
      'preserves EventDto PATCH semantics across all relation states',
      () {
        final keepDto = _eventDto(cityId: const Keep<int>());

        final clearDto = _eventDto(cityId: const Clear<int>());

        final assignDto = _eventDto(cityId: const Assign<int>(99));

        expect(
          keepDto.toPatchJson(),
          isEmpty,
        );

        expect(
          clearDto.toPatchJson(),
          {
            'city_id': null,
          },
        );

        expect(
          assignDto.toPatchJson(),
          {
            'city_id': 99,
          },
        );
      },
    );
  });

  group('MediaDtoPatchEncoding.toPatchJson', () {
    test(
      'omits MediaDto eventId and placeId fields when relation should remain '
      'unchanged',
      () {
        final dto = _mediaDto(
          eventId: const Keep<int>(),
          placeId: const Keep<int>(),
        );

        final json = dto.toPatchJson();

        expect(json.containsKey('event_id'), isFalse);
        expect(json.containsKey('place_id'), isFalse);
        expect(json, isEmpty);
      },
    );

    test(
      'encodes MediaDto eventId and placeId as null when relation should be '
      'cleared',
      () {
        final dto = _mediaDto(
          eventId: const Clear<int>(),
          placeId: const Clear<int>(),
        );

        final json = dto.toPatchJson();

        expect(json, {
          'event_id': null,
          'place_id': null,
        });
      },
    );

    test(
      'encodes MediaDto eventId primitive value when relation should be '
      'updated and place_id should be cleared',
      () {
        final dto = _mediaDto(
          eventId: const Assign<int>(42),
          placeId: const Clear<int>(),
        );

        final json = dto.toPatchJson();

        expect(json, {
          'event_id': 42,
          'place_id': null,
        });
      },
    );

    test(
      'encodes MediaDto placeId primitive value when relation should be '
      'updated and event_id should be cleared',
      () {
        final dto = _mediaDto(
          eventId: const Clear<int>(),
          placeId: const Assign<int>(42),
        );

        final json = dto.toPatchJson();

        expect(json, {
          'event_id': null,
          'place_id': 42,
        });
      },
    );

    test(
      'throws when both MediaDto eventId and placeId are assigned',
      () {
        final dto = _mediaDto(
          eventId: const Assign<int>(42),
          placeId: const Assign<int>(96),
        );

        var json = const <String, Object?>{};

        expect(() => json = dto.toPatchJson(), throwsA(isA<ArgumentError>()));
        expect(json, isEmpty);
      },
    );

    test(
      'throws when MediaDto eventId is assigned and placeId is kept',
      () {
        final dto = _mediaDto(
          eventId: const Assign<int>(42),
          placeId: const Keep<int>(),
        );

        var json = const <String, Object?>{};

        expect(() => json = dto.toPatchJson(), throwsA(isA<ArgumentError>()));
        expect(json, isEmpty);
      },
    );

    test(
      'throws when MediaDto eventId is kept and placeId is assigned',
      () {
        final dto = _mediaDto(
          eventId: const Keep<int>(),
          placeId: const Assign<int>(96),
        );

        var json = const <String, Object?>{};

        expect(() => json = dto.toPatchJson(), throwsA(isA<ArgumentError>()));
        expect(json, isEmpty);
      },
    );

    test(
      'preserves MediaDto PATCH semantics across all relation states',
      () {
        final keepDto = _mediaDto(
          eventId: const Keep<int>(),
          placeId: const Keep<int>(),
        );

        final clearDto = _mediaDto(
          eventId: const Clear<int>(),
          placeId: const Clear<int>(),
        );

        final assignDto1 = _mediaDto(
          eventId: const Assign<int>(99),
          placeId: const Clear<int>(),
        );

        final assignDto2 = _mediaDto(
          eventId: const Clear<int>(),
          placeId: const Assign<int>(99),
        );

        expect(
          keepDto.toPatchJson(),
          isEmpty,
        );

        expect(
          clearDto.toPatchJson(),
          {
            'event_id': null,
            'place_id': null,
          },
        );

        expect(
          assignDto1.toPatchJson(),
          {
            'event_id': 99,
            'place_id': null,
          },
        );

        expect(
          assignDto2.toPatchJson(),
          {
            'event_id': null,
            'place_id': 99,
          },
        );
      },
    );
  });

  group('PlaceDtoPatchEncoding.toPatchJson', () {
    test(
      'omits PlaceDto cityId field when relation should remain unchanged',
      () {
        final dto = _placeDto(cityId: const Keep<int>());

        final json = dto.toPatchJson();

        expect(json.containsKey('city_id'), isFalse);
        expect(json, isEmpty);
      },
    );

    test(
      'encodes PlaceDto cityId as null when relation should be cleared',
      () {
        final dto = _placeDto(cityId: const Clear<int>());

        final json = dto.toPatchJson();

        expect(json, {
          'city_id': null,
        });
      },
    );

    test(
      'encodes PlaceDto cityId primitive value when relation should be updated',
      () {
        final dto = _placeDto(cityId: const Assign<int>(42));

        final json = dto.toPatchJson();

        expect(json, {
          'city_id': 42,
        });
      },
    );

    test(
      'preserves PlaceDto PATCH semantics across all relation states',
      () {
        final keepDto = _placeDto(cityId: const Keep<int>());

        final clearDto = _placeDto(cityId: const Clear<int>());

        final assignDto = _placeDto(cityId: const Assign<int>(99));

        expect(
          keepDto.toPatchJson(),
          isEmpty,
        );

        expect(
          clearDto.toPatchJson(),
          {
            'city_id': null,
          },
        );

        expect(
          assignDto.toPatchJson(),
          {
            'city_id': 99,
          },
        );
      },
    );
  });

  group('EventDto decoding integration', () {
    test(
      'decodes omitted relation field as Keep',
      () {
        final dto = _eventDtoFromMap();

        expect(dto.cityId, isA<Keep<int>>());
      },
    );

    test(
      'decodes explicit null relation field as Clear',
      () {
        final dto = _eventDtoFromMap(() => null);

        expect(dto.cityId, isA<Clear<int>>());
      },
    );

    test(
      'decodes explicit relation value as Assign',
      () {
        final dto = _eventDtoFromMap(() => 42);

        expect(dto.cityId, isA<Assign<int>>());

        final relation = dto.cityId as Assign<int>;

        expect(relation.value, 42);
      },
    );
  });

  group('MediaDto decoding integration', () {
    test(
      'decodes omitted relation field as Keep',
      () {
        final dto = _mediaDtoFromMap();

        expect(dto.eventId, isA<Keep<int>>());
        expect(dto.placeId, isA<Keep<int>>());
      },
    );

    test(
      'decodes explicit null relation field as Clear',
      () {
        final dto = _mediaDtoFromMap(eventId: () => null);

        expect(dto.eventId, isA<Clear<int>>());
        expect(dto.placeId, isA<Keep<int>>());
      },
    );

    test(
      'decodes explicit relation value as Assign',
      () {
        final dto = _mediaDtoFromMap(placeId: () => 42);

        expect(dto.eventId, isA<Keep<int>>());
        expect(dto.placeId, isA<Assign<int>>());

        final relation = dto.placeId as Assign<int>;

        expect(relation.value, 42);
      },
    );
  });

  group('PlaceDto decoding integration', () {
    test(
      'decodes omitted relation field as Keep',
      () {
        final dto = _placeDtoFromMap();

        expect(dto.cityId, isA<Keep<int>>());
      },
    );

    test(
      'decodes explicit null relation field as Clear',
      () {
        final dto = _placeDtoFromMap(() => null);

        expect(dto.cityId, isA<Clear<int>>());
      },
    );

    test(
      'decodes explicit relation value as Assign',
      () {
        final dto = _placeDtoFromMap(() => 42);

        expect(dto.cityId, isA<Assign<int>>());

        final relation = dto.cityId as Assign<int>;

        expect(relation.value, 42);
      },
    );
  });
}

EventDto _eventDto({required RelationUpdate<int> cityId}) => EventDto(
  id: 0,
  name: '',
  description: '',
  latitude: 0,
  longitude: 0,
  category: ContentCategory.unknown,
  cityId: cityId,
  createdAt: DateTime.now(),
  modifiedAt: DateTime.now(),
  startDate: DateTime.now(),
);

MediaDto _mediaDto({
  required RelationUpdate<int> eventId,
  required RelationUpdate<int> placeId,
}) => MediaDto(
  id: 0,
  url: '',
  width: 0,
  height: 0,
  eventId: eventId,
  placeId: placeId,
  createdAt: DateTime.now(),
  modifiedAt: DateTime.now(),
);

PlaceDto _placeDto({required RelationUpdate<int> cityId}) => PlaceDto(
  id: 0,
  name: '',
  description: '',
  latitude: 0,
  longitude: 0,
  category: ContentCategory.unknown,
  cityId: cityId,
  createdAt: DateTime.now(),
  modifiedAt: DateTime.now(),
);

EventDto _eventDtoFromMap([int? Function()? cityId]) {
  final extra = cityId != null
      ? {'city_id': cityId()}
      : const <String, Object?>{};
  final map = <String, Object?>{
    'id': 0,
    'name': '',
    'description': '',
    'latitude': 0,
    'longitude': 0,
    'category': ContentCategory.unknown.name,
    'created_at': DateTime.now().toIso8601String(),
    'modified_at': DateTime.now().toIso8601String(),
    'start_date': DateTime.now().toIso8601String(),
  }..addEntries(extra.entries);
  return EventDtoMapper.fromMap(map);
}

MediaDto _mediaDtoFromMap({
  int? Function()? eventId,
  int? Function()? placeId,
}) {
  final extra1 = eventId != null
      ? {'event_id': eventId()}
      : const <String, Object?>{};
  final extra2 = placeId != null
      ? {'place_id': placeId()}
      : const <String, Object?>{};
  final map =
      <String, Object?>{
          'id': 0,
          'url': '',
          'width': 0,
          'height': 0,
          'created_at': DateTime.now().toIso8601String(),
          'modified_at': DateTime.now().toIso8601String(),
        }
        ..addEntries(extra1.entries)
        ..addEntries(extra2.entries);
  return MediaDtoMapper.fromMap(map);
}

PlaceDto _placeDtoFromMap([int? Function()? cityId]) {
  final extra = cityId != null
      ? {'city_id': cityId()}
      : const <String, Object?>{};
  final map = <String, Object?>{
    'id': 0,
    'name': '',
    'description': '',
    'latitude': 0,
    'longitude': 0,
    'category': ContentCategory.unknown.name,
    'created_at': DateTime.now().toIso8601String(),
    'modified_at': DateTime.now().toIso8601String(),
  }..addEntries(extra.entries);
  return PlaceDtoMapper.fromMap(map);
}

int _parseInt(dynamic value) {
  return int.parse(value as String);
}
