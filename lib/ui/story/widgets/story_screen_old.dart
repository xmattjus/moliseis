/*
import 'dart:async' show StreamController, Timer;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:moliseis/domain/models/attraction/attraction.dart';
import 'package:moliseis/domain/models/attraction/attraction_type.dart';
import 'package:moliseis/domain/models/geo_map/geo_map_state.dart';
import 'package:moliseis/domain/models/molis_image/molis_image.dart';
import 'package:moliseis/routing/route_names.dart';
import 'package:moliseis/ui/categories/widgets/category_button.dart';
import 'package:moliseis/ui/core/themes/text_style.dart';
import 'package:moliseis/ui/core/ui/favourite_button.dart';
import 'package:moliseis/ui/core/ui/button_list.dart';
import 'package:moliseis/ui/core/ui/cards/card_base.dart';
import 'package:moliseis/ui/core/ui/custom_appbar.dart';
import 'package:moliseis/ui/core/ui/custom_circular_progress_indicator.dart';
import 'package:moliseis/ui/core/ui/custom_image.dart';
import 'package:moliseis/ui/core/ui/custom_rich_text.dart';
import 'package:moliseis/ui/core/ui/empty_view.dart';
import 'package:moliseis/ui/core/ui/flex_test.dart';
import 'package:moliseis/ui/core/ui/future_built.dart';
import 'package:moliseis/ui/core/ui/near_attractions_list.dart';
import 'package:moliseis/ui/core/ui/pad.dart';
import 'package:moliseis/ui/explore/view_models/attraction_view_model.dart';
import 'package:moliseis/ui/gallery/widgets/gallery_preview_modal.dart';
import 'package:moliseis/ui/geo_map/widgets/geo_map.dart';
import 'package:moliseis/ui/geo_map/widgets/geo_map_attribution.dart';
import 'package:moliseis/ui/geo_map/widgets/geo_map_marker.dart';
import 'package:moliseis/ui/story/widgets/mountains_path_painter.dart';
import 'package:moliseis/utils/app_url_launcher.dart';
import 'package:moliseis/utils/extensions.dart';
import 'package:provider/provider.dart';

part 'story_geo_map_preview.dart';
part 'story_image_slideshow.dart';
part '_story_image_slideshow_button.dart';

class StoryScreen extends StatefulWidget {
  /// The [Attraction] Id.
  final String? attractionId;

  const StoryScreen({super.key, required this.attractionId});

  @override
  State<StoryScreen> createState() => _StoryScreenState();
}

class _StoryScreenState extends State<StoryScreen> {
  late final AttractionViewModel _uiAttractionController;

  @override
  void initState() {
    super.initState();
    _uiAttractionController = context.read();
  }

  @override
  Widget build(BuildContext context) {
    final urlLauncher = AppUrlLauncher();

    return Scaffold(
      appBar: const CustomAppBar(showBackButton: true),
      body: FutureBuilt<Attraction?>(
        _uiAttractionController.getAttractionById(widget.attractionId),
        onLoading:
            () => const Center(
              child: CustomCircularProgressIndicator.withDelay(),
            ),
        onSuccess: (attraction) {
          // TODO: Add retry button.
          if (attraction == null) {
            return const EmptyView.error(text: Text('data'));
          }

          return SafeArea(
            top: false,
            child: CustomScrollView(
              slivers: <Widget>[
                SliverList.list(
                  children: <Widget>[
                    _StoryScreenSlideshow(attraction: attraction),
                    FlexTest(
                      left: Pad(
                        v: 8.0,
                        h: 16.0,
                        child: Text(
                          attraction.name,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: CustomTextStyles.title(context),
                        ),
                      ),
                      right: AttractionSaveButton(id: attraction.id),
                    ),
                    Pad(
                      b: 8.0,
                      h: 16.0,
                      child: CustomRichText(
                        Text(attraction.place.target!.name),
                        labelTextStyle: CustomTextStyles.subtitle(context),
                        icon: const Icon(Icons.place_outlined),
                      ),
                    ),
                    ButtonList(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                      ),
                      items: <Widget>[
                        CategoryButton(
                          type: attraction.type,
                          onPressed: () {
                            return goToCategoryScreen(context, attraction.type);
                          },
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
                    Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        16.0,
                        16.0,
                        16.0,
                        0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          if (attraction.summary.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: CustomRichText(
                                Text(attraction.summary).justify,
                                maxLines: 10,
                              ),
                            ),
                          if (attraction.description.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: CustomRichText(
                                const Text('Descrizione'),
                                labelTextStyle: CustomTextStyles.section(
                                  context,
                                ),
                                content: Text(attraction.description).justify,
                                maxLines: 3,
                              ),
                            ),
                          if (attraction.history.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: CustomRichText(
                                const Text('Storia'),
                                labelTextStyle: CustomTextStyles.section(
                                  context,
                                ),
                                content: Text(attraction.history).justify,
                                maxLines: 2,
                              ),
                            ),
                          if (attraction.sources.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: List<Widget>.from(<Widget>[
                                  Pad(
                                    b: 8.0,
                                    child: Text(
                                      'Fonti',
                                      style: CustomTextStyles.section(context),
                                    ),
                                  ),
                                ])..addAll(
                                  _uiAttractionController.analyzeTest(
                                    context,
                                    attraction.sources,
                                    urlLauncher,
                                  ),
                                ),
                              ),
                            ),
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
                                  /// notify [mapState] changes to the next
                                  /// route.
                                  ///
                                  /// Removing the [key] query parameter will
                                  /// prevent state changes for the next route
                                  /// if it is already present in the navigation
                                  /// stack.
                                  context.goNamed(
                                    RouteNames.map,
                                    queryParameters: {"key": "${UniqueKey()}"},
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
                        ],
                      ),
                    ),
                    _StoryScreenGeoMapPreview(attraction: attraction),
                    Pad(
                      v: 16.0,
                      child: NearAttractionsList(
                        coordinates: [
                          attraction.coordinates[0],
                          attraction.coordinates[1],
                        ],
                        hideFirstItem: true,
                        onPressed: (id) {
                          final typeIndex = _uiAttractionController
                              .getTypeIndexFromAttractionId(id);

                          goToPostScreen(
                            context: context,
                            id: id,
                            typeIndex: typeIndex,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
        onError: (Object? error) {
          return EmptyView.error(
            text: Text(
              'Si è verificato un errore durante il caricamento: $error',
            ),
          );
        },
      ),
      extendBodyBehindAppBar: true,
    );
  }

  void goToCategoryScreen(BuildContext context, AttractionType type) {
    /// Source:
    /// https://github.com/flutter/flutter/issues/132824#issuecomment-1880465085
    final outerContext = Navigator.of(context).context;
    final routerStateUri = GoRouterState.of(outerContext).uri.toString();

    String? nextPath;

    if (routerStateUri.contains(RouteNames.explore)) {
      nextPath = RouteNames.exploreCategory;
    } else if (routerStateUri.contains(RouteNames.search)) {
      nextPath = RouteNames.searchCategory;
    }

    if (nextPath != null) {
      GoRouter.of(context).goNamed(
        nextPath,
        pathParameters: {'index': (type.index - 1).toString()},
      );
    }
  }

  void goToPostScreen({
    required BuildContext context,
    required int id,
    required int typeIndex,
  }) {
    String? nextPath;
    var indexNecessary = false;

    /// Source:
    /// https://github.com/flutter/flutter/issues/132824#issuecomment-1880465085
    final outerContext = Navigator.of(context).context;
    final routerStateUri = GoRouterState.of(outerContext).uri.toString();

    if (routerStateUri.contains(RouteNames.exploreCategory)) {
      nextPath = RouteNames.exploreCategoryStory;
      indexNecessary = true;
    } else if (routerStateUri.contains(RouteNames.explore)) {
      nextPath = RouteNames.exploreStory;
    }

    if (routerStateUri.contains(RouteNames.searchCategory)) {
      nextPath = RouteNames.searchCategoryStory;
      indexNecessary = true;
    } else if (routerStateUri.contains(RouteNames.search)) {
      nextPath = RouteNames.searchStory;
    }

    if (nextPath != null) {
      final map = <String, String>{'id': id.toString()};

      if (indexNecessary) {
        map['index'] = (typeIndex - 1).toString();
      }

      GoRouter.of(context).pop();

      GoRouter.of(context).goNamed(nextPath, pathParameters: map);

      /*
      if (indexNecessary) {
        GoRouter.of(context).goNamed(
          nextPath,
          pathParameters: {
            'index': (typeIndex - 1).toString(),
            'id': id.toString(),
          },
        );
      } else {
        GoRouter.of(context).goNamed(
          nextPath,
          pathParameters: {
            'id': id.toString(),
          },
        );
      }
     */
    }
  }
}
*/
