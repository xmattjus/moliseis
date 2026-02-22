import 'package:flutter/material.dart';

final class _AppSeeds {
  Color get main => const Color(0xFF10A549);
  Color get nature => const Color(0xFF52EA3E);
  Color get history => const Color(0XFFe83c70);
  Color get folklore => const Color(0XFFe8ea3f);
  Color get food => const Color(0XFF3fa1ec);
  Color get allure => const Color(0XFFe9863a);
  Color get experience => const Color(0XFF3ce9e6);

  const _AppSeeds();
}

class AppColorSchemesThemeExtension
    extends ThemeExtension<AppColorSchemesThemeExtension> {
  final ColorScheme main;
  final ColorScheme nature;
  final ColorScheme history;
  final ColorScheme folklore;
  final ColorScheme food;
  final ColorScheme allure;
  final ColorScheme experience;

  const AppColorSchemesThemeExtension._internal({
    required this.main,
    required this.nature,
    required this.history,
    required this.folklore,
    required this.food,
    required this.allure,
    required this.experience,
  });

  factory AppColorSchemesThemeExtension.fromSeed(Brightness brightness) {
    const appSeeds = _AppSeeds();

    return AppColorSchemesThemeExtension._internal(
      main: ColorScheme.fromSeed(
        seedColor: appSeeds.main,
        brightness: brightness,
        dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
      ),
      nature: ColorScheme.fromSeed(
        seedColor: appSeeds.nature,
        brightness: brightness,
        dynamicSchemeVariant: DynamicSchemeVariant.vibrant,
      ),
      history: ColorScheme.fromSeed(
        seedColor: appSeeds.history,
        brightness: brightness,
        dynamicSchemeVariant: DynamicSchemeVariant.vibrant,
      ),
      folklore: ColorScheme.fromSeed(
        seedColor: appSeeds.folklore,
        brightness: brightness,
        dynamicSchemeVariant: DynamicSchemeVariant.vibrant,
      ),
      food: ColorScheme.fromSeed(
        seedColor: appSeeds.food,
        brightness: brightness,
        dynamicSchemeVariant: DynamicSchemeVariant.vibrant,
      ),
      allure: ColorScheme.fromSeed(
        seedColor: appSeeds.allure,
        brightness: brightness,
        dynamicSchemeVariant: DynamicSchemeVariant.vibrant,
      ),
      experience: ColorScheme.fromSeed(
        seedColor: appSeeds.experience,
        brightness: brightness,
        dynamicSchemeVariant: DynamicSchemeVariant.vibrant,
      ),
    );
  }

  @override
  ThemeExtension<AppColorSchemesThemeExtension> copyWith({
    ColorScheme? main,
    ColorScheme? nature,
    ColorScheme? history,
    ColorScheme? folklore,
    ColorScheme? food,
    ColorScheme? allure,
    ColorScheme? experience,
  }) {
    return AppColorSchemesThemeExtension._internal(
      main: main ?? this.main,
      nature: nature ?? this.nature,
      history: history ?? this.history,
      folklore: folklore ?? this.folklore,
      food: food ?? this.food,
      allure: allure ?? this.allure,
      experience: experience ?? this.experience,
    );
  }

  @override
  AppColorSchemesThemeExtension lerp(
    ThemeExtension<AppColorSchemesThemeExtension>? other,
    double t,
  ) {
    if (other is! AppColorSchemesThemeExtension) {
      return this;
    }

    return AppColorSchemesThemeExtension._internal(
      main: ColorScheme.lerp(main, other.main, t),
      nature: ColorScheme.lerp(nature, other.nature, t),
      history: ColorScheme.lerp(history, other.history, t),
      folklore: ColorScheme.lerp(folklore, other.folklore, t),
      food: ColorScheme.lerp(food, other.food, t),
      allure: ColorScheme.lerp(allure, other.allure, t),
      experience: ColorScheme.lerp(experience, other.experience, t),
    );
  }
}
