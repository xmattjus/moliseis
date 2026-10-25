import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/content_sort.dart';
import 'package:moliseis/domain/models/place.dart';
import 'package:moliseis/ui/category/widgets/category_content_and_type_selection.dart';
import 'package:moliseis/ui/core/ui/content/content_sliver_grid.dart';
import 'package:moliseis/ui/core/ui/empty_view.dart';
import 'package:moliseis/ui/core/ui/skeletons/skeleton_content_sliver_grid.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/result_command.dart';

import '../../../support/category_screen_test_support.dart';
import '../../../support/command_test_support.dart';
import '../../../support/fake_repositories.dart';
import '../../../support/fixtures.dart';

void main() {
  testCategoryScreen(
    'first frame and completed sort preserve pending skeleton',
    (tester, data) async {
      final pending = Completer<Result<List<Place>>>();
      data.places.getByCategoriesHandler = (_) => pending.future;
      final vm = data.create();
      final screen = CategoryScreenTestHarness(vm);
      await screen.pump(tester);
      expect(vm.selectedCategories, {ContentCategory.history});
      expect(find.byType(SkeletonContentSliverGrid), findsOneWidget);
      expect(find.byType(ContentSliverGrid), findsNothing);
      expect(find.byType(EmptyView), findsNothing);
      vm.setSort.run(ContentSort.byDate);
      await pumpCommandTurns(tester);
      expect(vm.setSort.results.value.completed, isTrue);
      expect(find.byType(SkeletonContentSliverGrid), findsOneWidget);
      expect(find.byType(EmptyView), findsNothing);
      pending.complete(const Result.success([]));
      await tester.pumpAndSettle();
      expect(find.byType(SkeletonContentSliverGrid), findsNothing);
      expect(
        find.text('Nessun contenuto per questa selezione.'),
        findsOneWidget,
      );
      expect(find.text('Riprova'), findsNothing);
    },
  );

  for (final runtime in [false, true]) {
    testCategoryScreen('${runtime ? 'runtime' : 'domain'} failure offers retry '
        'then empty success', (tester, data) async {
      final pending = Completer<Result<List<Place>>>();
      data.places.getByCategoriesHandler = (_) => pending.future;
      final vm = data.create();
      final screen = CategoryScreenTestHarness(vm);
      await screen.pump(tester);
      await pumpCommandTurns(tester);
      final failure = runtime
          ? StateError('load runtime')
          : TestException('load domain');
      if (runtime) {
        pending.completeError(failure, StackTrace.current);
      } else {
        pending.complete(Result.error(failure as Exception));
      }
      await tester.pumpAndSettle();
      expect(find.text('Riprova'), findsOneWidget);
      expect(find.byType(SkeletonContentSliverGrid), findsNothing);
      expect(find.byType(ContentSliverGrid), findsNothing);
      expect(
        runtime
            ? vm.load.results.value.unexpectedError
            : vm.load.results.value.domainError,
        same(failure),
      );
      expect(data.logger.calls, runtime ? hasLength(1) : isEmpty);
      final retry = Completer<Result<List<Place>>>();
      data.places.getByCategoriesHandler = (_) => retry.future;
      await tester.tap(find.text('Riprova'));
      await tester.pump();
      expect(find.byType(SkeletonContentSliverGrid), findsOneWidget);
      expect(find.text('Riprova'), findsNothing);
      retry.complete(const Result.success([]));
      await tester.pumpAndSettle();
      expect(
        find.text('Nessun contenuto per questa selezione.'),
        findsOneWidget,
      );
      expect(data.places.getByCategoriesCallCount, 2);
      expect(tester.takeException(), isNull);
    });
  }

  for (final hasContent in [false, true]) {
    testCategoryScreen(
      'refresh from ${hasContent ? 'content' : 'empty'} renders loading '
      'on its first frame and then failure',
      (tester, data) async {
        final place = makePlace(name: 'Retained place');
        final content = hasContent ? [place] : <Place>[];
        data.places.getByCategoriesResult = Result.success(content);
        final vm = data.create();
        final screen = CategoryScreenTestHarness(vm);
        await screen.pump(tester);
        await tester.pumpAndSettle();
        expect(
          find.byType(ContentSliverGrid),
          hasContent ? findsOneWidget : findsNothing,
        );
        expect(
          find.text('Nessun contenuto per questa selezione.'),
          hasContent ? findsNothing : findsOneWidget,
        );
        final pending = Completer<Result<List<Place>>>();
        data.places.getByCategoriesHandler = (_) => pending.future;
        vm.refresh();
        await tester.pump();
        expect(vm.content, content);
        expect(find.byType(SkeletonContentSliverGrid), findsOneWidget);
        expect(find.byType(ContentSliverGrid), findsNothing);
        expect(find.byType(EmptyView), findsNothing);
        pending.complete(Result.error(TestException('refresh failed')));
        await tester.pumpAndSettle();
        expect(vm.content, content);
        expect(find.text('Riprova'), findsOneWidget);
        expect(find.byType(ContentSliverGrid), findsNothing);
        expect(find.text(place.name), findsNothing);
      },
    );
  }

  testCategoryScreen(
    'changed filter first frame cannot flash old or empty content',
    (tester, data) async {
      data.places.getByCategoriesResult = Result.success([makePlace()]);
      final vm = data.create();
      final screen = CategoryScreenTestHarness(vm);
      await screen.pump(tester);
      await tester.pumpAndSettle();
      expect(find.byType(ContentSliverGrid), findsOneWidget);
      final pending = Completer<Result<List<Place>>>();
      data.places.getByCategoriesHandler = (_) => pending.future;
      vm.setSelectedCategories({ContentCategory.nature});
      await tester.pump();
      expect(find.byType(SkeletonContentSliverGrid), findsOneWidget);
      expect(find.byType(ContentSliverGrid), findsNothing);
      expect(find.byType(EmptyView), findsNothing);
      pending.complete(const Result.success([]));
      await tester.pumpAndSettle();
      expect(
        find.text('Nessun contenuto per questa selezione.'),
        findsOneWidget,
      );
    },
  );

  testCategoryScreen('sort menu follows optimistic preference during write', (
    tester,
    data,
  ) async {
    final pending = Completer<Result<void>>();
    data.settings.onSetContentSort = (_) => pending.future;
    final vm = data.create();
    final screen = CategoryScreenTestHarness(vm);
    await screen.pump(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Ordina'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Per data'));
    await pumpCommandTurns(tester);
    expect(vm.sort, ContentSort.byDate);
    expect(data.settings.contentSort, ContentSort.byName);
    expect(vm.setSort.isRunningSync.value, isTrue);
    await tester.tap(find.byTooltip('Ordina'));
    await tester.pumpAndSettle();
    final dateItem = tester.widget<MenuItemButton>(
      find.ancestor(
        of: find.text('Per data'),
        matching: find.byType(MenuItemButton),
      ),
    );
    final nameItem = tester.widget<MenuItemButton>(
      find.ancestor(
        of: find.text('Per nome'),
        matching: find.byType(MenuItemButton),
      ),
    );
    expect(dateItem.trailingIcon, isNotNull);
    expect(nameItem.trailingIcon, isNull);
    pending.complete(Result.error(TestException('sort failed')));
    await tester.pumpAndSettle();
    expect(vm.sort, ContentSort.byDate);
    expect(find.text('Nessun contenuto per questa selezione.'), findsOneWidget);
    expect(find.text('Riprova'), findsNothing);
  });

  for (final width in [400.0, 1000.0]) {
    for (final empty in [false, true]) {
      testCategoryScreen('screen owner replacement ignores '
          '${empty ? 'empty' : 'edited'} modal at width $width', (
        tester,
        data,
      ) async {
        final old = data.create();
        final screen = CategoryScreenTestHarness(old);
        await screen.pump(tester, width: width);
        await tester.pumpAndSettle();
        final oldState = tester.state(
          find.byType(CategoryContentAndTypeSelection),
        );
        await tester.tap(find.byType(InputChip).at(1));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey(ContentCategory.history)));
        if (!empty) {
          await tester.tap(find.byKey(const ValueKey(ContentCategory.nature)));
        }
        final replacement = data.create();
        screen.owner.value = replacement;
        await tester.pump();
        final newState = tester.state(
          find.byType(CategoryContentAndTypeSelection),
        );
        expect(newState, isNot(same(oldState)));
        old.dispose();
        await tester.tap(
          width == 400 ? find.byTooltip('Salva') : find.text('Salva'),
        );
        await tester.pumpAndSettle();
        expect(old.selectedCategories, {ContentCategory.history});
        expect(replacement.selectedCategories, {ContentCategory.history});
        expect(data.places.getByCategoriesCallCount, 2);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
