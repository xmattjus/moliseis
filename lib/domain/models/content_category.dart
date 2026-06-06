enum ContentCategory {
  unknown,
  nature,
  history,
  folklore,
  food,
  allure,
  experience,
}

/// Converts a persisted category index back into a [ContentCategory].
///
/// Falls back to [ContentCategory.unknown] when [index] is out of range,
/// which can happen if the stored data predates an enum reorder or removal.
/// Calls [assertValidContentCategoryIndex] in debug builds to flag stale
/// index values early.
ContentCategory contentCategoryFromIndex(int index) {
  assertStableContentCategoryEnumIndexes();
  assertValidContentCategoryIndex(index);

  return index >= 0 && index < ContentCategory.values.length
      ? ContentCategory.values[index]
      : ContentCategory.unknown;
}

/// Verifies that [index] is a valid [ContentCategory] index.
void assertValidContentCategoryIndex(int index) {
  assert(
    index >= 0 && index < ContentCategory.values.length,
    '$index is not a valid ContentCategory index',
  );
}

/// Verifies the index of each [ContentCategory] enum has not changed.
void assertStableContentCategoryEnumIndexes() {
  assert(
    ContentCategory.unknown.index == 0,
    'ContentCategory.unknown must have index 0',
  );
  assert(
    ContentCategory.nature.index == 1,
    'ContentCategory.nature must have index 1',
  );
  assert(
    ContentCategory.history.index == 2,
    'ContentCategory.history must have index 2',
  );
  assert(
    ContentCategory.folklore.index == 3,
    'ContentCategory.folklore must have index 3',
  );
  assert(
    ContentCategory.food.index == 4,
    'ContentCategory.food must have index 4',
  );
  assert(
    ContentCategory.allure.index == 5,
    'ContentCategory.allure must have index 5',
  );
  assert(
    ContentCategory.experience.index == 6,
    'ContentCategory.experience must have index 6',
  );
}

/// Verifies no value has been added or removed from [ContentCategory].
void assertStableContentCategoryEnum() {
  assert(
    ContentCategory.values.length == 7,
    'ContentCategory has ${ContentCategory.values.length} values. '
    'Update ContentCategoryMapper.decode() and '
    'assertStableContentCategoryEnumValues() to handle the new value.',
  );
}
