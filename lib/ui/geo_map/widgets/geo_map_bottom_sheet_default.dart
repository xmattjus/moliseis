/*
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:moliseis/domain/models/core/content_base.dart';
import 'package:moliseis/ui/core/ui/bottom_sheet_adaptive_title.dart';

class GeoMapBottomSheetDefault extends StatelessWidget {
  const GeoMapBottomSheetDefault({
    required this.currentMapCenter,
    required this.onNearContentPressed,
  });

  /// The current map center.
  final LatLng currentMapCenter;

  /// Returns the [Place] Id that has been tapped on.
  final void Function(ContentBase content) onNearContentPressed;

  @override
  Widget build(BuildContext context) {
    return SliverList.list(
      children: <Widget>[
        const BottomSheetAdaptiveTitle('Esplora i dintorni'),
        /*
        NearbyContentHorizontalList(
          coordinates: <double>[
            currentMapCenter.latitude,
            currentMapCenter.longitude,
          ],
          onPressed: onNearContentPressed,
        ),
        */
      ],
    );
  }
}
*/
