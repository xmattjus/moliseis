import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/content_type.dart';

extension ContentCategoryExtensions on ContentCategory {
  IconData get icon => switch (this) {
    ContentCategory.unknown => Symbols.question_mark,
    ContentCategory.nature => Symbols.forest,
    ContentCategory.history => Symbols.school,
    ContentCategory.folklore => Symbols.groups_3,
    ContentCategory.food => Symbols.fastfood,
    ContentCategory.allure => Symbols.attractions,
    ContentCategory.experience => Symbols.signpost,
  };

  String get label => switch (this) {
    ContentCategory.unknown => 'unknown',
    ContentCategory.nature => 'Natura',
    ContentCategory.history => 'Storia',
    ContentCategory.folklore => 'Folklore',
    ContentCategory.food => 'Cibo',
    ContentCategory.allure => 'Attrazioni',
    ContentCategory.experience => 'Esperienze',
  };
}

extension ContentCategoryListExtensions on List<ContentCategory> {
  /// Returns a list of [ContentCategory]s containing all but
  /// [ContentCategory.unknown].
  List<ContentCategory> get minusUnknown =>
      where((category) => category != ContentCategory.unknown).toList();
}

extension ContentTypeExtensions on ContentType {
  String get label => switch (this) {
    ContentType.event => 'Eventi',
    ContentType.place => 'Luoghi',
  };
}
