import 'package:moliseis/data/core/relation_update.dart';
import 'package:moliseis/data/core/relation_update_hook.dart';
import 'package:moliseis/data/dtos/event_dto.dart';

/// Provides manual PATCH-style JSON serialization for [EventDto].
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
/// final dto = EventDto(
///   cityId: const Keep(),
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
/// EventDto(
///   cityId: const Clear(),
/// ).toPatchJson();
/// ```
///
/// Produces:
///
/// ```json
/// {
///   "city_id": null
/// }
/// ```
///
/// Example:
///
/// ```dart
/// EventDto(
///   cityId: const Assign(42),
/// ).toPatchJson();
/// ```
///
/// Produces:
///
/// ```json
/// {
///   "city_id": 42
/// }
/// ```
///
/// See also:
///
/// - [RelationUpdate]
/// - [Keep]
/// - [Clear]
/// - [Assign]
/// - [RelationUpdateHook]
extension EventDtoPatchEncoding on EventDto {
  /// Converts this DTO into a compact PATCH-style JSON payload.
  ///
  /// Fields represented by [Keep] are omitted from the resulting map.
  ///
  /// Fields represented by [Clear] are encoded as `null`.
  ///
  /// Fields represented by [Assign] are encoded using their contained value.
  Map<String, dynamic> toPatchJson() {
    final json = <String, dynamic>{};

    switch (cityId) {
      case Keep():
        break;

      case Clear():
        json['city_id'] = null;

      case Assign(value: final cityId):
        json['city_id'] = cityId;
    }

    return json;
  }
}
