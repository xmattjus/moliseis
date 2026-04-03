import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/ui/core/themes/text_styles.dart';
import 'package:moliseis/ui/post/widgets/components/post_geo_map_preview.dart';

/// Displays a map preview section with header and open map button.
///
/// Provides a reusable section for displaying a map preview of the
/// content location along with a button to navigate to the full map view.
class PostSectionMapPreview extends StatelessWidget {
  const PostSectionMapPreview({
    super.key,
    required this.content,
    required this.onMapPressed,
  });

  final ContentBase content;
  final VoidCallback onMapPressed;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsetsDirectional.fromSTEB(16.0, 0, 16.0, 16.0),
      sliver: SliverList.list(
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            spacing: 16.0,
            children: [
              Text('Mappa', style: AppTextStyles.section(context)),
              OutlinedButton.icon(
                onPressed: onMapPressed,
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                icon: const Icon(Symbols.explore),
                label: const Text('Apri mappa'),
              ),
            ],
          ),
          const SizedBox(height: 8.0),
          PostGeoMapPreview(content: content),
        ],
      ),
    );
  }
}
