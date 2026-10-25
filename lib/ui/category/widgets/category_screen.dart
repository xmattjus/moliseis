import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/domain/models/content_sort.dart';
import 'package:moliseis/domain/models/content_type.dart';
import 'package:moliseis/domain/models/event.dart';
import 'package:moliseis/routing/route_names.dart';
import 'package:moliseis/routing/route_parameters.dart';
import 'package:moliseis/ui/category/view_models/category_view_model.dart';
import 'package:moliseis/ui/category/widgets/category_content_and_type_selection.dart';
import 'package:moliseis/ui/core/ui/content/content_sliver_grid.dart';
import 'package:moliseis/ui/core/ui/custom_back_button.dart';
import 'package:moliseis/ui/core/ui/empty_view.dart';
import 'package:moliseis/ui/core/ui/skeletons/skeleton_content_sliver_grid.dart';

import 'package:moliseis/utils/result_command.dart';

class CategoryScreen extends StatefulWidget {
  const CategoryScreen({required this.viewModel, super.key});

  final CategoryViewModel viewModel;

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  @override
  Widget build(BuildContext context) {
    final viewModel = widget.viewModel;
    return ListenableBuilder(
      listenable: Listenable.merge([viewModel, viewModel.load.results]),
      builder: (context, _) {
        final snapshot = viewModel.load.results.value;
        return Scaffold(
          body: SafeArea(
            child: NestedScrollView(
              headerSliverBuilder: (context, _) => [
                SliverOverlapAbsorber(
                  handle: NestedScrollView.sliverOverlapAbsorberHandleFor(
                    context,
                  ),
                  sliver: SliverAppBar(
                    leading: const CustomBackButton(),
                    title: const Text('Categorie'),
                    actions: [
                      MenuAnchor(
                        menuChildren: [
                          MenuItemButton(
                            onPressed: () =>
                                viewModel.setSort.run(ContentSort.byName),
                            leadingIcon: const Icon(Symbols.text_fields),
                            trailingIcon: viewModel.sort == ContentSort.byName
                                ? const Icon(Symbols.check)
                                : null,
                            child: const Text('Per nome'),
                          ),
                          MenuItemButton(
                            onPressed: () =>
                                viewModel.setSort.run(ContentSort.byDate),
                            leadingIcon: const Icon(Symbols.access_time),
                            trailingIcon: viewModel.sort == ContentSort.byDate
                                ? const Icon(Symbols.check)
                                : null,
                            child: const Text('Per data'),
                          ),
                        ],
                        builder: (_, controller, _) => IconButton(
                          onPressed: () => controller.isOpen
                              ? controller.close()
                              : controller.open(),
                          tooltip: 'Ordina',
                          icon: const Icon(Symbols.sort),
                        ),
                      ),
                    ],
                    primary: false,
                    floating: true,
                    snap: true,
                    forceMaterialTransparency: true,
                  ),
                ),
                SliverAppBar(
                  flexibleSpace: FlexibleSpaceBar(
                    background: CategoryContentAndTypeSelection(
                      key: ObjectKey(viewModel),
                      selectedCategories: viewModel.selectedCategories,
                      selectedTypes: viewModel.selectedTypes,
                      onCategorySelectionChanged:
                          viewModel.setSelectedCategories,
                      onTypeSelectionChanged: viewModel.setSelectedTypes,
                    ),
                  ),
                  automaticallyImplyLeading: false,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  pinned: true,
                ),
              ],
              body: CustomScrollView(
                slivers: [
                  if (viewModel.load.isRunningSync.value ||
                      snapshot.isRunning ||
                      snapshot.idle)
                    const SkeletonContentSliverGrid()
                  else if (snapshot.completed)
                    if (viewModel.content.isEmpty)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: EmptyView(
                          text: Text('Nessun contenuto per questa selezione.'),
                        ),
                      )
                    else
                      ContentSliverGrid(
                        viewModel.content,
                        onPressed: _buildStoryRoute,
                      )
                  else if (snapshot.hasFailure)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyView(
                        text: const Text(
                          'Si è verificato un errore durante il caricamento.',
                        ),
                        action: TextButton(
                          onPressed: viewModel.refresh,
                          child: const Text('Riprova'),
                        ),
                      ),
                    )
                  else
                    const SkeletonContentSliverGrid(),
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _buildStoryRoute(ContentBase content) {
    if (!mounted) return;
    final nextRoute = switch (GoRouterState.of(context).name) {
      RouteNames.eventsCategory => RouteNames.eventsCategoryPost,
      RouteNames.favouritesCategory => RouteNames.favouritesCategoryPost,
      RouteNames.homeCategory => RouteNames.homeCategoryPost,
      _ => null,
    };

    if (nextRoute != null) {
      GoRouter.of(context).goNamed(
        nextRoute,
        pathParameters: {
          'id': content.remoteId.toString(),
          'categorySlug': RouteParameters.categorySlug(content.category),
        },
        queryParameters: {
          'type': RouteParameters.contentTypeSlug(
            content is Event ? ContentType.event : ContentType.place,
          ),
        },
      );
    }
  }
}
