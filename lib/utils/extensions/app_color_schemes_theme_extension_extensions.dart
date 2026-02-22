import 'package:flutter/material.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/ui/core/themes/theme_extensions.dart';

extension AppColorSchemesThemeExtensionExtensions
    on AppColorSchemesThemeExtension {
  ColorScheme byCategory(ContentCategory category) => switch (category) {
    ContentCategory.nature => nature,
    ContentCategory.history => history,
    ContentCategory.folklore => folklore,
    ContentCategory.food => food,
    ContentCategory.allure => allure,
    ContentCategory.experience => experience,
    ContentCategory.unknown => main,
  };
}
