import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:moliseis/domain/models/attraction/attraction_type.dart';
import 'package:moliseis/domain/models/geo_map/geo_map_state.dart';
import 'package:moliseis/routing/route_names.dart';
import 'package:moliseis/routing/route_paths.dart';
import 'package:moliseis/ui/categories/widgets/category_button.dart';
import 'package:moliseis/ui/core/themes/text_style.dart';
import 'package:moliseis/ui/core/ui/attraction_and_place_names.dart';
import 'package:moliseis/ui/core/ui/button_list.dart';
import 'package:moliseis/ui/core/ui/custom_appbar.dart';
import 'package:moliseis/ui/core/ui/empty_view.dart';
import 'package:moliseis/ui/core/ui/near_attractions_list.dart';
import 'package:moliseis/ui/favourite/widgets/favourite_button.dart';
import 'package:moliseis/ui/story/view_models/paragraph_view_model.dart';
import 'package:moliseis/ui/story/view_models/story_view_model.dart';
import 'package:moliseis/ui/story/widgets/paragraph_sliver_list.dart';
import 'package:moliseis/ui/story/widgets/story_author.dart';
import 'package:moliseis/ui/story/widgets/story_geo_map_preview.dart';
import 'package:moliseis/ui/story/widgets/story_image_slideshow.dart';
import 'package:moliseis/ui/story/widgets/story_source.dart';
import 'package:moliseis/utils/constants.dart';
import 'package:moliseis/utils/extensions.dart';

class StoryScreen extends StatefulWidget {
  const StoryScreen({
    super.key,
    required this.attractionId,
    required this.paragraphViewModel,
    required this.storyViewModel,
  });

  final int attractionId;
  final ParagraphViewModel paragraphViewModel;
  final StoryViewModel storyViewModel;

  @override
  State<StoryScreen> createState() => _StoryScreenState();
}

class _StoryScreenState extends State<StoryScreen> {
  late final ScrollController _scrollController = ScrollController();

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
    _currentUri = GoRouterState.of(context).uri.toString();

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
          listenable: widget.storyViewModel.load,
          builder: (context, _) {
            if (widget.storyViewModel.load.running) {
              return const EmptyView.loading(
                text: Text('Caricamento in corso...'),
              );
            } else if (widget.storyViewModel.load.error) {
              return EmptyView(
                text: const Text(
                  'Si è verificato un errore durante il caricamento',
                ),
                action: TextButton(
                  onPressed: () {
                    widget.storyViewModel.load.execute(widget.attractionId);
                  },
                  child: const Text('Riprova'),
                ),
              );
            }

            final attraction = widget.storyViewModel.attraction!;
            final story = widget.storyViewModel.story!;

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

                // Returning false allows the notification to continue bubbling
                // up to ancestor listeners.
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
                          child: StoryImageSlideshow(
                            images: widget.storyViewModel.images,
                          ),
                        );
                      },
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsetsDirectional.only(start: 16.0),
                    sliver: SliverList.list(
                      children: <Widget>[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 16.0,
                          children: [
                            Expanded(
                              child: AttractionAndPlaceNames(
                                name: story.title,
                                placeName: attraction.place.target!.name,
                                nameStyle: CustomTextStyles.title(context),
                                placeNameStyle: CustomTextStyles.subtitle(
                                  context,
                                ),
                                overflow: TextOverflow.visible,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsetsDirectional.only(
                                end: 8.0,
                              ),
                              child: FavouriteButton(id: widget.attractionId),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16.0),
                        ButtonList(
                          items: [
                            CategoryButton(
                              onPressed: () {
                                _buildCategoriesRoute(attraction.type);
                              },
                              attractionType: attraction.type,
                            ),
                            /*
                            ElevatedButton.icon(
                              onPressed: () {
                                _buildCategoriesRoute(attraction.type);
                              },
                              style: const ButtonStyle().byAttractionType(
                                attraction.type,
                                primary: Theme.of(context).colorScheme.primary,
                                brightness: Theme.of(context).brightness,
                              ),
                              icon: Icon(attraction.type.getIcon()),
                              label: Text(attraction.type.readableName),
                            ),
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
                        const SizedBox(height: 16.0),
                      ],
                    ),
                  ),
                  if (story.shortDescription.isNotEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      sliver: SliverToBoxAdapter(
                        child: Text(story.shortDescription),
                      ),
                    ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    sliver: ParagraphSliverList(
                      id: story.id,
                      viewModel: widget.paragraphViewModel,
                    ),
                  ),
                  if (story.sources.isNotEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 16.0,
                        horizontal: 16.0,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: StorySource(texts: story.sources),
                      ),
                    ),
                  if (story.author.isNotEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 16.0,
                        horizontal: 16.0,
                      ),
                      sliver: StoryAuthor(s: story.author),
                    ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    sliver: SliverList.list(
                      children: <Widget>[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Mappa',
                              style: CustomTextStyles.section(context),
                            ),
                            OutlinedButton.icon(
                              onPressed: () {
                                final mapState = GeoMapState(
                                  latitude: attraction.coordinates[0],
                                  longitude: attraction.coordinates[1],
                                  attractionId: attraction.id,
                                );

                                /// Sets a [UniqueKey] so that go_router can
                                /// notify [mapState] changes to the next route.
                                ///
                                /// Removing the [key] query parameter will
                                /// prevent state changes for the next route if
                                /// it is already present in the navigation stack.
                                context.goNamed(
                                  RouteNames.geoMap,
                                  queryParameters: {
                                    "key": UniqueKey().toString(),
                                  },
                                  extra: mapState,
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
                        StoryGeoMapPreview(attraction: attraction),
                      ],
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    sliver: SliverToBoxAdapter(
                      child: NearAttractionsList(
                        coordinates: [
                          attraction.coordinates[0],
                          attraction.coordinates[1],
                        ],
                        hideFirstItem: true,
                        onPressed: (id) {
                          final typeIndex = attraction.type.index + 1;

                          _buildStoryRoute(id, typeIndex);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      extendBodyBehindAppBar: true,
    );
  }

  void _buildCategoriesRoute(AttractionType type) {
    String? nextRouteName;

    if (_currentUri.startsWith(RoutePaths.favourites)) {
      nextRouteName = RouteNames.favouritesCategory;
    } else {
      nextRouteName = RouteNames.homeCategory;
    }

    GoRouter.of(context).goNamed(
      nextRouteName,
      pathParameters: {'index': (type.index - 1).toString()},
    );
  }

  void _buildStoryRoute(int id, int typeIndex) {
    String? nextRouteName;
    var indexNecessary = false;

    if (_currentUri.startsWith('${RoutePaths.home}/${RoutePaths.category}')) {
      nextRouteName = RouteNames.homeCategoryStory;
      indexNecessary = true;
    } else if (_currentUri.startsWith(RoutePaths.home)) {
      nextRouteName = RouteNames.homeStory;
    }

    if (_currentUri.startsWith(
      '${RoutePaths.favourites}/${RoutePaths.category}',
    )) {
      nextRouteName = RouteNames.favouritesCategoryStory;
      indexNecessary = true;
    } else if (_currentUri.startsWith(RoutePaths.favourites)) {
      nextRouteName = RouteNames.favouritesStory;
    }

    if (nextRouteName != null) {
      final map = {'id': id.toString()};

      if (indexNecessary) {
        map['index'] = (typeIndex - 1).toString();
      }

      GoRouter.of(context)
        ..pop()
        ..goNamed(nextRouteName, pathParameters: map);

      // GoRouter.of(context).goNamed(nextRouteName, pathParameters: map);
    }
  }
}
