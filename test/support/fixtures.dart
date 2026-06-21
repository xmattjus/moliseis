import 'package:latlong2/latlong.dart';
import 'package:moliseis/data/data-sources/city_entity.dart';
import 'package:moliseis/data/data-sources/event_entity.dart';
import 'package:moliseis/data/data-sources/media_entity.dart';
import 'package:moliseis/data/data-sources/place_entity.dart';
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
  ContentCategory category = ContentCategory.unknown,
  LatLng coordinates = const LatLng(41.56, 14.66),
  City? city,
  bool isSaved = false,
}) => Place(
  remoteId: remoteId,
  name: name,
  description: description,
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
EventEntity makeEventEntity({
  required int remoteId,
  String name = 'EventEntity',
  String? description,
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
    contentCategoryIndex: contentCategoryIndex,
    startDate: startDate,
    endDate: endDate,
    coordinates: coordinates,
    createdAt: createdAt ?? _defaultDate,
    modifiedAt: modifiedAt ?? _defaultDate,
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
PlaceEntity makePlaceEntity({
  required int remoteId,
  String name = 'PlaceEntity',
  String? description,
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
  return PlaceEntity(
    remoteId: remoteId,
    name: name,
    description: description,
    coordinates: coordinates,
    contentCategoryIndex: contentCategoryIndex,
    createdAt: createdAt ?? _defaultDate,
    modifiedAt: modifiedAt ?? _defaultDate,
    city: city ?? ToOne<CityEntity>(),
    media: ToMany<MediaEntity>(),
    isSaved: isSaved,
    isDeleted: isDeleted,
  );
}

/// Creates a [ToOne] relation with a new [City] named [name].
ToOne<CityEntity> newCityRelation({required String name}) =>
    ToOne<CityEntity>(target: makeCityEntity(remoteId: 1, name: name));
