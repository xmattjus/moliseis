part of 'geo_map_bottom_sheet.dart';

class _GeoMapBottomSheetDefault extends StatelessWidget {
  const _GeoMapBottomSheetDefault({
    required this.currentMapCenter,
    required this.onNearAttractionTap,
  });

  /// The current map center.
  final LatLng currentMapCenter;

  /// Returns the [Attraction] Id that has been tapped on.
  final void Function(int attractiondId) onNearAttractionTap;

  @override
  Widget build(BuildContext context) {
    return SliverList.list(
      children: <Widget>[
        Align(
          alignment: Platform.isIOS ? Alignment.center : Alignment.topLeft,
          child: Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              Platform.isIOS ? 72.0 : 16.0,
              18.0,
              Platform.isIOS ? 72.0 : 16.0,
              16.0,
            ),
            child: Text(
              'Esplora i dintorni',
              style: CustomTextStyles.title(context),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        NearAttractionsList(
          coordinates: <double>[
            currentMapCenter.latitude,
            currentMapCenter.longitude,
          ],
          onPressed: onNearAttractionTap,
        ),
      ],
    );
  }
}
