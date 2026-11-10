import 'dart:ui' show Tristate;

import 'package:flutter/gestures.dart' show kDoubleTapTimeout;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_map/flutter_map.dart' show TapPosition;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/ui/admin/submissions/widgets/admin_submission_location_editor.dart';
import 'package:moliseis/ui/core/ui/custom_back_button.dart';
import 'package:moliseis/ui/geo_map/widgets/geo_map.dart';
import 'package:moliseis/ui/geo_map/widgets/geo_map_location_picker.dart';
import 'package:moliseis/ui/geo_map/widgets/geo_map_marker.dart';
import 'package:moliseis/ui/geo_map/widgets/geo_map_marker_painter.dart';
import 'package:provider/provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../../../support/recording_tile_http_client.dart';

/// Minimal parent that owns the coordinate drafts like the editor ViewModel,
/// so map-driven prop changes can be replayed through the widget-update
/// lifecycle.
class _Harness extends StatefulWidget {
  const _Harness({
    required this.formKey,
    this.initialLatitude = '',
    this.initialLongitude = '',
    super.key,
  });

  final GlobalKey<FormState> formKey;
  final String initialLatitude;
  final String initialLongitude;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  late String latitudeText = widget.initialLatitude;
  late String longitudeText = widget.initialLongitude;
  final emittedLatitudeChanges = <String>[];
  final emittedLongitudeChanges = <String>[];
  final selectedPoints = <LatLng>[];

  @override
  Widget build(BuildContext context) {
    return AdminSubmissionLocationEditor(
      latitudeText: latitudeText,
      longitudeText: longitudeText,
      onLatitudeTextChanged: (value) => setState(() {
        emittedLatitudeChanges.add(value);
        latitudeText = value;
      }),
      onLongitudeTextChanged: (value) => setState(() {
        emittedLongitudeChanges.add(value);
        longitudeText = value;
      }),
      onMapCoordinatesSelected: (latitude, longitude) => setState(() {
        selectedPoints.add(LatLng(latitude, longitude));
        // Mirrors setCoordinates(): formatted six-decimal drafts.
        latitudeText = latitude.toStringAsFixed(6);
        longitudeText = longitude.toStringAsFixed(6);
      }),
      formKey: widget.formKey,
    );
  }
}

Future<(_HarnessState, GlobalKey<FormState>)> _pumpEditor(
  WidgetTester tester, {
  String latitude = '',
  String longitude = '',
  Brightness brightness = Brightness.light,
}) async {
  final formKey = GlobalKey<FormState>();
  final harnessKey = GlobalKey<_HarnessState>();
  await tester.pumpWidget(
    Provider<http.Client>.value(
      value: RecordingTileHttpClient(),
      child: MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: Scaffold(
          body: SingleChildScrollView(
            child: _Harness(
              key: harnessKey,
              formKey: formKey,
              initialLatitude: latitude,
              initialLongitude: longitude,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (harnessKey.currentState!, formKey);
}

void main() {
  testWidgets('defaults to Map mode and offers the shared picker', (
    tester,
  ) async {
    await _pumpEditor(tester);

    expect(find.byType(GeoMap), findsNothing);
    expect(find.text('Seleziona sulla mappa'), findsOneWidget);
    expect(
      find.ancestor(
        of: find.text('Seleziona sulla mappa'),
        matching: find.byType(SentryMask),
      ),
      findsOneWidget,
    );
    expect(find.text('Mappa'), findsOneWidget);
    expect(find.text('Coordinate'), findsOneWidget);
  });

  testWidgets('blank drafts validate successfully from Map mode', (
    tester,
  ) async {
    final (_, formKey) = await _pumpEditor(tester);

    expect(formKey.currentState, isNotNull);
    expect(formKey.currentState!.validate(), isTrue);
  });

  testWidgets('malformed hydrated draft opens in Coordinate mode '
      'with visible errors', (tester) async {
    final (_, formKey) = await _pumpEditor(tester, latitude: '41.55');

    expect(find.byType(GeoMap), findsNothing);
    expect(find.byType(TextFormField), findsNWidgets(2));
    for (final field in find.byType(TextFormField).evaluate()) {
      expect(
        find.ancestor(
          of: find.byWidget(field.widget),
          matching: find.byType(SentryMask),
        ),
        findsOneWidget,
      );
    }

    formKey.currentState!.validate();
    await tester.pump();

    expect(find.text('Inserisci anche la longitudine.'), findsOneWidget);
  });

  testWidgets('blank coordinates open picker without a selection', (
    tester,
  ) async {
    await _pumpEditor(tester);
    await tester.tap(find.text('Seleziona sulla mappa'));
    await tester.pumpAndSettle();

    expect(find.byType(GeoMapLocationPicker), findsOneWidget);
    expect(tester.widget<GeoMap>(find.byType(GeoMap)).markers, isEmpty);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('geo_map_location_picker_confirm')),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('existing location initializes picker marker and manual fields', (
    tester,
  ) async {
    await _pumpEditor(tester, latitude: '41.5575078', longitude: '14.6485406');
    await tester.tap(find.text('Seleziona sulla mappa'));
    await tester.pumpAndSettle();

    final geoMap = tester.widget<GeoMap>(find.byType(GeoMap));
    expect(geoMap.markers, hasLength(1));
    expect(geoMap.markers.single.point, const LatLng(41.5575078, 14.6485406));
    expect(find.byType(GeoMapMarkerIcon), findsOneWidget);
    final fields = tester.widgetList<TextFormField>(
      find.byType(TextFormField, skipOffstage: false),
    );
    expect(fields.first.controller!.text, '41.5575078');
    expect(fields.last.controller!.text, '14.6485406');
  });

  testWidgets('temporary marker tip meets the selected coordinate', (
    tester,
  ) async {
    await _pumpEditor(tester, latitude: '41.5575078', longitude: '14.6485406');
    await tester.tap(find.text('Seleziona sulla mappa'));
    await tester.pumpAndSettle();
    final marker = tester.widget<GeoMap>(find.byType(GeoMap)).markers.single;
    expect(marker.alignment, Alignment.topCenter);
    final artwork = find.descendant(
      of: find.byType(GeoMapMarkerIcon),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is CustomPaint && widget.painter is GeoMapMarkerPainter,
      ),
    );
    final tip = tester.getRect(artwork).bottomCenter;
    final coordinate = tester.getCenter(find.byType(GeoMap));
    expect((tip - coordinate).distance, lessThanOrEqualTo(1));
  });

  for (final (latitude, longitude) in [
    ('41.5575078', '14.6485406'),
    (' 41,5575078 ', ' 14,6485406 '),
  ]) {
    testWidgets(
      'confirming an unchanged point preserves raw drafts $latitude',
      (tester) async {
        final (state, _) = await _pumpEditor(
          tester,
          latitude: latitude,
          longitude: longitude,
        );
        await tester.tap(find.text('Seleziona sulla mappa'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('geo_map_location_picker_confirm')),
        );
        await tester.pumpAndSettle();
        expect(state.selectedPoints, isEmpty);
        expect(state.latitudeText, latitude);
        expect(state.longitudeText, longitude);
      },
    );
  }

  testWidgets('switching modes does not emit coordinate changes', (
    tester,
  ) async {
    final (state, _) = await _pumpEditor(
      tester,
      latitude: '41.5575078',
      longitude: '14.6485406',
    );

    await tester.tap(find.text('Coordinate'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mappa'));
    await tester.pumpAndSettle();

    expect(state.emittedLatitudeChanges, isEmpty);
    expect(state.emittedLongitudeChanges, isEmpty);
    expect(state.selectedPoints, isEmpty);
  });

  testWidgets('switching modes preserves manual text', (tester) async {
    final (_, _) = await _pumpEditor(tester);

    await tester.tap(find.text('Coordinate'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.first, '41.123456');
    await tester.enterText(fields.last, '14.654321');
    await tester.pump();

    await tester.tap(find.text('Mappa'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Coordinate'));
    await tester.pumpAndSettle();

    final updatedFields = tester.widgetList<TextFormField>(
      find.byType(TextFormField),
    );
    expect(updatedFields.first.controller!.text, '41.123456');
    expect(updatedFields.last.controller!.text, '14.654321');
  });

  testWidgets('manual valid edits invoke the paired draft callbacks', (
    tester,
  ) async {
    final (state, _) = await _pumpEditor(tester);

    await tester.tap(find.text('Coordinate'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '41,55');
    await tester.pump();

    expect(state.emittedLatitudeChanges.last, '41,55');
    expect(state.latitudeText, '41,55');
  });

  testWidgets('manual invalid text remains visible and reports validation', (
    tester,
  ) async {
    final (state, formKey) = await _pumpEditor(tester);

    await tester.tap(find.text('Coordinate'));
    await tester.pumpAndSettle();
    // Fill both sides so the completeness rule passes and the parse rule
    // becomes the visible error.
    await tester.enterText(find.byType(TextFormField).first, 'not-a-number');
    await tester.enterText(find.byType(TextFormField).last, '14.62');
    await tester.pump();

    expect(state.latitudeText, 'not-a-number');
    expect(find.widgetWithText(TextFormField, 'not-a-number'), findsOneWidget);
    expect(find.text('Valore non valido.'), findsOneWidget);
    expect(formKey.currentState!.validate(), isFalse);
  });

  testWidgets('filling one field of an empty pair surfaces the sibling '
      'completeness error immediately and clears it once completed', (
    tester,
  ) async {
    final (_, _) = await _pumpEditor(tester);

    await tester.tap(find.text('Coordinate'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '41.55');
    await tester.pump();

    expect(find.text('Inserisci anche la longitudine.'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).last, '14.62');
    await tester.pump();

    expect(find.text('Inserisci anche la longitudine.'), findsNothing);
  });

  testWidgets('map selection mutates draft only after confirmation', (
    tester,
  ) async {
    final (state, _) = await _pumpEditor(tester);
    await tester.tap(find.text('Seleziona sulla mappa'));
    await tester.pumpAndSettle();

    tester.widget<GeoMap>(find.byType(GeoMap)).onPressed!(
      const TapPosition(Offset.zero, Offset.zero),
      const LatLng(41.9, 14.9),
    );
    await tester.pump();
    expect(state.selectedPoints, isEmpty);
    expect(state.latitudeText, isEmpty);
    expect(state.longitudeText, isEmpty);

    await tester.tap(
      find.byKey(const ValueKey('geo_map_location_picker_confirm')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(GeoMapLocationPicker), findsNothing);
    expect(state.selectedPoints, const <LatLng>[LatLng(41.9, 14.9)]);
    expect(state.latitudeText, '41.900000');
    expect(state.longitudeText, '14.900000');

    await tester.tap(find.text('Coordinate'));
    await tester.pumpAndSettle();
    final fields = tester.widgetList<TextFormField>(find.byType(TextFormField));
    expect(fields.first.controller!.text, '41.900000');
    expect(fields.last.controller!.text, '14.900000');
  });

  testWidgets('successive taps replace the temporary marker '
      'without draft writes', (tester) async {
    final (state, _) = await _pumpEditor(tester);
    await tester.tap(find.text('Seleziona sulla mappa'));
    await tester.pumpAndSettle();

    tester.widget<GeoMap>(find.byType(GeoMap)).onPressed!(
      const TapPosition(Offset.zero, Offset.zero),
      const LatLng(41.9, 14.9),
    );
    await tester.pump();
    tester.widget<GeoMap>(find.byType(GeoMap)).onPressed!(
      const TapPosition(Offset.zero, Offset.zero),
      const LatLng(41.1, 14.2),
    );
    await tester.pump();
    expect(state.selectedPoints, isEmpty);
    expect(
      tester.widget<GeoMap>(find.byType(GeoMap)).markers.single.point,
      const LatLng(41.1, 14.2),
    );

    await tester.tap(
      find.byKey(const ValueKey('geo_map_location_picker_confirm')),
    );
    await tester.pumpAndSettle();

    expect(state.selectedPoints, const <LatLng>[LatLng(41.1, 14.2)]);
    expect(state.latitudeText, '41.100000');
    expect(state.longitudeText, '14.200000');
  });

  testWidgets('half-location and out-of-range values fail validation', (
    tester,
  ) async {
    final (_, formKey) = await _pumpEditor(tester, latitude: '41.55');
    expect(formKey.currentState!.validate(), isFalse);

    final (outOfRangeState, outOfRangeFormKey) = await _pumpEditor(
      tester,
      latitude: '95',
      longitude: '200',
    );
    expect(outOfRangeState, isNotNull);
    expect(outOfRangeFormKey.currentState!.validate(), isFalse);
  });

  testWidgets('invalid coordinate drafts do not become a map selection', (
    tester,
  ) async {
    await _pumpEditor(tester, latitude: '95', longitude: '200');
    expect(find.byType(GeoMap), findsNothing);
    expect(find.byType(TextFormField), findsNWidgets(2));

    await tester.tap(find.text('Mappa'));
    await tester.pumpAndSettle();
    expect(find.text('Coordinate non valide'), findsOneWidget);

    await tester.tap(find.text('Seleziona sulla mappa'));
    await tester.pumpAndSettle();
    final geoMap = tester.widget<GeoMap>(find.byType(GeoMap));
    expect(geoMap.initialCenter, const LatLng(41.5575078, 14.6485406));
    expect(geoMap.markers, isEmpty);
  });

  testWidgets('both blank coordinates validate successfully', (tester) async {
    final (_, formKey) = await _pumpEditor(tester);

    await tester.tap(find.text('Coordinate'));
    await tester.pumpAndSettle();

    expect(formKey.currentState!.validate(), isTrue);
  });

  testWidgets('unfocuses the coordinate fields when switching to Map mode', (
    tester,
  ) async {
    await _pumpEditor(tester);

    await tester.tap(find.text('Coordinate'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '41.55');
    await tester.pumpAndSettle();
    final latitudeEditable = tester.state<EditableTextState>(
      find.byType(EditableText).first,
    );
    expect(latitudeEditable.widget.focusNode.hasFocus, isTrue);

    // The fields remain mounted inside Offstage; the focus must be dropped
    // explicitly when they become invisible.
    await tester.tap(find.text('Mappa'));
    await tester.pumpAndSettle();

    expect(latitudeEditable.widget.focusNode.hasFocus, isFalse);
  });

  testWidgets('shows the invalid-draft hint while Map mode displays an '
      'invalid draft and hides it otherwise', (tester) async {
    // Start from a valid pair, break it in Coordinate mode, then return.
    final (_, _) = await _pumpEditor(
      tester,
      latitude: '41.55',
      longitude: '14.64',
    );
    expect(find.text('Coordinate non valide'), findsNothing);

    await tester.tap(find.text('Coordinate'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).last, '');
    await tester.pump();

    await tester.tap(find.text('Mappa'));
    await tester.pumpAndSettle();
    expect(find.text('Coordinate non valide'), findsOneWidget);
    expect(find.byType(GeoMap), findsNothing);
    expect(find.text('Seleziona sulla mappa'), findsOneWidget);
  });

  testWidgets('explicit Back discards the selection without changing draft', (
    tester,
  ) async {
    final (state, _) = await _pumpEditor(tester);
    await tester.tap(find.text('Seleziona sulla mappa'));
    await tester.pumpAndSettle();

    tester.widget<GeoMap>(find.byType(GeoMap)).onPressed!(
      const TapPosition(Offset.zero, Offset.zero),
      const LatLng(41.9, 14.9),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('geo_map_location_picker_back')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(GeoMapLocationPicker), findsNothing);
    expect(find.byType(AdminSubmissionLocationEditor), findsOneWidget);
    expect(state.selectedPoints, isEmpty);
    expect(state.latitudeText, isEmpty);
  });

  testWidgets('system Back pops only the picker route', (tester) async {
    final (state, _) = await _pumpEditor(
      tester,
      latitude: '41.55',
      longitude: '14.64',
    );
    await tester.tap(find.text('Seleziona sulla mappa'));
    await tester.pumpAndSettle();

    tester.widget<GeoMap>(find.byType(GeoMap)).onPressed!(
      const TapPosition(Offset.zero, Offset.zero),
      const LatLng(41.9, 14.9),
    );
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(GeoMapLocationPicker), findsNothing);
    expect(find.byType(AdminSubmissionLocationEditor), findsOneWidget);
    expect(state.selectedPoints, isEmpty);
    expect(state.latitudeText, '41.55');
    expect(state.longitudeText, '14.64');
  });

  testWidgets(
    'Enter confirms the focused action without selecting map center',
    (tester) async {
      final (state, _) = await _pumpEditor(
        tester,
        latitude: '41.55',
        longitude: '14.64',
      );
      await tester.tap(find.text('Seleziona sulla mappa'));
      await tester.pumpAndSettle();
      expect(
        FocusManager.instance.primaryFocus!.context!
            .findAncestorWidgetOfExactType<GeoMap>(),
        isNotNull,
      );
      await tester.tapAt(
        tester.getCenter(find.byType(GeoMap)) + const Offset(60, 20),
      );
      await tester.pump(kDoubleTapTimeout);
      await tester.pumpAndSettle();
      final map = tester.widget<GeoMap>(find.byType(GeoMap));
      final point = map.markers.single.point;
      expect(point, isNot(map.mapController!.camera.center));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final confirm = find.byKey(
        const ValueKey('geo_map_location_picker_confirm'),
      );
      expect(
        tester
            .getSemantics(confirm)
            .getSemanticsData()
            .flagsCollection
            .isFocused,
        Tristate.isTrue,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byType(GeoMapLocationPicker), findsNothing);
      expect(state.selectedPoints, [point]);
      expect(state.latitudeText, point.latitude.toStringAsFixed(6));
      expect(state.longitudeText, point.longitude.toStringAsFixed(6));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  for (final keyboard in [false, true]) {
    testWidgets('map supports accessible center selection keyboard=$keyboard', (
      tester,
    ) async {
      final (state, _) = await _pumpEditor(tester);
      await tester.tap(find.text('Seleziona sulla mappa'));
      await tester.pumpAndSettle();
      final initialCenter = tester
          .widget<GeoMap>(find.byType(GeoMap))
          .initialCenter;
      if (keyboard) {
        expect(
          FocusManager.instance.primaryFocus!.context!
              .findAncestorWidgetOfExactType<GeoMap>(),
          isNotNull,
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      } else {
        expect(
          tester
              .getSemantics(
                find.bySemanticsLabel(
                  'Mappa. Attiva per selezionare il centro.',
                ),
              )
              .getSemanticsData()
              .hint,
          'Per inserire coordinate precise, torna all’editor '
          'e scegli Coordinate.',
        );
        tester.semantics.tap(
          find.semantics.byLabel('Mappa. Attiva per selezionare il centro.'),
        );
      }
      await tester.pump();
      expect(
        tester.widget<GeoMap>(find.byType(GeoMap)).markers.single.point,
        initialCenter,
      );
      expect(state.selectedPoints, isEmpty);
      await tester.tap(
        find.byKey(const ValueKey('geo_map_location_picker_confirm')),
      );
      await tester.pumpAndSettle();
      expect(state.selectedPoints, [initialCenter]);
    });
  }

  testWidgets(
    'center selection wraps longitude after crossing the antimeridian',
    (tester) async {
      final (state, formKey) = await _pumpEditor(
        tester,
        latitude: '41',
        longitude: '179.999',
      );
      await tester.tap(find.text('Seleziona sulla mappa'));
      await tester.pumpAndSettle();
      final map = tester.widget<GeoMap>(find.byType(GeoMap));
      map.mapController!.move(const LatLng(41, 180.1), 13);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      final point = tester
          .widget<GeoMap>(find.byType(GeoMap))
          .markers
          .single
          .point;
      expect(point.longitude, closeTo(-179.9, 1e-10));
      await tester.tap(
        find.byKey(const ValueKey('geo_map_location_picker_confirm')),
      );
      await tester.pumpAndSettle();
      expect(state.longitudeText, '-179.900000');
      expect(formKey.currentState!.validate(), isTrue);
    },
  );

  testWidgets('resizing across compact preserves the temporary selection', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final (state, _) = await _pumpEditor(tester);
    await tester.tap(find.text('Seleziona sulla mappa'));
    await tester.pumpAndSettle();
    final controller = tester.widget<GeoMap>(find.byType(GeoMap)).mapController!
      ..move(const LatLng(41.8, 14.9), 11);
    await tester.pumpAndSettle();
    // Drive the real map gesture, rather than calling its callback.
    await tester.tapAt(
      tester.getCenter(find.byType(GeoMap)) + const Offset(30, 20),
    );
    await tester.pumpAndSettle();
    // flutter_map defers single taps while recognizing a possible double tap.
    await tester.pump(kDoubleTapTimeout);
    final point = tester
        .widget<GeoMap>(find.byType(GeoMap))
        .markers
        .single
        .point;
    for (final size in [const Size(390, 844), const Size(1280, 900)]) {
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(GeoMapLocationPicker)).width,
        size.width < 600 ? size.width : lessThanOrEqualTo(840),
      );
      expect(
        tester.widget<GeoMap>(find.byType(GeoMap)).markers.single.point,
        point,
      );
      expect(controller.camera.center, const LatLng(41.8, 14.9));
      expect(controller.camera.zoom, 11);
      expect(state.selectedPoints, isEmpty);
    }
    await tester.tap(
      find.byKey(const ValueKey('geo_map_location_picker_confirm')),
    );
    await tester.pumpAndSettle();
    expect(state.selectedPoints, [point]);
  });

  testWidgets('repeated explicit Back cannot pop the owning page', (
    tester,
  ) async {
    final (state, _) = await _pumpEditor(tester);
    await tester.tap(find.text('Seleziona sulla mappa'));
    await tester.pumpAndSettle();
    final back = tester
        .widget<CustomBackButton>(
          find.byKey(const ValueKey('geo_map_location_picker_back')),
        )
        .onPressed!;
    back();
    back();
    await tester.pumpAndSettle();
    expect(find.byType(AdminSubmissionLocationEditor), findsOneWidget);
    expect(state.selectedPoints, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact picker uses a fullscreen dialog', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    await _pumpEditor(tester);
    await tester.tap(find.text('Seleziona sulla mappa'));
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byType(GeoMapLocationPicker)),
      const Size(390, 844),
    );
    tester.view.padding = const FakeViewPadding(
      top: 24,
      bottom: 24,
      left: 20,
      right: 20,
    );
    await tester.pumpAndSettle();
    final back = tester.getRect(
      find.byKey(const ValueKey('geo_map_location_picker_back')),
    );
    final confirm = tester.getRect(
      find.byKey(const ValueKey('geo_map_location_picker_confirm')),
    );
    expect(back.left, greaterThanOrEqualTo(20));
    expect(back.top, greaterThanOrEqualTo(24));
    expect(confirm.right, lessThanOrEqualTo(370));
    expect(confirm.bottom, lessThanOrEqualTo(820));
  });

  testWidgets('expanded picker remains constrained', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 900);
    addTearDown(tester.view.reset);

    await _pumpEditor(tester);
    await tester.tap(find.text('Seleziona sulla mappa'));
    await tester.pumpAndSettle();

    // Dialog's outer render box fills the viewport; the map content is
    // constrained by the inner dialog surface.
    final size = tester.getSize(find.byType(GeoMapLocationPicker));
    expect(size.width, lessThanOrEqualTo(840));
    expect(size.height, lessThanOrEqualTo(720));
    expect(size.width, lessThan(1280));
  });

  for (final size in [
    const Size(390, 844),
    const Size(568, 320),
    const Size(600, 300),
    const Size(700, 360),
    const Size(1000, 800),
    const Size(1440, 900),
    const Size(1800, 1000),
  ]) {
    testWidgets('picker controls remain reachable with large text at $size', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = 3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _pumpEditor(
        tester,
        latitude: '41.5575078',
        longitude: '14.6485406',
        brightness: size.width >= 1000 ? Brightness.dark : Brightness.light,
      );
      await tester.ensureVisible(find.text('Seleziona sulla mappa'));
      await tester.tap(find.text('Seleziona sulla mappa'));
      await tester.pumpAndSettle();
      final confirm = find.byKey(
        const ValueKey('geo_map_location_picker_confirm'),
      );
      await tester.ensureVisible(confirm);
      expect(confirm.hitTestable(), findsOneWidget);
      expect(tester.getSize(find.byType(GeoMap)).height, greaterThan(0));
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(find.byType(GeoMapLocationPicker), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('editor unmounts without framework errors', (tester) async {
    await _pumpEditor(tester);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
