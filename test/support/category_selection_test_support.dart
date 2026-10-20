import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/content_type.dart';
import 'package:moliseis/ui/category/widgets/category_content_and_type_selection.dart';
import 'package:moliseis/ui/core/themes/app_theme_data.dart';

/// Rebuilds the real adaptive selector with independent confirmed snapshots.
///
/// Owner keys model CategoryScreen ownership without requiring content queries.
class CategorySelectionTestHarness extends ChangeNotifier {
  CategorySelectionTestHarness({
    this.categories = const {ContentCategory.nature},
    this.types = const {ContentType.event},
  }) {
    router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: ListenableBuilder(
              listenable: this,
              builder: (_, _) {
                final ownerCalls = calls;
                return visible
                    ? CategoryContentAndTypeSelection(
                        key: ObjectKey(owner),
                        selectedCategories: UnmodifiableSetView(
                          Set.of(categories),
                        ),
                        selectedTypes: UnmodifiableSetView(Set.of(types)),
                        onCategorySelectionChanged: ownerCalls.add,
                        onTypeSelectionChanged: ownerCalls.add,
                      )
                    : const SizedBox.shrink();
              },
            ),
          ),
        ),
      ],
    );
  }

  Set<ContentCategory> categories;
  Set<ContentType> types;
  Object owner = Object();
  bool visible = true;
  List<Set<Object>> calls = [];
  late final GoRouter router;

  void rebuild() => notifyListeners();

  void replaceOwner() {
    owner = Object();
    calls = [];
    rebuild();
  }

  Future<void> pump(WidgetTester tester, double width) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 900);
    addTearDown(tester.view.reset);
    addTearDown(dispose);
    await tester.pumpWidget(
      Builder(
        builder: (context) => MaterialApp.router(
          theme: AppThemeData.light(context: context),
          routerConfig: router,
        ),
      ),
    );
  }

  Future<void> open(WidgetTester tester, {required bool category}) async {
    await tester.tap(find.byType(InputChip).at(category ? 1 : 0));
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester, double width) async {
    await tester.tap(
      width == 400 ? find.byTooltip('Salva') : find.text('Salva'),
    );
    await tester.pumpAndSettle();
  }

  @override
  void dispose() {
    router.dispose();
    super.dispose();
  }
}
