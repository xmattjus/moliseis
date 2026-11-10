import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_map/flutter_map.dart' show MapController, Marker;
import 'package:latlong2/latlong.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/ui/core/ui/custom_back_button.dart';
import 'package:moliseis/ui/geo_map/widgets/geo_map.dart';
import 'package:moliseis/ui/geo_map/widgets/geo_map_marker.dart';
import 'package:moliseis/utils/extensions/extensions.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// The initial map center is not a selection.
const LatLng _fallbackCenter = LatLng(41.5575078, 14.6485406);

/// Opens a location picker on the root navigator as a modal route.
///
/// Cancellation and system Back return null; only explicit confirmation
/// supplies a coordinate. Callers retain ownership of draft mutations.
Future<LatLng?> showGeoMapLocationPicker(
  BuildContext context, {
  LatLng? initialLocation,
}) {
  return showDialog<LatLng>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      final compact = dialogContext.windowSizeClass.isCompact;
      return SentryMask(
        Dialog(
          constraints: BoxConstraints(
            maxWidth: compact ? double.infinity : 840,
            maxHeight: compact ? double.infinity : 720,
          ),
          insetPadding: compact ? EdgeInsets.zero : const EdgeInsets.all(24),
          elevation: compact ? 0 : null,
          shape: compact ? const RoundedRectangleBorder() : null,
          backgroundColor: compact ? dialogContext.colorScheme.surface : null,
          clipBehavior: Clip.antiAlias,
          // Retain selection and camera across size-class changes.
          child: SizedBox.expand(
            child: GeoMapLocationPicker(initialLocation: initialLocation),
          ),
        ),
      );
    },
  );
}

/// Map-only location selection, currently used by the Admin editor.
///
/// The selection stays local to this route until confirmation; the owning
/// form retains its coordinate text, validation and persistence behavior.
class GeoMapLocationPicker extends StatefulWidget {
  const GeoMapLocationPicker({this.initialLocation, super.key});

  final LatLng? initialLocation;

  @override
  State<GeoMapLocationPicker> createState() => _GeoMapLocationPickerState();
}

class _GeoMapLocationPickerState extends State<GeoMapLocationPicker> {
  final _mapController = MapController();
  late LatLng? _selected = widget.initialLocation;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _select(LatLng point) {
    if (!mounted) return;
    setState(() => _selected = point);
  }

  void _selectCenter() {
    if (!mounted) return;
    _select(_mapController.camera.center);
  }

  void _dismiss([LatLng? point]) {
    if (!mounted) return;
    if (ModalRoute.of(context)?.isCurrent != true) return;
    Navigator.of(context).pop(point);
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): _dismiss},
      child: LayoutBuilder(
        builder: (context, constraints) => Column(
          children: [
            SafeArea(
              bottom: false,
              child: Row(
                children: [
                  CustomBackButton(
                    key: const ValueKey('geo_map_location_picker_back'),
                    onPressed: _dismiss,
                  ),
                  Expanded(
                    child: Semantics(
                      namesRoute: true,
                      header: true,
                      child: Text(
                        'Seleziona posizione',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textTheme.titleLarge,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
              ),
            ),
            Expanded(
              child: CallbackShortcuts(
                bindings: {
                  const SingleActivator(LogicalKeyboardKey.enter):
                      _selectCenter,
                  const SingleActivator(LogicalKeyboardKey.numpadEnter):
                      _selectCenter,
                },
                child: Semantics(
                  container: true,
                  excludeSemantics: true,
                  label: 'Mappa. Attiva per selezionare il centro.',
                  hint:
                      'Per inserire coordinate precise, torna all’editor '
                      'e scegli Coordinate.',
                  onTap: _selectCenter,
                  child: GeoMap(
                    mapController: _mapController,
                    initialCenter: widget.initialLocation ?? _fallbackCenter,
                    initialZoom: widget.initialLocation == null ? 9 : 13,
                    markers: selected == null
                        ? const <Marker>[]
                        : <Marker>[
                            Marker(
                              point: selected,
                              alignment: Alignment.topCenter,
                              width: 60,
                              height: 60,
                              child: const GeoMapMarkerIcon(
                                Symbols.check,
                                size: 60,
                                tooltip: 'Posizione selezionata',
                                style: ButtonStyle(
                                  padding: WidgetStatePropertyAll(
                                    EdgeInsets.zero,
                                  ),
                                  visualDensity: VisualDensity.standard,
                                ),
                              ),
                            ),
                          ],
                    onPressed: (_, point) => _select(point),
                  ),
                ),
              ),
            ),
            _LocationPickerActions(
              selected: selected,
              maxHeight: constraints.maxHeight / 2,
              onConfirm: selected == null ? null : () => _dismiss(selected),
            ),
          ],
        ),
      ),
    );
  }
}

/// Keeps confirmation reachable without letting large text displace the map.
class _LocationPickerActions extends StatelessWidget {
  const _LocationPickerActions({
    required this.selected,
    required this.maxHeight,
    required this.onConfirm,
  });

  final LatLng? selected;
  final double maxHeight;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(maxHeight: maxHeight),
    child: SingleChildScrollView(
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                liveRegion: true,
                child: Text(
                  selected == null
                      ? 'Tocca un punto sulla mappa. '
                            'Con Invio selezioni il centro.'
                      : 'Lat. ${selected!.latitude.toStringAsFixed(6)} · '
                            'Lon. ${selected!.longitude.toStringAsFixed(6)}',
                  style: context.textTheme.bodyMedium,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                key: const ValueKey('geo_map_location_picker_confirm'),
                onPressed: onConfirm,
                child: const Text('Usa questa posizione'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
