enum ContentCategory {
  unknown,
  nature,
  history,
  folklore,
  food,
  allure,
  experience,
}

/// Asserts [ContentCategory] enum values indexes have not changed.
void assertStableContentCategoryEnumValues() {
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
