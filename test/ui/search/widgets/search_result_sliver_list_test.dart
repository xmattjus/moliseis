// Sequential statements keep command scheduling assertions readable.
// ignore_for_file: cascade_invocations

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/domain/use-cases/favourite_get_ids_use_case.dart';
import 'package:moliseis/ui/core/ui/content/content_sliver_grid.dart';
import 'package:moliseis/ui/core/ui/skeletons/skeleton_content_sliver_grid.dart';
import 'package:moliseis/ui/favourite/view_models/favourite_view_model.dart';
import 'package:moliseis/ui/search/view_models/search_view_model.dart';
import 'package:moliseis/ui/search/widgets/search_result_sliver_list.dart';
import 'package:moliseis/utils/result.dart';

import '../../../support/command_test_support.dart';
import '../../../support/fake_repositories.dart';
import '../../../support/favourite_button_harness.dart';
import '../../../support/fixtures.dart';
import '../../../support/mock_logger.dart';

void main() {
  testWidgets('neutral/loading stay distinct from success and valid empty', (
    tester,
  ) async {
    final pending = Completer<Result<List<ContentBase>>>();
    final repository = FakeSearchRepository();
    repository.pendingGetResultsByQuery = pending;
    final vm = SearchViewModel(searchRepository: repository);
    final favourites = FavouriteViewModel(
      favouriteGetIdsUseCase: FavouriteGetIdsUseCase(
        eventRepository: FakeEventRepository(),
        placeRepository: FakePlaceRepository(),
      ),
    );
    addTearDown(favourites.dispose);
    await tester.pumpWidget(
      favouriteButtonHarness(
        viewModel: favourites,
        child: CustomScrollView(
          slivers: [
            SearchResultSliverList(viewModel: vm, onResultPressed: (_) {}),
          ],
        ),
      ),
    );
    expect(find.byType(SkeletonContentSliverGrid), findsOneWidget);
    expect(find.text('Non è stato trovato alcun risultato.'), findsNothing);
    vm.loadResults.run('molise');
    await pumpCommandTurns(tester);
    expect(find.byType(SkeletonContentSliverGrid), findsOneWidget);
    pending.complete(Result.success([makePlace()]));
    await pumpCommandTurns(tester);
    expect(find.byType(ContentSliverGrid), findsOneWidget);
    repository.pendingGetResultsByQuery = null;
    vm.loadResults.run('empty');
    await pumpCommandTurns(tester);
    expect(find.text('Non è stato trovato alcun risultato.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    vm.dispose();
    await tester.pump(const Duration(milliseconds: 50));
  });

  for (final runtime in [false, true]) {
    testWidgets(
      '${runtime ? 'unexpected' : 'domain'} failure renders retry and recovers',
      (tester) async {
        final logger = MockLogger();
        addTearDown(installCommandTestReporting(logger));
        final pending = Completer<Result<List<ContentBase>>>();
        final repository = FakeSearchRepository();
        repository.pendingGetResultsByQuery = pending;
        final vm = SearchViewModel(searchRepository: repository);
        var retries = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CustomScrollView(
                slivers: [
                  SearchResultSliverList(
                    viewModel: vm,
                    onResultPressed: (_) {},
                    onRetrySearchPressed: () {
                      retries++;
                      repository.pendingGetResultsByQuery = null;
                      vm.loadResults.run('molise');
                    },
                  ),
                ],
              ),
            ),
          ),
        );
        vm.loadResults.run('molise');
        await pumpCommandTurns(tester);
        if (runtime) {
          pending.completeError(StateError('unexpected'), StackTrace.current);
        } else {
          pending.complete(Result.error(TestException('expected')));
        }
        await pumpCommandTurns(tester);
        expect(
          find.text('Si è verificato un errore durante il caricamento.'),
          findsOneWidget,
        );
        expect(find.byType(SkeletonContentSliverGrid), findsNothing);
        expect(logger.calls, hasLength(runtime ? 1 : 0));
        await tester.tap(find.text('Riprova'));
        await pumpCommandTurns(tester);
        expect(retries, 1);
        expect(
          find.text('Non è stato trovato alcun risultato.'),
          findsOneWidget,
        );
        await tester.pumpWidget(const SizedBox.shrink());
        vm.dispose();
        await tester.pump(const Duration(milliseconds: 50));
      },
    );
  }
}
