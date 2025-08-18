import 'package:flutter/material.dart';
import 'package:moliseis/domain/models/core/content_category.dart';
import 'package:moliseis/domain/models/core/content_type.dart';
import 'package:moliseis/ui/core/ui/window_size_provider.dart';

extension ColorExtensions on Color? {
  /// Darkens the color by the specified [amount].
  ///
  /// The [amount] parameter should be between 0.0 and 1.0, where:
  /// - 0.0 means no change
  /// - 1.0 means maximum darkening (towards black)
  ///
  /// Returns null if the original color is null.
  ///
  /// Example:
  /// ```dart
  /// Color red = Colors.red;
  /// Color darkerRed = red.darken(0.2); // 20% darker
  /// ```
  Color? darken(double amount) => _changeLightness(-amount);

  /// Lightens the color by the specified [amount].
  ///
  /// The [amount] parameter should be between 0.0 and 1.0, where:
  /// - 0.0 means no change
  /// - 1.0 means maximum lightening (towards white)
  ///
  /// Returns null if the original color is null.
  ///
  /// Example:
  /// ```dart
  /// Color blue = Colors.blue;
  /// Color lighterBlue = blue.lighten(0.3); // 30% lighter
  /// ```
  Color? lighten(double amount) => _changeLightness(amount);

  /// Internal method that changes the lightness of the color by the specified [amount].
  ///
  /// The [amount] can be positive (to lighten) or negative (to darken).
  /// The absolute value of [amount] must not exceed 1.0.
  ///
  /// The method converts the color to HSL, adjusts the lightness value,
  /// clamps it between 0.0 and 1.0, and converts back to RGB.
  ///
  /// Returns null if the original color is null.
  ///
  /// Throws an [AssertionError] if the absolute value of [amount] exceeds 1.0.
  Color? _changeLightness(double amount) {
    if (this == null) return null;

    assert(amount.abs() <= 1);

    final hsl = HSLColor.fromColor(this!);
    final hslNew = hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0));

    return hslNew.toColor();
  }
}

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

  int get gridViewColumnCount {
    final windowSize = WindowSizeProvider.of(this);

    if (windowSize.isExtraLarge) {
      return 6;
    } else if (windowSize.isLarge) {
      return 5;
    } else if (windowSize.isExpanded) {
      return 4;
    } else if (windowSize.isMedium) {
      return 3;
    } else {
      return 2;
    }
  }
}
