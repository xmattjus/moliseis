/// Maps WMO weather codes to the proper description.
///
/// This mapper centralizes description selection to ensure consistent visual
/// representation across the app.
class WmoWeatherDescriptionMapper {
  const WmoWeatherDescriptionMapper();

  static const Map<int, String> _weatherCodeDescriptionMap = {
    0: 'Sereno',
    1: 'Per lo più sereno',
    2: 'Parzialmente nuvoloso',
    3: 'Coperto',
    45: 'Nebbia',
    48: 'Nebbia con deposizione di brina',
    51: 'Leggera pioviggine',
    53: 'Moderata pioviggine',
    55: 'Intensa pioviggine',
    56: 'Leggera pioviggine gelata',
    57: 'Intensa pioviggine gelata',
    61: 'Pioggia leggera',
    63: 'Pioggia moderata',
    65: 'Pioggia intensa',
    66: 'Leggera pioggia gelata',
    67: 'Intensa pioggia gelata',
    71: 'Leggere nevicate',
    73: 'Moderate nevicate',
    75: 'Intense nevicate',
    77: 'Granelli di neve',
    80: 'Leggeri rovesci',
    81: 'Moderati rovesci',
    82: 'Intensi rovesci',
    85: 'Leggeri rovesci di neve',
    86: 'Intensi rovesci di neve',
    95: 'Temporale',
    96: 'Leggere grandinate',
    99: 'Intense grandinate',
  };

  /// Returns the appropriate description for the given [weatherCode].
  String descriptionForCode(int weatherCode) {
    return _weatherCodeDescriptionMap[weatherCode] ?? 'Meteo sconosciuto';
  }
}
