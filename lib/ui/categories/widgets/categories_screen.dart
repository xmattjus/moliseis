import 'dart:collection' show UnmodifiableListView;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:moliseis/domain/models/attraction/attraction_sort.dart';
import 'package:moliseis/domain/models/attraction/attraction_type.dart';
import 'package:moliseis/routing/route_names.dart';
import 'package:moliseis/routing/route_paths.dart';
import 'package:moliseis/ui/categories/view_models/categories_view_model.dart';
import 'package:moliseis/ui/core/ui/attraction_list_view_responsive.dart';
import 'package:moliseis/ui/core/ui/custom_back_button.dart';
import 'package:moliseis/ui/settings/view_models/settings_view_model.dart';
import 'package:moliseis/utils/extensions.dart';
import 'package:provider/provider.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key, this.tabIndex});

  final String? tabIndex;

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen>
    with TickerProviderStateMixin {
  late final CategoriesViewModel _viewModel;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();

    final initialIndex = int.parse(widget.tabIndex ?? '0');

    _viewModel = context.read();

    _tabController = TabController(
      initialIndex: initialIndex,
      length: _viewModel.attractionTypes.length,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CategoriesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tabIndex != oldWidget.tabIndex && widget.tabIndex != null) {
      _tabController.index = int.parse(widget.tabIndex!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Consumer<SettingsViewModel>(
          builder: (context, value, child) {
            return NestedScrollView(
              headerSliverBuilder: (
                BuildContext context,
                bool innerBoxIsScrolled,
              ) {
                return <Widget>[
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
                              onPressed: () {
                                value.saveAttractionSortBy(
                                  AttractionSort.byName,
                                );
                              },
                              leadingIcon: const Icon(Icons.text_fields),
                              trailingIcon:
                                  value.attractionSortBy ==
                                          AttractionSort.byName
                                      ? const Icon(Icons.check)
                                      : null,
                              child: const Text('Per nome'),
                            ),
                            MenuItemButton(
                              onPressed: () {
                                value.saveAttractionSortBy(
                                  AttractionSort.byDate,
                                );
                              },
                              leadingIcon: const Icon(Icons.access_time),
                              trailingIcon:
                                  value.attractionSortBy ==
                                          AttractionSort.byDate
                                      ? const Icon(Icons.check)
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
                              icon: const Icon(Icons.sort),
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
                    title: TabBar(
                      tabs: UnmodifiableListView<Tab>(
                        _viewModel.attractionTypes.map<Tab>(
                          (AttractionType type) => Tab(text: type.readableName),
                        ),
                      ),
                      controller: _tabController,
                      automaticIndicatorColorAdjustment: false,
                      isScrollable: true,
                    ),
                    automaticallyImplyLeading: false,
                    elevation: 0,
                    scrolledUnderElevation: 0,
                    backgroundColor: Theme.of(context).canvasColor,
                    // primary: false,
                    pinned: true,
                  ),
                ];
              },
              body: TabBarView(
                controller: _tabController,
                children:
                    _viewModel.attractionTypes.map((type) {
                      return _CategoriesScreenContent(
                        // key: ValueKey(type.name),
                        type: type,
                        orderBy: value.attractionSortBy,
                        viewModel: _viewModel,
                      );
                    }).toList(),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CategoriesScreenContent extends StatefulWidget {
  const _CategoriesScreenContent({
    required this.type,
    required this.orderBy,
    required this.viewModel,
  });

  final AttractionType type;
  final AttractionSort orderBy;
  final CategoriesViewModel viewModel;

  @override
  State<_CategoriesScreenContent> createState() =>
      _CategoriesScreenContentState();
}

class _CategoriesScreenContentState extends State<_CategoriesScreenContent> {
  late Future<List<int>> _future;

  AttractionType get _type => widget.type;

  @override
  void initState() {
    super.initState();

    _updateFuture(_type, widget.orderBy);
  }

  @override
  void didUpdateWidget(covariant _CategoriesScreenContent oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.orderBy != oldWidget.orderBy || widget.type != oldWidget.type) {
      _updateFuture(_type, widget.orderBy);
    }
  }

  @override
  Widget build(BuildContext context) {
    final routerState = GoRouterState.of(context).uri;

    return Builder(
      builder: (context) {
        return CustomScrollView(
          // key: PageStorageKey<String>(widget.type.name),
          slivers: <Widget>[
            SliverOverlapInjector(
              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              sliver: AttractionListViewResponsive(
                _future,
                onPressed: (id) {
                  final typeIndex =
                      widget.viewModel.getTypeIndexFromAttractionId(id) - 1;

                  var nextPath = RouteNames.homeCategoryStory;

                  if (routerState.toString().startsWith(
                    RoutePaths.favourites,
                  )) {
                    nextPath = RouteNames.favouritesCategoryStory;
                  }

                  GoRouter.of(context).goNamed(
                    nextPath,
                    pathParameters: {
                      'index': typeIndex.toString(),
                      'id': id.toString(),
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateFuture(
    AttractionType type,
    AttractionSort orderBy,
  ) async {
    _future = widget.viewModel.getAttractionIdsByType(type, orderBy);
  }
}
