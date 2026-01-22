import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/domain/models/event_content.dart';
import 'package:moliseis/routing/route_names.dart';
import 'package:moliseis/ui/category/widgets/category_button.dart';
import 'package:moliseis/ui/core/ui/content/content_adaptive_list_grid_view.dart';
import 'package:moliseis/ui/core/ui/empty_view.dart';
import 'package:moliseis/ui/core/ui/skeletons/skeleton_content_grid.dart';
import 'package:moliseis/ui/core/ui/skeletons/skeleton_content_list.dart';
import 'package:moliseis/ui/core/ui/text_section_divider.dart';
import 'package:moliseis/ui/core/ui/window_size_provider.dart';
import 'package:moliseis/ui/event/view_models/event_view_model.dart';
import 'package:moliseis/ui/explore/view_models/explore_view_model.dart';
import 'package:moliseis/ui/explore/widgets/explore_screen_carousel_view.dart';
import 'package:moliseis/ui/search/view_models/search_view_model.dart';
import 'package:moliseis/ui/search/widgets/custom_search_anchor.dart';
import 'package:moliseis/ui/suggestion/widgets/suggestion_cta_button.dart';
import 'package:moliseis/ui/sync/view_models/sync_view_model.dart';
import 'package:moliseis/utils/constants.dart';
import 'package:provider/provider.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({
    super.key,
    required this.eventViewModel,
    required this.exploreViewModel,
    required this.searchViewModel,
  });

  final EventViewModel eventViewModel;
  final ExploreViewModel exploreViewModel;
  final SearchViewModel searchViewModel;

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final _searchController = SearchController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          edgeOffset: kToolbarHeight * 2.0 + 8.0,
          onRefresh: () async {
            context.read<SyncViewModel>().sync.execute(true);

            // Redirects to the local app repositories synchronization screen.
            GoRouter.of(context).refresh();
          },
          child: CustomScrollView(
            slivers: <Widget>[
              SliverAppBar(
                title: DefaultTextStyle.merge(
                  style: const TextStyle(fontWeight: FontWeight.w700),
                  child: const Text('Molise Is'),
                ),
                actions: <Widget>[
                  MenuAnchor(
                    menuChildren: [
                      MenuItemButton(
                        onPressed: () {
                          context.pushNamed(RouteNames.settings);
                        },
                        leadingIcon: const Icon(Icons.settings),
                        child: const Text('Impostazioni'),
                      ),
                    ],
                    builder: (_, controller, _) {
                      return IconButton(
                        onPressed: () {
                          controller.isOpen
                              ? controller.close()
                              : controller.open();
                        },
                        tooltip: 'Altro',
                        icon: const Icon(Icons.more_vert),
                      );
                    },
                  ),
                ],
              ),
              SliverAppBar(
                elevation: 0,
                scrolledUnderElevation: 0,
                backgroundColor: Theme.of(context).colorScheme.surface,
                flexibleSpace: Align(
                  alignment: Alignment.centerLeft,
                  child: CustomSearchAnchor(
                    controller: _searchController,
                    onSubmitted: (text) {
                      _showSearchResults(text);
                    },
                    onSuggestionPressed: (ContentBase content) {
                      _searchController.closeView(null);
                      _showSearchResults(content.name);
                    },
                    viewModel: widget.searchViewModel,
                  ),
                ),
                primary: false,
                centerTitle: false,
                collapsedHeight: kToolbarHeight + 8.0,
                expandedHeight: kToolbarHeight,
                pinned: true,
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 8.0)),
              ExploreScreenCarouselView(
                exploreViewModel: widget.exploreViewModel,
              ),
              const SliverPadding(
                padding: EdgeInsetsDirectional.fromSTEB(16.0, 16.0, 16.0, 8.0),
                sliver: SliverToBoxAdapter(
                  child: TextSectionDivider('Categorie'),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: 16.0,
                ),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final type = widget.exploreViewModel.types[index];
                    return CategoryButton(
                      onPressed: () {
                        return GoRouter.of(context).goNamed(
                          RouteNames.homeCategory,
                          pathParameters: {
                            'index': (type.index - 1).toString(),
                          },
                        );
                      },
                      contentCategory: type,
                    );
                  }, childCount: widget.exploreViewModel.types.length),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 8.0,
                    crossAxisSpacing: 8.0,
                    mainAxisExtent: kButtonHeight,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(16.0),
                sliver: SliverToBoxAdapter(
                  child: SuggestionCTAButton(
                    onPressed: () => context.goNamed(RouteNames.suggestion),
                  ),
                ),
              ),
              const SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                sliver: SliverToBoxAdapter(
                  child: TextSectionDivider('Prossimi eventi'),
                ),
              ),
              ListenableBuilder(
                listenable: widget.eventViewModel.loadNext,
                builder: (context, child) {
                  if (widget.eventViewModel.loadNext.completed) {
                    return SliverPadding(
                      padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
                      sliver: ContentAdaptiveListGridView(
                        widget.eventViewModel.next,
                        onPressed: (content) {
                          GoRouter.of(context).goNamed(
                            RouteNames.homeDetails,
                            pathParameters: {'id': content.remoteId.toString()},
                            queryParameters: {
                              'isEvent': (content is EventContent
                                  ? 'true'
                                  : 'false'),
                            },
                          );
                        },
                      ),
                    );
                  }

                  if (widget.eventViewModel.loadNext.error) {
                    return SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
                      sliver: SliverToBoxAdapter(
                        child: EmptyView.error(
                          text: const Text(
                            'Si è verificato un errore durante il caricamento.',
                          ),
                          action: TextButton(
                            onPressed: () {
                              widget.eventViewModel.loadNext.execute();
                            },
                            child: const Text('Riprova'),
                          ),
                        ),
                      ),
                    );
                  }

                  final length = widget.eventViewModel.nextIds.length;

                  return WindowSizeProvider.of(context).isCompact
                      ? SkeletonContentList.sliver(itemCount: length)
                      : SkeletonContentGrid.sliver(itemCount: length);
                },
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    spacing: 16.0,
                    children: [
                      const Expanded(
                        child: TextSectionDivider('Ultimi aggiunti'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => GoRouter.of(context).goNamed(
                          RouteNames.homeCategory,
                          pathParameters: {
                            'index': kcategoryScreenNoIndex.toString(),
                          },
                        ),
                        style: const ButtonStyle(
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.apps),
                        label: const Text('Mostra tutti'),
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 8.0)),
              ListenableBuilder(
                listenable: widget.exploreViewModel.loadLatest,
                builder: (context, child) {
                  if (widget.exploreViewModel.loadLatest.completed) {
                    return ContentAdaptiveListGridView(
                      widget.exploreViewModel.latest,
                      onPressed: (content) {
                        GoRouter.of(context).goNamed(
                          RouteNames.homeDetails,
                          pathParameters: {'id': content.remoteId.toString()},
                          queryParameters: {
                            'isEvent': (content is EventContent
                                ? 'true'
                                : 'false'),
                          },
                        );
                      },
                    );
                  }

                  if (widget.exploreViewModel.loadLatest.error) {
                    return SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
                      sliver: SliverToBoxAdapter(
                        child: EmptyView.error(
                          text: const Text(
                            'Si è verificato un errore durante il caricamento.',
                          ),
                          action: TextButton(
                            onPressed: () {
                              widget.exploreViewModel.loadLatest.execute();
                            },
                            child: const Text('Riprova'),
                          ),
                        ),
                      ),
                    );
                  }

                  final length = widget.exploreViewModel.latestIds.length;

                  return WindowSizeProvider.of(context).isCompact
                      ? SkeletonContentList.sliver(itemCount: length)
                      : SkeletonContentGrid.sliver(itemCount: length);
                },
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16.0)),
            ],
          ),
        ),
      ),
      resizeToAvoidBottomInset: false,
    );
  }

  void _showSearchResults(String text) {
    if (text.isNotEmpty) {
      context.goNamed(
        RouteNames.homeSearchResults,
        pathParameters: {'query': text},
      );
    }

    _searchController.clear();
  }
}
