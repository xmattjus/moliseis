import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/ui/geo_map/widgets/geo_map_marker_painter.dart';
import 'package:moliseis/utils/extensions/extensions.dart';

/// Generates a map marker with the given [ContentBase].
Marker generateMapMarker(ContentBase content, {void Function()? onPressed}) {
  return Marker(
    point: content.coordinates,
    width: 60.0,
    height: 60.0,
    child: _GeoMapMarkerIcon(
      content.category.icon,
      size: 60.0,
      onPressed: onPressed,
      tooltip: content.name,
    ),
  );
}

class _GeoMapMarkerIcon extends StatelessWidget {
  const _GeoMapMarkerIcon(
    this.icon, {
    required this.size,
    this.onPressed,
    this.tooltip,
  });

  final double size;
  final IconData? icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      visualDensity: const VisualDensity(horizontal: 0.5, vertical: 0.5),
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Stack(
        alignment: Alignment.topCenter,
        children: [
          CustomPaint(
            painter: const GeoMapMarkerPainter(color: Colors.red),
            size: Size(size * 0.45, size),
          ),
          Positioned(
            top: 5.0,
            child: Icon(
              icon,
              size: size * 0.30,
              fill: 1.0,
              weight: 500,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
