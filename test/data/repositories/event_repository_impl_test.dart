// Test readability benefits from separate statements over cascades.
// ignore_for_file: cascade_invocations

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moliseis/data/data-sources/city_entity.dart';
import 'package:moliseis/data/data-sources/event_entity.dart';
import 'package:moliseis/data/data-sources/event_supabase_table.dart';
import 'package:moliseis/data/dtos/event_dto.dart';
import 'package:moliseis/data/repositories/event_repository_impl.dart';
import 'package:moliseis/data/services/objectbox.dart' as app_objectbox;
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/content_sort.dart';
import 'package:moliseis/domain/models/event.dart';
import 'package:moliseis/generated/objectbox.g.dart';
import 'package:moliseis/utils/logging/logging.dart';
import 'package:moliseis/utils/result.dart';
import 'package:objectbox/objectbox.dart';

import '../../support/mock_logger.dart';
import '../../support/mock_supabase.dart';
import '../../support/objectbox_test_store.dart';

void main() {
  setUpAll(setUpMockSupabase);

  group('EventRepositoryImpl - DateTime Overlap Logic', () {
    late TestObjectBoxEnvironment objectBoxEnvironment;
    late Box<EventEntity> eventBox;
    late MockLogger mockLogger;
    late EventRepositoryImpl repository;

    setUp(() async {
      objectBoxEnvironment = await TestObjectBoxEnvironment.create();
      eventBox = objectBoxEnvironment.store.box<EventEntity>();
      mockLogger = MockLogger();
      repository = EventRepositoryImpl(
        logger: mockLogger,
        supabaseI: MockSupabase(),
        supabaseTable: EventSupabaseTable(),
        objectBoxI: TestObjectBox(objectBoxEnvironment.store),
      );
    });

    tearDown(() async {
      await objectBoxEnvironment.dispose();
    });

    void seedEvents(List<EventEntity> events) {
      events.forEach(eventBox.put);
    }

    group('_getByDateRange with single-day events (endDate = null)', () {
      test(
        'includes single-day event when start date is within range',
        () async {
          final now = DateTime(2026, 3, 15);
          final rangeStart = DateTime(2026, 3, 10);
          final rangeEnd = DateTime(2026, 3, 20);

          final event = _createEvent(
            remoteId: 1,
            startDate: now,
            endDate: null,
          );

          seedEvents([event]);

          final result = await repository.getByDateRange(rangeStart, rangeEnd);

          expect(result, isA<Success<List<Event>>>());
          final success = result as Success<List<Event>>;
          expect(success.value, containsEventId(1));
        },
      );

      test(
        'excludes single-day event when start date is before range',
        () async {
          seedEvents([
            _createEvent(
              remoteId: 1,
              startDate: DateTime(2026, 3, 5), // before rangeStart
              endDate: null,
            ),
          ]);

          final result = await repository.getByDateRange(
            DateTime(2026, 3, 10),
            DateTime(2026, 3, 20),
          );

          expect(result, isA<Success<List<Event>>>());
          final success = result as Success<List<Event>>;
          expect(success.value, isEmpty);
        },
      );

      test(
        'excludes single-day event when start date is after range',
        () async {
          seedEvents([
            _createEvent(
              remoteId: 1,
              startDate: DateTime(2026, 3, 25), // after rangeEnd
              endDate: null,
            ),
          ]);

          final result = await repository.getByDateRange(
            DateTime(2026, 3, 10),
            DateTime(2026, 3, 20),
          );

          expect(result, isA<Success<List<Event>>>());
          final success = result as Success<List<Event>>;
          expect(success.value, isEmpty);
        },
      );

      test(
        'prevents old single-day events from leaking into range queries',
        () async {
          seedEvents([
            _createEvent(
              remoteId: 1,
              startDate: DateTime(2020), // years before the range
              endDate: null,
            ),
          ]);

          final result = await repository.getByDateRange(
            DateTime(2026, 3, 10),
            DateTime(2026, 3, 20),
          );

          expect(result, isA<Success<List<Event>>>());
          final success = result as Success<List<Event>>;
          expect(success.value, isEmpty);
        },
      );

      test('includes single-day event at range start boundary', () async {
        final event = _createEvent(
          remoteId: 1,
          startDate: DateTime(2026, 3, 10),
          endDate: null,
        );

        seedEvents([event]);

        final result = await repository.getByDateRange(
          DateTime(2026, 3, 10),
          DateTime(2026, 3, 20),
        );

        expect(result, isA<Success<List<Event>>>());
        final success = result as Success<List<Event>>;
        expect(success.value, containsEventId(1));
      });

      test('includes single-day event at range end boundary', () async {
        final event = _createEvent(
          remoteId: 1,
          startDate: DateTime(2026, 3, 20),
          endDate: null,
        );

        seedEvents([event]);

        final result = await repository.getByDateRange(
          DateTime(2026, 3, 10),
          DateTime(2026, 3, 20),
        );

        expect(result, isA<Success<List<Event>>>());
        final success = result as Success<List<Event>>;
        expect(success.value, containsEventId(1));
      });
    });

    group('_getByDateRange with multi-day events (endDate != null)', () {
      test('includes event fully contained within range', () async {
        final event = _createEvent(
          remoteId: 1,
          startDate: DateTime(2026, 3, 5),
          endDate: DateTime(2026, 3, 25),
        );

        seedEvents([event]);

        final result = await repository.getByDateRange(
          DateTime(2026, 3, 10),
          DateTime(2026, 3, 20),
        );

        expect(result, isA<Success<List<Event>>>());
        final success = result as Success<List<Event>>;
        expect(success.value, containsEventId(1));
      });

      test('includes event overlapping range start', () async {
        final event = _createEvent(
          remoteId: 1,
          startDate: DateTime(2026, 3, 5),
          endDate: DateTime(2026, 3, 15),
        );

        seedEvents([event]);

        final result = await repository.getByDateRange(
          DateTime(2026, 3, 10),
          DateTime(2026, 3, 20),
        );

        expect(result, isA<Success<List<Event>>>());
        final success = result as Success<List<Event>>;
        expect(success.value, containsEventId(1));
      });

      test('includes event overlapping range end', () async {
        final event = _createEvent(
          remoteId: 1,
          startDate: DateTime(2026, 3, 15),
          endDate: DateTime(2026, 3, 25),
        );

        seedEvents([event]);

        final result = await repository.getByDateRange(
          DateTime(2026, 3, 10),
          DateTime(2026, 3, 20),
        );

        expect(result, isA<Success<List<Event>>>());
        final success = result as Success<List<Event>>;
        expect(success.value, containsEventId(1));
      });

      test('includes event fully containing range', () async {
        final event = _createEvent(
          remoteId: 1,
          startDate: DateTime(2026, 3),
          endDate: DateTime(2026, 3, 31),
        );

        seedEvents([event]);

        final result = await repository.getByDateRange(
          DateTime(2026, 3, 10),
          DateTime(2026, 3, 20),
        );

        expect(result, isA<Success<List<Event>>>());
        final success = result as Success<List<Event>>;
        expect(success.value, containsEventId(1));
      });

      test('excludes event before range', () async {
        seedEvents([
          _createEvent(
            remoteId: 1,
            startDate: DateTime(2026, 3),
            endDate: DateTime(2026, 3, 8), // ends before rangeStart
          ),
        ]);

        final result = await repository.getByDateRange(
          DateTime(2026, 3, 10),
          DateTime(2026, 3, 20),
        );

        expect(result, isA<Success<List<Event>>>());
        final success = result as Success<List<Event>>;
        expect(success.value, isEmpty);
      });

      test('excludes event after range', () async {
        seedEvents([
          _createEvent(
            remoteId: 1,
            startDate: DateTime(2026, 3, 22), // starts after rangeEnd
            endDate: DateTime(2026, 3, 28),
          ),
        ]);

        final result = await repository.getByDateRange(
          DateTime(2026, 3, 10),
          DateTime(2026, 3, 20),
        );

        expect(result, isA<Success<List<Event>>>());
        final success = result as Success<List<Event>>;
        expect(success.value, isEmpty);
      });

      test('includes event at range start boundary', () async {
        final event = _createEvent(
          remoteId: 1,
          startDate: DateTime(2026, 3, 10),
          endDate: DateTime(2026, 3, 15),
        );

        seedEvents([event]);

        final result = await repository.getByDateRange(
          DateTime(2026, 3, 10),
          DateTime(2026, 3, 20),
        );

        expect(result, isA<Success<List<Event>>>());
        final success = result as Success<List<Event>>;
        expect(success.value, containsEventId(1));
      });

      test('includes event at range end boundary', () async {
        final event = _createEvent(
          remoteId: 1,
          startDate: DateTime(2026, 3, 15),
          endDate: DateTime(2026, 3, 20),
        );

        seedEvents([event]);

        final result = await repository.getByDateRange(
          DateTime(2026, 3, 10),
          DateTime(2026, 3, 20),
        );

        expect(result, isA<Success<List<Event>>>());
        final success = result as Success<List<Event>>;
        expect(success.value, containsEventId(1));
      });
    });

    group('_getByDateRange with mixed event types', () {
      test('correctly filters single-day and multi-day events', () async {
        final singleDay = _createEvent(
          remoteId: 1,
          startDate: DateTime(2026, 3, 15),
          endDate: null,
        );

        final multiDay = _createEvent(
          remoteId: 2,
          startDate: DateTime(2026, 3, 5),
          endDate: DateTime(2026, 3, 25),
        );

        seedEvents([singleDay, multiDay]);

        final result = await repository.getByDateRange(
          DateTime(2026, 3, 10),
          DateTime(2026, 3, 20),
        );

        expect(result, isA<Success<List<Event>>>());
        final success = result as Success<List<Event>>;
        expect(success.value, hasLength(2));
        expect(success.value, containsEventId(1));
        expect(success.value, containsEventId(2));
      });
    });

    group('exception propagation from _getByDateRange', () {
      late MockLogger mockLogger;
      late EventRepositoryImpl mockRepository;

      setUp(() {
        mockLogger = MockLogger();
        final mockBox = _MockEventEntityBox();
        when(() => mockBox.query(any())).thenThrow(Exception('query failed'));

        final mockStore = _MockStore(mockBox);

        mockRepository = EventRepositoryImpl(
          logger: mockLogger,
          supabaseI: MockSupabase(),
          supabaseTable: EventSupabaseTable(),
          objectBoxI: _MockObjectBox(mockStore),
        );
      });

      test(
        'getByDate returns Result.error when _getByDateRange rethrows',
        () async {
          final result = await mockRepository.getByDate(DateTime(2026, 3, 15));

          expect(result, isA<Error<List<Event>>>());
          final failedCall = mockLogger.firstCallOfType<EntityLoadFailed>();
          expect(failedCall, isNotNull);
          expect(
            failedCall!.event,
            const EntityLoadFailed('event', method: 'getByDate'),
          );
          expect(failedCall.error, isNotNull);
          expect(failedCall.stackTrace, isNotNull);
        },
      );

      test(
        'getByDateRange returns Result.error when _getByDateRange rethrows',
        () async {
          final result = await mockRepository.getByDateRange(
            DateTime(2026, 3, 10),
            DateTime(2026, 3, 20),
          );

          expect(result, isA<Error<List<Event>>>());
          final failedCall = mockLogger.firstCallOfType<EntityLoadFailed>();
          expect(failedCall, isNotNull);
          expect(
            failedCall!.event,
            const EntityLoadFailed('event', method: 'getByDateRange'),
          );
          expect(failedCall.error, isNotNull);
          expect(failedCall.stackTrace, isNotNull);
        },
      );
    });

    group('getByDate - single day normalization', () {
      test('normalizes date to full day range', () async {
        final event = _createEvent(
          remoteId: 1,
          startDate: DateTime(2026, 3, 15, 14, 30),
          endDate: null,
        );

        seedEvents([event]);

        final result = await repository.getByDate(DateTime(2026, 3, 15));

        expect(result, isA<Success<List<Event>>>());
        final success = result as Success<List<Event>>;
        expect(success.value, containsEventId(1));
      });

      test('excludes event that starts on the following day', () async {
        seedEvents([
          _createEvent(
            remoteId: 2,
            startDate: DateTime(2026, 3, 16), // midnight of next day
            endDate: null,
          ),
        ]);

        final result = await repository.getByDate(DateTime(2026, 3, 15));

        expect(result, isA<Success<List<Event>>>());
        final success = result as Success<List<Event>>;
        expect(success.value, isEmpty);
      });
    });
  });

  group('EventRepositoryImpl - getByCurrentYear', () {
    late TestObjectBoxEnvironment objectBoxEnvironment;
    late Box<EventEntity> eventBox;
    late EventRepositoryImpl repository;

    setUp(() async {
      objectBoxEnvironment = await TestObjectBoxEnvironment.create();
      eventBox = objectBoxEnvironment.store.box<EventEntity>();
      repository = EventRepositoryImpl(
        logger: MockLogger(),
        supabaseI: MockSupabase(),
        supabaseTable: EventSupabaseTable(),
        objectBoxI: TestObjectBox(objectBoxEnvironment.store),
      );
    });

    tearDown(() async {
      await objectBoxEnvironment.dispose();
    });

    test(
      'includes multi-day event that starts and ends within current year',
      () async {
        final now = DateTime.now();
        final event = _createEvent(
          remoteId: 1,
          startDate: DateTime(now.year, 6),
          endDate: DateTime(now.year, 6, 10),
        );
        eventBox.put(event);

        final result = await repository.getByCurrentYear();

        expect(result, isA<Success<List<Event>>>());
        expect(
          (result as Success<List<Event>>).value.map((e) => e.remoteId),
          contains(1),
        );
      },
    );

    test(
      'includes single-day event (null endDate) whose startDate is in current '
      'year',
      () async {
        final now = DateTime.now();
        final event = _createEvent(
          remoteId: 2,
          startDate: DateTime(now.year, 5, 15),
          endDate: null,
        );
        eventBox.put(event);

        final result = await repository.getByCurrentYear();

        expect(result, isA<Success<List<Event>>>());
        expect(
          (result as Success<List<Event>>).value.map((e) => e.remoteId),
          contains(2),
        );
      },
    );

    test('excludes multi-day event from a past year', () async {
      final event = _createEvent(
        remoteId: 3,
        startDate: DateTime(2020, 8),
        endDate: DateTime(2020, 8, 10),
      );
      eventBox.put(event);

      final result = await repository.getByCurrentYear();

      expect(result, isA<Success<List<Event>>>());
      expect(
        (result as Success<List<Event>>).value.map((e) => e.remoteId),
        isNot(contains(3)),
      );
    });

    test('excludes single-day event from a past year', () async {
      final event = _createEvent(
        remoteId: 4,
        startDate: DateTime(2020, 3, 20),
        endDate: null,
      );
      eventBox.put(event);

      final result = await repository.getByCurrentYear();

      expect(result, isA<Success<List<Event>>>());
      expect(
        (result as Success<List<Event>>).value.map((e) => e.remoteId),
        isNot(contains(4)),
      );
    });

    test('returns empty list when store is empty', () async {
      final result = await repository.getByCurrentYear();

      expect(result, isA<Success<List<Event>>>());
      expect((result as Success<List<Event>>).value, isEmpty);
    });
  });

  group('EventRepositoryImpl - getByCategories', () {
    late TestObjectBoxEnvironment objectBoxEnvironment;
    late Box<EventEntity> eventBox;
    late EventRepositoryImpl repository;

    setUp(() async {
      objectBoxEnvironment = await TestObjectBoxEnvironment.create();
      eventBox = objectBoxEnvironment.store.box<EventEntity>();
      repository = EventRepositoryImpl(
        logger: MockLogger(),
        supabaseI: MockSupabase(),
        supabaseTable: EventSupabaseTable(),
        objectBoxI: TestObjectBox(objectBoxEnvironment.store),
      );
    });

    tearDown(() async {
      await objectBoxEnvironment.dispose();
    });

    test(
      'includes current-year multi-day event matching the requested category',
      () async {
        final now = DateTime.now();
        final event = _createEvent(
          remoteId: 1,
          startDate: DateTime(now.year, 7),
          endDate: DateTime(now.year, 7, 5),
          category: ContentCategory.food,
        );
        eventBox.put(event);

        final result = await repository.getByCategories({ContentCategory.food});

        expect(result, isA<Success<List<Event>>>());
        expect(
          (result as Success<List<Event>>).value.map((e) => e.remoteId),
          contains(1),
        );
      },
    );

    test(
      'includes current-year single-day event (null endDate) matching the '
      'requested category',
      () async {
        final now = DateTime.now();
        final event = _createEvent(
          remoteId: 2,
          startDate: DateTime(now.year, 9, 10),
          endDate: null,
          category: ContentCategory.folklore,
        );
        eventBox.put(event);

        final result = await repository.getByCategories({
          ContentCategory.folklore,
        });

        expect(result, isA<Success<List<Event>>>());
        expect(
          (result as Success<List<Event>>).value.map((e) => e.remoteId),
          contains(2),
        );
      },
    );

    test('excludes past-year event even when category matches', () async {
      final event = _createEvent(
        remoteId: 3,
        startDate: DateTime(2020, 4),
        endDate: DateTime(2020, 4, 5),
        category: ContentCategory.nature,
      );
      eventBox.put(event);

      final result = await repository.getByCategories({ContentCategory.nature});

      expect(result, isA<Success<List<Event>>>());
      expect(
        (result as Success<List<Event>>).value.map((e) => e.remoteId),
        isNot(contains(3)),
      );
    });

    test('excludes current-year event whose category does not match', () async {
      final now = DateTime.now();
      final event = _createEvent(
        remoteId: 4,
        startDate: DateTime(now.year, 6),
        endDate: DateTime(now.year, 6, 5),
        category: ContentCategory.history,
      );
      eventBox.put(event);

      final result = await repository.getByCategories({ContentCategory.nature});

      expect(result, isA<Success<List<Event>>>());
      expect(
        (result as Success<List<Event>>).value.map((e) => e.remoteId),
        isNot(contains(4)),
      );
    });

    test('sorts by name ascending when sort is byName', () async {
      final now = DateTime.now();
      eventBox.put(
        _createEvent(
          remoteId: 1,
          name: 'Zeta Festival',
          startDate: DateTime(now.year, 7),
          endDate: DateTime(now.year, 7, 5),
          category: ContentCategory.folklore,
        ),
      );
      eventBox.put(
        _createEvent(
          remoteId: 2,
          name: 'Alpha Fair',
          startDate: DateTime(now.year, 8),
          endDate: DateTime(now.year, 8, 5),
          category: ContentCategory.folklore,
        ),
      );
      eventBox.put(
        _createEvent(
          remoteId: 3,
          name: 'Middle Market',
          startDate: DateTime(now.year, 9),
          endDate: null,
          category: ContentCategory.folklore,
        ),
      );

      final result = await repository.getByCategories(
        {ContentCategory.folklore},
      );

      expect(result, isA<Success<List<Event>>>());
      final names = (result as Success<List<Event>>).value
          .map((e) => e.name)
          .toList();
      expect(names, equals(['Alpha Fair', 'Middle Market', 'Zeta Festival']));
    });

    test('sorts by modifiedAt descending when sort is byDate', () async {
      final now = DateTime.now();
      eventBox.put(
        _createEvent(
          remoteId: 1,
          name: 'Older',
          startDate: DateTime(now.year, 7),
          endDate: null,
          category: ContentCategory.food,
          modifiedAt: DateTime(2025),
        ),
      );
      eventBox.put(
        _createEvent(
          remoteId: 2,
          name: 'Newer',
          startDate: DateTime(now.year, 8),
          endDate: null,
          category: ContentCategory.food,
          modifiedAt: DateTime(2026, 6),
        ),
      );
      eventBox.put(
        _createEvent(
          remoteId: 3,
          name: 'Middle',
          startDate: DateTime(now.year, 9),
          endDate: null,
          category: ContentCategory.food,
          modifiedAt: DateTime(2025, 12),
        ),
      );

      final result = await repository.getByCategories(
        {ContentCategory.food},
        sort: ContentSort.byDate,
      );

      expect(result, isA<Success<List<Event>>>());
      final names = (result as Success<List<Event>>).value
          .map((e) => e.name)
          .toList();
      expect(names, equals(['Newer', 'Middle', 'Older']));
    });
  });

  // ---------------------------------------------------------------------------
  // getByCurrentYear — cache invalidation
  // ---------------------------------------------------------------------------

  group('EventRepositoryImpl - getByCurrentYear cache invalidation', () {
    late MockLogger mockLogger;
    late MockSupabaseEnvironment supabaseEnv;
    late TestObjectBoxEnvironment objectBoxEnvironment;
    late Box<EventEntity> eventBox;
    late EventRepositoryImpl repository;

    setUp(() async {
      mockLogger = MockLogger();
      supabaseEnv = MockSupabaseEnvironment();
      objectBoxEnvironment = await TestObjectBoxEnvironment.create();
      eventBox = objectBoxEnvironment.store.box<EventEntity>();
      repository = EventRepositoryImpl(
        logger: mockLogger,
        supabaseI: supabaseEnv.mockSupabase,
        supabaseTable: EventSupabaseTable(),
        objectBoxI: TestObjectBox(objectBoxEnvironment.store),
      );
    });

    tearDown(() async {
      await objectBoxEnvironment.dispose();
    });

    test(
      'reflects newly synced events after synchronize invalidates cache',
      () async {
        final now = DateTime.now();

        // Seed a current-year event in the local store.
        eventBox.put(
          _createEvent(
            remoteId: 1,
            name: 'Existing Event',
            startDate: DateTime(now.year, 6),
            endDate: DateTime(now.year, 6, 5),
          ),
        );

        // Populate the cache via getByCurrentYear().
        final firstCall = await repository.getByCurrentYear();
        expect(firstCall, isA<Success<List<Event>>>());
        expect(
          (firstCall as Success<List<Event>>).value,
          hasLength(1),
        );

        // Sync adds a new event from remote.
        supabaseEnv.stubSelectResponse([
          {
            'id': 2,
            'name': 'Synced Event',
            'start_date': '${now.year}-07-01T00:00:00.000',
            'end_date': '${now.year}-07-05T00:00:00.000',
            'created_at': '2026-01-01T00:00:00.000',
            'modified_at': '2026-01-01T00:00:00.000',
            'description': '',
            'coordinates': [0, 0],
            'category': 'unknown',
          },
        ]);
        final prepareResult = await repository.prepareSync();
        final dtos = (prepareResult as Success<List<EventDto>>).value;
        repository.commitSync(dtos);

        // Cache was invalidated; getByCurrentYear() must reflect the new event.
        final secondCall = await repository.getByCurrentYear();
        expect(secondCall, isA<Success<List<Event>>>());
        expect(
          (secondCall as Success<List<Event>>).value,
          hasLength(2),
        );
      },
    );
  });
}

Matcher containsEventId(int remoteId) =>
    contains(predicate<Event>((e) => e.remoteId == remoteId));

EventEntity _createEvent({
  required int remoteId,
  required DateTime startDate,
  required DateTime? endDate,
  String? name,
  ContentCategory category = ContentCategory.unknown,
  DateTime? modifiedAt,
}) {
  final now = DateTime.now();
  return EventEntity(
    remoteId: remoteId,
    name: name ?? 'Test Event $remoteId',
    startDate: startDate,
    endDate: endDate,
    contentCategoryIndex: category.index,
    createdAt: now,
    modifiedAt: modifiedAt ?? now,
    city: ToOne<CityEntity>(),
    media: ToMany(),
  );
}

final class _MockStore extends Mock implements Store {
  _MockStore(this._mockBox);

  final Box<EventEntity> _mockBox;

  @override
  Box<T> box<T>() {
    if (T == EventEntity) return _mockBox as Box<T>;
    throw StateError(
      '_MockStore only supports Box<EventEntity>, got Box<$T>',
    );
  }
}

final class _MockEventEntityBox extends Mock implements Box<EventEntity> {}

final class _MockObjectBox implements app_objectbox.ObjectBox {
  _MockObjectBox(this._mockStore);

  final Store _mockStore;

  @override
  Store get store => _mockStore;

  @override
  set store(Store value) {
    throw UnsupportedError('_MockObjectBox store is immutable.');
  }
}
