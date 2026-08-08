import 'package:latlong2/latlong.dart';
import 'package:moliseis/data/data-sources/city_entity.dart';
import 'package:moliseis/data/data-sources/event_entity.dart';
import 'package:moliseis/data/data-sources/media_entity.dart';
import 'package:moliseis/data/data-sources/place_entity.dart';
import 'package:moliseis/data/repositories/event_repository_impl.dart';
import 'package:moliseis/data/repositories/media_repository_impl.dart';
import 'package:moliseis/data/repositories/place_repository_impl.dart';
import 'package:moliseis/domain/models/city.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/event.dart';
import 'package:moliseis/domain/models/place.dart';
import 'package:moliseis/generated/objectbox.g.dart';

/// Default timestamp used by all fixtures.
///
/// Uses [DateTime.utc] with a fixed year to avoid flaky tests caused by
/// `DateTime.now()` drift. All sub-fields default to zero (January 1, 00:00).
final _defaultDate = DateTime.utc(2026);

/// Creates a [City] with sensible defaults for testing.
City testCity({
  int remoteId = 0,
  String name = 'Molise',
  DateTime? createdAt,
  DateTime? modifiedAt,
}) => City(
  remoteId: remoteId,
  name: name,
  createdAt: createdAt ?? _defaultDate,
  modifiedAt: modifiedAt ?? _defaultDate,
);

/// Creates an [Event] with sensible defaults for testing.
///
/// Only `remoteId` varies frequently across tests; everything else has a
/// default that produces a valid, minimal object.
Event makeEvent({
  int remoteId = 1,
  String name = 'Event',
  String description = '',
  List<Map<String, dynamic>>? descriptionDelta,
  DateTime? startDate,
  DateTime? endDate,
  ContentCategory category = ContentCategory.unknown,
  LatLng coordinates = const LatLng(41.56, 14.66),
  City? city,
  bool isSaved = false,
}) => Event(
  remoteId: remoteId,
  name: name,
  description: description,
  descriptionDelta: descriptionDelta,
  startDate: startDate ?? _defaultDate,
  endDate: endDate,
  category: category,
  coordinates: coordinates,
  createdAt: _defaultDate,
  modifiedAt: _defaultDate,
  city: city ?? testCity(),
  media: const [],
  isSaved: isSaved,
);

/// Creates a [Place] with sensible defaults for testing.
Place makePlace({
  int remoteId = 1,
  String name = 'Place',
  String description = '',
  List<Map<String, dynamic>>? descriptionDelta,
  ContentCategory category = ContentCategory.unknown,
  LatLng coordinates = const LatLng(41.56, 14.66),
  City? city,
  bool isSaved = false,
}) => Place(
  remoteId: remoteId,
  name: name,
  description: description,
  descriptionDelta: descriptionDelta,
  category: category,
  coordinates: coordinates,
  createdAt: _defaultDate,
  modifiedAt: _defaultDate,
  city: city ?? testCity(),
  media: const [],
  isSaved: isSaved,
);

/// Creates a [CityEntity] with sensible defaults for testing.
CityEntity makeCityEntity({
  required int remoteId,
  String name = 'CityEntity',
  DateTime? createdAt,
  DateTime? modifiedAt,
  bool isDeleted = false,
}) => CityEntity(
  remoteId: remoteId,
  name: name,
  createdAt: createdAt ?? _defaultDate,
  modifiedAt: modifiedAt ?? _defaultDate,
  places: ToMany<PlaceEntity>(),
  events: ToMany<EventEntity>(),
  isDeleted: isDeleted,
);

/// Creates an [EventEntity] with sensible defaults for testing.
///
/// Relation can be wired either by raw id ([cityId]) or by target
/// object ([city]); providing both for the same relation is an error.
/// When an id is provided, both the JSON-serialization field
/// (`cityToOneId`) and the ObjectBox relation id (`city.targetId`) are set,
/// matching the layout required by [EventRepositoryImpl].
EventEntity makeEventEntity({
  required int remoteId,
  String name = 'EventEntity',
  String? description,
  List<Map<String, dynamic>>? descriptionDelta,
  DateTime? startDate,
  DateTime? endDate,
  List<double> coordinates = const [0, 0],
  int? cityId,
  int contentCategoryIndex = 0,
  DateTime? createdAt,
  DateTime? modifiedAt,
  bool isDeleted = false,
  ToOne<CityEntity>? city,
  ToMany<MediaEntity>? media,
}) {
  assert(
    !(cityId != null && city != null),
    'Only one of cityId or city may be provided, not both.',
  );
  final event = EventEntity(
    remoteId: remoteId,
    name: name,
    description: description,
    descriptionDelta: descriptionDelta,
    contentCategoryIndex: contentCategoryIndex,
    startDate: startDate,
    endDate: endDate,
    coordinates: coordinates,
    createdAt: createdAt ?? _defaultDate,
    modifiedAt: modifiedAt ?? _defaultDate,
    cityToOneId: cityId,
    city: city ?? ToOne<CityEntity>(),
    media: media ?? ToMany<MediaEntity>(),
    isDeleted: isDeleted,
  );

  if (cityId != null) {
    event.city.targetId = cityId;
  }

  return event;
}

/// Creates an [PlaceEntity] with sensible defaults for testing.
///
/// Relation can be wired either by raw id ([cityId]) or by target
/// object ([city]); providing both for the same relation is an error.
/// When an id is provided, both the JSON-serialization field
/// (`cityToOneId`) and the ObjectBox relation id (`city.targetId`) are set,
/// matching the layout required by [PlaceRepositoryImpl].
PlaceEntity makePlaceEntity({
  required int remoteId,
  String name = 'PlaceEntity',
  String? description,
  List<Map<String, dynamic>>? descriptionDelta,
  List<double> coordinates = const [0, 0],
  int? cityId,
  int contentCategoryIndex = 0,
  DateTime? createdAt,
  DateTime? modifiedAt,
  bool isDeleted = false,
  bool isSaved = false,
  ToOne<CityEntity>? city,
  ToMany<MediaEntity>? media,
}) {
  assert(
    !(cityId != null && city != null),
    'Only one of cityId or city may be provided, not both.',
  );
  final place = PlaceEntity(
    remoteId: remoteId,
    name: name,
    description: description,
    descriptionDelta: descriptionDelta,
    coordinates: coordinates,
    contentCategoryIndex: contentCategoryIndex,
    createdAt: createdAt ?? _defaultDate,
    modifiedAt: modifiedAt ?? _defaultDate,
    cityToOneId: cityId,
    city: city ?? ToOne<CityEntity>(),
    media: ToMany<MediaEntity>(),
    isSaved: isSaved,
    isDeleted: isDeleted,
  );

  if (cityId != null) {
    place.city.targetId = cityId;
  }

  return place;
}

/// Creates a [MediaEntity] with sensible defaults for testing.
///
/// Relations can be wired either by raw id ([eventId]/[placeId]) or by target
/// object ([eventTarget]/[placeTarget]); providing both for the same relation
/// is an error. When an id is provided, both the JSON-serialization field
/// (`eventToOneId`/`placeToOneId`) and the ObjectBox relation id
/// (`event.targetId`/`place.targetId`) are set, matching the layout required
/// by [MediaRepositoryImpl].
MediaEntity makeMediaEntity({
  int remoteId = 1,
  String url = 'https://cdn.example.com/img.jpg',
  int width = 800,
  int height = 600,
  String? title,
  String? author,
  String? license,
  String? licenseUrl,
  int? eventId,
  int? placeId,
  EventEntity? eventTarget,
  PlaceEntity? placeTarget,
  DateTime? createdAt,
  DateTime? modifiedAt,
  bool isDeleted = false,
}) {
  assert(
    !(eventId != null && eventTarget != null),
    'Only one of eventId or eventTarget may be provided, not both.',
  );
  assert(
    !(placeId != null && placeTarget != null),
    'Only one of placeId or placeTarget may be provided, not both.',
  );
  final entity = MediaEntity(
    remoteId: remoteId,
    title: title,
    author: author,
    license: license,
    licenseUrl: licenseUrl,
    url: url,
    width: width,
    height: height,
    eventToOneId: eventId,
    placeToOneId: placeId,
    createdAt: createdAt ?? _defaultDate,
    modifiedAt: modifiedAt ?? _defaultDate,
    place: placeTarget != null
        ? ToOne<PlaceEntity>(target: placeTarget)
        : ToOne<PlaceEntity>(),
    event: eventTarget != null
        ? ToOne<EventEntity>(target: eventTarget)
        : ToOne<EventEntity>(),
    isDeleted: isDeleted,
  );
  if (eventId != null) entity.event.targetId = eventId;
  if (placeId != null) entity.place.targetId = placeId;
  return entity;
}

/// Creates a [ToOne] relation with a new [CityEntity] named [name].
ToOne<CityEntity> newCityRelation({required String name}) =>
    ToOne<CityEntity>(target: makeCityEntity(remoteId: 1, name: name));
