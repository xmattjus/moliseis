import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:moliseis/routing/route_names.dart';
import 'package:moliseis/ui/categories/widgets/category_button.dart';
import 'package:moliseis/ui/core/ui/attraction_list_view_responsive.dart';
import 'package:moliseis/ui/core/ui/text_section_divider.dart';
import 'package:moliseis/ui/explore/view_models/attraction_view_model.dart';
import 'package:moliseis/ui/explore/widgets/explore_screen_carousel_view.dart';
import 'package:moliseis/ui/search/widgets/custom_search_anchor.dart';
import 'package:moliseis/ui/sync/view_models/sync_view_model.dart';
import 'package:moliseis/utils/constants.dart';
import 'package:provider/provider.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  late final AttractionViewModel _viewModel;
  final _searchController = SearchController();

  @override
  void initState() {
    super.initState();

    _viewModel = context.read();
  }

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
            context.read<SyncViewModel>().synchronize(force: true);

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
                elevation: 0.0,
                scrolledUnderElevation: 0.0,
                backgroundColor: Theme.of(context).colorScheme.surface,
                flexibleSpace: Align(
                  child: CustomSearchAnchor(
                    controller: _searchController,
                    onSubmitted: (text) {
                      _showSearchResults(text);
                    },
                    onSuggestionPressed: (_) {
                      _searchController.closeView(null);
                      _showSearchResults(_searchController.text);
                    },
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
                attractionsIdsFuture: _viewModel.suggestedAttractionIds,
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
                    final attractionType = _viewModel.attractionTypes[index];
                    return CategoryButton(
                      onPressed: () {
                        return GoRouter.of(context).goNamed(
                          RouteNames.homeCategory,
                          pathParameters: {
                            'index': (attractionType.index - 1).toString(),
                          },
                        );
                      },
                      attractionType: attractionType,
                    );
                  }, childCount: _viewModel.attractionTypes.length),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 8.0,
                    crossAxisSpacing: 8.0,
                    mainAxisExtent: kButtonHeight,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: TextSectionDivider('Ultimi aggiunti'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => GoRouter.of(context).goNamed(
                          RouteNames.homeCategory,
                          pathParameters: {'index': '0'},
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
              AttractionListViewResponsive(
                _viewModel.latestAttractionIds,
                onPressed: (attractionId) {
                  GoRouter.of(context).goNamed(
                    RouteNames.homeStory,
                    pathParameters: {'id': attractionId.toString()},
                  );
                },
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16.0)),
            ],
          ),
        ),
      ),
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
