import 'package:flutter/material.dart';
import 'package:material_color_utilities/blend/blend.dart';
import 'package:moliseis/domain/models/core/content_category.dart';

class CustomColorSchemes {
  const CustomColorSchemes._();

  /// The baseline primary color.
  static const Color primary = Color(0xFF10A549);

  /// The content categories primary colors.
  static const Color _primaryNature = Color(0xFF52EA3E);
  static const Color _primaryHistory = Color(0XFFe83c70);
  static const Color _primaryFolklore = Color(0XFFe8ea3f);
  static const Color _primaryFood = Color(0XFF3fa1ec);
  static const Color _primaryAllure = Color(0XFFe9863a);
  static const Color _primaryExperience = Color(0XFF3ce9e6);

  static Color harmonize(Color from, Color to) {
    if (from == to) return from;

    return Color(Blend.harmonize(from.toARGB32(), to.toARGB32()));
  }

  /// Generates a color scheme using the appropriate primary color based on
  /// [ContentCategory].
  static ColorScheme fromContentCategory(
    ContentCategory type,
    Brightness brightness,
  ) {
    final color = switch (type) {
      ContentCategory.unknown => primary,
      ContentCategory.nature => harmonize(_primaryNature, primary),
      ContentCategory.history => harmonize(_primaryHistory, primary),
      ContentCategory.folklore => harmonize(_primaryFolklore, primary),
      ContentCategory.food => harmonize(_primaryFood, primary),
      ContentCategory.allure => harmonize(_primaryAllure, primary),
      ContentCategory.experience => harmonize(_primaryExperience, primary),
    };

    return ColorScheme.fromSeed(seedColor: color, brightness: brightness);
  }
}
