import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:moliseis/data/services/url_launch_service.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/event_content.dart';
import 'package:moliseis/domain/models/place_content.dart';
import 'package:moliseis/routing/route_names.dart';
import 'package:moliseis/routing/route_paths.dart';
import 'package:moliseis/ui/category/widgets/category_button.dart';
import 'package:moliseis/ui/core/themes/text_styles.dart';
import 'package:moliseis/ui/core/ui/content/nearby_content_horizontal_list.dart';
import 'package:moliseis/ui/core/ui/custom_appbar.dart';
import 'package:moliseis/ui/core/ui/custom_snack_bar.dart';
import 'package:moliseis/ui/core/ui/empty_view.dart';
import 'package:moliseis/ui/core/ui/horizontal_button_list.dart';
import 'package:moliseis/ui/core/ui/linear_gradient_background.dart';
import 'package:moliseis/ui/favourite/widgets/favourite_button.dart';
import 'package:moliseis/ui/post/view_models/post_view_model.dart';
import 'package:moliseis/ui/post/widgets/components/post_description.dart';
import 'package:moliseis/ui/post/widgets/components/post_geo_map_preview.dart';
import 'package:moliseis/ui/post/widgets/components/post_media_slideshow.dart';
import 'package:moliseis/ui/post/widgets/components/post_title.dart';
import 'package:moliseis/ui/weather/view_models/weather_view_model.dart';
import 'package:moliseis/ui/weather/widgets/weather_forecast_button.dart';
import 'package:moliseis/utils/constants.dart';
import 'package:moliseis/utils/extensions/extensions.dart';
import 'package:provider/provider.dart';

class PostScreen extends StatefulWidget {
  const PostScreen({
    super.key,
    required this.isEvent,
    required this.viewModel,
    required this.weatherViewModel,
  });

  final bool isEvent;
  final PostViewModel viewModel;
  final WeatherViewModel weatherViewModel;

  @override
  State<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends State<PostScreen> {
  final ScrollController _scrollController = ScrollController();

  String _currentUri = '';

  /// Notifies its listeners of slideshow autoplay state changes.
  final _slideshowValueNotifier = ValueNotifier<bool>(true);
  bool get _slideshowEnabled => _slideshowValueNotifier.value;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _currentUri = GoRouterState.of(context).fullPath.toString();

    final screenHeight = MediaQuery.sizeOf(context).height;

    final trigger =
        screenHeight *
        (context.isLandscape
            ? kStorySlideshowLandscapeHeightPerc - 0.2
            : kStorySlideshowPortraitHeightPerc - 0.2);

    return Scaffold(
      appBar: const CustomAppBar(
        showBackButton: true,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      body: Stack(
        children: <Widget>[
          SafeArea(
            top: false,

            child: ListenableBuilder(
              listenable: Listenable.merge([
                widget.viewModel.loadEvent,
                widget.viewModel.loadPlace,
              ]),
              builder: (context, child) {
                if (widget.viewModel.loadEvent.completed ||
                    widget.viewModel.loadPlace.completed) {
                  final content = widget.viewModel.content is EventContent
                      ? widget.viewModel.content as EventContent
                      : widget.viewModel.content as PlaceContent;

                  return NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      // Make sure to update the ValueNotifier only when needed.
                      if (_scrollController.position.pixels > trigger &&
                          _slideshowEnabled) {
                        _slideshowValueNotifier.value = false;
                      } else if (_scrollController.position.pixels <= trigger &&
                          !_slideshowEnabled) {
                        _slideshowValueNotifier.value = true;
                      }

                      // Returning false allows the notification to continue
                      // bubbling up to ancestor listeners.
                      return false;
                    },
                    child: CustomScrollView(
                      controller: _scrollController,
                      slivers: <Widget>[
                        SliverToBoxAdapter(
                          child: AnimatedBuilder(
                            animation: _slideshowValueNotifier,
                            builder: (context, child) {
                              return TickerMode(
                                enabled: _slideshowEnabled,
                                child: PostMediaSlideshow(
                                  images: content.media,
                                ),
                              );
                            },
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          sliver: SliverToBoxAdapter(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                PostTitle(content: content),
                                WeatherForecastButton(
                                  content: content,
                                  coordinates: content.coordinates,
                                  viewModel: widget.weatherViewModel,
                                ),
                              ],
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: HorizontalButtonList(
                            padding: const EdgeInsets.all(16.0),
                            items: <Widget>[
                              CategoryButton(
                                onPressed: () {
                                  _buildCategoriesRoute(content.category);
                                },
                                contentCategory: content.category,
                              ),
                              FavouriteButton.wide(content: content),
                              OutlinedButton.icon(
                                onPressed: () async {
                                  if (!await context
                                      .read<UrlLaunchService>()
                                      .openGoogleMaps(
                                        content.name,
                                        content.city.target?.name ?? 'Molise',
                                      )) {
                                    if (context.mounted) {
                                      showSnackBar(
                                        context: context,
                                        textContent:
                                            'Si è verificato un errore, riprova più tardi.',
                                      );
                                    }
                                  }
                                },
                                icon: const Icon(Symbols.directions),
                                label: const Text('Indicazioni'),
                              ),
                              /*
                            OutlinedButton.icon(
                              onPressed: () {
                                // TODO (xmattjus): share deep link to this screen.
                              },
                              icon: const Icon(Symbols.share),
                              label: const Text('Condividi'),
                            ),
                             */
                            ],
                          ),
                        ),
                        // SupplementaryInformation(viewModel: widget.viewModel),
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          sliver: PostDescription.sliver(content: content),
                        ),
                        _pad(
                          SliverList.list(
                            children: <Widget>[
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                spacing: 16.0,
                                children: [
                                  Text(
                                    'Mappa',
                                    style: AppTextStyles.section(context),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () {
                                      // Sets a [UniqueKey] so that go_router
                                      // can notify [mapState] changes to the next
                                      // route.
                                      //
                                      // Removing the [key] query parameter will
                                      // prevent state changes for the next route
                                      // if it is already present in the
                                      // navigation stack.
                                      context.goNamed(
                                        RouteNames.geoMap,
                                        queryParameters: {
                                          "key": UniqueKey().toString(),
                                        },
                                        extra: content,
                                      );
                                    },
                                    style: const ButtonStyle(
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    icon: const Icon(Symbols.explore),
                                    label: const Text('Apri mappa'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8.0),
                              PostGeoMapPreview(content: content),
                            ],
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: NearbyContentHorizontalList(
                            coordinates: content.coordinates,
                            onPressed: (content) => _buildPostRoute(content),
                            loadNearContentCommand:
                                widget.viewModel.loadNearContent,
                            nearContent: widget.viewModel.nearContent,
                          ),
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
          LinearGradientBackground(
            child: SizedBox(
              width: double.infinity,
              height: MediaQuery.paddingOf(context).top,
            ),
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
    );
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

  /// Creates insets for [sliver] of such dimensions:
  /// - Left: 16.0
  /// - Top: 0
  /// - Right: 16.0
  /// - Bottom: 16.0
  Widget _pad(Widget sliver) => SliverPadding(
    padding: const EdgeInsetsDirectional.fromSTEB(16.0, 0, 16.0, 16.0),
    sliver: sliver,
  );

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

      GoRouter.of(context).pushReplacementNamed(
        nextRoute,
        pathParameters: map,
        queryParameters: {
          'isEvent': (content is EventContent ? 'true' : 'false'),
        },
      );
    }
  }
}
