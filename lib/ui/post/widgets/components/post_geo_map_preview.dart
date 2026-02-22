import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/ui/core/ui/cards/card_base.dart';
import 'package:moliseis/ui/geo_map/widgets/components/map_attribution.dart';
import 'package:moliseis/ui/geo_map/widgets/geo_map.dart';
import 'package:moliseis/ui/geo_map/widgets/geo_map_marker.dart';

class PostGeoMapPreview extends StatelessWidget {
  const PostGeoMapPreview({required this.content});

  final ContentBase content;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints.tightForFinite(height: 400.0),
      child: CardBase(
        child: Stack(
          children: <Widget>[
            IgnorePointer(
              child: GeoMap(
                initialCenter: content.coordinates,
                initialZoom: 16.0,
                markers: <Marker>[generateMapMarker(content)],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: MapAttribution(),
            ),
          ],
        ),
      ),
    );
  }
}
