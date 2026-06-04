import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:moliseis/domain/core/sync_dto.dart';
import 'package:moliseis/domain/models/city.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/content_sort.dart';
import 'package:moliseis/domain/models/event.dart';
import 'package:moliseis/domain/models/place.dart';
import 'package:moliseis/domain/repositories/event_repository.dart';
import 'package:moliseis/domain/repositories/search_repository.dart';
import 'package:moliseis/domain/use-cases/explore_get_by_id_use_case.dart';
import 'package:moliseis/ui/search/view_models/search_view_model.dart';
import 'package:moliseis/utils/result.dart';

void main() {
  group('SearchViewModel', () {
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
            pastSearchesResult: Result.error(_TestException('db error')),
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
            addToHistoryResult: Result.error(_TestException('write failed')),
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
              _TestException('write failed'),
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
          final place = _makePlaceContent(1);
          final event = _makeEvent(2);

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
              _TestException('place search failed'),
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
              _TestException('event search failed'),
            ),
          ),
        );

        await vm.loadSuggestions.execute('campobasso');

        expect(vm.loadSuggestions.error, isTrue);
        expect(vm.suggestions, isEmpty);
      });

      test('silently skips place when its getById fails', () async {
        final event = _makeEvent(2);

        final vm = await _buildLoaded(
          searchRepository: _FakeSearchRepository(
            placeIdsByQueryResult: const Result.success([1]),
            eventIdsByQueryResult: const Result.success([2]),
          ),
          placeResults: {1: Result.error(_TestException('not found'))},
          eventResults: {2: Result.success(event)},
        );

        await vm.loadSuggestions.execute('campobasso');

        // Place 1 is silently skipped; only event 2 is added.
        expect(vm.loadSuggestions.completed, isTrue);
        expect(vm.suggestions, hasLength(1));
      });

      test('silently skips event when its getById fails', () async {
        final place = _makePlaceContent(1);

        final vm = await _buildLoaded(
          searchRepository: _FakeSearchRepository(
            placeIdsByQueryResult: const Result.success([1]),
            eventIdsByQueryResult: const Result.success([2]),
          ),
          placeResults: {1: Result.success(place)},
          eventResults: {2: Result.error(_TestException('not found'))},
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
          placeResults: {1: Result.success(_makePlaceContent(1))},
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
          eventResults: {2: Result.success(_makeEvent(2))},
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
          placeResults: {1: Result.success(_makePlaceContent(1))},
        );

        await vm.loadRelatedResultsIds.execute('mo');

        expect(vm.loadRelatedResultsIds.completed, isTrue);
        expect(vm.relatedResultIds, isEmpty);
        expect(vm.relatedResults, isEmpty);
      });

      test('fetches results for queries of exactly 3 chars', () async {
        final place = _makePlaceContent(1);

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
          final place = _makePlaceContent(1);
          final event = _makeEvent(2);

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
              _TestException('place search failed'),
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
              _TestException('event search failed'),
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
  final eventRepository = _FakeEventRepository(eventResults: eventResults);

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
      Result.error(_TestException('place $id not configured'));
}

final class _FakeEventRepository implements EventRepository {
  _FakeEventRepository({this.eventResults = const {}});

  final Map<int, Result<Event>> eventResults;

  @override
  Future<Result<Event>> getById(int id) async =>
      eventResults[id] ??
      Result.error(_TestException('event $id not configured'));

  @override
  Future<Result<List<Event>>> getByCurrentYear() async =>
      const Result.success([]);

  @override
  Future<Result<List<Event>>> getByDate(DateTime date) async =>
      const Result.success([]);

  @override
  Future<Result<List<Event>>> getByDateRange(
    DateTime start,
    DateTime end,
  ) async => const Result.success([]);

  @override
  Future<Result<List<Event>>> getByCategories(
    Set<ContentCategory> categories, {
    ContentSort sort = ContentSort.byName,
  }) async => const Result.success([]);

  @override
  Future<Result<List<Event>>> getByCoordinates(
    List<double> coordinates,
  ) async => const Result.success([]);

  @override
  Future<Result<List<int>>> getNextEventIds() async => const Result.success([]);

  @override
  Future<Result<List<int>>> getFavouriteEventIds() async =>
      const Result.success([]);

  @override
  Future<Result<void>> setFavouriteEvent(int id, bool save) async =>
      const Result.success(null);

  @override
  Future<Result<List<SyncDto>>> prepareSync() async =>
      const Result.success(<SyncDto>[]);

  @override
  Result<void> commitSync(List<SyncDto> dtos) => const Result.success(null);
}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

City _testCity() => City(
  remoteId: 0,
  name: 'Molise',
  createdAt: DateTime(2025),
  modifiedAt: DateTime(2025),
);

Place _makePlaceContent(int id) => Place(
  category: ContentCategory.nature,
  city: _testCity(),
  coordinates: const LatLng(41.56, 14.66),
  createdAt: DateTime(2025),
  description: '',
  isSaved: false,
  media: const [],
  modifiedAt: DateTime(2025),
  name: 'Place $id',
  remoteId: id,
);

Event _makeEvent(int id) => Event(
  remoteId: id,
  name: 'Event $id',
  description: '',
  category: ContentCategory.unknown,
  city: _testCity(),
  coordinates: const LatLng(41.56, 14.66),
  startDate: DateTime(2025),
  createdAt: DateTime(2025),
  modifiedAt: DateTime(2025),
  media: const [],
  isSaved: false,
);

final class _TestException implements Exception {
  _TestException(this.message);

  final String message;

  @override
  String toString() => message;
}
