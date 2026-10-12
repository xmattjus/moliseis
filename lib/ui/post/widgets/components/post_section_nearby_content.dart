import 'package:material_ui/material_ui.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/ui/core/ui/content/nearby_content_horizontal_list.dart';

/// Displays nearby content in a horizontal scrollable list.
///
/// Provides a reusable section for displaying content recommendations near
/// the current location, with customizable data source handling through
/// command and list parameters.
class PostSectionNearbyContent extends StatelessWidget {
  const PostSectionNearbyContent({
    required this.loadListenable,
    required this.loadKey,
    required this.onLoad,
    required this.readState,
    required this.onContentPressed,
    this.onRetry,
    super.key,
  });

  final Listenable loadListenable;
  final Object loadKey;
  final VoidCallback onLoad;
  final NearbyContentPresentation Function() readState;
  final VoidCallback? onRetry;
  final void Function(ContentBase content) onContentPressed;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: NearbyContentHorizontalList(
        loadListenable: loadListenable,
        loadKey: loadKey,
        onLoad: onLoad,
        readState: readState,
        onRetry: onRetry,
        onPressed: onContentPressed,
      ),
    );
  }
}
