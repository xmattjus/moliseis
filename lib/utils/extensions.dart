import 'package:flutter/material.dart';
import 'package:moliseis/domain/models/core/content_category.dart';
import 'package:moliseis/domain/models/core/content_type.dart';

extension ContentCategoryExtensions on ContentCategory {
  IconData get icon => switch (this) {
    ContentCategory.unknown => Icons.question_mark,
    ContentCategory.nature => Icons.forest,
    ContentCategory.history => Icons.school,
    ContentCategory.folklore => Icons.groups_3,
    ContentCategory.food => Icons.fastfood,
    ContentCategory.allure => Icons.attractions,
    ContentCategory.experience => Icons.signpost,
  };

  IconData get iconAlt => switch (this) {
    ContentCategory.unknown => Icons.question_mark_outlined,
    ContentCategory.nature => Icons.forest_outlined,
    ContentCategory.history => Icons.school_outlined,
    ContentCategory.folklore => Icons.groups_3_outlined,
    ContentCategory.food => Icons.fastfood_outlined,
    ContentCategory.allure => Icons.attractions_outlined,
    ContentCategory.experience => Icons.signpost_outlined,
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

extension ContentTypeExtensions on ContentType {
  String get label => switch (this) {
    ContentType.event => 'Eventi',
    ContentType.place => 'Luoghi',
  };
}

extension ContentCategoryListExtensions on List<ContentCategory> {
  /// Returns a list of [ContentCategory]s containing all but
  /// [ContentCategory.unknown].
  List<ContentCategory> get minusUnknown => ContentCategory.values.sublist(1);
}

extension BuildContextExtensions on BuildContext {
  /// Whether the [MediaQueryData.orientation] reported for the nearest
  /// [MediaQuery] ancestor equals [Orientation.landscape] or false, if no such
  /// ancestor exists.
  bool get isLandscape {
    final inherited = InheritedModel.inheritFrom<MediaQuery>(this)?.data;
    return inherited?.orientation == Orientation.landscape;
  }

  bool get isDarkTheme {
    return Theme.of(this).brightness == Brightness.dark;
  }

  // TODO(xmattjus): Implement a method to check if the device is a phone.
}
