// Sequential statements keep command scheduling assertions readable.
// ignore_for_file: cascade_invocations

import 'dart:async';

import 'package:flutter/foundation.dart'
    show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/domain/models/content_base.dart';

import 'package:moliseis/routing/route_names.dart';
import 'package:moliseis/ui/search/view_models/search_view_model.dart';
import 'package:moliseis/ui/search/widgets/components/app_search_anchor.dart';
import 'package:moliseis/ui/search/widgets/search_result_screen.dart';
import 'package:moliseis/utils/result.dart';

import '../../../../support/command_test_support.dart';
import '../../../../support/fake_repositories.dart';
import '../../../../support/fixtures.dart';
import '../../../../support/mock_logger.dart';
import '../../../../support/predictive_back.dart';

void main() {
  group('AppSearchAnchor', () {
    for (final initial in [
      <String>[],
      ['initial'],
    ]) {
      testWidgets(
        'H10 open unchanged popup reacts to confirmed history, failure '
        'and read-only reload initial=$initial',
        (tester) async {
          final reads = <Completer<Result<List<String>>>>[];
          final repository = FakeSearchRepository()
            ..historyReadHandler = () {
              final read = Completer<Result<List<String>>>();
              reads.add(read);
              return read.future;
            };
          final fixture = _SearchFixture(
            cleanupOnClose: false,
            surfaceSize: const Size(390, 844),
            searchRepository: repository,
          );
          addTearDown(fixture.dispose);
          await fixture.pumpApp(tester);
          reads.single.complete(Result.success(initial));
          await pumpCommandTurns(tester);
          await _openSearch(tester, fixture);
          final oldAnchor = tester.widget<SearchAnchor>(
            find.byType(SearchAnchor),
          );
          fixture.viewModel.requestPastSearchesRefresh();
          await pumpCommandTurns(tester);
          reads.last.complete(const Result.success(['confirmed A']));
          await pumpCommandTurns(tester);
          expect(find.widgetWithText(RawChip, 'confirmed A'), findsOneWidget);
          expect(fixture.controller.text, isEmpty);
          expect(fixture.controller.isOpen, isTrue);
          fixture.viewModel.requestPastSearchesRefresh();
          await pumpCommandTurns(tester);
          reads.last.complete(Result.error(TestException('read failed')));
          await pumpCommandTurns(tester);
          expect(find.widgetWithText(RawChip, 'confirmed A'), findsOneWidget);
          expect(
            find.text('Impossibile caricare la cronologia.'),
            findsOneWidget,
          );
          await tester.tap(find.text('Ricarica cronologia'));
          await pumpCommandTurns(tester);
          reads.last.complete(const Result.success(['confirmed B']));
          await pumpCommandTurns(tester);
          expect(find.widgetWithText(RawChip, 'confirmed B'), findsOneWidget);
          expect(find.widgetWithText(RawChip, 'confirmed A'), findsNothing);
          expect(
            find.text('Impossibile caricare la cronologia.'),
            findsNothing,
          );
          expect(repository.historyWrites, isEmpty);
          expect(fixture.controller.text, isEmpty);
          expect(fixture.controller.isOpen, isTrue);
          final staleReload = tester
              .widget<TextButton>(
                find.widgetWithText(TextButton, 'Ricarica cronologia'),
              )
              .onPressed!;
          fixture.controller.closeView(null);
          await tester.pumpAndSettle();
          await tester.pumpWidget(const SizedBox.shrink());
          staleReload();
          final count = reads.length;
          final stale = await oldAnchor.suggestionsBuilder(
            tester.element(find.byType(SizedBox).first),
            fixture.controller,
          );
          expect(stale, isNotEmpty);
          oldAnchor.viewBuilder!(stale);
          await pumpCommandTurns(tester);
          expect(reads, hasLength(count));
          expect(repository.historyWrites, isEmpty);
          expect(tester.takeException(), isNull);
          debugDefaultTargetPlatformOverride = null;
        },
      );
    }

    testWidgets('H10 replaced owner ignores old read and popup callbacks', (
      tester,
    ) async {
      final oldRead = Completer<Result<List<String>>>();
      final nextRead = Completer<Result<List<String>>>();
      final oldRepository = FakeSearchRepository(
        pastSearchesResult: const Result.success(['old confirmed']),
      );
      final nextRepository = FakeSearchRepository()
        ..pendingGetPastSearches = nextRead;
      final owner = SearchViewModel(searchRepository: oldRepository);
      final nextOwner = SearchViewModel(searchRepository: nextRepository);
      final controller = SearchController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppSearchAnchor(
              controller: controller,
              viewModel: owner,
              onSuggestionPressed: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(SearchBar));
      await tester.pumpAndSettle();
      final oldAnchor = tester.widget<SearchAnchor>(find.byType(SearchAnchor));
      final oldChip = tester.widget<RawChip>(
        find.widgetWithText(RawChip, 'old confirmed'),
      );
      final oldReload = tester
          .widget<TextButton>(
            find.widgetWithText(TextButton, 'Ricarica cronologia'),
          )
          .onPressed!;
      oldRepository.pendingGetPastSearches = oldRead;
      owner.requestPastSearchesRefresh();
      await pumpCommandTurns(tester);
      controller.closeView(null);
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppSearchAnchor(
              controller: controller,
              viewModel: nextOwner,
              onSuggestionPressed: (_) {},
            ),
          ),
        ),
      );
      owner.dispose();
      await tester.pumpAndSettle();
      await tester.tap(find.byType(SearchBar));
      await tester.pump(const Duration(seconds: 1));
      await pumpCommandTurns(tester);
      nextRead.complete(const Result.success(['new confirmed']));
      await pumpCommandTurns(tester);
      expect(nextOwner.pastSearches, ['new confirmed']);
      expect(controller.isOpen, isTrue);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(RawChip, 'new confirmed'), findsOneWidget);
      oldRead.complete(const Result.success(['stale completion']));
      oldReload();
      oldChip.onPressed!();
      oldChip.onDeleted!();
      oldAnchor.viewOnSubmitted!('stale submit');
      final staleView = oldAnchor.viewBuilder!(const []);
      expect(staleView, isA<SizedBox>());
      await pumpCommandTurns(tester);
      expect(find.widgetWithText(RawChip, 'new confirmed'), findsOneWidget);
      expect(find.widgetWithText(RawChip, 'stale completion'), findsNothing);
      expect(find.text('Impossibile caricare la cronologia.'), findsNothing);
      expect(controller.text, isEmpty);
      expect(controller.isOpen, isTrue);
      expect(oldRepository.historyWrites, isEmpty);
      expect(nextRepository.historyWrites, isEmpty);
      expect(nextRepository.getPastSearchesCallCount, 1);
      controller.closeView(null);
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      nextOwner.dispose();
      controller.dispose();
      await tester.pump(const Duration(milliseconds: 51));
      expect(tester.takeException(), isNull);
    });

    testWidgets('debounce admits only latest input and repeated builders '
        'do not postpone it', (tester) async {
      final repository = FakeSearchRepository();
      final fixture = _SearchFixture(
        cleanupOnClose: false,
        surfaceSize: const Size(390, 844),
        searchRepository: repository,
      );
      addTearDown(fixture.dispose);
      await fixture.pumpApp(tester);
      await _openSearch(tester, fixture);
      expect(
        tester.widget<SearchBar>(find.byType(SearchBar).last).hintText,
        'Cerca per luogo, evento o categoria',
      );
      fixture.controller.text = 'alpha';
      await tester.pump(const Duration(milliseconds: 200));
      fixture.controller.text = 'bravo';
      await tester.pump(const Duration(milliseconds: 300));
      expect(repository.capturedQueries, isEmpty);
      final anchor = tester.widget<SearchAnchor>(
        find.byType(SearchAnchor).first,
      );
      anchor.suggestionsBuilder(
        tester.element(find.byType(SearchAnchor).first),
        fixture.controller,
      );
      await tester.pump(const Duration(milliseconds: 199));
      expect(repository.capturedQueries, isEmpty);
      await tester.pump(const Duration(milliseconds: 1));
      await pumpCommandTurns(tester);
      expect(repository.capturedQueries, ['bravo']);
      fixture.controller.closeView(null);
      await tester.pumpAndSettle();
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('closing during debounce allows the same query on reopen', (
      tester,
    ) async {
      final repository = FakeSearchRepository();
      final fixture = _SearchFixture(
        cleanupOnClose: false,
        surfaceSize: const Size(390, 844),
        searchRepository: repository,
      );
      addTearDown(fixture.dispose);
      await fixture.pumpApp(tester);
      await _openSearch(tester, fixture);
      fixture.controller.text = 'alpha';
      await tester.pump(const Duration(milliseconds: 200));
      fixture.controller.closeView(null);
      await tester.pumpAndSettle();
      expect(repository.capturedQueries, isEmpty);
      await tester.tap(find.byType(SearchBar));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await pumpCommandTurns(tester);
      expect(repository.capturedQueries, ['alpha']);
      fixture.controller.closeView(null);
      await tester.pumpAndSettle();
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets(
      'old completion during next debounce cannot repopulate suggestions',
      (tester) async {
        final a = Completer<Result<List<ContentBase>>>();
        final b = Completer<Result<List<ContentBase>>>();
        final repository = FakeSearchRepository(
          resultsByQueryHandler: (query) =>
              query == 'alpha' ? a.future : b.future,
        );
        final fixture = _SearchFixture(
          cleanupOnClose: false,
          surfaceSize: const Size(390, 844),
          searchRepository: repository,
        );
        addTearDown(fixture.dispose);
        await fixture.pumpApp(tester);
        await _openSearch(tester, fixture);
        fixture.controller.text = 'alpha';
        await tester.pump(const Duration(milliseconds: 500));
        await pumpCommandTurns(tester);
        fixture.controller.text = 'bravo';
        a.complete(Result.success([makePlace()]));
        await pumpCommandTurns(tester);
        expect(fixture.viewModel.suggestions, isEmpty);
        expect(repository.capturedQueries, ['alpha']);
        await tester.pump(const Duration(milliseconds: 500));
        await pumpCommandTurns(tester);
        expect(repository.capturedQueries, ['alpha', 'bravo']);
        b.complete(const Result.success([]));
        await pumpCommandTurns(tester);
        fixture.controller.closeView(null);
        await tester.pumpAndSettle();
        debugDefaultTargetPlatformOverride = null;
      },
    );

    for (final short in ['a', '']) {
      testWidgets(
        'valid pending to ${short.isEmpty ? 'empty history' : 'short'} '
        'revokes suggestions',
        (tester) async {
          final pending = Completer<Result<List<ContentBase>>>();
          final repository = FakeSearchRepository(
            pastSearchesResult: const Result.success(['saved query']),
            resultsByQueryHandler: (_) => pending.future,
          );
          final fixture = _SearchFixture(
            cleanupOnClose: false,
            surfaceSize: const Size(390, 844),
            searchRepository: repository,
          );
          addTearDown(fixture.dispose);
          await fixture.pumpApp(tester);
          await _openSearch(tester, fixture);
          fixture.controller.text = 'alpha';
          await tester.pump(const Duration(milliseconds: 500));
          await pumpCommandTurns(tester);
          fixture.controller.text = short;
          pending.complete(Result.success([makePlace()]));
          await pumpCommandTurns(tester);
          expect(fixture.viewModel.suggestions, isEmpty);
          expect(repository.capturedQueries, ['alpha']);
          if (short.isEmpty) expect(find.text('saved query'), findsOneWidget);
          fixture.controller.closeView(null);
          await tester.pumpAndSettle();
          debugDefaultTargetPlatformOverride = null;
        },
      );
    }

    for (final replaceOwner in [false, true]) {
      testWidgets('${replaceOwner ? 'VM' : 'controller'} replacement '
          'cancels old debounce', (tester) async {
        final oldRepository = FakeSearchRepository();
        final newRepository = FakeSearchRepository();
        final oldVm = SearchViewModel(searchRepository: oldRepository);
        final newVm = SearchViewModel(searchRepository: newRepository);
        final oldController = SearchController();
        final newController = SearchController();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AppSearchAnchor(
                controller: oldController,
                viewModel: oldVm,
                onSuggestionPressed: (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final anchor = tester.widget<SearchAnchor>(find.byType(SearchAnchor));
        final element = tester.element(find.byType(SearchAnchor));
        oldController.text = 'alpha';
        anchor.suggestionsBuilder(element, oldController);
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AppSearchAnchor(
                controller: replaceOwner ? oldController : newController,
                viewModel: replaceOwner ? newVm : oldVm,
                onSuggestionPressed: (_) {},
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 600));
        await pumpCommandTurns(tester);
        expect(oldRepository.capturedQueries, isEmpty);
        expect(newRepository.capturedQueries, isEmpty);
        final currentAnchor = tester.widget<SearchAnchor>(
          find.byType(SearchAnchor),
        );
        final controller = replaceOwner ? oldController : newController;
        controller.text = 'bravo';
        currentAnchor.suggestionsBuilder(
          tester.element(find.byType(SearchAnchor)),
          controller,
        );
        await tester.pump(const Duration(milliseconds: 500));
        await pumpCommandTurns(tester);
        expect((replaceOwner ? newRepository : oldRepository).capturedQueries, [
          'bravo',
        ]);
        await tester.pumpWidget(const SizedBox.shrink());
        oldVm.dispose();
        newVm.dispose();
        oldController.dispose();
        newController.dispose();
        await tester.pump(const Duration(milliseconds: 50));
      });
    }

    testWidgets('closed popup callbacks cannot create new history intents', (
      tester,
    ) async {
      final repository = FakeSearchRepository(
        pastSearchesResult: const Result.success(['saved']),
      );
      final fixture = _SearchFixture(
        cleanupOnClose: false,
        surfaceSize: const Size(390, 844),
        searchRepository: repository,
      );
      addTearDown(fixture.dispose);
      await fixture.pumpApp(tester);
      await _openSearch(tester, fixture);
      final anchor = tester.widget<SearchAnchor>(find.byType(SearchAnchor));
      final chip = tester.widget<RawChip>(
        find.widgetWithText(RawChip, 'saved'),
      );
      fixture.controller.closeView(null);
      await tester.pumpAndSettle();
      anchor.viewOnSubmitted!('stale submit');
      chip.onPressed!();
      chip.onDeleted!();
      await pumpCommandTurns(tester);
      expect(repository.historyWrites, isEmpty);
      expect(fixture.controller.text, isEmpty);

      // A new popup does not restore authority to the old route callbacks.
      await tester.tap(find.byType(SearchBar));
      await tester.pumpAndSettle();
      anchor.viewOnSubmitted!('stale reopened submit');
      chip.onDeleted!();
      await pumpCommandTurns(tester);
      expect(repository.historyWrites, isEmpty);
      expect(fixture.controller.isOpen, isTrue);
      fixture.controller.closeView(null);
      await tester.pumpAndSettle();
      debugDefaultTargetPlatformOverride = null;
    });

    for (final replaceOwner in [false, true]) {
      testWidgets('cached history callbacks ignore '
          '${replaceOwner ? 'owner' : 'controller'} replacement', (
        tester,
      ) async {
        final repository = FakeSearchRepository(
          pastSearchesResult: const Result.success(['saved']),
        );
        final owner = SearchViewModel(searchRepository: repository);
        final replacement = SearchViewModel(
          searchRepository: FakeSearchRepository(),
        );
        final controller = SearchController();
        final nextController = SearchController();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AppSearchAnchor(
                controller: controller,
                viewModel: owner,
                onSuggestionPressed: (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byType(SearchBar));
        await tester.pumpAndSettle();
        final oldAnchor = tester.widget<SearchAnchor>(
          find.byType(SearchAnchor),
        );
        final chip = tester.widget<RawChip>(
          find.widgetWithText(RawChip, 'saved'),
        );
        chip.onDeleted!();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AppSearchAnchor(
                controller: replaceOwner ? controller : nextController,
                viewModel: replaceOwner ? replacement : owner,
                onSuggestionPressed: (_) {},
              ),
            ),
          ),
        );
        final currentController = replaceOwner ? controller : nextController;
        currentController.text = 'fresh input';
        chip.onPressed!();
        chip.onDeleted!();
        oldAnchor.viewOnSubmitted!('stale submit');
        await tester.pump(Durations.medium1);
        await pumpCommandTurns(tester);
        expect(currentController.text, 'fresh input');
        expect(repository.historyWrites, [
          (operation: 'remove', query: 'saved'),
        ]);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        owner.dispose();
        replacement.dispose();
        controller.dispose();
        nextController.dispose();
        await tester.pump(const Duration(milliseconds: 50));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('confirmed-history removal never edits controller text', (
      tester,
    ) async {
      final repository = FakeSearchRepository(
        pastSearchesResult: const Result.success(['saved']),
      );
      final fixture = _SearchFixture(
        cleanupOnClose: false,
        surfaceSize: const Size(390, 844),
        searchRepository: repository,
      );
      addTearDown(fixture.dispose);
      await fixture.pumpApp(tester);
      await _openSearch(tester, fixture);
      tester
          .widget<RawChip>(find.widgetWithText(RawChip, 'saved'))
          .onDeleted!();
      fixture.controller.text = 'new input';
      await tester.pump(Durations.medium1);
      await pumpCommandTurns(tester);
      expect(fixture.controller.text, 'new input');
      expect(repository.historyWrites, [(operation: 'remove', query: 'saved')]);
      fixture.controller.closeView(null);
      await tester.pumpAndSettle();
      debugDefaultTargetPlatformOverride = null;
    });

    for (final queued in [false, true]) {
      for (final runtimeFailure in [false, true]) {
        testWidgets('accepted ${queued ? 'queued' : 'head'} submit persists '
            'after immediate disposal, '
            '${runtimeFailure ? 'runtime' : 'success'} settlement', (
          tester,
        ) async {
          final first = Completer<Result<void>>();
          final write = Completer<Result<void>>();
          final logger = MockLogger();
          addTearDown(installCommandTestReporting(logger));
          final repository = FakeSearchRepository()
            ..historyAddHandler = (query) =>
                query == 'predecessor' ? first.future : write.future;
          final owner = SearchViewModel(searchRepository: repository);
          final controller = SearchController();
          var navigations = 0;
          var lateNotifications = 0;
          var disposed = false;
          owner.addListener(() {
            if (disposed) lateNotifications++;
          });
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: AppSearchAnchor(
                  controller: controller,
                  viewModel: owner,
                  onSuggestionPressed: (_) {},
                  onSubmitted: (_) {
                    navigations++;
                    owner.dispose();
                    disposed = true;
                  },
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byType(SearchBar));
          await tester.pumpAndSettle();
          if (queued) {
            owner.addToPastSearches('predecessor');
            await pumpCommandTurns(tester);
          }
          final submit = tester
              .widget<SearchAnchor>(find.byType(SearchAnchor))
              .viewOnSubmitted!;
          submit('accepted');
          expect(navigations, 1);
          expect(controller.isOpen, isFalse);
          expect(repository.historyWrites, [
            if (queued) (operation: 'add', query: 'predecessor'),
          ]);
          submit('stale');
          await tester.pumpWidget(const SizedBox.shrink());
          if (queued) first.complete(const Result.success(null));
          await pumpCommandTurns(tester);
          expect(repository.historyWrites, [
            if (queued) (operation: 'add', query: 'predecessor'),
            (operation: 'add', query: 'accepted'),
          ]);
          final failure = StateError('history write');
          if (runtimeFailure) {
            write.completeError(failure, StackTrace.current);
          } else {
            write.complete(const Result.success(null));
          }
          await pumpCommandTurns(tester);
          await tester.pumpAndSettle();
          expect(navigations, 1);
          expect(lateNotifications, 0);
          expect(logger.calls, hasLength(runtimeFailure ? 1 : 0));
          if (runtimeFailure) expect(logger.calls.single.error, same(failure));
          expect(tester.takeException(), isNull);
          controller.dispose();
        });
      }
    }

    testWidgets(
      'accepted write permits immediate navigation without optimistic dispatch',
      (tester) async {
        final repository = FakeSearchRepository();
        final owner = SearchViewModel(searchRepository: repository);
        final controller = SearchController();
        var navigations = 0;
        var closeOnMutation = false;
        owner.addListener(() {
          if (closeOnMutation && controller.isOpen) controller.closeView(null);
        });
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AppSearchAnchor(
                controller: controller,
                viewModel: owner,
                onSuggestionPressed: (_) {},
                onSubmitted: (_) => navigations++,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byType(SearchBar));
        await tester.pumpAndSettle();
        closeOnMutation = true;
        tester.widget<SearchAnchor>(find.byType(SearchAnchor)).viewOnSubmitted!(
          'accepted',
        );
        expect(navigations, 1);
        expect(controller.isOpen, isFalse);
        await pumpCommandTurns(tester);
        await tester.pumpAndSettle();
        expect(repository.historyWrites, [
          (operation: 'add', query: 'accepted'),
        ]);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        owner.dispose();
        controller.dispose();
        await tester.pump(const Duration(milliseconds: 50));
      },
    );

    group('compact full-screen search', () {
      testWidgets('fallback back closes the popup and keeps the route', (
        tester,
      ) async {
        final fixture = _compactFixture(cleanupOnClose: false);
        addTearDown(fixture.dispose);
        await fixture.pumpApp(tester);
        await _openSearch(tester, fixture);

        fixture.controller.text = 'molise';
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump();
        expect(await tester.binding.handlePopRoute(), isTrue);
        await tester.pumpAndSettle();

        _expectPopupClosed(fixture);
        expect(fixture.controller.text, 'molise');
        expect(tester.takeException(), isNull);
        debugDefaultTargetPlatformOverride = null;
      });

      testWidgets('predictive commit closes the popup and keeps the route', (
        tester,
      ) async {
        final fixture = _compactFixture(cleanupOnClose: false);
        addTearDown(fixture.dispose);
        await fixture.pumpApp(tester);
        await _openSearch(tester, fixture);

        await startPredictiveBack(tester);
        await commitPredictiveBack(tester);

        _expectPopupClosed(fixture);
        expect(tester.takeException(), isNull);
        debugDefaultTargetPlatformOverride = null;
      });

      testWidgets('leading button closes the popup and keeps the route', (
        tester,
      ) async {
        final fixture = _compactFixture(cleanupOnClose: false);
        addTearDown(fixture.dispose);
        await fixture.pumpApp(tester);
        await _openSearch(tester, fixture);

        await tester.tap(find.widgetWithIcon(IconButton, Icons.arrow_back));
        await tester.pumpAndSettle();

        _expectPopupClosed(fixture);
        expect(tester.takeException(), isNull);
        debugDefaultTargetPlatformOverride = null;
      });

      testWidgets(
        'programmatic closeView closes the popup and keeps the route',
        (tester) async {
          final fixture = _compactFixture(cleanupOnClose: false);
          addTearDown(fixture.dispose);
          await fixture.pumpApp(tester);
          await _openSearch(tester, fixture);

          fixture.controller.closeView(null);
          await tester.pumpAndSettle();

          _expectPopupClosed(fixture);
          expect(tester.takeException(), isNull);
          debugDefaultTargetPlatformOverride = null;
        },
      );
    });

    group('expanded non-full-screen search', () {
      testWidgets('fallback back closes the popup and keeps the route', (
        tester,
      ) async {
        final fixture = _expandedFixture(cleanupOnClose: false);
        addTearDown(fixture.dispose);
        await fixture.pumpApp(tester);
        await _openSearch(tester, fixture);

        expect(await tester.binding.handlePopRoute(), isTrue);
        await tester.pumpAndSettle();

        _expectPopupClosed(fixture);
        expect(tester.takeException(), isNull);
        debugDefaultTargetPlatformOverride = null;
      });

      testWidgets('barrier dismissal closes the popup and keeps the route', (
        tester,
      ) async {
        final fixture = _expandedFixture(cleanupOnClose: false);
        addTearDown(fixture.dispose);
        await fixture.pumpApp(tester);
        await _openSearch(tester, fixture);

        await tester.tapAt(const Offset(640, 1500));
        await tester.pumpAndSettle();

        _expectPopupClosed(fixture);
        expect(tester.takeException(), isNull);
        debugDefaultTargetPlatformOverride = null;
      });

      testWidgets('predictive commit closes the popup and keeps the route', (
        tester,
      ) async {
        final fixture = _expandedFixture(cleanupOnClose: false);
        addTearDown(fixture.dispose);
        await fixture.pumpApp(tester);
        await _openSearch(tester, fixture);

        await startPredictiveBack(tester);
        await commitPredictiveBack(tester);

        _expectPopupClosed(fixture);
        expect(tester.takeException(), isNull);
        debugDefaultTargetPlatformOverride = null;
      });
    });

    group('production shell', () {
      testWidgets('fallback back closes the popup and keeps the branch route', (
        tester,
      ) async {
        final fixture = _ShellSearchFixture();
        addTearDown(fixture.dispose);
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(fixture.app);
        await tester.pumpAndSettle();

        await tester.tap(find.byType(SearchBar));
        await tester.pumpAndSettle();
        expect(fixture.controller.isOpen, isTrue);

        expect(await tester.binding.handlePopRoute(), isTrue);
        await tester.pumpAndSettle();

        expect(fixture.controller.isOpen, isFalse);
        expect(find.byType(_SearchHostPage), findsOneWidget);
        expect(fixture.matchedLocation, '/home');
        expect(tester.takeException(), isNull);
        debugDefaultTargetPlatformOverride = null;
      });

      testWidgets(
        'predictive commit closes the popup and keeps the branch route',
        (tester) async {
          final fixture = _ShellSearchFixture();
          addTearDown(fixture.dispose);
          await tester.binding.setSurfaceSize(const Size(390, 844));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          await tester.pumpWidget(fixture.app);
          await tester.pumpAndSettle();

          await tester.tap(find.byType(SearchBar));
          await tester.pumpAndSettle();
          expect(fixture.controller.isOpen, isTrue);

          await startPredictiveBack(tester);
          await commitPredictiveBack(tester);

          expect(fixture.controller.isOpen, isFalse);
          expect(find.byType(_SearchHostPage), findsOneWidget);
          expect(fixture.matchedLocation, '/home');
          expect(tester.takeException(), isNull);
          debugDefaultTargetPlatformOverride = null;
        },
      );
    });

    group('close cleanup', () {
      testWidgets('runs exactly once for fallback back', (tester) async {
        final fixture = _compactFixture(cleanupOnClose: true);
        addTearDown(fixture.dispose);
        await fixture.pumpApp(tester);
        await _openSearch(tester, fixture);

        fixture.controller.text = 'molise';
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump();
        expect(await tester.binding.handlePopRoute(), isTrue);
        await tester.pumpAndSettle();

        expect(fixture.closeCleanupCount, 1);
        expect(fixture.controller.text, isEmpty);
        debugDefaultTargetPlatformOverride = null;
      });

      testWidgets('runs exactly once for the leading button', (tester) async {
        final fixture = _compactFixture(cleanupOnClose: true);
        addTearDown(fixture.dispose);
        await fixture.pumpApp(tester);
        await _openSearch(tester, fixture);

        fixture.controller.text = 'molise';
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump();
        await tester.tap(find.widgetWithIcon(IconButton, Icons.arrow_back));
        await tester.pumpAndSettle();

        expect(fixture.closeCleanupCount, 1);
        expect(fixture.controller.text, isEmpty);
        debugDefaultTargetPlatformOverride = null;
      });

      testWidgets('runs exactly once for barrier dismissal', (tester) async {
        final fixture = _expandedFixture(cleanupOnClose: true);
        addTearDown(fixture.dispose);
        await fixture.pumpApp(tester);
        await _openSearch(tester, fixture);

        fixture.controller.text = 'molise';
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump();
        await tester.tapAt(const Offset(640, 1500));
        await tester.pumpAndSettle();

        expect(fixture.closeCleanupCount, 1);
        expect(fixture.controller.text, isEmpty);
        debugDefaultTargetPlatformOverride = null;
      });

      testWidgets('runs exactly once for programmatic close', (tester) async {
        final fixture = _compactFixture(cleanupOnClose: true);
        addTearDown(fixture.dispose);
        await fixture.pumpApp(tester);
        await _openSearch(tester, fixture);

        fixture.controller.text = 'molise';
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump();
        fixture.controller.closeView(null);
        await tester.pumpAndSettle();

        expect(fixture.closeCleanupCount, 1);
        expect(fixture.controller.text, isEmpty);
        debugDefaultTargetPlatformOverride = null;
      });
    });

    group('viewOnSubmitted unmount race', () {
      // Swallows the debug-only "deactivated widget's ancestor" diagnostic
      // that the framework emits during the deactivation window. This is
      // not a real error — it does not appear in release mode — and would
      // otherwise cause takeException to report a false failure.
      void installDiagnosticFilter() {
        final previousErrorHandler = FlutterError.onError;
        FlutterError.onError = (details) {
          if (details.exception.toString().startsWith(
            "Looking up a deactivated widget's ancestor is unsafe.",
          )) {
            return;
          }
          previousErrorHandler?.call(details);
        };
        addTearDown(() => FlutterError.onError = previousErrorHandler);
      }

      testWidgets(
        'submission that goNamed-unmounts the anchor does not crash during '
        'the popup exit transition',
        (tester) async {
          installDiagnosticFilter();

          final fixture = _ShellSearchFixture(navigateOnSubmit: true);
          addTearDown(fixture.dispose);
          await fixture.pumpApp(tester);

          // Open the search view.
          await tester.tap(find.byType(SearchBar));
          await tester.pumpAndSettle();
          expect(fixture.controller.isOpen, isTrue);

          // Enter a valid query and let the debouncer settle.
          fixture.controller.text = 'molise';
          await tester.pump(const Duration(milliseconds: 600));
          await tester.pump();

          // Drive the framework's real viewOnSubmitted path with ONE call.
          // The view's SearchBar.onSubmitted is wired to SearchAnchor's
          // viewOnSubmitted, which performs addToPastSearches -> closeView
          // (pop + 600 ms exit transition) -> widget.onSubmitted (goNamed
          // -> unmount anchor) in production order. The anchor's own
          // SearchBar (find .first) has no onSubmitted; the view's
          // (find .last) does.
          final viewBar = tester.widget<SearchBar>(find.byType(SearchBar).last);
          viewBar.onSubmitted!('molise');

          // Process the pop + goNamed, then run every popup exit-transition
          // tick — each tick re-invokes viewBuilder on the now-dead anchor
          // State. The 600 ms popup exit outlives the ~300 ms route pop, so
          // post-unmount ticks are guaranteed.
          await tester.pump();
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(fixture.matchedLocation, '/home/search_results');
          debugDefaultTargetPlatformOverride = null;
        },
      );

      testWidgets(
        'suggestionsBuilder does not crash when re-invoked after unmount',
        (tester) async {
          installDiagnosticFilter();

          final fixture = _ShellSearchFixture(
            navigateOnSubmit: true,
            pastSearches: const ['termoli'],
          );
          addTearDown(fixture.dispose);
          await fixture.pumpApp(tester);

          // Open the search view — a history chip is visible.
          await tester.tap(find.byType(SearchBar));
          await tester.pumpAndSettle();
          expect(fixture.controller.isOpen, isTrue);
          expect(find.text('termoli'), findsOneWidget);

          // Capture the suggestionsBuilder closure and a valid context
          // before unmounting the anchor.
          final searchAnchor = tester.widget<SearchAnchor>(
            find.byType(SearchAnchor),
          );
          final suggestionsBuilder = searchAnchor.suggestionsBuilder;
          final callbackContext = tester.element(find.byType(MaterialApp));

          // Submit → closeView (pop + 600 ms exit transition) → goNamed
          // (page replacement via ValueKey(query) → unmount old anchor).
          final viewBar = tester.widget<SearchBar>(find.byType(SearchBar).last);
          viewBar.onSubmitted!('molise');

          // Process the pop + goNamed + unmount. Pump enough frames for
          // the element to be fully unmounted (_widget = null, mounted =
          // false).
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 50));

          // Directly re-invoke the captured suggestionsBuilder on the
          // dead anchor State — this mirrors what the popup view's
          // SearchController listener would do if the text changed.
          // Without the mounted guard at the top of the closure,
          // widget.viewModel throws the null-check TypeError.
          await suggestionsBuilder(callbackContext, fixture.controller);

          // Complete the exit transition.
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(fixture.matchedLocation, '/home/search_results');
          debugDefaultTargetPlatformOverride = null;
        },
      );

      testWidgets(
        'debounce-window submission does not crash when _search runs after '
        'the page is replaced',
        (tester) async {
          installDiagnosticFilter();

          final fixture = _ShellSearchFixture(navigateOnSubmit: true);
          addTearDown(fixture.dispose);
          await fixture.pumpApp(tester);

          // Open the search view.
          await tester.tap(find.byType(SearchBar));
          await tester.pumpAndSettle();
          expect(fixture.controller.isOpen, isTrue);

          // Type a valid query — this starts the 500 ms debounce timer via
          // _debouncedSearch inside suggestionsBuilder. Pump one frame to
          // ensure the async chain (listener → updateSuggestions →
          // suggestionsBuilder → _debouncedSearch → Timer(500ms)) is fully
          // processed and the timer is pending.
          fixture.controller.text = 'molise';
          await tester.pump();

          // Submit within the 500 ms debounce window — viewOnSubmitted →
          // closeView (pop + 600 ms exit transition) → goNamed (page
          // replacement → unmount anchor). The debounce timer is still
          // pending.
          final viewBar = tester.widget<SearchBar>(find.byType(SearchBar).last);
          viewBar.onSubmitted!('molise');

          // Process the pop + goNamed + unmount.
          await tester.pump();

          // Pump past the 500 ms debounce timer. The timer fires and calls
          // _search on the dead anchor State. Without the mounted guard at
          // the top of _search, widget.viewModel throws the null-check
          // TypeError.
          await tester.pump(const Duration(milliseconds: 500));
          await tester.pump();

          // Complete the exit transition.
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          debugDefaultTargetPlatformOverride = null;
        },
      );
    });
  });

  group('SearchResultScreen canonical query', () {
    ({GoRouter router, SearchViewModel viewModel, Widget app}) buildFixture() {
      final viewModel = SearchViewModel(
        searchRepository: FakeSearchRepository(),
      );
      final router = GoRouter(
        initialLocation: '/home/search_results?q=old',
        routes: <RouteBase>[
          GoRoute(
            path: '/home/search_results',
            name: RouteNames.homeSearchResult,
            builder: (_, state) => SearchResultScreen(
              query: state.uri.queryParameters['q'] ?? '',
              viewModel: viewModel,
            ),
          ),
        ],
      );
      return (
        router: router,
        viewModel: viewModel,
        app: MaterialApp.router(routerConfig: router),
      );
    }

    testWidgets('submission updates the canonical q URI', (tester) async {
      final fixture = buildFixture();
      addTearDown(fixture.router.dispose);
      addTearDown(fixture.viewModel.dispose);
      fixture.viewModel.loadResults.run('old');
      await pumpCommandTurns(tester);
      await tester.pumpWidget(fixture.app);
      await tester.pumpAndSettle();

      tester.widget<AppSearchAnchor>(find.byType(AppSearchAnchor)).onSubmitted!(
        'new query',
      );
      await tester.pumpAndSettle();

      expect(
        fixture.router.routeInformationProvider.value.uri.queryParameters['q'],
        'new query',
      );
      expect(
        tester
            .widget<SearchResultScreen>(find.byType(SearchResultScreen))
            .query,
        'new query',
      );
    });

    testWidgets('suggestion uses its content name as the canonical q', (
      tester,
    ) async {
      final fixture = buildFixture();
      addTearDown(fixture.router.dispose);
      addTearDown(fixture.viewModel.dispose);
      fixture.viewModel.loadResults.run('old');
      await pumpCommandTurns(tester);
      await tester.pumpWidget(fixture.app);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(SearchBar));
      await tester.pumpAndSettle();
      tester
          .widget<AppSearchAnchor>(find.byType(AppSearchAnchor))
          .onSuggestionPressed(makePlace(name: 'Castello Monforte'));
      await tester.pumpAndSettle();

      expect(
        fixture.router.routeInformationProvider.value.uri.queryParameters['q'],
        'Castello Monforte',
      );
      expect(find.byType(SearchResultScreen), findsOneWidget);
    });
  });
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

Future<void> _openSearch(WidgetTester tester, _SearchFixture fixture) async {
  await tester.tap(find.text('Open search'));
  await tester.pumpAndSettle();

  expect(find.byType(_SearchHostPage), findsOneWidget);
  expect(fixture.matchedLocation, '/search');

  await tester.tap(find.byType(SearchBar));
  await tester.pumpAndSettle();

  expect(fixture.controller.isOpen, isTrue);
  expect(fixture.matchedLocation, '/search');
}

void _expectPopupClosed(_SearchFixture fixture) {
  expect(fixture.controller.isOpen, isFalse);
  expect(find.byType(_SearchHostPage), findsOneWidget);
  expect(fixture.matchedLocation, '/search');
  expect(fixture.uri.path, '/');
}

_SearchFixture _compactFixture({required bool cleanupOnClose}) {
  return _SearchFixture(
    cleanupOnClose: cleanupOnClose,
    surfaceSize: const Size(390, 844),
  );
}

_SearchFixture _expandedFixture({required bool cleanupOnClose}) {
  return _SearchFixture(
    cleanupOnClose: cleanupOnClose,
    surfaceSize: const Size(1280, 1600),
  );
}

// ---------------------------------------------------------------------------
// Fixture
// ---------------------------------------------------------------------------

final class _SearchFixture {
  _SearchFixture({
    required bool cleanupOnClose,
    required Size surfaceSize,
    FakeSearchRepository? searchRepository,
  }) : _surfaceSize = surfaceSize {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    controller = SearchController();
    viewModel = SearchViewModel(
      searchRepository: searchRepository ?? FakeSearchRepository(),
    );
    router = GoRouter(
      initialLocation: '/',
      routes: <RouteBase>[
        GoRoute(path: '/', name: 'home', builder: (_, _) => const _HomePage()),
        GoRoute(
          path: '/search',
          name: 'search',
          builder: (_, _) => _SearchHostPage(
            controller: controller,
            viewModel: viewModel,
            onBackPressed: cleanupOnClose
                ? () {
                    closeCleanupCount++;
                    controller.clear();
                  }
                : null,
          ),
        ),
      ],
    );
  }

  late final SearchController controller;
  late final SearchViewModel viewModel;
  final Size _surfaceSize;
  late final GoRouter router;
  int closeCleanupCount = 0;

  Uri get uri => router.routeInformationProvider.value.uri;

  String get matchedLocation =>
      router.routerDelegate.currentConfiguration.matches.last.matchedLocation;

  Widget get app => MaterialApp.router(routerConfig: router);

  /// Pins the window surface to the fixture size and pumps the app.
  Future<void> pumpApp(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(_surfaceSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
  }

  void dispose() {
    debugDefaultTargetPlatformOverride = null;
    controller.dispose();
    viewModel.dispose();
    router.dispose();
  }
}

class _HomePage extends StatelessWidget {
  const _HomePage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FilledButton(
          onPressed: () => context.pushNamed('search'),
          child: const Text('Open search'),
        ),
      ),
    );
  }
}

/// Shell-based fixture that mirrors the production `StatefulShellRoute`
/// topology with all four branches so the search popup receives Router back
/// inside a branch and hidden branches behave exactly as in production.
///
/// When [navigateOnSubmit] is true, the fixture starts at
/// `/home/search_results?q=initial` — matching the production
/// `SearchResultScreen` flow where the anchor lives on the results page.
/// Submitting calls `goNamed` to the same route with a different `q`
/// parameter, which replaces the page (via `ValueKey(query)`) and unmounts
/// the old anchor while the popup view is still fading out.
final class _ShellSearchFixture {
  _ShellSearchFixture({
    this.navigateOnSubmit = false,
    List<String> pastSearches = const [],
  }) {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    controller = SearchController();
    viewModel = SearchViewModel(
      searchRepository: FakeSearchRepository(
        pastSearchesResult: Result.success(pastSearches),
      ),
    );
    router = GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: navigateOnSubmit
          ? '/home/search_results?q=initial'
          : '/home',
      routes: <RouteBase>[
        StatefulShellRoute.indexedStack(
          branches: <StatefulShellBranch>[
            StatefulShellBranch(
              navigatorKey: exploreNavigatorKey,
              routes: <RouteBase>[
                GoRoute(
                  path: '/home',
                  builder: (_, _) => _SearchHostPage(
                    controller: controller,
                    viewModel: viewModel,
                  ),
                  // Production declares /home/search_results as a child of
                  // /home with parentNavigatorKey: rootNavigatorKey, so the
                  // results page pushes on the root navigator. The child
                  // path is relative ('search_results'), matching
                  // RoutePaths. The results page has ValueKey(query) —
                  // matching SearchResultScreen's wrapper in router.dart —
                  // so goNamed to the same route with a different q
                  // replaces the page and unmounts the old anchor.
                  routes: <RouteBase>[
                    GoRoute(
                      parentNavigatorKey: rootNavigatorKey,
                      path: 'search_results',
                      name: RouteNames.homeSearchResult,
                      builder: (_, state) => _SearchHostPage(
                        key: ValueKey(state.uri.queryParameters['q'] ?? ''),
                        controller: controller,
                        viewModel: viewModel,
                        navigateOnSubmit: true,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            StatefulShellBranch(
              navigatorKey: favouritesNavigatorKey,
              routes: <RouteBase>[
                GoRoute(
                  path: '/favourites',
                  builder: (_, _) => const _StubBranchPage(label: 'Favourites'),
                ),
              ],
            ),
            StatefulShellBranch(
              navigatorKey: eventsNavigatorKey,
              routes: <RouteBase>[
                GoRoute(
                  path: '/events',
                  builder: (_, _) => const _StubBranchPage(label: 'Events'),
                ),
              ],
            ),
            StatefulShellBranch(
              navigatorKey: mapNavigatorKey,
              routes: <RouteBase>[
                GoRoute(
                  path: '/map',
                  builder: (_, _) => const _StubBranchPage(label: 'Map'),
                ),
              ],
            ),
          ],
          builder: (_, _, navigationShell) => navigationShell,
        ),
      ],
    );
  }

  final bool navigateOnSubmit;

  final rootNavigatorKey = GlobalKey<NavigatorState>();
  final exploreNavigatorKey = GlobalKey<NavigatorState>();
  final favouritesNavigatorKey = GlobalKey<NavigatorState>();
  final eventsNavigatorKey = GlobalKey<NavigatorState>();
  final mapNavigatorKey = GlobalKey<NavigatorState>();
  late final SearchController controller;
  late final SearchViewModel viewModel;
  late final GoRouter router;

  Uri get uri => router.routeInformationProvider.value.uri;

  String get matchedLocation =>
      router.routerDelegate.currentConfiguration.matches.last.matchedLocation;

  Widget get app => MaterialApp.router(routerConfig: router);

  /// Pins the window surface to a compact phone size and pumps the app.
  Future<void> pumpApp(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
  }

  void dispose() {
    debugDefaultTargetPlatformOverride = null;
    controller.dispose();
    viewModel.dispose();
    router.dispose();
  }
}

class _StubBranchPage extends StatelessWidget {
  const _StubBranchPage({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text(label)));
  }
}

class _SearchHostPage extends StatelessWidget {
  const _SearchHostPage({
    required this.controller,
    required this.viewModel,
    this.onBackPressed,
    this.navigateOnSubmit = false,
    super.key,
  });

  final SearchController controller;
  final SearchViewModel viewModel;
  final VoidCallback? onBackPressed;
  final bool navigateOnSubmit;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topLeft,
          child: AppSearchAnchor(
            controller: controller,
            onBackPressed: onBackPressed,
            onSubmitted: navigateOnSubmit
                ? (query) {
                    if (query.isEmpty) return;
                    context.goNamed(
                      RouteNames.homeSearchResult,
                      queryParameters: {'q': query},
                    );
                  }
                : (_) {},
            onSuggestionPressed: navigateOnSubmit
                ? (content) {
                    if (controller.isOpen) controller.closeView(null);
                    context.goNamed(
                      RouteNames.homeSearchResult,
                      queryParameters: {'q': content.name},
                    );
                  }
                : (_) {},
            viewModel: viewModel,
          ),
        ),
      ),
    );
  }
}
