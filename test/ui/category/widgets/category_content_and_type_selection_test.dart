import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/content_type.dart';
import 'package:moliseis/ui/category/widgets/category_content_and_type_selection.dart';
import 'package:moliseis/ui/core/themes/app_theme_data.dart';

void main() {
  for (final width in [400.0, 1000.0]) {
    for (final category in [false, true]) {
      testWidgets(
        '${category ? 'category' : 'type'} publishes and resets only after '
        '${width == 400 ? 'sheet' : 'dialog'} closes',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = Size(width, 900);
          addTearDown(tester.view.reset);
          final categoryCalls = <Set<ContentCategory>>[];
          final typeCalls = <Set<ContentType>>[];
          final router = GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (_, _) => Scaffold(
                  body: CategoryContentAndTypeSelection(
                    selectedCategories: const {ContentCategory.nature},
                    selectedTypes: const {ContentType.event},
                    onCategorySelectionChanged: categoryCalls.add,
                    onTypeSelectionChanged: typeCalls.add,
                  ),
                ),
              ),
            ],
          );
          addTearDown(router.dispose);
          await tester.pumpWidget(
            Builder(
              builder: (context) => MaterialApp.router(
                theme: AppThemeData.light(context: context),
                routerConfig: router,
              ),
            ),
          );
          await tester.tap(find.byType(InputChip).at(category ? 1 : 0));
          await tester.pumpAndSettle();
          expect(
            find.byType(AlertDialog),
            width == 400 ? findsNothing : findsOneWidget,
          );
          expect(
            find.byType(BottomSheet),
            width == 400 ? findsOneWidget : findsNothing,
          );
          await tester.tap(
            find.byKey(
              category
                  ? const ValueKey(ContentCategory.nature)
                  : const ValueKey(ContentType.event),
            ),
          );
          await tester.pump();
          expect(categoryCalls, isEmpty);
          expect(typeCalls, isEmpty);
          await tester.tap(
            width == 400 ? find.byTooltip('Salva') : find.text('Salva'),
          );
          await tester.pumpAndSettle();
          if (category) {
            expect(categoryCalls, [
              ContentCategory.values
                  .where((value) => value != ContentCategory.unknown)
                  .toSet(),
            ]);
            expect(typeCalls, isEmpty);
          } else {
            expect(typeCalls, [ContentType.values.toSet()]);
            expect(categoryCalls, isEmpty);
          }
        },
      );
    }
  }

  testWidgets('closing after selection owner unmounts publishes nothing', (
    tester,
  ) async {
    final visible = ValueNotifier(true);
    addTearDown(visible.dispose);
    var callbackCount = 0;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: ValueListenableBuilder<bool>(
              valueListenable: visible,
              builder: (_, show, _) => show
                  ? CategoryContentAndTypeSelection(
                      selectedCategories: const {ContentCategory.nature},
                      selectedTypes: const {ContentType.event},
                      onCategorySelectionChanged: (_) => callbackCount++,
                      onTypeSelectionChanged: (_) => callbackCount++,
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      Builder(
        builder: (context) => MaterialApp.router(
          theme: AppThemeData.light(context: context),
          routerConfig: router,
        ),
      ),
    );
    await tester.tap(find.byType(InputChip).first);
    await tester.pumpAndSettle();
    visible.value = false;
    await tester.pump();
    expect(find.byType(CategoryContentAndTypeSelection), findsNothing);
    await tester.tap(find.byTooltip('Salva'));
    await tester.pumpAndSettle();
    expect(callbackCount, 0);
    expect(tester.takeException(), isNull);
  });
}
