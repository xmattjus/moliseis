/// Minimal Open-Meteo response shared by transport acceptance tests.
const Map<String, Object> weatherHttpResponse = {
  'latitude': 41.5,
  'longitude': 14.5,
  'generationtime_ms': 0.1,
  'utc_offset_seconds': 0,
  'timezone': 'Europe/Rome',
  'timezone_abbreviation': 'CET',
  'elevation': 100,
  'current': {
    'time': '2026-10-30T12:00',
    'interval': 900,
    'temperature_2m': 18.0,
    'is_day': 1,
    'weather_code': 0,
  },
  'hourly': {
    'time': <String>[],
    'temperature_2m': <double>[],
    'precipitation_probability': <int>[],
    'weather_code': <int>[],
    'is_day': <int>[],
  },
  'daily': {
    'time': <String>[],
    'weather_code': <int>[],
    'temperature_2m_max': <double>[],
    'temperature_2m_min': <double>[],
    'precipitation_probability_max': <int>[],
  },
};
