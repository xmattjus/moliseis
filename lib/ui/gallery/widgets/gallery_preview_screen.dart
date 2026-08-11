import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:moliseis/domain/models/media.dart';
import 'package:moliseis/routing/route_names.dart';
import 'package:moliseis/ui/core/ui/media/app_network_image.dart';
import 'package:moliseis/ui/gallery/models/gallery_preview_route_data.dart';
import 'package:moliseis/ui/gallery/widgets/gallery_preview_modal_overlay.dart';
import 'package:swipe_image_gallery/widget/gallery.dart';

/// Full-screen, route-owned image gallery.
///
/// Hosted on a standard opaque [MaterialPage] via the router's `builder:`
/// callback (see `lib/routing/router.dart`). [MaterialPage] is always opaque,
/// so routes beneath this page are never painted even though the inner
/// [Scaffold] uses `Colors.transparent` below. The transparent Scaffold lets
/// the only background paint come from the `swipe_image_gallery` `Gallery`
/// widget, whose black container fades with the in-app drag.
///
/// Two distinct drag behaviors are handled by different layers:
///
/// * **In-app vertical drag-to-dismiss** — owned by the `Gallery` widget
///   (`dragEnabled: true`, `setBackgroundOpacity`), which fades only its own
///   background. The route does not animate, and because [MaterialPage] is
///   opaque the source route is *not* revealed behind the gallery. This is
///   the gesture described here.
///
/// * **Android predictive-back** — owned by [MaterialPage]'s transition. The
///   route itself slides and scales per the platform page transition, so the
///   source route *is* revealed by design during the gesture. See
///   `test/routing/gallery_route_test.dart` for the assertions that pin this
///   behavior.
///
/// This route intentionally avoids the `CustomTransitionPage(opaque: false)`
/// fade pattern described in `.agents/skills/molise-is-go-router-navigator`:
/// the in-app drag would otherwise show the source route through the fading
/// background.
class GalleryPreviewScreen extends StatefulWidget {
  const GalleryPreviewScreen({required this.data, super.key});

  /// Serializable media and initial-page data for this route.
  final GalleryPreviewRouteData data;

  /// Pushes the gallery as a managed root GoRouter route.
  ///
  /// Throws an [ArgumentError] or [RangeError] when the input cannot describe
  /// a valid gallery.
  static Future<void> show({
    required BuildContext context,
    required List<Media> media,
    required int initialIndex,
  }) {
    final data = GalleryPreviewRouteData(
      media: media,
      initialIndex: initialIndex,
    );

    return context.pushNamed<void>(
      RouteNames.gallery,
      extra: data.toExtra(),
    );
  }

  @override
  State<GalleryPreviewScreen> createState() => _GalleryPreviewScreenState();
}

class _GalleryPreviewScreenState extends State<GalleryPreviewScreen>
    with RestorationMixin<GalleryPreviewScreen> {
  late final RestorableInt _index;
  PageController? _pageController;
  var _backgroundOpacity = 1.0;
  var _showOverlay = true;

  @override
  String? get restorationId => 'galleryPreview';

  @override
  void initState() {
    super.initState();
    _index = RestorableInt(widget.data.initialIndex);
  }

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    registerForRestoration(_index, 'index');

    final controller = _pageController;
    if (controller == null) {
      // restoreState runs before the initial build, so this controller starts
      // on the restored page instead of the route's original initial index.
      _pageController = PageController(initialPage: _index.value);
      return;
    }

    final restoredIndex = _index.value;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && controller.hasClients) {
        controller.jumpToPage(restoredIndex);
      }
    });
  }

  @override
  void dispose() {
    _pageController?.dispose();
    _index.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Transparent so the `Gallery` widget's fading black container is the
      // only background layer; route opacity is controlled by the outer
      // MaterialPage (see class doc).
      backgroundColor: Colors.transparent,
      body: Stack(
        children: <Widget>[
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _showOverlay = !_showOverlay),
            child: Gallery(
              controller: _pageController!,
              initialIndex: _index.value,
              itemCount: widget.data.media.length,
              itemBuilder: (_, index) {
                final media = widget.data.media[index];
                return AppNetworkImage.fullResolution(
                  url: media.url,
                  imageWidth: media.width,
                  imageHeight: media.height,
                  fit: BoxFit.contain,
                );
              },
              onSwipe: (index) => setState(() => _index.value = index),
              dismissDragDistance: 160,
              scrollDirection: Axis.horizontal,
              backgroundColor: Colors.black,
              opacity: _backgroundOpacity,
              dragEnabled: true,
              panEnabled: true,
              zoomEnabled: true,
              setBackgroundOpacity: (opacity) {
                setState(() {
                  _backgroundOpacity = clampDouble(opacity, 0, 1);
                });
              },
              useSafeArea: false,
            ),
          ),
          IgnorePointer(
            key: const ValueKey('galleryPreviewOverlay'),
            ignoring: !_showOverlay,
            child: AnimatedOpacity(
              opacity: _showOverlay ? _backgroundOpacity : 0,
              duration: const Duration(milliseconds: 200),
              child: GalleryPreviewModalOverlay(
                media: widget.data.media[_index.value],
                index: _index.value,
                itemCount: widget.data.media.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fallback shown when an external gallery route has invalid data.
class GalleryUnavailableScreen extends StatelessWidget {
  const GalleryUnavailableScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Anteprima')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text('Anteprima non disponibile.'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                final didPop = await Navigator.of(context).maybePop();
                if (!didPop && context.mounted) {
                  context.goNamed(RouteNames.home);
                }
              },
              child: const Text('Torna indietro'),
            ),
          ],
        ),
      ),
    );
  }
}
