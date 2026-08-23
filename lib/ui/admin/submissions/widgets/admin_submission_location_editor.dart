import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' show Marker;
import 'package:latlong2/latlong.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:moliseis/ui/geo_map/widgets/geo_map.dart';

/// The display representation selected inside the location editor.
enum _LocationMode {
  mappa,
  coordinate,
}

/// Fallback center used when the current drafts hold no valid point.
///
/// Kept local on purpose; there is no shared fallback-center constant.
const LatLng _fallbackCenter = LatLng(41.5575078, 14.6485406);

/// Parses one trimmed coordinate draft with narrow decimal-comma support.
///
/// Returns `null` for blank input or any invalid value; callers distinguish
/// blankness themselves.
double? _tryParseCoordinate(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  if (','.allMatches(trimmed).length > 1) return null;
  final value = double.tryParse(trimmed.replaceFirst(',', '.'));
  if (value == null || !value.isFinite) return null;
  return value;
}

/// Admin-only editor for a submission's optional geographical coordinates.
///
/// The interactive map and the manual latitude/longitude fields are two
/// representations of the same draft owned by the view model. Values and
/// callbacks only, mirroring the shared `ContentSubmissionFields` convention.
class AdminSubmissionLocationEditor extends StatefulWidget {
  /// Creates a location editor bound to the screen-owned [formKey].
  const AdminSubmissionLocationEditor({
    required this.latitudeText,
    required this.longitudeText,
    required this.onLatitudeTextChanged,
    required this.onLongitudeTextChanged,
    required this.onMapCoordinatesSelected,
    required this.formKey,
    super.key,
  });

  /// Raw latitude draft from the view model.
  final String latitudeText;

  /// Raw longitude draft from the view model.
  final String longitudeText;

  /// Called when the manual latitude text changes.
  final ValueChanged<String> onLatitudeTextChanged;

  /// Called when the manual longitude text changes.
  final ValueChanged<String> onLongitudeTextChanged;

  /// Called with the tapped map point, replacing any previous selection.
  final void Function(double latitude, double longitude)
  onMapCoordinatesSelected;

  /// Screen-owned key of the always-mounted location [Form], so Save can
  /// validate from every display mode.
  final GlobalKey<FormState> formKey;

  @override
  State<AdminSubmissionLocationEditor> createState() =>
      _AdminSubmissionLocationEditorState();
}

class _AdminSubmissionLocationEditorState
    extends State<AdminSubmissionLocationEditor> {
  late final TextEditingController _latitudeController;
  late final TextEditingController _longitudeController;
  late final GlobalKey<FormFieldState<String>> _latitudeFieldKey;
  late final GlobalKey<FormFieldState<String>> _longitudeFieldKey;
  late String _lastEmittedLatitude;
  late String _lastEmittedLongitude;
  late _LocationMode _mode;

  @override
  void initState() {
    super.initState();
    _latitudeController = TextEditingController(text: widget.latitudeText);
    _longitudeController = TextEditingController(text: widget.longitudeText);
    _latitudeFieldKey = GlobalKey<FormFieldState<String>>();
    _longitudeFieldKey = GlobalKey<FormFieldState<String>>();
    _lastEmittedLatitude = widget.latitudeText;
    _lastEmittedLongitude = widget.longitudeText;
    // Startup rule: blank or valid drafts start in Map mode; malformed drafts
    // (half-pair, unparsable, out-of-range) open in Coordinate mode so the
    // problem is visible without interaction.
    _mode = _classifyDrafts(
      widget.latitudeText,
      widget.longitudeText,
    );
  }

  @override
  void didUpdateWidget(AdminSubmissionLocationEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Echo-guard sync: overwrite a controller only when the incoming prop was
    // not already mirrored in its text AND was not emitted by this widget's
    // manual callbacks. Note _lastEmitted* records only manual emissions and
    // deliberately goes stale after a map-driven overwrite (map picks bypass
    // onChanged), so the text-mismatch conjunct is what keeps the guard
    // complete; never react to our own echo.
    if (widget.latitudeText != _lastEmittedLatitude &&
        widget.latitudeText != _latitudeController.text) {
      _latitudeController.text = widget.latitudeText;
    }
    if (widget.longitudeText != _lastEmittedLongitude &&
        widget.longitudeText != _longitudeController.text) {
      _longitudeController.text = widget.longitudeText;
    }
  }

  @override
  void dispose() {
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  void _handleModeChanged(_LocationMode mode) {
    setState(() => _mode = mode);
    if (mode == _LocationMode.mappa) {
      // The fields stay mounted inside Offstage, so an active focus would
      // survive invisibly; drop it explicitly when leaving Coordinate mode.
      FocusScope.of(context).unfocus();
    }
  }

  void _handleLatitudeChanged(String value) {
    _lastEmittedLatitude = value;
    widget.onLatitudeTextChanged(value);
    _longitudeFieldKey.currentState?.validate();
  }

  void _handleLongitudeChanged(String value) {
    _lastEmittedLongitude = value;
    widget.onLongitudeTextChanged(value);
    _latitudeFieldKey.currentState?.validate();
  }

  /// Parses both drafts into a coordinate pair valid on the map.
  ///
  /// Returns `null` unless both sides parse and sit inside their bounds
  /// (latitude ±90, longitude ±180). This mirrors the save-boundary ranges so
  /// map geometry is never built from an out-of-range legacy row: Web-Mercator
  /// projection is undefined outside those bounds.
  static (double, double)? _parseRangedPair(
    String latitudeText,
    String longitudeText,
  ) {
    final latitude = _tryParseCoordinate(latitudeText);
    final longitude = _tryParseCoordinate(longitudeText);
    if (latitude == null || longitude == null) return null;
    if (latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      return null;
    }
    return (latitude, longitude);
  }

  static _LocationMode _classifyDrafts(
    String latitudeText,
    String longitudeText,
  ) {
    final bothBlank =
        latitudeText.trim().isEmpty && longitudeText.trim().isEmpty;
    return (bothBlank || _parseRangedPair(latitudeText, longitudeText) != null)
        ? _LocationMode.mappa
        : _LocationMode.coordinate;
  }

  bool get _hasValidDraft =>
      _classifyDrafts(
        _latitudeController.text,
        _longitudeController.text,
      ) ==
      _LocationMode.mappa;

  /// Map center from a range-valid draft pair, else [_fallbackCenter].
  LatLng get _mapCenter {
    final pair = _parseRangedPair(
      _latitudeController.text,
      _longitudeController.text,
    );
    if (pair == null) return _fallbackCenter;
    return LatLng(pair.$1, pair.$2);
  }

  String? _validateLatitude(String? value) {
    final text = value ?? '';
    if (text.trim().isEmpty) return null;
    final siblingTrimmed = _longitudeController.text.trim();
    if (siblingTrimmed.isEmpty) return 'Inserisci anche la longitudine.';
    final parsed = _tryParseCoordinate(text);
    if (parsed == null) return 'Valore non valido.';
    if (parsed < -90 || parsed > 90) {
      return 'La latitudine deve essere tra -90 e 90.';
    }
    return null;
  }

  String? _validateLongitude(String? value) {
    final text = value ?? '';
    if (text.trim().isEmpty) return null;
    final siblingTrimmed = _latitudeController.text.trim();
    if (siblingTrimmed.isEmpty) return 'Inserisci anche la latitudine.';
    final parsed = _tryParseCoordinate(text);
    if (parsed == null) return 'Valore non valido.';
    if (parsed < -180 || parsed > 180) {
      return 'La longitudine deve essere tra -180 e 180.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final selectionPair = _parseRangedPair(
      _latitudeController.text,
      _longitudeController.text,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: <Widget>[
        SegmentedButton<_LocationMode>(
          segments: const <ButtonSegment<_LocationMode>>[
            ButtonSegment<_LocationMode>(
              value: _LocationMode.mappa,
              label: Text('Mappa'),
              icon: Icon(Symbols.map),
            ),
            ButtonSegment<_LocationMode>(
              value: _LocationMode.coordinate,
              label: Text('Coordinate'),
              icon: Icon(Symbols.pin_drop),
            ),
          ],
          selected: <_LocationMode>{_mode},
          onSelectionChanged: (selection) =>
              _handleModeChanged(selection.first),
        ),
        // Compact visible hint so a blocked Save is never silent while Map
        // mode hides the invalid fields.
        if (_mode == _LocationMode.mappa && !_hasValidDraft)
          Text(
            'Coordinate non valide',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        // The Form stays mounted in every display mode so the screen-owned
        // formKey can validate from Map mode too; only its visibility hides.
        Form(
          key: widget.formKey,
          child: Offstage(
            offstage: _mode == _LocationMode.mappa,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: <Widget>[
                TextFormField(
                  key: _latitudeFieldKey,
                  controller: _latitudeController,
                  decoration: const InputDecoration(
                    labelText: 'Latitudine',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    signed: true,
                    decimal: true,
                  ),
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: _validateLatitude,
                  onChanged: _handleLatitudeChanged,
                ),
                TextFormField(
                  key: _longitudeFieldKey,
                  controller: _longitudeController,
                  decoration: const InputDecoration(
                    labelText: 'Longitudine',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    signed: true,
                    decimal: true,
                  ),
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: _validateLongitude,
                  onChanged: _handleLongitudeChanged,
                ),
              ],
            ),
          ),
        ),
        // Only the map branch is conditional: each entry into Map mode
        // rebuilds GeoMap and re-centers via initialCenter.
        if (_mode == _LocationMode.mappa) ...<Widget>[
          SizedBox(
            height: 280,
            width: double.infinity,
            child: GeoMap(
              initialCenter: _mapCenter,
              markers: selectionPair == null
                  ? const <Marker>[]
                  : <Marker>[
                      Marker(
                        point: LatLng(selectionPair.$1, selectionPair.$2),
                        width: 40,
                        height: 40,
                        child: const Icon(
                          Symbols.location_pin,
                          size: 32,
                          fill: 1,
                        ),
                      ),
                    ],
              onPressed: (_, point) => widget.onMapCoordinatesSelected(
                point.latitude,
                point.longitude,
              ),
            ),
          ),
          const Text('Tocca la mappa per impostare la posizione.'),
        ],
      ],
    );
  }
}
