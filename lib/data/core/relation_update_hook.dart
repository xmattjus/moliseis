import 'package:dart_mappable/dart_mappable.dart';
import 'package:moliseis/data/core/place_dto_patch_encoding.dart';
import 'package:moliseis/data/core/relation_update.dart';
import 'package:moliseis/data/core/relation_update_resolver_hook.dart';

/// A decode-only mapping hook for compact PATCH-style relation payloads.
///
/// This hook converts primitive or nullable JSON field values into a
/// strongly-typed [RelationUpdate] representation.
///
/// It is intended for DTO fields that support partial update semantics,
/// where a relation field may be:
///
/// - omitted entirely
/// - explicitly cleared with `null`
/// - assigned a new value
///
/// Example JSON payloads:
///
/// ```json
/// {}
/// ```
///
/// ```json
/// {
///   "projectId": null
/// }
/// ```
///
/// ```json
/// {
///   "projectId": 42
/// }
/// ```
///
/// These payloads decode respectively to:
///
/// - `Keep()`
/// - `Clear()`
/// - `Assign(42)`
///
/// Because `MappingHook.beforeDecode` cannot distinguish missing keys
/// from explicit `null` values, a companion [MappingHook] at the
/// `@MappableClass` level must inject a [Keep] sentinel for absent
/// relation keys before field-level hooks run.
///
/// Example:
///
/// ```dart
/// @MappableClass(
///   hook: RelationUpdateResolverHook([city_id]),
/// )
/// class PlaceDto with PlaceDtoMappable {
///   const PlaceDto({
///     this.cityId = const Keep(),
///   });
///
///   @MappableField(
///     hook: RelationUpdateHook<int>(
///       decoder: relationUpdateDecodeInt,
///     ),
///   )
///   final RelationUpdate<int> cityId;
/// }
/// ```
///
/// This hook intentionally does not customize encoding.
///
/// PATCH serialization semantics require field omission for [Keep],
/// which cannot be implemented correctly at the field-hook level.
/// Encoding should instead be implemented manually at the DTO level.
///
/// See also:
///
/// - [RelationUpdateResolverHook]
/// - [RelationUpdate]
/// - [Keep]
/// - [Clear]
/// - [Assign]
/// - [PlaceDtoPatchEncoding]
class RelationUpdateHook<T> extends MappingHook {
  /// Creates a relation update decoding hook.
  ///
  /// The [decoder] converts raw JSON values into the target type [T].
  const RelationUpdateHook({
    required this.decoder,
  });

  /// Converts a raw JSON value into type [T].
  final T Function(Object value) decoder;

  @override
  Object? beforeDecode(Object? value) {
    if (value is Keep) return Keep<T>();
    if (value == null) return Clear<T>();
    return Assign<T>(decoder(value));
  }
}

/// Converts a raw JSON value to [int] for use as a [RelationUpdateHook]
/// decoder.
///
/// Typically passed as the `decoder` argument to
/// [RelationUpdateHook<int>] in DTO fields representing relation
/// identifiers:
///
/// ```dart
/// @MappableField(
///   hook: RelationUpdateHook<int>(
///     decoder: relationUpdateDecodeInt,
///   ),
/// )
/// final RelationUpdate<int> cityId;
/// ```
///
/// Throws a [TypeError] if [value] is not an [int].
int relationUpdateDecodeInt(dynamic value) => value as int;
