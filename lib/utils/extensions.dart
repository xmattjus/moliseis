import 'package:flutter/material.dart';
import 'package:moliseis/domain/models/attraction/attraction_type.dart';

extension AttractionTypeExtensions on AttractionType {
  IconData get icon => switch (this) {
    AttractionType.unknown => Icons.question_mark,
    AttractionType.nature => Icons.forest,
    AttractionType.history => Icons.school,
    AttractionType.folklore => Icons.groups_3,
    AttractionType.food => Icons.fastfood,
    AttractionType.allure => Icons.attractions,
    AttractionType.experience => Icons.signpost,
  };

  IconData get iconAlt => switch (this) {
    AttractionType.unknown => Icons.question_mark_outlined,
    AttractionType.nature => Icons.forest_outlined,
    AttractionType.history => Icons.school_outlined,
    AttractionType.folklore => Icons.groups_3_outlined,
    AttractionType.food => Icons.fastfood_outlined,
    AttractionType.allure => Icons.attractions_outlined,
    AttractionType.experience => Icons.signpost_outlined,
  };

  String get label => switch (this) {
    AttractionType.unknown => 'unknown',
    AttractionType.nature => 'Natura',
    AttractionType.history => 'Storia',
    AttractionType.folklore => 'Folklore',
    AttractionType.food => 'Cibo',
    AttractionType.allure => 'Attrazioni',
    AttractionType.experience => 'Esperienze',
  };
}

extension AttractionTypeListExtensions on List<AttractionType> {
  /// Returns a list of [AttractionType]s containing all but
  /// [AttractionType.unknown].
  List<AttractionType> get minusUnknown => AttractionType.values.sublist(1);
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
}
