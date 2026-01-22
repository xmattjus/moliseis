import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Maps WMO weather codes to the proper weather icon with day/night variants.
///
/// This mapper centralizes icon selection to ensure consistent visual
/// representation across the app while handling time-of-day differences for
/// clear sky conditions. Unknown codes fall back to a help icon.
class WmoWeatherIconMapper {
  const WmoWeatherIconMapper();

  static const Map<int, PhosphorIconData> _sharedWeatherCodeMap = {
    45: PhosphorIconsBold.cloudFog,
    48: PhosphorIconsBold.cloudFog,
    51: PhosphorIconsBold.cloudRain,
    53: PhosphorIconsBold.cloudRain,
    55: PhosphorIconsBold.cloudRain,
    56: PhosphorIconsBold.cloudSnow,
    57: PhosphorIconsBold.cloudSnow,
    61: PhosphorIconsBold.cloudRain,
    63: PhosphorIconsBold.cloudRain,
    65: PhosphorIconsBold.cloudRain,
    66: PhosphorIconsBold.cloudSnow,
    67: PhosphorIconsBold.cloudSnow,
    71: PhosphorIconsBold.snowflake,
    73: PhosphorIconsBold.snowflake,
    75: PhosphorIconsBold.snowflake,
    77: PhosphorIconsBold.cloudSnow,
    80: PhosphorIconsBold.cloudRain,
    81: PhosphorIconsBold.cloudRain,
    82: PhosphorIconsBold.cloudRain,
    85: PhosphorIconsBold.cloudSnow,
    86: PhosphorIconsBold.cloudSnow,
    95: PhosphorIconsBold.cloudLightning,
    96: PhosphorIconsBold.cloudLightning,
    99: PhosphorIconsBold.cloudLightning,
  };

  static const Map<int, PhosphorIconData> _dayOverrides = {
    0: PhosphorIconsBold.sun,
    1: PhosphorIconsBold.sunDim,
    2: PhosphorIconsBold.cloudSun,
    3: PhosphorIconsBold.cloudSun,
  };

  static const Map<int, PhosphorIconData> _nightOverrides = {
    0: PhosphorIconsBold.moon,
    1: PhosphorIconsBold.cloudMoon,
    2: PhosphorIconsBold.cloudMoon,
    3: PhosphorIconsBold.cloudMoon,
  };

  static const Map<int, PhosphorIconData> _dayWeatherCodeMap = {
    ..._sharedWeatherCodeMap,
    ..._dayOverrides,
  };

  static const Map<int, PhosphorIconData> _nightWeatherCodeMap = {
    ..._sharedWeatherCodeMap,
    ..._nightOverrides,
  };

  /// Returns the appropriate icon for the given [weatherCode] and time of day.
  ///
  /// The [isDay] parameter determines whether to use day or night variants.
  /// Returns [Icons.help_outline] if the code is not recognized.
  PhosphorIconData iconForCode(int weatherCode, bool isDay) {
    return () {
          if (isDay) {
            return _dayWeatherCodeMap[weatherCode];
          } else {
            return _nightWeatherCodeMap[weatherCode];
          }
        }() ??
        PhosphorIconsBold.questionMark;
  }
}
