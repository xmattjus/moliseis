import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:meta/meta.dart';
import 'package:moliseis/domain/use-cases/favourite_get_ids_use_case.dart';
import 'package:moliseis/ui/category/view_models/category_view_model.dart';
import 'package:moliseis/ui/category/widgets/category_screen.dart';
import 'package:moliseis/ui/core/themes/app_theme_data.dart';
import 'package:moliseis/ui/favourite/view_models/favourite_view_model.dart';
import 'package:provider/provider.dart';

import 'category_view_model_test_support.dart';
import 'command_test_support.dart';
import 'fake_repositories.dart';

/// Hosts the real Category screen and its popup routes with replaceable owners.
/// Category owners remain explicitly owned by the calling test's data harness.
class CategoryScreenTestHarness {
  CategoryScreenTestHarness(CategoryViewModel viewModel)
    : owner = ValueNotifier(viewModel) {
    router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => ValueListenableBuilder<CategoryViewModel>(
            valueListenable: owner,
            builder: (_, viewModel, _) => CategoryScreen(viewModel: viewModel),
          ),
        ),
      ],
    );
  }

  final ValueNotifier<CategoryViewModel> owner;
  late final GoRouter router;

  Widget get app => ChangeNotifierProvider<FavouriteViewModel>(
    create: (_) => FavouriteViewModel(
      favouriteGetIdsUseCase: FavouriteGetIdsUseCase(
        eventRepository: FakeEventRepository(),
        placeRepository: FakePlaceRepository(),
      ),
    ),
    child: Builder(
      builder: (context) => MaterialApp.router(
        theme: AppThemeData.light(context: context),
        routerConfig: router,
      ),
    ),
  );

  Future<void> pump(WidgetTester tester, {double width = 400}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 900);
    addTearDown(tester.view.reset);
    addTearDown(dispose);
    await tester.pumpWidget(app);
  }

  void dispose() {
    router.dispose();
    owner.dispose();
  }
}

/// Unmounts screen observations before disposing explicitly owned commands.
@isTest
void testCategoryScreen(
  String description,
  Future<void> Function(WidgetTester, CategoryTestHarness) body,
) {
  testWidgets(description, (tester) async {
    final data = CategoryTestHarness();
    final restore = installCommandTestReporting(data.logger);
    try {
      await body(tester, data);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await data.dispose(tester);
      restore();
    }
  });
}
