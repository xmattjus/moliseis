import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' show TapPosition;
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:moliseis/ui/admin/submissions/widgets/admin_submission_location_editor.dart';
import 'package:moliseis/ui/geo_map/widgets/geo_map.dart';

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
}) async {
  final formKey = GlobalKey<FormState>();
  final harnessKey = GlobalKey<_HarnessState>();
  await tester.pumpWidget(
    MaterialApp(
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
  );
  await tester.pumpAndSettle();
  return (harnessKey.currentState!, formKey);
}

void main() {
  testWidgets('defaults to Map mode and renders GeoMap', (tester) async {
    await _pumpEditor(tester);

    expect(find.byType(GeoMap), findsOneWidget);
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

    formKey.currentState!.validate();
    await tester.pump();

    expect(find.text('Inserisci anche la longitudine.'), findsOneWidget);
  });

  testWidgets('no coordinates render no marker', (tester) async {
    await _pumpEditor(tester);

    expect(tester.widget<GeoMap>(find.byType(GeoMap)).markers, isEmpty);
  });

  testWidgets('existing coordinates render a marker at the loaded point and '
      'hydrate the manual fields', (tester) async {
    final (_, _) = await _pumpEditor(
      tester,
      latitude: '41.5575078',
      longitude: '14.6485406',
    );

    final geoMap = tester.widget<GeoMap>(find.byType(GeoMap));
    expect(geoMap.markers, hasLength(1));
    expect(geoMap.markers.single.point, const LatLng(41.5575078, 14.6485406));

    // The fields are mounted but hidden inside Offstage in Map mode.
    final fields = tester.widgetList<TextFormField>(
      find.byType(TextFormField, skipOffstage: false),
    );
    expect(fields.first.controller!.text, '41.5575078');
    expect(fields.last.controller!.text, '14.6485406');
  });

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
    await tester.enterText(
      find.byType(TextFormField).first,
      '41,55',
    );
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

  testWidgets('map tap invokes the paired coordinate callback and updates '
      'both manual field texts', (tester) async {
    final (state, _) = await _pumpEditor(tester);

    tester.widget<GeoMap>(find.byType(GeoMap)).onPressed!(
      const TapPosition(Offset.zero, Offset.zero),
      const LatLng(41.9, 14.9),
    );
    await tester.pumpAndSettle();

    expect(state.selectedPoints, const <LatLng>[LatLng(41.9, 14.9)]);
    expect(state.latitudeText, '41.900000');
    expect(state.longitudeText, '14.900000');

    // Reveal the hidden fields through Coordinate mode.
    await tester.tap(find.text('Coordinate'));
    await tester.pumpAndSettle();
    final fields = tester.widgetList<TextFormField>(
      find.byType(TextFormField),
    );
    expect(fields.first.controller!.text, '41.900000');
    expect(fields.last.controller!.text, '14.900000');
  });

  testWidgets('a second map tap replaces the first selected point', (
    tester,
  ) async {
    final (state, _) = await _pumpEditor(tester);
    final geoMap = tester.widget<GeoMap>(find.byType(GeoMap));

    geoMap.onPressed!(
      const TapPosition(Offset.zero, Offset.zero),
      const LatLng(41.9, 14.9),
    );
    await tester.pumpAndSettle();
    tester.widget<GeoMap>(find.byType(GeoMap)).onPressed!(
      const TapPosition(Offset.zero, Offset.zero),
      const LatLng(41.1, 14.2),
    );
    await tester.pumpAndSettle();

    expect(state.selectedPoints, hasLength(2));
    expect(state.selectedPoints.last, const LatLng(41.1, 14.2));
    expect(state.latitudeText, '41.100000');
    expect(state.longitudeText, '14.200000');
    expect(
      tester.widget<GeoMap>(find.byType(GeoMap)).markers.single.point,
      const LatLng(41.1, 14.2),
    );
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

  testWidgets(
    'out-of-range hydration opens in Coordinate mode and switching to Map '
    'mode falls back safely without a marker',
    (tester) async {
      await _pumpEditor(tester, latitude: '95', longitude: '200');

      // Startup classification treats out-of-range drafts as malformed, so
      // the editor opens in Coordinate mode with the problem visible.
      expect(find.byType(GeoMap), findsNothing);
      expect(find.byType(TextFormField), findsNWidgets(2));

      // Map safety: the range-invalid pair must never reach map geometry.
      await tester.tap(find.text('Mappa'));
      await tester.pumpAndSettle();

      final geoMap = tester.widget<GeoMap>(find.byType(GeoMap));
      // Mirrors the private _fallbackCenter constant.
      expect(geoMap.initialCenter, const LatLng(41.5575078, 14.6485406));
      expect(geoMap.markers, isEmpty);
      expect(find.text('Coordinate non valide'), findsOneWidget);
    },
  );

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
    expect(find.byType(GeoMap), findsOneWidget);
  });

  testWidgets('controllers are disposed without leaks', (tester) async {
    await _pumpEditor(tester);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
