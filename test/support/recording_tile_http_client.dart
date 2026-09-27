import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/ui/geo_map/widgets/geo_map.dart';
import 'package:provider/provider.dart';

/// Serves valid tile images and records transport ownership in widget tests.
final class RecordingTileHttpClient extends http.BaseClient {
  int closeCount = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (closeCount != 0) {
      throw http.ClientException('Client is closed', request.url);
    }

    return http.StreamedResponse(
      Stream<List<int>>.value(TileProvider.transparentImage),
      200,
      request: request,
      headers: const {'cache-control': 'no-store'},
    );
  }

  @override
  void close() => closeCount++;
}

/// Mounts the production map with an application-owned test client.
Widget tileMapApp(
  http.Client client,
  Brightness brightness,
  double pixelRatio,
) => Provider<http.Client>.value(
  value: client,
  child: MaterialApp(
    home: Theme(
      data: ThemeData(brightness: brightness),
      child: MediaQuery(
        data: MediaQueryData(devicePixelRatio: pixelRatio),
        child: const Scaffold(
          body: SizedBox(
            width: 400,
            height: 400,
            child: GeoMap(initialCenter: LatLng(41.56, 14.65)),
          ),
        ),
      ),
    ),
  ),
);
