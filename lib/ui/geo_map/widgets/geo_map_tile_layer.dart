import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

class GeoMapTileLayer extends StatelessWidget {
  const GeoMapTileLayer({super.key});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return TileLayer(
      urlTemplate:
          'https://api.maptiler.com/maps/{mapUrl}/{z}/{x}/{y}{r}.png'
          '?key={apiKey}',
      tileDimension:
          512, // https://docs.fleaflet.dev/layers/tile-layer#tilesize
      zoomOffset: -1,
      additionalOptions: {
        'mapUrl': brightness == Brightness.dark ? 'basic-v2-dark' : 'basic-v2',
        'apiKey': 'ApYiPMeYThI0wnaG93zr',
      },
      retinaMode: RetinaMode.isHighDensity(context),
      userAgentPackageName: 'com.benitomatteobercini.moliseis',
    );
  }
}
