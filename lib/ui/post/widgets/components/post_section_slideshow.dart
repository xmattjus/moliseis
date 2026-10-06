import 'package:material_ui/material_ui.dart';
import 'package:moliseis/domain/models/media.dart';
import 'package:moliseis/ui/post/widgets/components/post_media_slideshow.dart';
import 'package:moliseis/utils/extensions/extensions.dart';

/// Encapsulates the post media slideshow with optional overlay controls.
///
/// Provides a reusable slideshow section that can display media with
/// optional overlay widgets (e.g., drag handle, close button in modals).
/// Handles visibility state changes through a [ValueNotifier] to coordinate
/// autoplay behavior.
class PostSectionSlideshow extends StatelessWidget {
  const PostSectionSlideshow({
    required this.height,
    required this.media,
    required this.visibilityNotifier,
    this.chromeColor,
    super.key,
  });

  final double height;
  final List<Media> media;
  final ValueNotifier<bool> visibilityNotifier;

  /// The color the slideshow bottom chrome will have.
  final Color? chromeColor;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: AnimatedBuilder(
          animation: visibilityNotifier,
          builder: (context, _) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(
              borderRadius: context.appShapes.circular.cornerExtraLarge,
              child: PostMediaSlideshow(
                height: height,
                media: media,
                visibilityNotifier: visibilityNotifier,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
