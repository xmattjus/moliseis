import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:http/retry.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/utils/constants.dart';
import 'package:provider/provider.dart';

class GeoMapTileLayer extends StatefulWidget {
  const GeoMapTileLayer({super.key});

  @override
  State<GeoMapTileLayer> createState() => _GeoMapTileLayerState();
}

class _GeoMapTileLayerState extends State<GeoMapTileLayer> {
  late final NetworkTileProvider _tileProvider;

  @override
  void initState() {
    super.initState();
    _tileProvider = NetworkTileProvider(
      httpClient: RetryClient(context.read<http.Client>()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return TileLayer(
      tileProvider: _tileProvider,
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
      userAgentPackageName: kUserAgent,
    );
  }
}
