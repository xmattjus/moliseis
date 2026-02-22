import 'package:flutter/widgets.dart';
import 'package:latlong2/latlong.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/ui/core/ui/app_bottom_sheet_title.dart';
import 'package:moliseis/ui/core/ui/content/nearby_content_horizontal_list.dart';
import 'package:moliseis/ui/geo_map/view_models/geo_map_view_model.dart';

class GeoMapBottomSheetDefault extends StatelessWidget {
  const GeoMapBottomSheetDefault({
    required this.currentMapCenter,
    required this.onNearContentPressed,
    required this.viewModel,
  });

  /// The current map center.
  final LatLng currentMapCenter;

  /// Returns the [Place] Id that has been tapped on.
  final void Function(ContentBase content) onNearContentPressed;

  final GeoMapViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return SliverList.list(
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: AppBottomSheetTitle(title: 'Esplora i dintorni', icon: null),
        ),
        const SizedBox(height: 16.0),
        NearbyContentHorizontalList(
          coordinates: currentMapCenter,
          onPressed: onNearContentPressed,
          loadNearContentCommand: viewModel.loadNearContent,
          nearContent: viewModel.nearContent,
        ),
      ],
    );
  }
}
