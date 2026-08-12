import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:moliseis/domain/models/content_type.dart';
import 'package:moliseis/domain/models/event.dart';
import 'package:moliseis/routing/route_names.dart';
import 'package:moliseis/routing/route_parameters.dart';
import 'package:moliseis/ui/category/widgets/category_button.dart';
import 'package:moliseis/ui/content_submission/widgets/content_submission_cta_button.dart';
import 'package:moliseis/ui/core/ui/content/content_sliver_grid.dart';
import 'package:moliseis/ui/core/ui/empty_view.dart';
import 'package:moliseis/ui/core/ui/skeletons/skeleton_content_sliver_grid.dart';
import 'package:moliseis/ui/core/ui/text_section_divider.dart';
import 'package:moliseis/ui/event/view_models/event_view_model.dart';
import 'package:moliseis/ui/explore/view_models/explore_view_model.dart';
import 'package:moliseis/ui/explore/view_models/suggestion_view_model.dart';
import 'package:moliseis/ui/explore/widgets/responsive_overflow_menu.dart';
import 'package:moliseis/ui/explore/widgets/suggestion_horizontal_list_view.dart';
import 'package:moliseis/ui/search/view_models/search_view_model.dart';
import 'package:moliseis/ui/search/widgets/components/app_search_anchor.dart';
import 'package:moliseis/ui/sync/view_models/sync_view_model.dart';
import 'package:moliseis/utils/constants.dart';
import 'package:provider/provider.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({
    required this.eventViewModel,
    required this.exploreViewModel,
    required this.searchViewModel,
    required this.suggestedViewModel,
    super.key,
  });

  final EventViewModel eventViewModel;
  final ExploreViewModel exploreViewModel;
  final SearchViewModel searchViewModel;
  final SuggestionViewModel suggestedViewModel;

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
          onRefresh: () async => _startSync(),
          child: CustomScrollView(
            slivers: <Widget>[
              SliverAppBar(
                title: DefaultTextStyle.merge(
                  style: const TextStyle(fontWeight: FontWeight.w700),
                  child: const Text('Molise Is'),
                ),
                actions: <Widget>[
                  ResponsiveOverflowMenu(
                    items: <MenuItem>[
                      MenuItem(
                        title: const Text('Aggiorna'),
                        icon: const Icon(Symbols.sync, weight: 500),
                        tooltip: 'Aggiorna i contenuti',
                        onPressed: _startSync,
                      ),
                      MenuItem(
                        title: const Text('Impostazioni'),
                        icon: const Icon(Symbols.settings, weight: 500),
                        tooltip: 'Impostazioni',
                        onPressed: () => context.pushNamed(RouteNames.settings),
                      ),
                      if (kDebugMode)
                        MenuItem(
                          title: const Text('Debug'),
                          icon: const Icon(Symbols.bug_report, weight: 500),
                          tooltip: 'Debug',
                          onPressed: () =>
                              context.pushNamed(RouteNames.logging),
                        ),
                    ],
                  ),
                ],
              ),
              SliverAppBar(
                elevation: 0,
                scrolledUnderElevation: 0,
                backgroundColor: Theme.of(context).colorScheme.surface,
                flexibleSpace: Align(
                  alignment: Alignment.centerLeft,
                  child: AppSearchAnchor(
                    controller: _searchController,
                    onSubmitted: _showSearchResults,
                    onSuggestionPressed: (content) {
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
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
              SuggestiondHorizontalListView(
                viewModel: widget.suggestedViewModel,
              ),
              const SliverToBoxAdapter(child: TextSectionDivider('Categorie')),
              SliverPadding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: 16,
                ),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final type = widget.exploreViewModel.types[index];
                    return CategoryButton(
                      onPressed: () {
                        return GoRouter.of(context).goNamed(
                          RouteNames.homeCategory,
                          pathParameters: {
                            'categorySlug': RouteParameters.categorySlug(type),
                          },
                        );
                      },
                      contentCategory: type,
                    );
                  }, childCount: widget.exploreViewModel.types.length),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    mainAxisExtent: kButtonHeight,
                  ),
                ),
              ),
              const SliverPadding(
                padding: EdgeInsets.all(16),
                sliver: SliverToBoxAdapter(child: ContentSubmissionCTAButton()),
              ),
              const SliverToBoxAdapter(
                child: TextSectionDivider(
                  'Prossimi eventi',
                  padding: EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
              ListenableBuilder(
                listenable: widget.eventViewModel.loadNext,
                builder: (context, child) {
                  if (widget.eventViewModel.loadNext.completed) {
                    return SliverPadding(
                      padding: const EdgeInsets.only(top: 8, bottom: 16),
                      sliver: ContentSliverGrid(
                        widget.eventViewModel.next,
                        onPressed: (content) {
                          GoRouter.of(context).goNamed(
                            RouteNames.homePost,
                            pathParameters: {'id': content.remoteId.toString()},
                            queryParameters: {
                              'type': RouteParameters.contentTypeSlug(
                                content is Event
                                    ? ContentType.event
                                    : ContentType.place,
                              ),
                            },
                          );
                        },
                      ),
                    );
                  }

                  if (widget.eventViewModel.loadNext.error) {
                    return SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      sliver: SliverToBoxAdapter(
                        child: EmptyView.error(
                          text: const Text(
                            'Si è verificato un errore durante il caricamento.',
                          ),
                          action: TextButton(
                            onPressed: () => unawaited(
                              widget.eventViewModel.loadNext.execute(),
                            ),
                            child: const Text('Riprova'),
                          ),
                        ),
                      ),
                    );
                  }

                  return const SkeletonContentSliverGrid();
                },
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    spacing: 16,
                    children: [
                      const Expanded(
                        child: TextSectionDivider(
                          'Ultimi aggiunti',
                          padding: EdgeInsets.zero,
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => GoRouter.of(context).goNamed(
                          RouteNames.homeCategory,
                          pathParameters: {
                            'categorySlug': RouteParameters.allCategorySlug,
                          },
                        ),
                        style: const ButtonStyle(
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Symbols.apps, grade: 500),
                        label: const Text('Mostra tutti'),
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
              ListenableBuilder(
                listenable: widget.exploreViewModel.loadLatest,
                builder: (context, child) {
                  if (widget.exploreViewModel.loadLatest.completed) {
                    return ContentSliverGrid(
                      widget.exploreViewModel.latest,
                      onPressed: (content) {
                        GoRouter.of(context).goNamed(
                          RouteNames.homePost,
                          pathParameters: {'id': content.remoteId.toString()},
                          queryParameters: {
                            'type': RouteParameters.contentTypeSlug(
                              content is Event
                                  ? ContentType.event
                                  : ContentType.place,
                            ),
                          },
                        );
                      },
                    );
                  }

                  if (widget.exploreViewModel.loadLatest.error) {
                    return SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      sliver: SliverToBoxAdapter(
                        child: EmptyView.error(
                          text: const Text(
                            'Si è verificato un errore durante il caricamento.',
                          ),
                          action: TextButton(
                            onPressed: () => unawaited(
                              widget.exploreViewModel.loadLatest.execute(),
                            ),
                            child: const Text('Riprova'),
                          ),
                        ),
                      ),
                    );
                  }

                  return const SkeletonContentSliverGrid();
                },
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
            ],
          ),
        ),
      ),
      resizeToAvoidBottomInset: false,
    );
  }

  void _startSync() {
    final syncViewModel = context.read<SyncViewModel>();
    unawaited(syncViewModel.sync.execute(true));
  }

  void _showSearchResults(String text) {
    if (text.isNotEmpty) {
      context.goNamed(
        RouteNames.homeSearchResult,
        queryParameters: {'q': text},
      );
    }

    _searchController.clear();
  }
}
