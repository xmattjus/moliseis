import 'package:latlong2/latlong.dart';
import 'package:moliseis/domain/models/city.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/media.dart';

/// A base class representing a generic unit of content used in the application.
///
/// This abstract class defines the core properties and behavior common to
/// all content-related entities such as [Event] and [Place].
///
/// It serves as the foundational model in the domain layer and should be
/// extended by specific content types to add specialized fields or methods.
///
/// ### Example:
/// ```dart
/// @immutable
/// class Event extends ContentBase {
///   Event({
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
///     this.endDate,
///   });
///
///   final DateTime startDate;
///   final DateTime? endDate;
/// }
/// ```
///
/// ### Usage:
/// Used in the domain layer to represent content in a clean, abstract form,
/// decoupled from data sources or UI-specific formatting.
///
abstract class ContentBase {
  final ContentCategory category;
  final City? city;
  final LatLng coordinates;
  final DateTime createdAt;
  final String description;
  final DateTime modifiedAt;
  final List<Media> media;
  final String name;
  final int remoteId;
  final bool isSaved;

  /// Creates a [ContentBase] with the given [category], [city], [coordinates],
  /// [createdAt], [description], [modifiedAt], [media], [name], [remoteId] and
  /// optionally [isSaved].
  const ContentBase({
    required this.category,
    required this.city,
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
