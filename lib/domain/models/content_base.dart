import 'package:latlong2/latlong.dart';
import 'package:moliseis/data/sources/city.dart';
import 'package:moliseis/data/sources/media.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:objectbox/objectbox.dart';

/// A base class representing a generic unit of content used in the application.
///
/// This abstract class defines the core properties and behavior common to
/// all content-related entities such as [EventContent], [PlaceContent], and
/// [StoryContent].
///
/// It serves as the foundational model in the domain layer and should be
/// extended by specific content types to add specialized fields or methods.
///
/// ### Example:
/// ```dart
/// @immutable
/// class EventContent extends ContentBase {
///   EventContent({
///     required super.category,
///     required super.city,
///     required super.coordinates,
///     required super.createdAt,
///     required super.description,
///     required super.media,
///     required super.modifiedAt,
///     required super.name,
///     required super.remoteId,
///     required super.isSaved,
///     required this.startDate,
///   });
///
///   final DateTime startDate;
/// }
/// ```
///
/// ### Usage:
/// Used in the domain layer to represent content in a clean, abstract form,
/// decoupled from data sources or UI-specific formatting.
///
/// TODO (xmattjus): make [Place], [Event], etc. classes extends [ContentBase] when objectbox Entity inheritance lands.
/// See: https://github.com/objectbox/objectbox-dart/issues/249
abstract class ContentBase {
  final ContentCategory category;
  final ToOne<City> city;
  final int? cityToOneId;
  final LatLng coordinates;
  final DateTime createdAt;
  final String description;
  final DateTime modifiedAt;
  final ToMany<Media> media;
  final String name;
  final int remoteId;
  final bool isSaved;

  /// Creates a [ContentBase] with the given [city], [cityToOneId],
  /// [coordinates], [createdAt], [description], [modifiedAt], [media],
  /// [name] and [remoteId].
  const ContentBase({
    required this.category,
    required this.city,
    this.cityToOneId,
    required this.coordinates,
    required this.createdAt,
    required this.description,
    required this.modifiedAt,
    required this.media,
    required this.name,
    required this.remoteId,
    this.isSaved = false,
  });
}
