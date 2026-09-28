import 'dart:async' show Completer;

import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/domain/models/event.dart';
import 'package:moliseis/domain/models/place.dart';
import 'package:moliseis/domain/repositories/search_repository.dart';
import 'package:moliseis/domain/use-cases/explore_get_by_id_use_case.dart';
import 'package:moliseis/domain/use-cases/explore_use_case.dart';
import 'package:moliseis/ui/search/view_models/search_view_model.dart';
import 'package:moliseis/utils/result.dart';

import '../../../support/fake_repositories.dart';
import '../../../support/fixtures.dart';

void main() {
  group('SearchViewModel', () {
    test('late history failure does not roll back after disposal', () async {
      final repository = FakeSearchRepository();
      final vm = SearchViewModel(
        eventRepository: FakeEventRepository(),
        exploreGetByIdUseCase: _FakeExploreGetByIdUseCase(),
        searchRepository: repository,
      );
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
        final vm = SearchViewModel(
          eventRepository: FakeEventRepository(),
          exploreGetByIdUseCase: _FakeExploreGetByIdUseCase(),
          searchRepository: repository,
        );
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

    test('late search result skips the next repository request', () async {
      final repository = FakeSearchRepository();
      final vm = SearchViewModel(
        eventRepository: FakeEventRepository(),
        exploreGetByIdUseCase: _FakeExploreGetByIdUseCase(),
        searchRepository: repository,
      );
      await pumpEventQueue();
      expect(vm.loadPastSearches.completed, isTrue);

      final pendingPlaceIds = Completer<Result<List<int>>>();
      repository.pendingGetPlaceIdsByQuery = pendingPlaceIds;
      final search = vm.loadResults.execute('molise');
      vm.dispose();
      pendingPlaceIds.complete(const Result.success(<int>[1]));
      await search;

      expect(repository.getEventIdsByQueryCallCount, 0);
      expect(vm.results, isEmpty);
      expect(vm.loadResults.completed, isTrue);
    });

    test('late related IDs do not start the child command', () async {
      final repository = FakeSearchRepository();
      final vm = SearchViewModel(
        eventRepository: FakeEventRepository(),
        exploreGetByIdUseCase: _FakeExploreGetByIdUseCase(),
        searchRepository: repository,
      );
      await pumpEventQueue();
      expect(vm.loadPastSearches.completed, isTrue);

      final pendingIds = Completer<Result<List<int>>>();
      repository.pendingGetRelatedResults = pendingIds;
      final related = vm.loadRelatedResultsIds.execute('molise');
      vm.dispose();
      pendingIds.complete(const Result.success(<int>[1]));
      await related;

      expect(vm.relatedResultIds, isEmpty);
      expect(vm.loadRelatedResults.idle, isTrue);
      expect(vm.loadRelatedResultsIds.completed, isTrue);
    });

    test(
      'late related Place does not publish results after disposal',
      () async {
        final repository = FakeSearchRepository();
        final places = FakePlaceRepository();
        final pendingRelatedIds = Completer<Result<List<int>>>()
          ..complete(const Result.success(<int>[1]));
        final pendingPlace = Completer<Result<Place>>();
        repository.pendingGetRelatedResults = pendingRelatedIds;
        places.pendingGetById[1] = pendingPlace;
        final events = FakeEventRepository();
        final vm = SearchViewModel(
          eventRepository: events,
          exploreGetByIdUseCase: ExploreUseCase(
            eventRepository: events,
            placeRepository: places,
          ),
          searchRepository: repository,
        );
        await pumpEventQueue();

        final related = vm.loadRelatedResultsIds.execute('molise');
        await pumpEventQueue();
        expect(vm.loadRelatedResults.running, isTrue);
        vm.dispose();
        pendingPlace.complete(Result.success(makePlace()));
        await related;

        expect(vm.relatedResultIds, [1]);
        expect(vm.relatedResults, isEmpty);
        expect(vm.loadRelatedResults.completed, isTrue);
        expect(vm.loadRelatedResultsIds.completed, isTrue);
      },
    );

    group('loadPastSearches', () {
      test('populates pastSearches on success', () async {
        final vm = _buildVm(
          searchRepository: _FakeSearchRepository(
            pastSearchesResult: const Result.success(['molise', 'campobasso']),
          ),
        );

        await pumpEventQueue();

        expect(vm.loadPastSearches.completed, isTrue);
        expect(vm.pastSearches, equals(['molise', 'campobasso']));
      });

      test('surfaces error on failure', () async {
        final vm = _buildVm(
          searchRepository: _FakeSearchRepository(
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
        final vm = await _buildLoaded(
          searchRepository: _FakeSearchRepository(
            pastSearchesResult: const Result.success([]),
          ),
        );

        await vm.addToPastSearches.execute('');

        expect(vm.addToPastSearches.completed, isTrue);
        expect(vm.pastSearches, isEmpty);
      });

      test('does nothing when query matches a type label', () async {
        final vm = await _buildLoaded(
          searchRepository: _FakeSearchRepository(
            pastSearchesResult: const Result.success([]),
          ),
        );

        // 'Natura' is a category label.
        await vm.addToPastSearches.execute('Natura');

        expect(vm.addToPastSearches.completed, isTrue);
        expect(vm.pastSearches, isEmpty);
      });

      test('does not duplicate an already-present query', () async {
        final vm = await _buildLoaded(
          searchRepository: _FakeSearchRepository(
            pastSearchesResult: const Result.success(['molise']),
          ),
        );

        await vm.addToPastSearches.execute('molise');

        expect(vm.addToPastSearches.completed, isTrue);
        expect(vm.pastSearches, equals(['molise']));
      });

      test('case-insensitive duplicate check', () async {
        final vm = await _buildLoaded(
          searchRepository: _FakeSearchRepository(
            pastSearchesResult: const Result.success(['Molise']),
          ),
        );

        await vm.addToPastSearches.execute('molise');

        expect(vm.addToPastSearches.completed, isTrue);
        expect(vm.pastSearches, hasLength(1));
      });

      test('optimistically adds query and persists on success', () async {
        final vm = await _buildLoaded(
          searchRepository: _FakeSearchRepository(
            pastSearchesResult: const Result.success([]),
            addToHistoryResult: const Result.success(null),
          ),
        );

        await vm.addToPastSearches.execute('campobasso');

        expect(vm.addToPastSearches.completed, isTrue);
        expect(vm.pastSearches, contains('campobasso'));
      });

      test('rolls back optimistic add when persist fails', () async {
        final vm = await _buildLoaded(
          searchRepository: _FakeSearchRepository(
            pastSearchesResult: const Result.success([]),
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
          searchRepository: _FakeSearchRepository(
            pastSearchesResult: const Result.success(['molise']),
            removeFromHistoryResult: const Result.success(null),
          ),
        );

        await vm.removeFromPastSearches.execute('molise');

        expect(vm.removeFromPastSearches.completed, isTrue);
        expect(vm.pastSearches, isNot(contains('molise')));
      });

      test('rolls back removal when persist fails', () async {
        final vm = await _buildLoaded(
          searchRepository: _FakeSearchRepository(
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

    group('loadSuggestions', () {
      test(
        'succeeds without searching for queries shorter than 3 chars',
        () async {
          final vm = await _buildLoaded(
            searchRepository: _FakeSearchRepository(),
          );

          await vm.loadSuggestions.execute('mo');

          expect(vm.loadSuggestions.completed, isTrue);
          expect(vm.suggestions, isEmpty);
        },
      );

      test(
        'populates results from both place and event ids on success',
        () async {
          final place = makePlace();
          final event = makeEvent(remoteId: 2);

          final vm = await _buildLoaded(
            searchRepository: _FakeSearchRepository(
              placeIdsByQueryResult: const Result.success([1]),
              eventIdsByQueryResult: const Result.success([2]),
            ),
            placeResults: {1: Result.success(place)},
            eventResults: {2: Result.success(event)},
          );

          await vm.loadSuggestions.execute('campobasso');

          expect(vm.loadSuggestions.completed, isTrue);
          expect(vm.suggestions, hasLength(2));
        },
      );

      test('surfaces error when getPlaceIdsByQuery fails', () async {
        final vm = await _buildLoaded(
          searchRepository: _FakeSearchRepository(
            placeIdsByQueryResult: Result.error(
              TestException('place search failed'),
            ),
            eventIdsByQueryResult: const Result.success([]),
          ),
        );

        await vm.loadSuggestions.execute('campobasso');

        expect(vm.loadSuggestions.error, isTrue);
        expect(vm.suggestions, isEmpty);
      });

      test('surfaces error when getEventIdsByQuery fails', () async {
        final vm = await _buildLoaded(
          searchRepository: _FakeSearchRepository(
            placeIdsByQueryResult: const Result.success([]),
            eventIdsByQueryResult: Result.error(
              TestException('event search failed'),
            ),
          ),
        );

        await vm.loadSuggestions.execute('campobasso');

        expect(vm.loadSuggestions.error, isTrue);
        expect(vm.suggestions, isEmpty);
      });

      test('silently skips place when its getById fails', () async {
        final event = makeEvent(remoteId: 2);

        final vm = await _buildLoaded(
          searchRepository: _FakeSearchRepository(
            placeIdsByQueryResult: const Result.success([1]),
            eventIdsByQueryResult: const Result.success([2]),
          ),
          placeResults: {1: Result.error(TestException('not found'))},
          eventResults: {2: Result.success(event)},
        );

        await vm.loadSuggestions.execute('campobasso');

        // Place 1 is silently skipped; only event 2 is added.
        expect(vm.loadSuggestions.completed, isTrue);
        expect(vm.suggestions, hasLength(1));
      });

      test('silently skips event when its getById fails', () async {
        final place = makePlace();

        final vm = await _buildLoaded(
          searchRepository: _FakeSearchRepository(
            placeIdsByQueryResult: const Result.success([1]),
            eventIdsByQueryResult: const Result.success([2]),
          ),
          placeResults: {1: Result.success(place)},
          eventResults: {2: Result.error(TestException('not found'))},
        );

        await vm.loadSuggestions.execute('campobasso');

        // Event 2 is silently skipped; only place 1 is added.
        expect(vm.loadSuggestions.completed, isTrue);
        expect(vm.suggestions, hasLength(1));
      });

      test('clears previous place results before each search', () async {
        final repo = _FakeSearchRepository(
          placeIdsByQueryResult: const Result.success([1]),
          eventIdsByQueryResult: const Result.success([]),
        );
        final vm = await _buildLoaded(
          searchRepository: repo,
          placeResults: {1: Result.success(makePlace())},
        );

        await vm.loadSuggestions.execute('campobasso');
        expect(vm.suggestions, hasLength(1));

        // Switch to empty results and search again on the same VM instance.
        repo._placeIdsByQueryResult = const Result.success([]);
        await vm.loadSuggestions.execute('isernia');
        expect(vm.suggestions, isEmpty);
      });

      test('clears previous event results before each search', () async {
        final repo = _FakeSearchRepository(
          placeIdsByQueryResult: const Result.success([]),
          eventIdsByQueryResult: const Result.success([2]),
        );
        final vm = await _buildLoaded(
          searchRepository: repo,
          eventResults: {2: Result.success(makeEvent(remoteId: 2))},
        );

        await vm.loadSuggestions.execute('campobasso');
        expect(vm.suggestions, hasLength(1));

        // Switch to empty results and search again on the same VM instance.
        repo._eventIdsByQueryResult = const Result.success([]);
        await vm.loadSuggestions.execute('isernia');
        expect(vm.suggestions, isEmpty);
      });
    });

    group('loadRelatedResultsIds', () {
      test('does not fetch results for queries shorter than 3 chars', () async {
        final vm = await _buildLoaded(
          searchRepository: _FakeSearchRepository(
            relatedResultsResult: const Result.success([1]),
          ),
          placeResults: {1: Result.success(makePlace())},
        );

        await vm.loadRelatedResultsIds.execute('mo');

        expect(vm.loadRelatedResultsIds.completed, isTrue);
        expect(vm.relatedResultIds, isEmpty);
        expect(vm.relatedResults, isEmpty);
      });

      test('fetches results for queries of exactly 3 chars', () async {
        final place = makePlace();

        final vm = await _buildLoaded(
          searchRepository: _FakeSearchRepository(
            relatedResultsResult: const Result.success([1]),
          ),
          placeResults: {1: Result.success(place)},
        );

        await vm.loadRelatedResultsIds.execute('mol');

        expect(vm.loadRelatedResultsIds.completed, isTrue);
        expect(vm.relatedResultIds, equals([1]));
        expect(vm.relatedResults, hasLength(1));
      });
    });

    group('loadResults', () {
      test(
        'succeeds without searching for queries shorter than 3 chars',
        () async {
          final vm = await _buildLoaded(
            searchRepository: _FakeSearchRepository(),
          );

          await vm.loadResults.execute('mo');

          expect(vm.loadResults.completed, isTrue);
          expect(vm.results, isEmpty);
        },
      );

      test(
        'populates results from both place and event ids on success',
        () async {
          final place = makePlace();
          final event = makeEvent(remoteId: 2);

          final vm = await _buildLoaded(
            searchRepository: _FakeSearchRepository(
              placeIdsByQueryResult: const Result.success([1]),
              eventIdsByQueryResult: const Result.success([2]),
            ),
            placeResults: {1: Result.success(place)},
            eventResults: {2: Result.success(event)},
          );

          await vm.loadResults.execute('campobasso');

          expect(vm.loadResults.completed, isTrue);
          expect(vm.results, hasLength(2));
        },
      );

      test('surfaces error when getPlaceIdsByQuery fails', () async {
        final vm = await _buildLoaded(
          searchRepository: _FakeSearchRepository(
            placeIdsByQueryResult: Result.error(
              TestException('place search failed'),
            ),
            eventIdsByQueryResult: const Result.success([]),
          ),
        );

        await vm.loadResults.execute('campobasso');

        expect(vm.loadResults.error, isTrue);
        expect(vm.results, isEmpty);
      });

      test('surfaces error when getEventIdsByQuery fails', () async {
        final vm = await _buildLoaded(
          searchRepository: _FakeSearchRepository(
            placeIdsByQueryResult: const Result.success([]),
            eventIdsByQueryResult: Result.error(
              TestException('event search failed'),
            ),
          ),
        );

        await vm.loadResults.execute('campobasso');

        expect(vm.loadResults.error, isTrue);
        expect(vm.results, isEmpty);
      });
    });
  });
}

// ---------------------------------------------------------------------------
// Builder helpers
// ---------------------------------------------------------------------------

SearchViewModel _buildVm({
  required _FakeSearchRepository searchRepository,
  Map<int, Result<Place>> placeResults = const {},
  Map<int, Result<Event>> eventResults = const {},
}) {
  final eventRepository = FakeEventRepository(getByIdResults: eventResults);

  return SearchViewModel(
    eventRepository: eventRepository,
    exploreGetByIdUseCase: _FakeExploreGetByIdUseCase(
      placeResults: placeResults,
    ),
    searchRepository: searchRepository,
  );
}

Future<SearchViewModel> _buildLoaded({
  required _FakeSearchRepository searchRepository,
  Map<int, Result<Place>> placeResults = const {},
  Map<int, Result<Event>> eventResults = const {},
}) async {
  final vm = _buildVm(
    searchRepository: searchRepository,
    placeResults: placeResults,
    eventResults: eventResults,
  );

  // Let the initial loadPastSearches complete.
  await pumpEventQueue();

  return vm;
}

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

final class _FakeSearchRepository implements SearchRepository {
  _FakeSearchRepository({
    Result<List<String>>? pastSearchesResult,
    Result<void>? addToHistoryResult,
    Result<void>? removeFromHistoryResult,
    Result<List<int>>? placeIdsByQueryResult,
    Result<List<int>>? eventIdsByQueryResult,
    Result<List<int>>? relatedResultsResult,
  }) : _pastSearchesResult = pastSearchesResult ?? const Result.success([]),
       _addToHistoryResult = addToHistoryResult ?? const Result.success(null),
       _removeFromHistoryResult =
           removeFromHistoryResult ?? const Result.success(null),
       _placeIdsByQueryResult =
           placeIdsByQueryResult ?? const Result.success([]),
       _eventIdsByQueryResult =
           eventIdsByQueryResult ?? const Result.success([]),
       _relatedResultsResult = relatedResultsResult ?? const Result.success([]);

  final Result<List<String>> _pastSearchesResult;
  final Result<void> _addToHistoryResult;
  final Result<void> _removeFromHistoryResult;
  // Non-final to allow tests to reconfigure between calls on the same instance.
  Result<List<int>> _placeIdsByQueryResult;
  // Non-final to allow tests to reconfigure between calls on the same instance.
  Result<List<int>> _eventIdsByQueryResult;
  final Result<List<int>> _relatedResultsResult;

  @override
  Future<Result<void>> addToPastSearches(String text) async =>
      _addToHistoryResult;

  @override
  Future<Result<List<int>>> getEventIdsByQuery(String text) async =>
      _eventIdsByQueryResult;

  @override
  Future<Result<List<int>>> getPlaceIdsByQuery(String text) async =>
      _placeIdsByQueryResult;

  @override
  Future<Result<List<int>>> getRelatedResults(String text) async =>
      _relatedResultsResult;

  @override
  // Always return a mutable copy, as a real DB-backed repository would.
  Future<Result<List<String>>> getPastSearches() async =>
      _pastSearchesResult.map(List.of);

  @override
  Future<Result<void>> removeFromPastSearches(String text) async =>
      _removeFromHistoryResult;
}

final class _FakeExploreGetByIdUseCase implements ExploreGetByIdUseCase {
  _FakeExploreGetByIdUseCase({this.placeResults = const {}});

  final Map<int, Result<Place>> placeResults;

  @override
  Future<Result<Place>> getById(int id) async =>
      placeResults[id] ??
      Result.error(TestException('place $id not configured'));
}
