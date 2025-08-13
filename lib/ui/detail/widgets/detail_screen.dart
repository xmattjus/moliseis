import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:moliseis/domain/models/core/content_base.dart';
import 'package:moliseis/domain/models/core/content_category.dart';
import 'package:moliseis/domain/models/event/event_content.dart';
import 'package:moliseis/domain/models/place/place_content.dart';
import 'package:moliseis/routing/route_names.dart';
import 'package:moliseis/ui/category/widgets/category_button.dart';
import 'package:moliseis/ui/core/themes/shapes.dart';
import 'package:moliseis/ui/core/themes/text_styles.dart';
import 'package:moliseis/ui/core/ui/content/content_base_card_grid_item.dart';
import 'package:moliseis/ui/core/ui/content/content_name_and_city.dart';
import 'package:moliseis/ui/core/ui/content/event_content_start_date_time.dart';
import 'package:moliseis/ui/core/ui/custom_appbar.dart';
import 'package:moliseis/ui/core/ui/custom_snack_bar.dart';
import 'package:moliseis/ui/core/ui/empty_view.dart';
import 'package:moliseis/ui/core/ui/horizontal_button_list.dart';
import 'package:moliseis/ui/core/ui/skeletons/custom_pulse_effect.dart';
import 'package:moliseis/ui/core/ui/skeletons/skeleton_content_grid_item.dart';
import 'package:moliseis/ui/core/ui/text_section_divider.dart';
import 'package:moliseis/ui/detail/view_models/detail_view_model.dart';
import 'package:moliseis/ui/detail/widgets/detail_geo_map_preview.dart';
import 'package:moliseis/ui/detail/widgets/detail_image_slideshow.dart';
import 'package:moliseis/ui/detail/widgets/details_content.dart';
import 'package:moliseis/ui/detail/widgets/information_card.dart';
import 'package:moliseis/ui/favourite/widgets/favourite_button.dart';
import 'package:moliseis/utils/app_url_launcher.dart';
import 'package:moliseis/utils/constants.dart';
import 'package:moliseis/utils/extensions.dart';
import 'package:provider/provider.dart';
import 'package:skeletonizer/skeletonizer.dart';

class DetailScreen extends StatefulWidget {
  const DetailScreen({
    super.key,
    required this.isEvent,
    required this.viewModel,
  });

  final bool isEvent;
  final DetailViewModel viewModel;

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
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
    final localizations = MaterialLocalizations.of(context);

    _currentUri = GoRouterState.of(context).fullPath.toString();

    final screenHeight = MediaQuery.sizeOf(context).height;

    final trigger =
        screenHeight *
        (context.isLandscape
            ? kStorySlideshowLandscapeHeightPerc - 0.2
            : kStorySlideshowPortraitHeightPerc - 0.2);

    return Scaffold(
      appBar: const CustomAppBar(showBackButton: true),
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
              final content = widget.viewModel.content is EventContent
                  ? widget.viewModel.content as EventContent
                  : widget.viewModel.content as PlaceContent;

              // Load the street address for the content.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                widget.viewModel.loadStreetAddress.execute(content.coordinates);
              });

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
                            child: DetailImageSlideshow(images: content.media),
                          );
                        },
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      sliver: SliverToBoxAdapter(
                        child: ContentNameAndCity(
                          name: content.name,
                          cityName: content.city.target?.name,
                          nameStyle: CustomTextStyles.title(context),
                          cityNameStyle: CustomTextStyles.subtitle(context),
                          overflow: TextOverflow.visible,
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
                                  .read<AppUrlLauncher>()
                                  .googleMaps(
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
                            icon: const Icon(Icons.directions),
                            label: const Text('Indicazioni'),
                          ),
                          /*
                            OutlinedButton.icon(
                              onPressed: () {
                                // TODO(xmattjus): share deep link to this screen.
                              },
                              icon: const Icon(Icons.share_outlined),
                              label: const Text('Condividi'),
                            ),
                             */
                        ],
                      ),
                    ),
                    if (content is EventContent)
                      _pad(
                        SliverToBoxAdapter(
                          child: InformationCard(
                            leading: const Icon(Icons.calendar_month_outlined),
                            title: Text(
                              localizations.formatFullDate(content.startDate),
                            ),
                            subtitle: Text(
                              localizations.formatTimeOfDay(
                                TimeOfDay.fromDateTime(content.startDate),
                              ),
                            ),
                            enableSkeletonizer: false,
                          ),
                        ),
                      ),
                    if (content.coordinates.length == 2 &&
                        content.coordinates.first != 0)
                      _pad(
                        SliverToBoxAdapter(
                          child: ListenableBuilder(
                            listenable: widget.viewModel.loadStreetAddress,
                            builder: (context, child) {
                              return InformationCard(
                                leading: const Icon(Icons.place_outlined),
                                title: Text(
                                  widget.viewModel.loadStreetAddress.running
                                      ? 'Pippo Baudo in concerto, Via Roma 1, Campobasso'
                                      : widget.viewModel.streetAddress,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                subtitle: Text(
                                  'Data © OpenStreetMap contributors, ODbL 1.0. http://osm.org/copyright',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                useBoldSubtitle: false,
                                enableSkeletonizer:
                                    widget.viewModel.loadStreetAddress.running,
                              );
                            },
                          ),
                        ),
                      ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      sliver: DetailsContent.sliver(content: content),
                    ),
                    _pad(
                      SliverList.list(
                        children: <Widget>[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            spacing: 16.0,
                            children: [
                              Text(
                                'Mappa',
                                style: CustomTextStyles.section(context),
                              ),
                              OutlinedButton.icon(
                                onPressed: () {
                                  /*
                                  final mapState = GeoMapState(
                                    latitude: content.coordinates[0],
                                    longitude: content.coordinates[1],
                                    contentId: content.remoteId,
                                  );
                                  */

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
                                icon: const Icon(Icons.explore_outlined),
                                label: const Text('Apri mappa'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8.0),
                          DetailGeoMapPreview(content: content),
                        ],
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: _NearbyContentHorizontalList(
                        coordinates: content.coordinates,
                        onPressed: (content) => _buildStoryRoute(content),
                        viewModel: widget.viewModel,
                      ),
                    ),
                    const SliverPadding(padding: EdgeInsets.only(bottom: 16.0)),
                  ],
                ),
              );
            }

            return const Center(
              child: EmptyView.loading(text: Text('Caricamento in corso...')),
            );
          },
        ),
      ),
      extendBodyBehindAppBar: true,
    );
  }

  void _buildCategoriesRoute(ContentCategory category) {
    String? nextRouteName;

    if (_currentUri.startsWith('/favourites/')) {
      nextRouteName = RouteNames.favouritesCategory;
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

  void _buildStoryRoute(ContentBase content) {
    String? nextRoute;
    var indexNecessary = false;

    if (_currentUri.startsWith('/favourites/category/')) {
      nextRoute = RouteNames.favouritesCategoryDetail;
      indexNecessary = true;
    } else if (_currentUri.startsWith('/category/')) {
      nextRoute = RouteNames.homeCategoryDetail;
      indexNecessary = true;
    } else if (_currentUri.startsWith('/favourites/')) {
      nextRoute = RouteNames.favouritesStory;
    } else if (_currentUri.startsWith('/')) {
      nextRoute = RouteNames.homeStory;
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

class _NearbyContentHorizontalList extends StatefulWidget {
  const _NearbyContentHorizontalList({
    // super.key,
    required this.coordinates,
    required this.onPressed,
    required this.viewModel,
  });

  final List<double> coordinates;
  final void Function(ContentBase content) onPressed;
  final DetailViewModel viewModel;

  @override
  State<_NearbyContentHorizontalList> createState() =>
      __NearbyContentHorizontalListState();
}

class __NearbyContentHorizontalListState
    extends State<_NearbyContentHorizontalList> {
  @override
  void initState() {
    super.initState();

    widget.viewModel.loadNearContent.execute(widget.coordinates);
  }

  @override
  Widget build(BuildContext context) {
    const padding = EdgeInsetsDirectional.fromSTEB(16.0, 0, 16.0, 4.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Padding(
          padding: EdgeInsetsDirectional.fromSTEB(16.0, 0, 16.0, 8.0),
          child: TextSectionDivider('Nelle vicinanze'),
        ),
        SizedBox(
          height: kGridViewCardHeight,
          child: ListenableBuilder(
            listenable: widget.viewModel.loadNearContent,
            builder: (context, child) {
              if (widget.viewModel.loadNearContent.completed) {
                if (widget.viewModel.nearContent.isEmpty) {
                  return const EmptyView(
                    text: Text('Nessun luogo trovato nelle vicinanze.'),
                  );
                }

                return ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: padding,
                  itemBuilder: (_, index) {
                    final content = widget.viewModel.nearContent[index];

                    return ContentBaseCardGridItem(
                      content,
                      width: kGridViewCardWidth,
                      onPressed: (ContentBase content) =>
                          widget.onPressed(content),
                      verticalTrailing: content is EventContent
                          ? EventContentStartDateTime(content)
                          : null,
                      horizontalTrailing: FavouriteButton(
                        color: Colors.white,
                        content: content,
                        radius: Shapes.small,
                      ),
                    );
                  },
                  separatorBuilder: (_, _) => const SizedBox(width: 8.0),
                  itemCount: widget.viewModel.nearContent.length,
                );
              }

              if (widget.viewModel.loadNearContent.error) {
                return const EmptyView.error(
                  text: Text(
                    'Si è verificato un errore durante il caricamento.',
                  ),
                );
              }

              return Skeletonizer(
                effect: CustomPulseEffect(context: context),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: padding,
                  itemBuilder: (_, _) => const SkeletonContentGridItem(
                    width: kGridViewCardWidth,
                    height: kGridViewCardHeight,
                  ),
                  separatorBuilder: (_, _) => const SizedBox(width: 8.0),
                  itemCount: 5,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
