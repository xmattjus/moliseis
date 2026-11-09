import 'package:flutter_map/flutter_map.dart' show Marker;
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

/// Opens a location picker on the current navigator as a modal route.
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
      final picker = GeoMapLocationPicker(initialLocation: initialLocation);
      return SentryMask(
        dialogContext.windowSizeClass.isCompact
            ? Dialog.fullscreen(child: picker)
            : Dialog(
                constraints: const BoxConstraints(
                  maxWidth: 840,
                  maxHeight: 720,
                ),
                insetPadding: const EdgeInsets.all(24),
                clipBehavior: Clip.antiAlias,
                child: SizedBox(width: 840, height: 720, child: picker),
              ),
      );
    },
  );
}

/// Map-only selection UI shared by administrative and public submission flows.
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
  late LatLng? _selected = widget.initialLocation;

  void _confirm() {
    final point = _selected;
    if (point == null) return;
    Navigator.of(context).pop(point);
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    return Column(
      children: [
        SafeArea(
          bottom: false,
          child: Row(
            children: [
              CustomBackButton(
                key: const ValueKey('geo_map_location_picker_back'),
                onPressed: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: Text(
                  'Seleziona posizione',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.titleLarge,
                ),
              ),
              const SizedBox(width: 16),
            ],
          ),
        ),
        Expanded(
          child: GeoMap(
            initialCenter: widget.initialLocation ?? _fallbackCenter,
            initialZoom: widget.initialLocation == null ? 9 : 13,
            markers: selected == null
                ? const <Marker>[]
                : <Marker>[
                    Marker(
                      point: selected,
                      width: 60,
                      height: 60,
                      child: const GeoMapMarkerIcon(
                        Symbols.check,
                        size: 60,
                        tooltip: 'Posizione selezionata',
                      ),
                    ),
                  ],
            onPressed: (_, point) => setState(() => _selected = point),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  selected == null
                      ? 'Tocca la mappa per scegliere una posizione.'
                      : 'Lat. ${selected.latitude.toStringAsFixed(6)} · '
                            'Lon. ${selected.longitude.toStringAsFixed(6)}',
                  style: context.textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                FilledButton(
                  key: const ValueKey('geo_map_location_picker_confirm'),
                  onPressed: selected == null ? null : _confirm,
                  child: const Text('Usa questa posizione'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
