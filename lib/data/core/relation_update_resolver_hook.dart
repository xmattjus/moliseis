import 'package:dart_mappable/dart_mappable.dart';
import 'package:moliseis/data/core/relation_update.dart';

/// A [MappingHook] that ensures specified relation fields are present during
/// deserialization.
///
/// Before decoding a map, this hook checks that all configured [keys] exist.
/// If a key is missing, it is populated with a default [Keep] value,
/// preventing the relation from being interpreted as updated or removed.
///
/// This is useful when decoding partial payloads where omitted relation fields
/// should retain their existing values.
///
/// Example:
/// ```dart
/// const RelationUpdateResolverHook(['authorId', 'categoryId']);
/// ```
///
/// Given:
/// ```json
/// { "authorId": 42 }
/// ```
///
/// The decoded map becomes:
/// ```dart
/// {
///   'authorId': 42,
///   'categoryId': const Keep<dynamic>(),
/// }
/// ```
class RelationUpdateResolverHook extends MappingHook {
  /// Creates a hook that inserts a default [Keep] value for any missing key
  /// listed in [keys].
  const RelationUpdateResolverHook(this.keys);

  /// The relation field names that should always be present in the decoded map.
  final Iterable<String> keys;

  /// Ensures all configured [keys] exist in the decoded map.
  ///
  /// For every missing key, a `const Keep<dynamic>()` value is inserted. If
  /// [value] is not a `Map<String, dynamic>`, it is returned unchanged.
  @override
  Object? beforeDecode(Object? value) {
    if (value is Map<String, dynamic>) {
      final map = Map<String, dynamic>.from(value);
      for (final key in keys) {
        if (!map.containsKey(key)) {
          map[key] = const Keep<dynamic>();
        }
      }
      return map;
    }
    return value;
  }
}
