/// Returns a deeply copied, recursively unmodifiable snapshot of
/// [descriptionDelta].
///
/// It freezes ownership only and does not validate, normalize, or otherwise
/// interpret Delta operations.
List<Map<String, dynamic>>? freezeDescriptionDelta(
  List<Map<String, dynamic>>? descriptionDelta,
) {
  if (descriptionDelta == null) return null;

  return List<Map<String, dynamic>>.unmodifiable(
    descriptionDelta.map(
      (operation) => Map<String, dynamic>.unmodifiable({
        for (final entry in operation.entries)
          entry.key: _freezeDescriptionDeltaValue(entry.value),
      }),
    ),
  );
}

Object? _freezeDescriptionDeltaValue(Object? value) {
  if (value is Map<String, dynamic>) {
    return Map<String, dynamic>.unmodifiable({
      for (final entry in value.entries)
        entry.key: _freezeDescriptionDeltaValue(entry.value),
    });
  }

  if (value is List<dynamic>) {
    return List<Object?>.unmodifiable(
      value.map(_freezeDescriptionDeltaValue),
    );
  }

  return value;
}
