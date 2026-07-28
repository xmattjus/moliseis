import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/event.dart';
import 'package:moliseis/routing/route_names.dart';
import 'package:moliseis/routing/route_paths.dart';
import 'package:moliseis/ui/core/ui/custom_appbar.dart';
import 'package:moliseis/ui/core/ui/empty_view.dart';
import 'package:moliseis/ui/core/utils/slideshow_visibility_notifier.dart';
import 'package:moliseis/ui/post/view_models/post_view_model.dart';
import 'package:moliseis/ui/post/widgets/components/post_section_action_buttons.dart';
import 'package:moliseis/ui/post/widgets/components/post_section_description.dart';
import 'package:moliseis/ui/post/widgets/components/post_section_header.dart';
import 'package:moliseis/ui/post/widgets/components/post_section_map_preview.dart';
import 'package:moliseis/ui/post/widgets/components/post_section_nearby_content.dart';
import 'package:moliseis/ui/post/widgets/components/post_section_slideshow.dart';
import 'package:moliseis/ui/weather/view_models/weather_view_model.dart';
import 'package:moliseis/utils/extensions/extensions.dart';

const double _mediaSlideshowHeight = 450;

class PostScreen extends StatefulWidget {
  const PostScreen({
    required this.isEvent,
    required this.viewModel,
    required this.weatherViewModel,
    super.key,
  });

  final bool isEvent;
  final PostViewModel viewModel;
  final WeatherViewModel weatherViewModel;

  @override
  State<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends State<PostScreen> {
  String _currentUri = '';

  /// Controls [PopScope.canPop]. Exposed for test access via
  /// [ValueListenableBuilder.valueListenable].
  final ValueNotifier<bool> isGalleryOpenNotifier = ValueNotifier(false);

  final ScrollController _scrollController = ScrollController();
  late final SlideshowVisibilityNotifier _slideshowVisibilityNotifier =
      SlideshowVisibilityNotifier(threshold: _mediaSlideshowHeight * 0.6);

  @override
  void dispose() {
    isGalleryOpenNotifier.dispose();
    _slideshowVisibilityNotifier.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onGalleryOpened() {
    if (!mounted) return;
    isGalleryOpenNotifier.value = true;
  }

  void _onGalleryClosed() {
    if (!mounted) return;
    isGalleryOpenNotifier.value = false;
  }

  bool _onScrollNotification(ScrollNotification notification) {
    _slideshowVisibilityNotifier.updateVisibilityFromNotification(notification);

    // Returning false allows the notification to continue
    // bubbling up to ancestor listeners.
    return false;
  }

  @override
  Widget build(BuildContext context) {
    _currentUri = GoRouterState.of(context).fullPath.toString();

    return ValueListenableBuilder<bool>(
      key: const ValueKey('galleryPopScopeVlb'),
      valueListenable: isGalleryOpenNotifier,
      builder: (_, isGalleryOpen, child) {
        return PopScope(
          key: const ValueKey('galleryPopScope'),
          canPop: !isGalleryOpen,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) {
              unawaited(Navigator.of(context, rootNavigator: true).maybePop());
            }
          },
          child: child!,
        );
      },
      child: Scaffold(
        appBar: const CustomAppBar(
          showBackButton: true,
          systemOverlayStyle: SystemUiOverlayStyle.light,
        ),
        body: SafeArea(
          top: false,
          child: ListenableBuilder(
            listenable: Listenable.merge([
              widget.viewModel.loadEvent,
              widget.viewModel.loadPlace,
            ]),
            builder: (context, child) {
              if (widget.viewModel.loadEvent.completed ||
                  widget.viewModel.loadPlace.completed) {
                final content = widget.viewModel.content;

                return NotificationListener<ScrollNotification>(
                  onNotification: _onScrollNotification,
                  child: CustomScrollView(
                    controller: _scrollController,
                    slivers: <Widget>[
                      if (content.media.isNotEmpty)
                        PostSectionSlideshow(
                          height: _mediaSlideshowHeight,
                          media: content.media,
                          visibilityNotifier:
                              _slideshowVisibilityNotifier.notifier,
                          onGalleryOpened: _onGalleryOpened,
                          onGalleryClosed: _onGalleryClosed,
                        ),
                      PostSectionHeader(
                        content: content,
                        weatherViewModel: widget.weatherViewModel,
                      ),
                      PostSectionActionButtons(
                        content: content,
                        onCategoryPressed: () =>
                            _buildCategoriesRoute(content.category),
                      ),
                      PostSectionDescription(content: content),
                      PostSectionMapPreview(
                        content: content,
                        onMapPressed: () {
                          // A unique query parameter forces go_router to
                          // treat this as a fresh navigation update even
                          // when the destination route is already in stack.
                          context.goNamed(
                            RouteNames.geoMap,
                            queryParameters: {
                              'key': UniqueKey().toString(),
                            },
                            extra: content,
                          );
                        },
                      ),
                      PostSectionNearbyContent(
                        coordinates: content.coordinates,
                        onContentPressed: _buildPostRoute,
                        loadNearContentCommand:
                            widget.viewModel.loadNearContent,
                        nearContent: widget.viewModel.nearContent,
                      ),
                      SliverPadding(
                        padding: EdgeInsets.only(
                          bottom: context.bottomPadding,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return const Center(
                child: EmptyView.loading(
                  text: Text('Caricamento in corso...'),
                ),
              );
            },
          ),
        ),
        extendBodyBehindAppBar: true,
      ),
    );
  }

  @override
  void deactivate() {
    // Dismiss any orphaned gallery dialog on the root navigator when this
    // screen is deactivated (e.g., GoRouter removes the branch route while
    // the gallery is open, or the user switches shell tabs). The gallery uses
    // barrierDismissible: false and has no PopScope of its own, so without
    // this call the dialog would be permanently orphaned with no
    // user-accessible dismiss path.
    //
    // A push-behind regression (deactivate firing when another route is pushed
    // on top) is not a concern here: the gallery dialog is a fullscreen overlay
    // that physically blocks all PostScreen UI — no tap target can trigger a
    // push while the gallery is visible, so isGalleryOpenNotifier.value is
    // always false when a push-behind deactivation occurs in practice.
    // Tab-switch deactivations are similarly safe: the gallery overlay blocks
    // the tab bar, so the user cannot switch tabs while the gallery is open.
    if (isGalleryOpenNotifier.value) {
      unawaited(Navigator.of(context, rootNavigator: true).maybePop());
    }
    super.deactivate();
  }

  void _buildCategoriesRoute(ContentCategory category) {
    String? nextRouteName;

    if (_currentUri.startsWith(RoutePaths.favourites)) {
      nextRouteName = RouteNames.favouritesCategory;
    } else if (_currentUri.startsWith(RoutePaths.events)) {
      nextRouteName = RouteNames.eventsCategory;
    } else {
      nextRouteName = RouteNames.homeCategory;
    }

    GoRouter.of(context).goNamed(
      nextRouteName,
      pathParameters: {'index': (category.index - 1).toString()},
    );
  }

  void _buildPostRoute(ContentBase content) {
    String? nextRoute;
    var indexNecessary = false;

    if (_currentUri.startsWith('${RoutePaths.events}/category')) {
      nextRoute = RouteNames.eventsCategoryPost;
      indexNecessary = true;
    } else if (_currentUri.startsWith('${RoutePaths.favourites}/category')) {
      nextRoute = RouteNames.favouritesCategoryPost;
      indexNecessary = true;
    } else if (_currentUri.startsWith('${RoutePaths.home}/category')) {
      nextRoute = RouteNames.homeCategoryPost;
      indexNecessary = true;
    } else if (_currentUri.startsWith(RoutePaths.events)) {
      nextRoute = RouteNames.eventsPost;
    } else if (_currentUri.startsWith(RoutePaths.favourites)) {
      nextRoute = RouteNames.favouritesPost;
    } else if (_currentUri.startsWith(RoutePaths.home)) {
      nextRoute = RouteNames.homePost;
    }

    if (nextRoute != null) {
      final map = {'id': content.remoteId.toString()};

      if (indexNecessary) {
        map['index'] = (content.category.index - 1).toString();
      }

      unawaited(
        GoRouter.of(context).pushReplacementNamed(
          nextRoute,
          pathParameters: map,
          queryParameters: {'isEvent': (content is Event ? 'true' : 'false')},
        ),
      );
    }
  }
}
