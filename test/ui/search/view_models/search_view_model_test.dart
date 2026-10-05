import 'dart:async' show Completer;

import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/ui/search/view_models/search_view_model.dart';
import 'package:moliseis/utils/result.dart';

import '../../../support/fake_repositories.dart';
import '../../../support/fixtures.dart';

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

    for (final suggestions in [false, true]) {
      final label = suggestions ? 'loadSuggestions' : 'loadResults';
      group(label, () {
        test('returns final repository order in one discovery call', () async {
          final content = <ContentBase>[
            makePlace(remoteId: 7),
            makeEvent(remoteId: 7),
          ];
          final repository = FakeSearchRepository(
            resultsByQueryResult: Result.success(content),
          );
          final vm = await _buildLoaded(searchRepository: repository);
          addTearDown(vm.dispose);
          final command = suggestions ? vm.loadSuggestions : vm.loadResults;
          await command.execute('mol');
          expect(command.completed, isTrue);
          expect(suggestions ? vm.suggestions : vm.results, content);
          expect(repository.getResultsByQueryCallCount, 1);
          expect(repository.lastQuery, 'mol');
        });

        test(
          'short query is a no-op and preserves prior successful state',
          () async {
            final content = <ContentBase>[makePlace()];
            final repository = FakeSearchRepository(
              resultsByQueryResult: Result.success(content),
            );
            final vm = await _buildLoaded(searchRepository: repository);
            addTearDown(vm.dispose);
            final command = suggestions ? vm.loadSuggestions : vm.loadResults;
            await command.execute('molise');
            await command.execute('mo');
            expect(command.completed, isTrue);
            expect(suggestions ? vm.suggestions : vm.results, content);
            expect(repository.getResultsByQueryCallCount, 1);
          },
        );

        test('keeps prior state pending then atomically replaces it', () async {
          final prior = <ContentBase>[makePlace()];
          final replacement = <ContentBase>[
            makeEvent(remoteId: 2),
            makePlace(remoteId: 3),
          ];
          final repository = FakeSearchRepository(
            resultsByQueryResult: Result.success(prior),
          );
          final vm = await _buildLoaded(searchRepository: repository);
          addTearDown(vm.dispose);
          final command = suggestions ? vm.loadSuggestions : vm.loadResults;
          await command.execute('molise');
          final pending = Completer<Result<List<ContentBase>>>();
          repository.pendingGetResultsByQuery = pending;
          var notifications = 0;
          vm.addListener(() => notifications++);
          final load = command.execute('termoli');
          expect(command.running, isTrue);
          expect(suggestions ? vm.suggestions : vm.results, prior);
          expect(notifications, 0);
          pending.complete(Result.success(replacement));
          await load;
          expect(suggestions ? vm.suggestions : vm.results, replacement);
          expect(notifications, 1);
        });

        test('successful empty clears earlier results', () async {
          final repository = FakeSearchRepository(
            resultsByQueryResult: Result.success([makePlace()]),
          );
          final vm = await _buildLoaded(searchRepository: repository);
          addTearDown(vm.dispose);
          final command = suggestions ? vm.loadSuggestions : vm.loadResults;
          await command.execute('molise');
          repository.resultsByQueryResult = const Result.success([]);
          await command.execute('termoli');
          expect(command.completed, isTrue);
          expect(suggestions ? vm.suggestions : vm.results, isEmpty);
        });

        test('direct failure surfaces without partial publication '
            'and retry rediscovers', () async {
          final prior = <ContentBase>[makePlace()];
          final repository = FakeSearchRepository(
            resultsByQueryResult: Result.success(prior),
          );
          final vm = await _buildLoaded(searchRepository: repository);
          addTearDown(vm.dispose);
          final command = suggestions ? vm.loadSuggestions : vm.loadResults;
          await command.execute('molise');
          final error = TestException('materialization failed');
          repository.resultsByQueryResult = Result.error(error);
          await command.execute('termoli');
          expect(command.error, isTrue);
          expect((command.result! as Error<void>).error, same(error));
          expect(suggestions ? vm.suggestions : vm.results, prior);
          repository.resultsByQueryResult = Result.success([makeEvent()]);
          await command.execute('termoli');
          expect(command.completed, isTrue);
          expect(repository.getResultsByQueryCallCount, 3);
        });

        test(
          'pending direct success cannot mutate or notify after disposal',
          () async {
            final prior = <ContentBase>[makePlace()];
            final repository = FakeSearchRepository(
              resultsByQueryResult: Result.success(prior),
            );
            final vm = await _buildLoaded(searchRepository: repository);
            final command = suggestions ? vm.loadSuggestions : vm.loadResults;
            await command.execute('molise');
            final pending = Completer<Result<List<ContentBase>>>();
            repository.pendingGetResultsByQuery = pending;
            var notifications = 0;
            vm.addListener(() => notifications++);
            final load = command.execute('termoli');
            vm.dispose();
            pending.complete(Result.success([makeEvent(remoteId: 2)]));
            await load;
            expect(suggestions ? vm.suggestions : vm.results, prior);
            expect(notifications, 0);
            expect(command.completed, isTrue);
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
