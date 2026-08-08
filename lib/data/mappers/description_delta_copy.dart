/// Creates an immutable deep copy of Delta operations at mapper boundaries.
///
/// This prevents callers that retain decoded JSON collections from mutating
/// data held by a domain model or ObjectBox entity.
List<Map<String, dynamic>>? copyDescriptionDelta(
  List<Map<String, dynamic>>? descriptionDelta,
) {
  if (descriptionDelta == null) return null;

  return List<Map<String, dynamic>>.unmodifiable(
    descriptionDelta.map(
      (operation) => Map<String, dynamic>.unmodifiable({
        for (final entry in operation.entries)
          entry.key: _copyDescriptionDeltaValue(entry.value),
      }),
    ),
  );
}

Object? _copyDescriptionDeltaValue(Object? value) {
  if (value is Map<String, dynamic>) {
    return Map<String, dynamic>.unmodifiable({
      for (final entry in value.entries)
        entry.key: _copyDescriptionDeltaValue(entry.value),
    });
  }

  if (value is List<dynamic>) {
    return List<Object?>.unmodifiable(
      value.map(_copyDescriptionDeltaValue),
    );
  }

  return value;
}
