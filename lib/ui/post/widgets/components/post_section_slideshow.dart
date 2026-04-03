import 'package:flutter/material.dart';
import 'package:moliseis/data/sources/media.dart';
import 'package:moliseis/ui/post/widgets/components/post_media_slideshow.dart';

/// Encapsulates the post media slideshow with optional overlay controls.
///
/// Provides a reusable slideshow section that can display media with
/// optional overlay widgets (e.g., drag handle, close button in modals).
/// Handles visibility state changes through a [ValueNotifier] to coordinate
/// autoplay behavior.
class PostSectionSlideshow extends StatelessWidget {
  const PostSectionSlideshow({
    super.key,
    required this.height,
    required this.media,
    required this.visibilityNotifier,
    this.overlayBuilder,
  });

  final double height;
  final List<Media> media;
  final ValueNotifier<bool> visibilityNotifier;

  /// Optional builder to layer controls (e.g., drag handle, close button)
  /// over the slideshow.
  ///
  /// If provided, the slideshow will be placed in a [Stack] with the
  /// overlay widgets positioned on top. Used for modal-specific UI.
  final Widget Function(BuildContext context)? overlayBuilder;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: AnimatedBuilder(
        animation: visibilityNotifier,
        builder: (context, child) {
          final slideshow = PostMediaSlideshow(
            height: height,
            media: media,
            visibilityNotifier: visibilityNotifier,
          );

          // If overlay is provided (e.g., for modal), stack it on top.
          if (overlayBuilder != null) {
            return Stack(
              children: <Widget>[slideshow, overlayBuilder!(context)],
            );
          }

          return slideshow;
        },
      ),
    );
  }
}
