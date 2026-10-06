import 'package:flex_seed_scheme/flex_seed_scheme.dart';
import 'package:material_ui/material_ui.dart';

final class _AppSeeds {
  const _AppSeeds();

  Color get primaryKey => const Color(0xFF10A549);
  Color get secondaryKey => const Color(0xFF176B87);
  Color get tertiaryKey => const Color(0xFFB84E23);
  Color get naturePrimaryKey => const Color(0xFF52EA3E);
  Color get historyPrimaryKey => const Color(0XFFe83c70);
  Color get folklorePrimaryKey => const Color(0XFFe8ea3f);
  Color get foodPrimaryKey => const Color(0XFF3fa1ec);
  Color get allurePrimaryKey => const Color(0XFFe9863a);
  Color get experiencePrimaryKey => const Color(0XFF3ce9e6);
}

class AppColorSchemesThemeExtension
    extends ThemeExtension<AppColorSchemesThemeExtension> {
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
      main: SeedColorScheme.fromSeeds(
        brightness: brightness,
        primaryKey: appSeeds.primaryKey,
        secondaryKey: appSeeds.secondaryKey,
        tertiaryKey: appSeeds.tertiaryKey,
        variant: FlexSchemeVariant.vivid,
      ),
      nature: SeedColorScheme.fromSeeds(
        primaryKey: appSeeds.naturePrimaryKey,
        brightness: brightness,
        variant: FlexSchemeVariant.vibrant,
      ),
      history: SeedColorScheme.fromSeeds(
        primaryKey: appSeeds.historyPrimaryKey,
        brightness: brightness,
        variant: FlexSchemeVariant.vibrant,
      ),
      folklore: SeedColorScheme.fromSeeds(
        primaryKey: appSeeds.folklorePrimaryKey,
        brightness: brightness,
        variant: FlexSchemeVariant.vibrant,
      ),
      food: SeedColorScheme.fromSeeds(
        primaryKey: appSeeds.foodPrimaryKey,
        brightness: brightness,
        variant: FlexSchemeVariant.vibrant,
      ),
      allure: SeedColorScheme.fromSeeds(
        primaryKey: appSeeds.allurePrimaryKey,
        brightness: brightness,
        variant: FlexSchemeVariant.vibrant,
      ),
      experience: SeedColorScheme.fromSeeds(
        primaryKey: appSeeds.experiencePrimaryKey,
        brightness: brightness,
        variant: FlexSchemeVariant.vibrant,
      ),
    );
  }
  final ColorScheme main;
  final ColorScheme nature;
  final ColorScheme history;
  final ColorScheme folklore;
  final ColorScheme food;
  final ColorScheme allure;
  final ColorScheme experience;

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
