import 'package:collection/collection.dart';
import 'package:latlong2/latlong.dart';
import 'package:meta/meta.dart';
import 'package:moliseis/domain/models/city.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/event.dart'; // Import added to fix the comment_references lint.
import 'package:moliseis/domain/models/media.dart';
import 'package:moliseis/domain/models/place.dart'; // Import added to fix the comment_references lint.

/// The decimal places a [LatLng] ContentBase field will be rounded to.
/// Equals to street/building precision. Coordinates updates requiring higher
/// precision are unlikely.
const int _roundingDecimalPlaces = 4;

/// Rounds a [LatLng] coordinates to prevent precision issues during equality
/// checks.
LatLng _round(LatLng coordinates) =>
    coordinates.round(decimals: _roundingDecimalPlaces);

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
@immutable
abstract class ContentBase {
  /// Creates a [ContentBase] with the given [category], [city], [coordinates],
  /// [createdAt], [description], [modifiedAt], [media], [name], [remoteId] and
  /// optionally [descriptionDelta] and [isSaved].
  const ContentBase({
    required this.category,
    required this.city,
    required this.coordinates,
    required this.createdAt,
    required this.description,
    this.descriptionDelta,
    required this.modifiedAt,
    required this.media,
    required this.name,
    required this.remoteId,
    this.isSaved = false,
  });

  final ContentCategory category;
  final City? city;
  final LatLng coordinates;
  final DateTime createdAt;
  final String description;
  final List<Map<String, dynamic>>? descriptionDelta;
  final DateTime modifiedAt;
  final List<Media> media;
  final String name;
  final int remoteId;
  final bool isSaved;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ContentBase &&
        other.category == category &&
        other.city == city &&
        _round(other.coordinates) == _round(coordinates) &&
        other.createdAt.isAtSameMomentAs(createdAt) &&
        other.description == description &&
        const DeepCollectionEquality().equals(
          other.descriptionDelta,
          descriptionDelta,
        ) &&
        other.modifiedAt.isAtSameMomentAs(modifiedAt) &&
        const ListEquality<Media>().equals(other.media, media) &&
        other.name == name &&
        other.remoteId == remoteId &&
        other.isSaved == isSaved;
  }

  @override
  int get hashCode => Object.hash(
    category,
    city,
    _round(coordinates),
    createdAt.millisecondsSinceEpoch,
    description,
    const DeepCollectionEquality().hash(descriptionDelta),
    modifiedAt.millisecondsSinceEpoch,
    Object.hashAll(media),
    name,
    remoteId,
    isSaved,
  );
}
