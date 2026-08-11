import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  testWidgets('zero-displacement fling keeps the map camera finite', (
    tester,
  ) async {
    final controller = MapController();
    final events = <MapEvent>[];
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              height: 400,
              width: 400,
              child: FlutterMap(
                mapController: controller,
                options: MapOptions(
                  initialCenter: const LatLng(41.5575078, 14.6485406),
                  initialZoom: 13.5,
                  onMapEvent: events.add,
                ),
                children: const <Widget>[],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final origin = tester.getCenter(find.byType(FlutterMap));
    final gesture = await tester.createGesture();

    // This reproduces a high-velocity gesture whose final pointer segment and
    // total displacement are both zero.
    await gesture.down(
      origin,
      timeStamp: const Duration(microseconds: 1),
    );
    await gesture.moveTo(
      origin + const Offset(120, 0),
      timeStamp: const Duration(milliseconds: 10),
    );
    await gesture.moveTo(
      origin,
      timeStamp: const Duration(milliseconds: 20),
    );
    await gesture.moveTo(
      origin,
      timeStamp: const Duration(milliseconds: 25),
    );
    await gesture.up(timeStamp: const Duration(milliseconds: 30));

    for (var frame = 0; frame < 10; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(
      events.any(
        (event) => event.source == MapEventSource.flingAnimationController,
      ),
      isTrue,
    );
    expect(controller.camera.center.latitude.isFinite, isTrue);
    expect(controller.camera.center.longitude.isFinite, isTrue);
    expect(controller.camera.zoom.isFinite, isTrue);
    expect(
      events.every(
        (event) =>
            event.camera.center.latitude.isFinite &&
            event.camera.center.longitude.isFinite,
      ),
      isTrue,
    );
    expect(
      events.every((event) => event.camera.zoom.isFinite),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });
}
