enum ContentCategory {
  unknown,
  nature,
  history,
  folklore,
  food,
  allure,
  experience,
}

void ensureStableEnumValues() {
  assert(ContentCategory.unknown.index == 0);
  assert(ContentCategory.nature.index == 1);
  assert(ContentCategory.history.index == 2);
  assert(ContentCategory.folklore.index == 3);
  assert(ContentCategory.food.index == 4);
  assert(ContentCategory.allure.index == 5);
  assert(ContentCategory.experience.index == 6);
}
