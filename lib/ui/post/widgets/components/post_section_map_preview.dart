import 'package:flutter_map/flutter_map.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/ui/core/themes/text_styles.dart';
import 'package:moliseis/ui/geo_map/widgets/components/map_attribution.dart';
import 'package:moliseis/ui/geo_map/widgets/geo_map.dart';
import 'package:moliseis/ui/geo_map/widgets/geo_map_marker.dart';
import 'package:moliseis/utils/extensions/extensions.dart';

/// Displays a map preview section with header and open map button.
///
/// Provides a reusable section for displaying a map preview of the
/// content location along with a button to navigate to the full map view.
class PostSectionMapPreview extends StatelessWidget {
  const PostSectionMapPreview({
    required this.content,
    required this.onMapPressed,
    super.key,
  });

  final ContentBase content;
  final VoidCallback onMapPressed;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 16),
      sliver: SliverList.list(
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            spacing: 16,
            children: [Text('Mappa', style: AppTextStyles.section(context))],
          ),
          const SizedBox(height: 8),
          Stack(
            children: [
              SizedBox(
                height: 400,
                child: ClipRRect(
                  borderRadius: context.appShapes.circular.cornerExtraLarge,
                  child: Stack(
                    children: <Widget>[
                      IgnorePointer(
                        child: GeoMap(
                          initialCenter: content.coordinates,
                          initialZoom: 16,
                          markers: <Marker>[generateMapMarker(content)],
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: MapAttribution(),
                      ),
                      Positioned(
                        top: 16,
                        right: 16,
                        child: IconButton.filledTonal(
                          onPressed: onMapPressed,
                          tooltip: 'Allarga mappa',
                          icon: const Icon(Symbols.expand_content),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
