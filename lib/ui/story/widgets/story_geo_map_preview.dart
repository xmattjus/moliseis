import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:moliseis/domain/models/attraction/attraction.dart';
import 'package:moliseis/ui/core/ui/cards/card_base.dart';
import 'package:moliseis/ui/geo_map/widgets/geo_map.dart';
import 'package:moliseis/ui/geo_map/widgets/geo_map_attribution.dart';
import 'package:moliseis/ui/geo_map/widgets/geo_map_marker.dart';

class StoryGeoMapPreview extends StatelessWidget {
  const StoryGeoMapPreview({required this.attraction});

  final Attraction attraction;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints.tightForFinite(height: 400.0),
      child: CardBase(
        child: Stack(
          children: <Widget>[
            IgnorePointer(
              child: GeoMap(
                initialCenter: LatLng(
                  attraction.coordinates[0],
                  attraction.coordinates[1],
                ),
                initialZoom: 16.0,
                markers: <Marker>[generateMapMarker(attraction)],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: GeoMapAttribution(),
            ),
          ],
        ),
      ),
    );
  }
}
