import 'package:latlong2/latlong.dart';
import 'package:moliseis/domain/models/city.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/event.dart';
import 'package:moliseis/domain/models/place.dart';

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
