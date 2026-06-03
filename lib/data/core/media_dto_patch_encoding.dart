import 'package:moliseis/data/core/relation_update.dart';
import 'package:moliseis/data/core/relation_update_hook.dart';
import 'package:moliseis/data/dtos/media_dto.dart';

/// Provides manual PATCH-style JSON serialization for [MediaDto].
///
/// This extension implements correct partial-update semantics for
/// [RelationUpdate] fields.
///
/// Unlike standard object serialization, PATCH payloads must distinguish
/// between:
///
/// - omitted fields
/// - fields explicitly set to `null`
/// - fields assigned a new value
///
/// Standard field-level mapping hooks cannot omit fields from the
/// serialized parent object. Because of this, PATCH encoding must be
/// implemented manually at the DTO level.
///
/// Example:
///
/// ```dart
/// final dto = MediaDto(
///   eventId: const Keep(),
///   placeId: const Keep(),
/// );
///
/// final json = dto.toPatchJson();
/// ```
///
/// Result:
///
/// ```json
/// {}
/// ```
///
/// Encoding behavior:
///
/// | RelationUpdate | JSON output |
/// |---|---|
/// | `Keep()` | field omitted |
/// | `Clear()` | `null` |
/// | `Assign(value)` | encoded value |
///
/// Example:
///
/// ```dart
/// MediaDto(
///   eventId: const Clear(),
///   placeId: const Keep(),
/// ).toPatchJson();
/// ```
///
/// Produces:
///
/// ```json
/// {
///   "event_id": null
/// }
/// ```
///
/// Example:
///
/// ```dart
/// MediaDto(
///   eventId: const Clear(),
///   placeId: const Assign(23),
/// ).toPatchJson();
/// ```
///
/// Produces:
///
/// ```json
/// {
///   "event_id": null,
///   "place_id": 23,
/// }
/// ```
///
/// Example:
///
/// ```dart
/// MediaDto(
///   eventId: const Assign(42),
///   placeId: const Clear<int>(),
/// ).toPatchJson();
/// ```
///
/// Produces:
///
/// ```json
/// {
///   "event_id": 42,
///   "place_id": null,
/// }
/// ```
///
/// [eventId] and [placeId] are mutually exclusive: when one is [Assign], the
/// other must be [Clear]. The backend rejects simultaneous assignment of both
/// relations.
///
/// See also:
///
/// - [RelationUpdate]
/// - [Keep]
/// - [Clear]
/// - [Assign]
/// - [RelationUpdateHook]
extension MediaDtoPatchEncoding on MediaDto {
  /// Converts this DTO into a compact PATCH-style JSON payload.
  ///
  /// Fields represented by [Keep] are omitted from the resulting map.
  ///
  /// Fields represented by [Clear] are encoded as `null`.
  ///
  /// Fields represented by [Assign] are encoded using their contained value.
  ///
  /// Throws [ArgumentError] if [eventId] and [placeId] would result in both
  /// relations being set simultaneously, which the backend rejects. When one
  /// field is [Assign], the other must be [Clear] to avoid a conflict.
  Map<String, dynamic> toPatchJson() {
    if ((eventId is Assign<int> && placeId is! Clear<int>) ||
        (placeId is Assign<int> && eventId is! Clear<int>)) {
      throw ArgumentError(
        'MediaDto.eventId and MediaDto.placeId are mutually exclusive: '
        'assigning both is rejected by the backend. '
        'When one is assigned, the other must be Clear().',
      );
    }

    final json = <String, dynamic>{};

    switch (eventId) {
      case Keep():
        break;

      case Clear():
        json['event_id'] = null;

      case Assign(value: final eventId):
        json['event_id'] = eventId;
    }

    switch (placeId) {
      case Keep():
        break;

      case Clear():
        json['place_id'] = null;

      case Assign(value: final placeId):
        json['place_id'] = placeId;
    }

    return json;
  }
}
