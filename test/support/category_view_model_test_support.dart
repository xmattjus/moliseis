import 'package:flutter_test/flutter_test.dart';
import 'package:meta/meta.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/use-cases/category_use_case.dart';
import 'package:moliseis/domain/use-cases/explore_use_case.dart';
import 'package:moliseis/ui/category/view_models/category_view_model.dart';

import 'command_test_support.dart';
import 'fake_repositories.dart';
import 'mock_logger.dart';
import 'ordinary_view_model_lifecycle_support.dart';

/// Real command owners sharing configurable repositories and safe teardown.
class CategoryTestHarness {
  final places = FakePlaceRepository();
  final events = FakeEventRepository();
  final settings = FakeSettingsRepository();
  final logger = MockLogger();
  final _owners = <CategoryViewModel>[];

  CategoryViewModel create({
    Set<ContentCategory> initialCategories = const {ContentCategory.history},
  }) {
    final vm = CategoryViewModel(
      initialCategories: initialCategories,
      categoryUseCase: CategoryUseCase(
        eventRepository: events,
        placeRepository: places,
      ),
      exploreGetByIdUseCase: ExploreUseCase(
        eventRepository: events,
        placeRepository: places,
      ),
      settingsRepository: settings,
    );
    _owners.add(vm);
    return vm;
  }

  Future<void> dispose(WidgetTester tester) async {
    for (final vm in _owners) {
      vm.dispose();
    }
    await pumpPhysicalCommandDisposal(tester);
  }
}

/// Keeps command cleanup inside the virtual clock, including failed assertions.
@isTest
void testCategoryViewModel(
  String description,
  Future<void> Function(WidgetTester tester, CategoryTestHarness harness) body,
) {
  testWidgets(description, (tester) async {
    final harness = CategoryTestHarness();
    final restore = installCommandTestReporting(harness.logger);
    try {
      await body(tester, harness);
    } finally {
      await harness.dispose(tester);
      restore();
    }
  });
}
