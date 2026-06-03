import 'package:dart_mappable/dart_mappable.dart';
import 'package:moliseis/domain/models/content_category.dart';

class ContentCategoryMapper extends SimpleMapper<ContentCategory> {
  const ContentCategoryMapper();

  @override
  ContentCategory decode(Object value) {
    assertStableContentCategoryEnum();
    assertStableContentCategoryEnumIndexes();

    return switch (value) {
      'unknown' => ContentCategory.unknown,
      'nature' => ContentCategory.nature,
      'history' => ContentCategory.history,
      'folklore' => ContentCategory.folklore,
      'food' => ContentCategory.food,
      'allure' => ContentCategory.allure,
      'experience' => ContentCategory.experience,
      _ => ContentCategory.unknown,
    };
  }

  @override
  Object? encode(ContentCategory self) {
    assertStableContentCategoryEnum();
    assertStableContentCategoryEnumIndexes();

    return switch (self) {
      ContentCategory.unknown => 'unknown',
      ContentCategory.nature => 'nature',
      ContentCategory.history => 'history',
      ContentCategory.folklore => 'folklore',
      ContentCategory.food => 'food',
      ContentCategory.allure => 'allure',
      ContentCategory.experience => 'experience',
    };
  }
}
