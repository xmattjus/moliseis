import 'package:flutter/widgets.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

/// Maps WMO weather codes to the proper weather icon with day/night variants.
///
/// This mapper centralizes icon selection to ensure consistent visual
/// representation across the app while handling time-of-day differences for
/// clear sky conditions. Unknown codes fall back to a help icon.
class WmoWeatherIconMapper {
  const WmoWeatherIconMapper();

  static const Map<int, IconData> _sharedWeatherCodeMap = {
    3: Symbols.cloud,
    45: Symbols.foggy,
    48: Symbols.mist,
    51: Symbols.rainy,
    53: Symbols.rainy,
    55: Symbols.rainy,
    56: Symbols.weather_mix,
    57: Symbols.weather_mix,
    61: Symbols.rainy,
    63: Symbols.rainy,
    65: Symbols.rainy,
    66: Symbols.weather_mix,
    67: Symbols.weather_mix,
    71: Symbols.weather_snowy,
    73: Symbols.weather_snowy,
    75: Symbols.weather_snowy,
    77: Symbols.weather_hail,
    80: Symbols.rainy,
    81: Symbols.rainy,
    82: Symbols.rainy,
    85: Symbols.weather_snowy,
    86: Symbols.weather_snowy,
    95: Symbols.thunderstorm,
    96: Symbols.weather_hail,
    99: Symbols.weather_hail,
  };

  static const Map<int, IconData> _dayOverrides = {
    0: Symbols.sunny,
    1: Symbols.wb_sunny,
    2: Symbols.partly_cloudy_day,
  };

  static const Map<int, IconData> _nightOverrides = {
    0: Symbols.moon_stars,
    1: Symbols.bedtime,
    2: Symbols.partly_cloudy_night,
  };

  static const Map<int, IconData> _dayWeatherCodeMap = {
    ..._sharedWeatherCodeMap,
    ..._dayOverrides,
  };

  static const Map<int, IconData> _nightWeatherCodeMap = {
    ..._sharedWeatherCodeMap,
    ..._nightOverrides,
  };

  /// Returns the appropriate icon for the given [weatherCode] and time of day.
  ///
  /// The [isDay] parameter determines whether to use day or night variants.
  /// Returns [Symbols.help_outline] if the code is not recognized.
  IconData iconForCode(int weatherCode, bool isDay) {
    return () {
          if (isDay) {
            return _dayWeatherCodeMap[weatherCode];
          } else {
            return _nightWeatherCodeMap[weatherCode];
          }
        }() ??
        Symbols.help_outline;
  }
}
