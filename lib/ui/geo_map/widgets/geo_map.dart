import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:moliseis/ui/geo_map/widgets/geo_map_tile_layer.dart';
import 'package:moliseis/utils/extensions/extensions.dart';

class GeoMap extends StatefulWidget {
  /// Creates an interactive geographical map with flutter_map.
  const GeoMap({
    super.key,
    this.mapController,
    required this.initialCenter,
    this.initialZoom,
    this.markers = const <Marker>[],
    this.children = const <Widget>[],
    this.onPressed,
    this.onPositionChangeStart,
    this.onPositionChangeEnd,
    this.onMapReady,
  });

  /// An optional controller that allows to interact with the map from other
  /// widgets.
  ///
  /// If this is null, one internal map controller is created automatically.
  final MapController? mapController;

  /// The center when the map is first loaded.
  final LatLng initialCenter;

  /// The zoom when the map is first loaded.
  final double? initialZoom;

  /// The list of [Marker]s.
  final List<Marker> markers;

  ///
  final List<Widget> children;

  /// The event which is fired when the map is tapped.
  final void Function(TapPosition tapPosition, LatLng point)? onPressed;

  /// The event which is fired when the map drag has started.
  ///
  /// Returns the current map center (coordinates) when the map drag has
  /// started.
  final void Function(LatLng center)? onPositionChangeStart;

  /// The event which is fired when the map drag has ended.
  ///
  /// Returns the current map center (coordinates) when the map drag has ended.
  final void Function(LatLng center)? onPositionChangeEnd;

  /// The event which if fired when the [GeoMap] has finished its internal
  /// initState().
  final void Function(LatLng center)? onMapReady;

  @override
  State<GeoMap> createState() => _GeoMapState();
}

class _GeoMapState extends State<GeoMap> {
  /// Creates an internal map controller if it has not been provided.
  MapController? _internalMapController;
  MapController get _mapController =>
      widget.mapController ?? (_internalMapController ??= MapController());

  @override
  void initState() {
    super.initState();

    /// Schedules a callback to be fired once when the build phase of this
    /// widget has ended.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onMapReady?.call(_mapController.camera.center);
    });
  }

  @override
  void dispose() {
    _internalMapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FlutterMap(
    mapController: _mapController,
    options: MapOptions(
      initialCenter: widget.initialCenter,
      initialZoom: widget.initialZoom ?? 13.0,
      minZoom: 9.0,
      maxZoom: 18.0,
      backgroundColor: context.isDarkTheme
          ? const Color(0xFF2E2E2E)
          : const Color(0xFFEAEADD),
      onMapEvent: (event) {
        if (event is MapEventMoveStart) {
          widget.onPositionChangeStart?.call(_mapController.camera.center);
        } else if (event is MapEventFlingAnimationEnd ||
            event is MapEventMoveEnd) {
          widget.onPositionChangeEnd?.call(_mapController.camera.center);
        }
      },
      onTap: widget.onPressed,
    ),
    children: <Widget>[
      const GeoMapTileLayer(),
      if (widget.markers.isNotEmpty) MarkerLayer(markers: widget.markers),
      ...widget.children,
    ],
  );
}
