import 'package:flutter/material.dart';
import 'package:material_color_utilities/blend/blend.dart';
import 'package:moliseis/domain/models/attraction/attraction_type.dart';

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
  /// [type].
  static ColorScheme fromAttractionType(
    AttractionType type,
    Brightness brightness,
  ) {
    final color = switch (type) {
      AttractionType.unknown => primary,
      AttractionType.nature => harmonize(_primaryNature, primary),
      AttractionType.history => harmonize(_primaryHistory, primary),
      AttractionType.folklore => harmonize(_primaryFolklore, primary),
      AttractionType.food => harmonize(_primaryFood, primary),
      AttractionType.allure => harmonize(_primaryAllure, primary),
      AttractionType.experience => harmonize(_primaryExperience, primary),
    };

    return ColorScheme.fromSeed(seedColor: color, brightness: brightness);
  }
}
