// Sequential statements keep command scheduling assertions readable.
// ignore_for_file: cascade_invocations

import 'dart:async' show Completer;

import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/ui/search/view_models/search_view_model.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/result_command.dart';

import '../../../support/command_test_support.dart';
import '../../../support/fake_repositories.dart';
import '../../../support/fixtures.dart';
import '../../../support/mock_logger.dart';

void main() {
  group('SearchViewModel', () {
    test('late history failure does not roll back after disposal', () async {
      final repository = FakeSearchRepository();
      final vm = SearchViewModel(searchRepository: repository);
      await pumpEventQueue();
      expect(vm.loadPastSearches.completed, isTrue);

      final pendingAdd = Completer<Result<void>>();
      repository.pendingAddToPastSearches = pendingAdd;
      final add = vm.addToPastSearches.execute('campobasso');
      expect(vm.pastSearches, ['campobasso']);
      vm.dispose();
      pendingAdd.complete(Result.error(TestException('db error')));
      await add;

      expect(vm.pastSearches, ['campobasso']);
      expect(vm.addToPastSearches.error, isTrue);
    });

    test(
      'late remove failure does not restore history after disposal',
      () async {
        final repository = FakeSearchRepository();
        final vm = SearchViewModel(searchRepository: repository);
        await pumpEventQueue();
        await vm.addToPastSearches.execute('campobasso');
        expect(vm.pastSearches, ['campobasso']);

        final pendingRemove = Completer<Result<void>>();
        repository.pendingRemoveFromPastSearches = pendingRemove;
        final remove = vm.removeFromPastSearches.execute('campobasso');
        expect(vm.pastSearches, isEmpty);
        vm.dispose();
        pendingRemove.complete(Result.error(TestException('db error')));
        await remove;

        expect(vm.pastSearches, isEmpty);
        expect(vm.removeFromPastSearches.error, isTrue);
      },
    );

    group('loadPastSearches', () {
      test('populates pastSearches on success', () async {
        final vm = _buildVm(
          searchRepository: FakeSearchRepository(
            pastSearchesResult: const Result.success(['molise', 'campobasso']),
          ),
        );

        await pumpEventQueue();

        expect(vm.loadPastSearches.completed, isTrue);
        expect(vm.pastSearches, equals(['molise', 'campobasso']));
      });

      test('surfaces error on failure', () async {
        final vm = _buildVm(
          searchRepository: FakeSearchRepository(
            pastSearchesResult: Result.error(TestException('db error')),
          ),
        );

        await pumpEventQueue();

        expect(vm.loadPastSearches.error, isTrue);
        expect(vm.pastSearches, isEmpty);
      });
    });

    group('addToPastSearches', () {
      test('does nothing for empty query', () async {
        final vm = await _buildLoaded(searchRepository: FakeSearchRepository());

        await vm.addToPastSearches.execute('');

        expect(vm.addToPastSearches.completed, isTrue);
        expect(vm.pastSearches, isEmpty);
      });

      test('does nothing when query matches a type label', () async {
        final vm = await _buildLoaded(searchRepository: FakeSearchRepository());

        // 'Natura' is a category label.
        await vm.addToPastSearches.execute('Natura');

        expect(vm.addToPastSearches.completed, isTrue);
        expect(vm.pastSearches, isEmpty);
      });

      test('does not duplicate an already-present query', () async {
        final vm = await _buildLoaded(
          searchRepository: FakeSearchRepository(
            pastSearchesResult: const Result.success(['molise']),
          ),
        );

        await vm.addToPastSearches.execute('molise');

        expect(vm.addToPastSearches.completed, isTrue);
        expect(vm.pastSearches, equals(['molise']));
      });

      test('case-insensitive duplicate check', () async {
        final vm = await _buildLoaded(
          searchRepository: FakeSearchRepository(
            pastSearchesResult: const Result.success(['Molise']),
          ),
        );

        await vm.addToPastSearches.execute('molise');

        expect(vm.addToPastSearches.completed, isTrue);
        expect(vm.pastSearches, hasLength(1));
      });

      test('optimistically adds query and persists on success', () async {
        final vm = await _buildLoaded(searchRepository: FakeSearchRepository());

        await vm.addToPastSearches.execute('campobasso');

        expect(vm.addToPastSearches.completed, isTrue);
        expect(vm.pastSearches, contains('campobasso'));
      });

      test('rolls back optimistic add when persist fails', () async {
        final vm = await _buildLoaded(
          searchRepository: FakeSearchRepository(
            addToHistoryResult: Result.error(TestException('write failed')),
          ),
        );

        await vm.addToPastSearches.execute('campobasso');

        expect(vm.addToPastSearches.error, isTrue);
        expect(vm.pastSearches, isNot(contains('campobasso')));
      });
    });

    group('removeFromPastSearches', () {
      test('removes query on success', () async {
        final vm = await _buildLoaded(
          searchRepository: FakeSearchRepository(
            pastSearchesResult: const Result.success(['molise']),
          ),
        );

        await vm.removeFromPastSearches.execute('molise');

        expect(vm.removeFromPastSearches.completed, isTrue);
        expect(vm.pastSearches, isNot(contains('molise')));
      });

      test('rolls back removal when persist fails', () async {
        final vm = await _buildLoaded(
          searchRepository: FakeSearchRepository(
            pastSearchesResult: const Result.success(['molise']),
            removeFromHistoryResult: Result.error(
              TestException('write failed'),
            ),
          ),
        );

        await vm.removeFromPastSearches.execute('molise');

        expect(vm.removeFromPastSearches.error, isTrue);
        expect(vm.pastSearches, contains('molise'));
      });
    });

    testWidgets('results and suggestions retain independent ownership lanes', (
      tester,
    ) async {
      final pending = <String, Completer<Result<List<ContentBase>>>>{
        'results': Completer(),
        'suggestions': Completer(),
      };
      final vm = SearchViewModel(
        searchRepository: FakeSearchRepository(
          resultsByQueryHandler: (query) => pending[query]!.future,
        ),
      );
      await pumpCommandTurns(tester);
      vm.loadResults.run('results');
      vm.loadSuggestions.run('suggestions');
      await pumpCommandTurns(tester);
      final suggestion = <ContentBase>[makePlace(remoteId: 2)];
      pending['suggestions']!.complete(Result.success(suggestion));
      await pumpCommandTurns(tester);
      expect(vm.suggestions, suggestion);
      expect(vm.loadResults.isRunningSync.value, isTrue);
      final result = <ContentBase>[makeEvent()];
      pending['results']!.complete(Result.success(result));
      await pumpCommandTurns(tester);
      expect(vm.results, result);
      expect(vm.suggestions, suggestion);
      vm.dispose();
      await tester.pump(const Duration(milliseconds: 50));
    });

    for (final suggestions in [false, true]) {
      final label = suggestions ? 'loadSuggestions' : 'loadResults';
      group(label, () {
        testWidgets(
          'initial short query is successful no-op without discovery',
          (tester) async {
            final repository = FakeSearchRepository();
            final vm = SearchViewModel(searchRepository: repository);
            await pumpCommandTurns(tester);
            final command = suggestions ? vm.loadSuggestions : vm.loadResults;
            expect(command.results.value.idle, isTrue);
            command.run('a');
            await pumpCommandTurns(tester);
            expect(command.results.value.completed, isTrue);
            expect(repository.getResultsByQueryCallCount, 0);
            expect(suggestions ? vm.suggestions : vm.results, isEmpty);
            vm.dispose();
            await tester.pump(const Duration(milliseconds: 50));
          },
        );

        testWidgets(
          'late runtime failure after dispose reports without VM notification',
          (tester) async {
            final logger = MockLogger();
            addTearDown(installCommandTestReporting(logger));
            final pending = Completer<Result<List<ContentBase>>>();
            final vm = SearchViewModel(
              searchRepository: FakeSearchRepository(
                resultsByQueryHandler: (_) => pending.future,
              ),
            );
            await pumpCommandTurns(tester);
            final command = suggestions ? vm.loadSuggestions : vm.loadResults;
            var notifications = 0;
            vm.addListener(() => notifications++);
            command.run('alpha');
            await pumpCommandTurns(tester);
            vm.dispose();
            final failure = StateError('late disposed read');
            pending.completeError(failure, StackTrace.current);
            await pumpCommandTurns(tester);
            expect(notifications, 0);
            expect(logger.calls, hasLength(1));
            expect(logger.calls.single.error, same(failure));
            expect(tester.takeException(), isNull);
            await tester.pump(const Duration(milliseconds: 50));
          },
        );

        for (final staleOutcome in ['success', 'domain', 'runtime']) {
          testWidgets('slow A fast B ignores stale $staleOutcome', (
            tester,
          ) async {
            final logger = MockLogger();
            addTearDown(installCommandTestReporting(logger));
            final pending = <String, Completer<Result<List<ContentBase>>>>{
              'alpha': Completer(),
              'bravo': Completer(),
            };
            final repository = FakeSearchRepository(
              resultsByQueryHandler: (query) => pending[query]!.future,
            );
            final vm = SearchViewModel(searchRepository: repository);
            await pumpCommandTurns(tester);
            final command = suggestions ? vm.loadSuggestions : vm.loadResults;
            var notifications = 0;
            vm.addListener(() => notifications++);
            command.run('alpha');
            await pumpCommandTurns(tester);
            command.run('bravo');
            await pumpCommandTurns(tester);
            expect(repository.capturedQueries, ['alpha', 'bravo']);
            final latest = <ContentBase>[makePlace(remoteId: 2)];
            pending['bravo']!.complete(Result.success(latest));
            await pumpCommandTurns(tester);
            expect(suggestions ? vm.suggestions : vm.results, latest);
            expect(command.isRunningSync.value, isFalse);
            expect(notifications, 1);
            final unexpected = StateError('obsolete runtime error');
            switch (staleOutcome) {
              case 'success':
                pending['alpha']!.complete(Result.success([makeEvent()]));
              case 'domain':
                pending['alpha']!.complete(
                  Result.error(TestException('stale')),
                );
              case 'runtime':
                pending['alpha']!.completeError(unexpected, StackTrace.current);
            }
            await pumpCommandTurns(tester);
            expect(suggestions ? vm.suggestions : vm.results, latest);
            expect(command.results.value.paramData, 'bravo');
            expect(command.results.value.completed, isTrue);
            expect(notifications, 1);
            expect(logger.calls, hasLength(staleOutcome == 'runtime' ? 1 : 0));
            if (staleOutcome == 'runtime') {
              expect(logger.calls.single.error, same(unexpected));
            }
            vm.dispose();
            await tester.pump(const Duration(milliseconds: 50));
          });
        }

        testWidgets('A completes stale immediately after B acceptance', (
          tester,
        ) async {
          final a = Completer<Result<List<ContentBase>>>();
          final b = Completer<Result<List<ContentBase>>>();
          final repository = FakeSearchRepository(
            resultsByQueryHandler: (query) =>
                query == 'alpha' ? a.future : b.future,
          );
          final vm = SearchViewModel(searchRepository: repository);
          await pumpCommandTurns(tester);
          final command = suggestions ? vm.loadSuggestions : vm.loadResults;
          command.run('alpha');
          await pumpCommandTurns(tester);
          command.run('bravo');
          a.complete(Result.success([makeEvent()]));
          await pumpCommandTurns(tester);
          expect(suggestions ? vm.suggestions : vm.results, isEmpty);
          expect(command.isRunningSync.value, isTrue);
          final content = <ContentBase>[makePlace(remoteId: 2)];
          b.complete(Result.success(content));
          await pumpCommandTurns(tester);
          expect(suggestions ? vm.suggestions : vm.results, content);
          vm.dispose();
          await tester.pump(const Duration(milliseconds: 50));
        });

        testWidgets('A B C publishes only C', (tester) async {
          final pending = <String, Completer<Result<List<ContentBase>>>>{
            'alpha': Completer(),
            'bravo': Completer(),
            'charlie': Completer(),
          };
          final repository = FakeSearchRepository(
            resultsByQueryHandler: (query) => pending[query]!.future,
          );
          final vm = SearchViewModel(searchRepository: repository);
          await pumpCommandTurns(tester);
          var commits = 0;
          vm.addListener(() => commits++);
          final command = suggestions ? vm.loadSuggestions : vm.loadResults;
          for (final query in pending.keys) {
            command.run(query);
            await pumpCommandTurns(tester);
          }
          pending['bravo']!.complete(Result.success([makeEvent(remoteId: 2)]));
          pending['alpha']!.complete(Result.success([makePlace()]));
          await pumpCommandTurns(tester);
          expect(commits, 0);
          final latest = <ContentBase>[makePlace(remoteId: 3)];
          pending['charlie']!.complete(Result.success(latest));
          await pumpCommandTurns(tester);
          expect(suggestions ? vm.suggestions : vm.results, latest);
          expect(commits, 1);
          vm.dispose();
          await tester.pump(const Duration(milliseconds: 50));
        });

        for (final runtime in [false, true]) {
          testWidgets(
            'latest ${runtime ? 'runtime' : 'domain'} error ends running',
            (tester) async {
              final logger = MockLogger();
              addTearDown(installCommandTestReporting(logger));
              final pending = Completer<Result<List<ContentBase>>>();
              final repository = FakeSearchRepository(
                resultsByQueryHandler: (_) => pending.future,
              );
              final vm = SearchViewModel(searchRepository: repository);
              await pumpCommandTurns(tester);
              final command = suggestions ? vm.loadSuggestions : vm.loadResults;
              command.run('molise');
              await pumpCommandTurns(tester);
              final domain = TestException('domain');
              final unexpected = StateError('runtime');
              if (runtime) {
                pending.completeError(unexpected, StackTrace.current);
              } else {
                pending.complete(Result.error(domain));
              }
              await pumpCommandTurns(tester);
              expect(command.isRunningSync.value, isFalse);
              expect(command.results.value.hasFailure, isTrue);
              expect(
                command.results.value.domainError,
                runtime ? isNull : same(domain),
              );
              expect(
                command.results.value.unexpectedError,
                runtime ? same(unexpected) : isNull,
              );
              expect(logger.calls, hasLength(runtime ? 1 : 0));
              expect(suggestions ? vm.suggestions : vm.results, isEmpty);
              vm.dispose();
              await tester.pump(const Duration(milliseconds: 50));
            },
          );
        }

        testWidgets(
          'valid pending to short revokes work and preserves committed list',
          (tester) async {
            final prior = <ContentBase>[makePlace()];
            final pending = Completer<Result<List<ContentBase>>>();
            final repository = FakeSearchRepository(
              resultsByQueryResult: Result.success(prior),
            );
            final vm = SearchViewModel(searchRepository: repository);
            await pumpCommandTurns(tester);
            final command = suggestions ? vm.loadSuggestions : vm.loadResults;
            command.run('initial');
            await pumpCommandTurns(tester);
            repository.pendingGetResultsByQuery = pending;
            command.run('alpha');
            await pumpCommandTurns(tester);
            command.run('a');
            pending.complete(Result.success([makeEvent()]));
            await pumpCommandTurns(tester);
            expect(command.results.value.completed, isTrue);
            expect(command.results.value.data!.getOrNull(), isNull);
            expect(suggestions ? vm.suggestions : vm.results, prior);
            expect(repository.capturedQueries, ['initial', 'alpha']);
            vm.dispose();
            await tester.pump(const Duration(milliseconds: 50));
          },
        );

        testWidgets('returns final repository order in one discovery call', (
          tester,
        ) async {
          final content = <ContentBase>[
            makePlace(remoteId: 7),
            makeEvent(remoteId: 7),
          ];
          final repository = FakeSearchRepository(
            resultsByQueryResult: Result.success(content),
          );
          final vm = SearchViewModel(searchRepository: repository);
          await pumpCommandTurns(tester);
          addTearDown(vm.dispose);
          final command = suggestions ? vm.loadSuggestions : vm.loadResults;
          command.run('mol');
          await pumpCommandTurns(tester);
          expect(command.results.value.completed, isTrue);
          expect(suggestions ? vm.suggestions : vm.results, content);
          expect(repository.getResultsByQueryCallCount, 1);
          await tester.pump(const Duration(milliseconds: 50));
          expect(repository.lastQuery, 'mol');
          await tester.pump(const Duration(milliseconds: 50));
        });

        testWidgets(
          'short query is a no-op and preserves prior successful state',
          (tester) async {
            final content = <ContentBase>[makePlace()];
            final repository = FakeSearchRepository(
              resultsByQueryResult: Result.success(content),
            );
            final vm = SearchViewModel(searchRepository: repository);
            await pumpCommandTurns(tester);
            addTearDown(vm.dispose);
            final command = suggestions ? vm.loadSuggestions : vm.loadResults;
            command.run('molise');
            await pumpCommandTurns(tester);
            command.run('mo');
            await pumpCommandTurns(tester);
            expect(command.results.value.completed, isTrue);
            expect(suggestions ? vm.suggestions : vm.results, content);
            expect(repository.getResultsByQueryCallCount, 1);
            await tester.pump(const Duration(milliseconds: 50));
          },
        );

        testWidgets('keeps prior state pending then atomically replaces it', (
          tester,
        ) async {
          final prior = <ContentBase>[makePlace()];
          final replacement = <ContentBase>[
            makeEvent(remoteId: 2),
            makePlace(remoteId: 3),
          ];
          final repository = FakeSearchRepository(
            resultsByQueryResult: Result.success(prior),
          );
          final vm = SearchViewModel(searchRepository: repository);
          await pumpCommandTurns(tester);
          addTearDown(vm.dispose);
          final command = suggestions ? vm.loadSuggestions : vm.loadResults;
          command.run('molise');
          await pumpCommandTurns(tester);
          final pending = Completer<Result<List<ContentBase>>>();
          repository.pendingGetResultsByQuery = pending;
          var notifications = 0;
          vm.addListener(() => notifications++);
          command.run('termoli');
          await pumpCommandTurns(tester);
          expect(command.isRunningSync.value, isTrue);
          expect(suggestions ? vm.suggestions : vm.results, prior);
          expect(notifications, 0);
          pending.complete(Result.success(replacement));
          await pumpCommandTurns(tester);
          expect(suggestions ? vm.suggestions : vm.results, replacement);
          expect(notifications, 1);
          await tester.pump(const Duration(milliseconds: 50));
        });

        testWidgets('successful empty clears earlier results', (tester) async {
          final repository = FakeSearchRepository(
            resultsByQueryResult: Result.success([makePlace()]),
          );
          final vm = SearchViewModel(searchRepository: repository);
          await pumpCommandTurns(tester);
          addTearDown(vm.dispose);
          final command = suggestions ? vm.loadSuggestions : vm.loadResults;
          command.run('molise');
          await pumpCommandTurns(tester);
          repository.resultsByQueryResult = const Result.success([]);
          command.run('termoli');
          await pumpCommandTurns(tester);
          expect(command.results.value.completed, isTrue);
          expect(suggestions ? vm.suggestions : vm.results, isEmpty);
          await tester.pump(const Duration(milliseconds: 50));
        });

        testWidgets('direct failure surfaces without partial publication '
            'and retry rediscovers', (tester) async {
          final prior = <ContentBase>[makePlace()];
          final repository = FakeSearchRepository(
            resultsByQueryResult: Result.success(prior),
          );
          final vm = SearchViewModel(searchRepository: repository);
          await pumpCommandTurns(tester);
          addTearDown(vm.dispose);
          final command = suggestions ? vm.loadSuggestions : vm.loadResults;
          command.run('molise');
          await pumpCommandTurns(tester);
          final error = TestException('materialization failed');
          repository.resultsByQueryResult = Result.error(error);
          command.run('termoli');
          await pumpCommandTurns(tester);
          expect(command.results.value.hasFailure, isTrue);
          expect(command.results.value.domainError, same(error));
          expect(suggestions ? vm.suggestions : vm.results, prior);
          repository.resultsByQueryResult = Result.success([makeEvent()]);
          command.run('termoli');
          await pumpCommandTurns(tester);
          expect(command.results.value.completed, isTrue);
          expect(repository.getResultsByQueryCallCount, 3);
          await tester.pump(const Duration(milliseconds: 50));
        });

        testWidgets(
          'pending direct success cannot mutate or notify after disposal',
          (tester) async {
            final prior = <ContentBase>[makePlace()];
            final repository = FakeSearchRepository(
              resultsByQueryResult: Result.success(prior),
            );
            final vm = SearchViewModel(searchRepository: repository);
            await pumpCommandTurns(tester);
            final command = suggestions ? vm.loadSuggestions : vm.loadResults;
            command.run('molise');
            await pumpCommandTurns(tester);
            final pending = Completer<Result<List<ContentBase>>>();
            repository.pendingGetResultsByQuery = pending;
            var notifications = 0;
            vm.addListener(() => notifications++);
            command.run('termoli');
            await pumpCommandTurns(tester);
            vm.dispose();
            pending.complete(Result.success([makeEvent(remoteId: 2)]));
            await pumpCommandTurns(tester);
            expect(suggestions ? vm.suggestions : vm.results, prior);
            expect(notifications, 0);
            expect(command.results.value.isRunning, isTrue);
            await tester.pump(const Duration(milliseconds: 50));
          },
        );
      });
    }
  });
}

SearchViewModel _buildVm({required FakeSearchRepository searchRepository}) =>
    SearchViewModel(searchRepository: searchRepository);

Future<SearchViewModel> _buildLoaded({
  required FakeSearchRepository searchRepository,
}) async {
  final vm = _buildVm(searchRepository: searchRepository);
  await pumpEventQueue();
  return vm;
}
