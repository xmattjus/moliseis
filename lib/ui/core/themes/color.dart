import 'package:flutter/material.dart';

class CustomColorSchemes {
  const CustomColorSchemes._();

  /// The color seed used to generate the app color scheme.
  static const Color appSeed = Color(0xFF10A549);

  // TODO(xmattjus): add user customizable colors.

  static const Color _natureSeed = Color(0xFF52EA3E);
  static const Color _historySeed = Color(0XFFe83c70);
  static const Color _folkloreSeed = Color(0XFFe8ea3f);
  static const Color _foodSeed = Color(0XFF3fa1ec);
  static const Color _allureSeed = Color(0XFFe9863a);
  static const Color _experienceSeed = Color(0XFF3ce9e6);

  static Brightness? _brightness;

  static ColorScheme? _main;
  static ColorScheme? _nature;
  static ColorScheme? _history;
  static ColorScheme? _folklore;
  static ColorScheme? _food;
  static ColorScheme? _allure;
  static ColorScheme? _experience;

  static void _resetBrightness(Brightness newBrightness) {
    if (newBrightness != _brightness) {
      _brightness = newBrightness;
      _main = ColorScheme.fromSeed(
        seedColor: appSeed,
        brightness: _brightness!,
      );
      _nature = ColorScheme.fromSeed(
        seedColor: _natureSeed,
        brightness: _brightness!,
      );
      _history = ColorScheme.fromSeed(
        seedColor: _historySeed,
        brightness: _brightness!,
      );
      _folklore = ColorScheme.fromSeed(
        seedColor: _folkloreSeed,
        brightness: _brightness!,
      );
      _food = ColorScheme.fromSeed(
        seedColor: _foodSeed,
        brightness: _brightness!,
      );
      _allure = ColorScheme.fromSeed(
        seedColor: _allureSeed,
        brightness: _brightness!,
      );
      _experience = ColorScheme.fromSeed(
        seedColor: _experienceSeed,
        brightness: _brightness!,
      );
    }
  }

  static ColorScheme main(Color primary, Brightness brightness) {
    _resetBrightness(brightness);
    return _main!;
  }

  static ColorScheme nature(Color primary, Brightness brightness) {
    _resetBrightness(brightness);
    return _nature!;
  }

  static ColorScheme history(Color primary, Brightness brightness) {
    _resetBrightness(brightness);
    return _history!;
  }

  static ColorScheme folklore(Color primary, Brightness brightness) {
    _resetBrightness(brightness);
    return _folklore!;
  }

  static ColorScheme food(Color primary, Brightness brightness) {
    _resetBrightness(brightness);
    return _food!;
  }

  static ColorScheme allure(Color primary, Brightness brightness) {
    _resetBrightness(brightness);
    return _allure!;
  }

  static ColorScheme experience(Color primary, Brightness brightness) {
    _resetBrightness(brightness);
    return _experience!;
  }
}
