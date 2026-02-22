import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/content_sort.dart';
import 'package:moliseis/domain/models/content_type.dart';
import 'package:moliseis/domain/models/event_content.dart';
import 'package:moliseis/routing/route_names.dart';
import 'package:moliseis/routing/route_paths.dart';
import 'package:moliseis/ui/category/view_models/category_view_model.dart';
import 'package:moliseis/ui/category/widgets/category_content_and_type_selection.dart';
import 'package:moliseis/ui/core/ui/content/content_sliver_grid.dart';
import 'package:moliseis/ui/core/ui/custom_back_button.dart';
import 'package:moliseis/ui/core/ui/skeletons/skeleton_content_sliver_grid.dart';

class CategoryScreen extends StatefulWidget {
  const CategoryScreen({super.key, required this.viewModel});

  final CategoryViewModel viewModel;

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  String _currentUri = '';

  @override
  Widget build(BuildContext context) {
    _currentUri = GoRouterState.of(context).fullPath.toString();

    return Scaffold(
      body: SafeArea(
        child: NestedScrollView(
          headerSliverBuilder: (BuildContext context, _) {
            return <Widget>[
              SliverOverlapAbsorber(
                handle: NestedScrollView.sliverOverlapAbsorberHandleFor(
                  context,
                ),
                sliver: SliverAppBar(
                  leading: const CustomBackButton(),
                  title: const Text('Categorie'),
                  actions: <Widget>[
                    ListenableBuilder(
                      listenable: widget.viewModel.setSort,
                      builder: (context, child) {
                        return MenuAnchor(
                          menuChildren: <Widget>[
                            MenuItemButton(
                              onPressed: () => widget.viewModel.setSort.execute(
                                ContentSort.byName,
                              ),
                              leadingIcon: const Icon(Symbols.text_fields),
                              trailingIcon:
                                  widget.viewModel.sort == ContentSort.byName
                                  ? const Icon(Symbols.check)
                                  : null,
                              child: const Text('Per nome'),
                            ),
                            MenuItemButton(
                              onPressed: () => widget.viewModel.setSort.execute(
                                ContentSort.byDate,
                              ),
                              leadingIcon: const Icon(Symbols.access_time),
                              trailingIcon:
                                  widget.viewModel.sort == ContentSort.byDate
                                  ? const Icon(Symbols.check)
                                  : null,
                              child: const Text('Per data'),
                            ),
                          ],
                          builder: (_, controller, _) {
                            return IconButton(
                              onPressed: () {
                                controller.isOpen
                                    ? controller.close()
                                    : controller.open();
                              },
                              tooltip: 'Ordina',
                              icon: const Icon(Symbols.sort),
                            );
                          },
                        );
                      },
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
                    selectedCategories: widget.viewModel.selectedCategories,
                    selectedTypes: widget.viewModel.selectedTypes,
                    onContentSelectionChanged:
                        (Set<ContentCategory> categories) => widget
                            .viewModel
                            .setSelectedCategories
                            .execute(categories),
                    onTypeSelectionChanged: (Set<ContentType> types) =>
                        widget.viewModel.setSelectedTypes.execute(types),
                  ),
                ),
                automaticallyImplyLeading: false,
                elevation: 0,
                scrolledUnderElevation: 0,
                backgroundColor: Theme.of(context).colorScheme.surface,
                pinned: true,
              ),
            ];
          },
          body: CustomScrollView(
            slivers: <Widget>[
              ListenableBuilder(
                listenable: widget.viewModel,
                builder: (context, _) {
                  if (widget.viewModel.load.completed ||
                      widget.viewModel.setSort.completed) {
                    return ContentSliverGrid(
                      widget.viewModel.content,
                      onPressed: (ContentBase content) =>
                          _buildStoryRoute(content),
                    );
                  }

                  return const SkeletonContentSliverGrid();
                },
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16.0)),
            ],
          ),
        ),
      ),
    );
  }

  void _buildStoryRoute(ContentBase content) {
    String? nextRoute;

    if (_currentUri.startsWith('${RoutePaths.events}/category')) {
      nextRoute = RouteNames.eventsCategoryPost;
    } else if (_currentUri.startsWith('${RoutePaths.favourites}/category')) {
      nextRoute = RouteNames.favouritesCategoryPost;
    } else if (_currentUri.startsWith('${RoutePaths.home}/category')) {
      nextRoute = RouteNames.homeCategoryPost;
    }

    if (nextRoute != null) {
      final map = {
        'id': content.remoteId.toString(),
        'index': (content.category.index - 1).toString(),
      };

      GoRouter.of(context).goNamed(
        nextRoute,
        pathParameters: map,
        queryParameters: {
          'isEvent': (content is EventContent ? 'true' : 'false'),
        },
      );
    }
  }
}
