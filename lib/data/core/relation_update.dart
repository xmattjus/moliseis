/// Represents a synchronization operation for a relation field.
///
/// A [RelationUpdate] distinguishes between:
///
/// - leaving the current relation unchanged
/// - explicitly clearing the relation
/// - assigning a new relation value
///
/// This is especially useful when synchronizing partially-loaded backend
/// payloads into local persistence layers such as ObjectBox.
///
/// A plain nullable value (`T?`) cannot represent the semantic difference
/// between:
///
/// - a field omitted from the payload
/// - a field explicitly set to `null`
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
/// These payloads respectively map to:
///
/// - [Keep]
/// - [Clear]
/// - [Assign]
///
/// Example:
///
/// ```dart
/// final RelationUpdate<int> projectId =
///     parseRelation(json, 'projectId');
///
/// switch (projectId) {
///   case Keep():
///     break;
///
///   case Clear():
///     entity.project.targetId = 0;
///
///   case Assign(value: final id):
///     entity.project.targetId = id;
/// }
/// ```
///
/// This pattern is commonly used for:
///
/// - partial API responses
/// - PATCH semantics
/// - relation synchronization
/// - cache merging
/// - offline-first persistence layers
///
/// See also:
///
/// - [Keep]
/// - [Clear]
/// - [Assign]
sealed class RelationUpdate<T> {
  /// Creates a relation update operation.
  const RelationUpdate();
}

/// Represents a relation field that was not included in the serialized payload.
///
/// This indicates that the relation should remain unchanged.
///
/// Typical causes include:
///
/// - partial backend responses
/// - sparse fieldsets
/// - fields intentionally omitted by the API
/// - synchronization payload optimization
///
/// Example:
///
/// ```dart
/// const RelationUpdate<int> update = Keep();
/// ```
final class Keep<T> extends RelationUpdate<T> {
  /// Creates a keep operation.
  const Keep();
}

/// Represents a relation field explicitly cleared by the serialized payload.
///
/// This indicates that the existing relation should be removed.
///
/// In JSON payloads this usually corresponds to:
///
/// ```json
/// {
///   "relationId": null
/// }
/// ```
///
/// Example:
///
/// ```dart
/// const RelationUpdate<int> update = Clear();
/// ```
final class Clear<T> extends RelationUpdate<T> {
  /// Creates a clear operation.
  const Clear();
}

/// Represents a relation field explicitly assigned a value.
///
/// The relation should be updated to reference [value].
///
/// Example:
///
/// ```dart
/// const RelationUpdate<int> update = Assign(42);
/// ```
///
/// In JSON payloads this usually corresponds to:
///
/// ```json
/// {
///   "relationId": 42
/// }
/// ```
final class Assign<T> extends RelationUpdate<T> {
  /// Creates an assign operation.
  const Assign(this.value);

  /// The relation value to assign.
  final T value;
}
