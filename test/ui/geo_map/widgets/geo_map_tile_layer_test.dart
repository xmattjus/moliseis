import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../support/recording_tile_http_client.dart';

void main() {
  testWidgets('keeps one provider across theme and density rebuilds', (
    tester,
  ) async {
    final client = RecordingTileHttpClient();

    await tester.pumpWidget(tileMapApp(client, Brightness.light, 1));
    final initialLayer = tester.widget<TileLayer>(find.byType(TileLayer));
    final provider = initialLayer.tileProvider;
    expect(initialLayer.resolvedRetinaMode, RetinaMode.disabled);

    await tester.pumpWidget(tileMapApp(client, Brightness.dark, 1));
    expect(
      tester
          .widget<TileLayer>(find.byType(TileLayer))
          .additionalOptions['mapUrl'],
      'basic-v2-dark',
    );
    expect(
      tester.widget<TileLayer>(find.byType(TileLayer)).tileProvider,
      same(provider),
    );

    await tester.pumpWidget(tileMapApp(client, Brightness.dark, 2));
    expect(
      tester.widget<TileLayer>(find.byType(TileLayer)).resolvedRetinaMode,
      RetinaMode.server,
    );
    expect(
      tester.widget<TileLayer>(find.byType(TileLayer)).tileProvider,
      same(provider),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'map disposal preserves app client and remount creates provider',
    (tester) async {
      final client = RecordingTileHttpClient();

      await tester.pumpWidget(tileMapApp(client, Brightness.light, 1));
      final firstProvider = tester
          .widget<TileLayer>(find.byType(TileLayer))
          .tileProvider;

      await tester.pumpWidget(
        Provider<http.Client>.value(
          value: client,
          child: const MaterialApp(home: SizedBox.shrink()),
        ),
      );
      expect(client.closeCount, 0);
      expect(
        (await client.get(Uri.parse('https://example.test/tile'))).statusCode,
        200,
      );

      await tester.pumpWidget(tileMapApp(client, Brightness.light, 1));
      final secondProvider = tester
          .widget<TileLayer>(find.byType(TileLayer))
          .tileProvider;
      expect(secondProvider, isNot(same(firstProvider)));
      expect(client.closeCount, 0);

      await tester.pumpWidget(const SizedBox.shrink());
      expect(client.closeCount, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
