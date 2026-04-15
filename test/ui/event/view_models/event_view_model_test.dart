// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:moliseis/data/sources/city.dart';
import 'package:moliseis/data/sources/event.dart';
import 'package:moliseis/data/sources/media.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/content_sort.dart';
import 'package:moliseis/domain/models/event_content.dart';
import 'package:moliseis/domain/repositories/event_repository.dart';
import 'package:moliseis/ui/event/view_models/event_view_model.dart';
import 'package:moliseis/utils/result.dart';
import 'package:objectbox/objectbox.dart';

void main() {
  group('EventViewModel', () {
    group('loadAll', () {
      test('populates all events on success', () async {
        final event1 = _event(remoteId: 1, name: 'Festival');
        final vm = await buildLoaded(
          _FakeEventRepository(
            getByCurrentYearResult: Result.success([event1]),
          ),
        );

        expect(vm.loadAll.completed, isTrue);
        expect(vm.all, hasLength(1));
        expect(vm.all.first.remoteId, 1);
        expect(vm.all.first.name, 'Festival');
      });

      test('leaves all empty and surfaces error on failure', () async {
        final vm = await buildLoaded(
          _FakeEventRepository(
            getByCurrentYearResult: Result.error(
              _TestException('year fetch failed'),
            ),
          ),
        );

        expect(vm.loadAll.error, isTrue);
        expect(vm.all, isEmpty);
      });
    });

    group('loadNextIds', () {
      test('does not trigger loadNext when getNextEventIds fails', () async {
        final vm = await buildLoaded(
          _FakeEventRepository(
            getNextEventIdsResult: Result.error(
              _TestException('ids fetch failed'),
            ),
          ),
        );

        await vm.loadNextIds.execute();

        expect(vm.loadNextIds.error, isTrue);
        // loadNext must not have been triggered by the failed loadNextIds.
        expect(vm.loadNext.completed, isFalse);
        expect(vm.loadNext.error, isFalse);
      });

      test('triggers loadNext when getNextEventIds succeeds', () async {
        // Default repo has getNextEventIdsResult = Result.success([]).
        final vm = await buildLoaded(_FakeEventRepository());

        await vm.loadNextIds.execute();
        await pumpEventQueue(times: 10);

        expect(vm.loadNextIds.completed, isTrue);
        // loadNext ran over an empty list and completed without error.
        expect(vm.loadNext.completed, isTrue);
      });
    });

    group('isEventOnDay', () {
      late EventViewModel vm;

      setUp(() async {
        vm = await buildLoaded(_FakeEventRepository());
      });

      test('returns true for a single-day event on its start date', () {
        final event = _eventContent(startDate: DateTime(2026, 4, 7));
        expect(vm.isEventOnDay(event, DateTime(2026, 4, 7, 12)), isTrue);
      });

      test('returns false for a single-day event on a different date', () {
        final event = _eventContent(startDate: DateTime(2026, 4, 7));
        expect(vm.isEventOnDay(event, DateTime(2026, 4, 8)), isFalse);
      });

      test('returns true on the first day of a multi-day event', () {
        final event = _eventContent(
          startDate: DateTime(2026, 4, 7),
          endDate: DateTime(2026, 4, 9),
        );
        expect(vm.isEventOnDay(event, DateTime(2026, 4, 7)), isTrue);
      });

      test('returns true on the last day of a multi-day event', () {
        final event = _eventContent(
          startDate: DateTime(2026, 4, 7),
          endDate: DateTime(2026, 4, 9),
        );
        expect(vm.isEventOnDay(event, DateTime(2026, 4, 9)), isTrue);
      });

      test('returns false on the day after a multi-day event ends', () {
        final event = _eventContent(
          startDate: DateTime(2026, 4, 7),
          endDate: DateTime(2026, 4, 9),
        );
        expect(vm.isEventOnDay(event, DateTime(2026, 4, 10)), isFalse);
      });

      test(
        'treats malformed event (end before start) as single-day on startDate',
        () {
          final event = _eventContent(
            startDate: DateTime(2026, 4, 9),
            endDate: DateTime(2026, 4, 7),
          );
          // Falls back to single-day on startDate.
          expect(vm.isEventOnDay(event, DateTime(2026, 4, 9)), isTrue);
          expect(vm.isEventOnDay(event, DateTime(2026, 4, 7)), isFalse);
        },
      );
    });
  });
}

// ---------------------------------------------------------------------------
// Builder helper
// ---------------------------------------------------------------------------

/// Builds a fully-loaded [EventViewModel] and drains the constructor's
/// auto-fired [EventViewModel.loadAll] command.
Future<EventViewModel> buildLoaded(_FakeEventRepository repo) async {
  final vm = EventViewModel(repository: repo);
  await pumpEventQueue(times: 10);
  assert(
    vm.loadAll.completed || vm.loadAll.error,
    'buildLoaded returned before loadAll finished',
  );
  return vm;
}

// ---------------------------------------------------------------------------
// Fake repository
// ---------------------------------------------------------------------------

final class _FakeEventRepository extends EventRepository {
  _FakeEventRepository({
    this.getByCurrentYearResult = const Result.success(<Event>[]),
    this.getNextEventIdsResult = const Result.success(<int>[]),
  });

  final Result<List<Event>> getByCurrentYearResult;
  final Result<List<int>> getNextEventIdsResult;

  @override
  Future<Result<List<Event>>> getByCurrentYear() async =>
      getByCurrentYearResult;

  @override
  Future<Result<List<int>>> getNextEventIds() async => getNextEventIdsResult;

  @override
  Future<Result<List<Event>>> getByDate(DateTime date) async =>
      const Result.success(<Event>[]);

  @override
  Future<Result<List<Event>>> getByDateRange(
    DateTime start,
    DateTime end,
  ) async => const Result.success(<Event>[]);

  @override
  Future<Result<List<Event>>> getByCategories(
    Set<ContentCategory> categories, {
    ContentSort sort = ContentSort.byName,
  }) async => const Result.success(<Event>[]);

  @override
  Future<Result<List<Event>>> getByCoordinates(
    List<double> coordinates,
  ) async => const Result.success(<Event>[]);

  @override
  Future<Result<Event>> getById(int id) async =>
      Result.error(_TestException('not configured'));

  @override
  Future<Result<List<int>>> getFavouriteEventIds() async =>
      const Result.success(<int>[]);

  @override
  Future<Result<void>> setFavouriteEvent(int id, bool save) async =>
      const Result.success(null);

  @override
  Future<Result<void>> synchronize() async => const Result.success(null);
}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

Event _event({required int remoteId, required String name}) {
  final now = DateTime.utc(2026, 4, 7);
  return Event(
    remoteId: remoteId,
    name: name,
    description: 'Description',
    startDate: now,
    coordinates: const [41.9, 14.7],
    category: ContentCategory.history,
    createdAt: now,
    modifiedAt: now,
    city: ToOne<City>(),
    media: ToMany<Media>(),
  );
}

EventContent _eventContent({required DateTime startDate, DateTime? endDate}) {
  final now = DateTime(2026, 4, 1);
  return EventContent(
    remoteId: 1,
    name: 'Event',
    description: '',
    category: ContentCategory.unknown,
    city: ToOne<City>(),
    coordinates: const LatLng(0, 0),
    createdAt: now,
    modifiedAt: now,
    media: ToMany<Media>(),
    startDate: startDate,
    endDate: endDate,
    isSaved: false,
  );
}

// ---------------------------------------------------------------------------
// Test exception
// ---------------------------------------------------------------------------

final class _TestException implements Exception {
  _TestException(this.message);

  final String message;

  @override
  String toString() => message;
}
