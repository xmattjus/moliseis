// Test readability benefits from separate statements over cascades.
// ignore_for_file: cascade_invocations

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moliseis/data/core/relation_update.dart';
import 'package:moliseis/data/data-sources/event_entity.dart';
import 'package:moliseis/data/dtos/event_dto.dart';
import 'package:moliseis/data/repositories/event_repository_impl.dart';
import 'package:moliseis/domain/core/event_time.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/content_sort.dart';
import 'package:moliseis/domain/models/event.dart';
import 'package:moliseis/generated/objectbox.g.dart';
import 'package:moliseis/utils/logging/logging.dart';
import 'package:moliseis/utils/result.dart';
import 'package:objectbox/objectbox.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../support/fixtures.dart';
import '../../support/mock_logger.dart';
import '../../support/mock_objectbox.dart';
import '../../support/mock_supabase.dart';
import '../../support/objectbox_test_store.dart';

void main() {
  setUpAll(setUpMockSupabase);
  final fixedNowUtc = DateTime.utc(2026, 3, 15, 12);

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
        objectBoxI: TestObjectBox(objectBoxEnvironment.store),
        nowUtc: () => fixedNowUtc,
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
          final rangeStart = EventCalendarDate(2026, 3, 10);
          final rangeEnd = EventCalendarDate(2026, 3, 20);

          final event = makeEventEntity(remoteId: 1, startDate: now);

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
            makeEventEntity(
              remoteId: 1,
              startDate: DateTime(2026, 3, 5), // before rangeStart
            ),
          ]);

          final result = await repository.getByDateRange(
            EventCalendarDate(2026, 3, 10),
            EventCalendarDate(2026, 3, 20),
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
            makeEventEntity(
              remoteId: 1,
              startDate: DateTime(2026, 3, 25), // after rangeEnd
            ),
          ]);

          final result = await repository.getByDateRange(
            EventCalendarDate(2026, 3, 10),
            EventCalendarDate(2026, 3, 20),
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
            makeEventEntity(
              remoteId: 1,
              startDate: DateTime(2020), // years before the range
            ),
          ]);

          final result = await repository.getByDateRange(
            EventCalendarDate(2026, 3, 10),
            EventCalendarDate(2026, 3, 20),
          );

          expect(result, isA<Success<List<Event>>>());
          final success = result as Success<List<Event>>;
          expect(success.value, isEmpty);
        },
      );

      test('includes single-day event at range start boundary', () async {
        final event = makeEventEntity(
          remoteId: 1,
          startDate: DateTime(2026, 3, 10),
        );

        seedEvents([event]);

        final result = await repository.getByDateRange(
          EventCalendarDate(2026, 3, 10),
          EventCalendarDate(2026, 3, 20),
        );

        expect(result, isA<Success<List<Event>>>());
        final success = result as Success<List<Event>>;
        expect(success.value, containsEventId(1));
      });

      test('includes single-day event at range end boundary', () async {
        final event = makeEventEntity(
          remoteId: 1,
          startDate: DateTime(2026, 3, 20),
        );

        seedEvents([event]);

        final result = await repository.getByDateRange(
          EventCalendarDate(2026, 3, 10),
          EventCalendarDate(2026, 3, 20),
        );

        expect(result, isA<Success<List<Event>>>());
        final success = result as Success<List<Event>>;
        expect(success.value, containsEventId(1));
      });
    });

    group('_getByDateRange with multi-day events (endDate != null)', () {
      test('includes event fully contained within range', () async {
        final event = makeEventEntity(
          remoteId: 1,
          startDate: DateTime(2026, 3, 5),
          endDate: DateTime(2026, 3, 25),
        );

        seedEvents([event]);

        final result = await repository.getByDateRange(
          EventCalendarDate(2026, 3, 10),
          EventCalendarDate(2026, 3, 20),
        );

        expect(result, isA<Success<List<Event>>>());
        final success = result as Success<List<Event>>;
        expect(success.value, containsEventId(1));
      });

      test('includes event overlapping range start', () async {
        final event = makeEventEntity(
          remoteId: 1,
          startDate: DateTime(2026, 3, 5),
          endDate: DateTime(2026, 3, 15),
        );

        seedEvents([event]);

        final result = await repository.getByDateRange(
          EventCalendarDate(2026, 3, 10),
          EventCalendarDate(2026, 3, 20),
        );

        expect(result, isA<Success<List<Event>>>());
        final success = result as Success<List<Event>>;
        expect(success.value, containsEventId(1));
      });

      test('includes event overlapping range end', () async {
        final event = makeEventEntity(
          remoteId: 1,
          startDate: DateTime(2026, 3, 15),
          endDate: DateTime(2026, 3, 25),
        );

        seedEvents([event]);

        final result = await repository.getByDateRange(
          EventCalendarDate(2026, 3, 10),
          EventCalendarDate(2026, 3, 20),
        );

        expect(result, isA<Success<List<Event>>>());
        final success = result as Success<List<Event>>;
        expect(success.value, containsEventId(1));
      });

      test('includes event fully containing range', () async {
        final event = makeEventEntity(
          remoteId: 1,
          startDate: DateTime(2026, 3),
          endDate: DateTime(2026, 3, 31),
        );

        seedEvents([event]);

        final result = await repository.getByDateRange(
          EventCalendarDate(2026, 3, 10),
          EventCalendarDate(2026, 3, 20),
        );

        expect(result, isA<Success<List<Event>>>());
        final success = result as Success<List<Event>>;
        expect(success.value, containsEventId(1));
      });

      test('excludes event before range', () async {
        seedEvents([
          makeEventEntity(
            remoteId: 1,
            startDate: DateTime(2026, 3),
            endDate: DateTime(2026, 3, 8), // ends before rangeStart
          ),
        ]);

        final result = await repository.getByDateRange(
          EventCalendarDate(2026, 3, 10),
          EventCalendarDate(2026, 3, 20),
        );

        expect(result, isA<Success<List<Event>>>());
        final success = result as Success<List<Event>>;
        expect(success.value, isEmpty);
      });

      test('excludes event after range', () async {
        seedEvents([
          makeEventEntity(
            remoteId: 1,
            startDate: DateTime(2026, 3, 22), // starts after rangeEnd
            endDate: DateTime(2026, 3, 28),
          ),
        ]);

        final result = await repository.getByDateRange(
          EventCalendarDate(2026, 3, 10),
          EventCalendarDate(2026, 3, 20),
        );

        expect(result, isA<Success<List<Event>>>());
        final success = result as Success<List<Event>>;
        expect(success.value, isEmpty);
      });

      test('includes event at range start boundary', () async {
        final event = makeEventEntity(
          remoteId: 1,
          startDate: DateTime(2026, 3, 10),
          endDate: DateTime(2026, 3, 15),
        );

        seedEvents([event]);

        final result = await repository.getByDateRange(
          EventCalendarDate(2026, 3, 10),
          EventCalendarDate(2026, 3, 20),
        );

        expect(result, isA<Success<List<Event>>>());
        final success = result as Success<List<Event>>;
        expect(success.value, containsEventId(1));
      });

      test('includes event at range end boundary', () async {
        final event = makeEventEntity(
          remoteId: 1,
          startDate: DateTime(2026, 3, 15),
          endDate: DateTime(2026, 3, 20),
        );

        seedEvents([event]);

        final result = await repository.getByDateRange(
          EventCalendarDate(2026, 3, 10),
          EventCalendarDate(2026, 3, 20),
        );

        expect(result, isA<Success<List<Event>>>());
        final success = result as Success<List<Event>>;
        expect(success.value, containsEventId(1));
      });
    });

    group('_getByDateRange with mixed event types', () {
      test('correctly filters single-day and multi-day events', () async {
        final singleDay = makeEventEntity(
          remoteId: 1,
          startDate: DateTime(2026, 3, 15),
        );

        final multiDay = makeEventEntity(
          remoteId: 2,
          startDate: DateTime(2026, 3, 5),
          endDate: DateTime(2026, 3, 25),
        );

        seedEvents([singleDay, multiDay]);

        final result = await repository.getByDateRange(
          EventCalendarDate(2026, 3, 10),
          EventCalendarDate(2026, 3, 20),
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
        final mockBox = MockEntityBox<EventEntity>();
        when(() => mockBox.query(any())).thenThrow(Exception('query failed'));

        final mockStore = MockObjectBoxStore<EventEntity>(mockBox);

        mockRepository = EventRepositoryImpl(
          logger: mockLogger,
          supabaseI: MockSupabase(),
          objectBoxI: MockObjectBox(mockStore),
        );
      });

      test(
        'ongoing query failure returns and logs its own Result.error',
        () async {
          final result = await mockRepository.getOngoingEvents(fixedNowUtc);
          expect(result, isA<Error<List<Event>>>());
          final failedCall = mockLogger.firstCallOfType<EntityLoadFailed>()!;
          expect(
            (failedCall.event as EntityLoadFailed).method,
            'getOngoingEvents',
          );
          expect(failedCall.error, same((result as Error<List<Event>>).error));
          expect(failedCall.stackTrace, isNotNull);
        },
      );

      test(
        'upcoming query failure returns and logs its own Result.error',
        () async {
          final result = await mockRepository.getNextEvents(fixedNowUtc);
          expect(result, isA<Error<List<Event>>>());
          final failedCall = mockLogger.firstCallOfType<EntityLoadFailed>()!;
          expect(
            (failedCall.event as EntityLoadFailed).method,
            'getNextEvents',
          );
          expect(failedCall.error, same((result as Error<List<Event>>).error));
          expect(failedCall.stackTrace, isNotNull);
        },
      );

      test(
        'getByDate returns Result.error when _getByDateRange rethrows',
        () async {
          final date = EventCalendarDate(2026, 3, 15);

          final result = await mockRepository.getByDate(date);

          expect(result, isA<Error<List<Event>>>());
          final failedCall = mockLogger.firstCallOfType<EntityLoadFailed>();
          expect(failedCall, isNotNull);
          final failedEvent = failedCall!.event as EntityLoadFailed;
          expect(failedEvent.entityType, 'event');
          expect(failedEvent.method, 'getByDate');
          expect(failedEvent.data, {
            'entityType': 'event',
            'method': 'getByDate',
            'startDate': date.toString(),
          });
          expect(failedCall.error, isNotNull);
          expect(failedCall.stackTrace, isNotNull);
        },
      );

      test(
        'getByDateRange returns Result.error when _getByDateRange rethrows',
        () async {
          final start = EventCalendarDate(2026, 3, 10);
          final end = EventCalendarDate(2026, 3, 20);

          final result = await mockRepository.getByDateRange(start, end);

          expect(result, isA<Error<List<Event>>>());
          final failedCall = mockLogger.firstCallOfType<EntityLoadFailed>();
          expect(failedCall, isNotNull);
          final failedEvent = failedCall!.event as EntityLoadFailed;
          expect(failedEvent.entityType, 'event');
          expect(failedEvent.method, 'getByDateRange');
          expect(failedEvent.data, {
            'entityType': 'event',
            'method': 'getByDateRange',
            'startDate': start.toString(),
            'endDate': end.toString(),
          });
          expect(failedCall.error, isNotNull);
          expect(failedCall.stackTrace, isNotNull);
        },
      );
    });

    group('getByDate - single day normalization', () {
      test('normalizes date to full day range', () async {
        final event = makeEventEntity(
          remoteId: 1,
          startDate: DateTime(2026, 3, 15, 14, 30),
        );

        seedEvents([event]);

        final result = await repository.getByDate(
          EventCalendarDate(2026, 3, 15),
        );

        expect(result, isA<Success<List<Event>>>());
        final success = result as Success<List<Event>>;
        expect(success.value, containsEventId(1));
      });

      test('excludes event that starts on the following day', () async {
        seedEvents([
          makeEventEntity(
            remoteId: 2,
            startDate: DateTime(2026, 3, 16), // midnight of next day
          ),
        ]);

        final result = await repository.getByDate(
          EventCalendarDate(2026, 3, 15),
        );

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
        objectBoxI: TestObjectBox(objectBoxEnvironment.store),
        nowUtc: () => fixedNowUtc,
      );
    });

    tearDown(() async {
      await objectBoxEnvironment.dispose();
    });

    test(
      'includes multi-day event that starts and ends within current year',
      () async {
        final now = fixedNowUtc;
        final event = makeEventEntity(
          remoteId: 1,
          startDate: DateTime.utc(now.year, 6),
          endDate: DateTime.utc(now.year, 6, 10),
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
        final now = fixedNowUtc;
        final event = makeEventEntity(
          remoteId: 2,
          startDate: DateTime.utc(now.year, 5, 15),
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

    test(
      'uses inclusive annual overlap for ranged events and boundaries',
      () async {
        final policy = EventTimePolicy();
        final yearStart = policy
            .utcRangeForCalendarDate(EventCalendarDate(2026, 1, 1))
            .startUtc;
        final yearEnd = policy
            .utcRangeForCalendarDate(EventCalendarDate(2026, 12, 31))
            .endUtc;

        eventBox.putMany([
          makeEventEntity(remoteId: 10, startDate: DateTime.utc(2026, 6)),
          makeEventEntity(
            remoteId: 11,
            startDate: DateTime.utc(2026, 6),
            endDate: DateTime.utc(2026, 6, 2),
          ),
          makeEventEntity(
            remoteId: 12,
            startDate: DateTime.utc(2025, 6),
            endDate: DateTime.utc(2025, 6, 2),
          ),
          makeEventEntity(
            remoteId: 13,
            startDate: DateTime.utc(2027, 6),
            endDate: DateTime.utc(2027, 6, 2),
          ),
          makeEventEntity(
            remoteId: 14,
            startDate: DateTime.utc(2025, 12),
            endDate: DateTime.utc(2026, 1, 2),
          ),
          makeEventEntity(
            remoteId: 15,
            startDate: DateTime.utc(2026, 12, 31),
            endDate: DateTime.utc(2027, 1, 2),
          ),
          makeEventEntity(
            remoteId: 16,
            startDate: DateTime.utc(2025),
            endDate: DateTime.utc(2027, 12, 31),
          ),
          makeEventEntity(
            remoteId: 17,
            startDate: yearStart,
            endDate: DateTime.utc(2026, 1, 2),
          ),
          makeEventEntity(
            remoteId: 18,
            startDate: DateTime.utc(2026, 12, 30),
            endDate: yearEnd,
          ),
          makeEventEntity(
            remoteId: 19,
            startDate: DateTime.utc(2026, 6),
            endDate: DateTime.utc(2026, 6, 2),
            isDeleted: true,
          ),
          makeEventEntity(
            remoteId: 20,
            startDate: DateTime.utc(2025, 12, 30),
            endDate: yearStart,
          ),
          makeEventEntity(
            remoteId: 21,
            startDate: yearEnd,
            endDate: DateTime.utc(2027, 1, 2),
          ),
        ]);

        final result = await repository.getByCurrentYear();
        final ids = (result as Success<List<Event>>).value
            .map((event) => event.remoteId)
            .toSet();

        expect(ids, containsAll(<int>{10, 11, 14, 15, 16, 17, 18, 20, 21}));
        expect(ids, isNot(contains(12)));
        expect(ids, isNot(contains(13)));
        expect(ids, isNot(contains(19)));
      },
    );

    test('excludes multi-day event from a past year', () async {
      final event = makeEventEntity(
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
      final event = makeEventEntity(
        remoteId: 4,
        startDate: DateTime(2020, 3, 20),
      );
      eventBox.put(event);

      final result = await repository.getByCurrentYear();

      expect(result, isA<Success<List<Event>>>());
      expect(
        (result as Success<List<Event>>).value.map((e) => e.remoteId),
        isNot(contains(4)),
      );
    });

    test('excludes soft-deleted current-year event', () async {
      final now = fixedNowUtc;
      final event = makeEventEntity(
        remoteId: 5,
        startDate: DateTime.utc(now.year, 4),
        endDate: DateTime.utc(now.year, 4, 10),
        isDeleted: true,
      );
      eventBox.put(event);

      final result = await repository.getByCurrentYear();

      expect(result, isA<Success<List<Event>>>());
      expect(
        (result as Success<List<Event>>).value.map((e) => e.remoteId),
        isNot(contains(5)),
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
        objectBoxI: TestObjectBox(objectBoxEnvironment.store),
        nowUtc: () => fixedNowUtc,
      );
    });

    tearDown(() async {
      await objectBoxEnvironment.dispose();
    });

    test(
      'includes current-year multi-day event matching the requested category',
      () async {
        final now = fixedNowUtc;
        final event = makeEventEntity(
          remoteId: 1,
          startDate: DateTime.utc(now.year, 7),
          endDate: DateTime.utc(now.year, 7, 5),
          contentCategoryIndex: ContentCategory.food.index,
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

    test('includes current-year single-day event (null endDate) matching the '
        'requested category', () async {
      final now = fixedNowUtc;
      final event = makeEventEntity(
        remoteId: 2,
        startDate: DateTime.utc(now.year, 9, 10),
        contentCategoryIndex: ContentCategory.folklore.index,
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
    });

    test('excludes past-year event even when category matches', () async {
      final event = makeEventEntity(
        remoteId: 3,
        startDate: DateTime(2020, 4),
        endDate: DateTime(2020, 4, 5),
        contentCategoryIndex: ContentCategory.nature.index,
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
      final now = fixedNowUtc;
      final event = makeEventEntity(
        remoteId: 4,
        startDate: DateTime.utc(now.year, 6),
        endDate: DateTime.utc(now.year, 6, 5),
        contentCategoryIndex: ContentCategory.history.index,
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
      final now = fixedNowUtc;
      eventBox.put(
        makeEventEntity(
          remoteId: 1,
          name: 'Zeta Festival',
          startDate: DateTime.utc(now.year, 7),
          endDate: DateTime.utc(now.year, 7, 5),
          contentCategoryIndex: ContentCategory.folklore.index,
        ),
      );
      eventBox.put(
        makeEventEntity(
          remoteId: 2,
          name: 'Alpha Fair',
          startDate: DateTime.utc(now.year, 8),
          endDate: DateTime.utc(now.year, 8, 5),
          contentCategoryIndex: ContentCategory.folklore.index,
        ),
      );
      eventBox.put(
        makeEventEntity(
          remoteId: 3,
          name: 'Middle Market',
          startDate: DateTime.utc(now.year, 9),
          contentCategoryIndex: ContentCategory.folklore.index,
        ),
      );

      final result = await repository.getByCategories({
        ContentCategory.folklore,
      });

      expect(result, isA<Success<List<Event>>>());
      final names = (result as Success<List<Event>>).value
          .map((e) => e.name)
          .toList();
      expect(names, equals(['Alpha Fair', 'Middle Market', 'Zeta Festival']));
    });

    test('sorts by modifiedAt descending when sort is byDate', () async {
      final now = fixedNowUtc;
      eventBox.put(
        makeEventEntity(
          remoteId: 1,
          name: 'Older',
          startDate: DateTime.utc(now.year, 7),
          contentCategoryIndex: ContentCategory.food.index,
          modifiedAt: DateTime(2025),
        ),
      );
      eventBox.put(
        makeEventEntity(
          remoteId: 2,
          name: 'Newer',
          startDate: DateTime.utc(now.year, 8),
          contentCategoryIndex: ContentCategory.food.index,
          modifiedAt: DateTime(2026, 6),
        ),
      );
      eventBox.put(
        makeEventEntity(
          remoteId: 3,
          name: 'Middle',
          startDate: DateTime.utc(now.year, 9),
          contentCategoryIndex: ContentCategory.food.index,
          modifiedAt: DateTime(2025, 12),
        ),
      );

      final result = await repository.getByCategories({
        ContentCategory.food,
      }, sort: ContentSort.byDate);

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
        objectBoxI: TestObjectBox(objectBoxEnvironment.store),
        nowUtc: () => fixedNowUtc,
      );
    });

    tearDown(() async {
      await objectBoxEnvironment.dispose();
    });

    test(
      'reflects newly synced events after synchronize invalidates cache',
      () async {
        final now = fixedNowUtc;

        // Seed a current-year event in the local store.
        eventBox.put(
          makeEventEntity(
            remoteId: 1,
            name: 'Existing Event',
            startDate: DateTime.utc(now.year, 6),
            endDate: DateTime.utc(now.year, 6, 5),
          ),
        );

        // Populate the cache via getByCurrentYear().
        final firstCall = await repository.getByCurrentYear();
        expect(firstCall, isA<Success<List<Event>>>());
        expect((firstCall as Success<List<Event>>).value, hasLength(1));

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
            'latitude': 0,
            'longitude': 0,
            'category': 'unknown',
          },
        ]);
        final prepareResult = await repository.prepareSync();
        final dtos = (prepareResult as Success<List<EventDto>>).value;
        repository.commitSync(dtos);

        // Cache was invalidated; getByCurrentYear() must reflect the new event.
        final secondCall = await repository.getByCurrentYear();
        expect(secondCall, isA<Success<List<Event>>>());
        expect((secondCall as Success<List<Event>>).value, hasLength(2));
      },
    );
  });

  group('EventRepositoryImpl - commitSync description Delta', () {
    late TestObjectBoxEnvironment objectBoxEnvironment;
    late Box<EventEntity> eventBox;
    late MockSupabaseEnvironment supabaseEnv;
    late EventRepositoryImpl repository;

    setUp(() async {
      objectBoxEnvironment = await TestObjectBoxEnvironment.create();
      eventBox = objectBoxEnvironment.store.box<EventEntity>();
      supabaseEnv = MockSupabaseEnvironment();
      repository = EventRepositoryImpl(
        logger: MockLogger(),
        supabaseI: supabaseEnv.mockSupabase,
        objectBoxI: TestObjectBox(objectBoxEnvironment.store),
        nowUtc: () => fixedNowUtc,
      );
    });

    tearDown(() async {
      await objectBoxEnvironment.dispose();
    });

    test(
      'persists and clears description Delta from newer remote data',
      () async {
        final descriptionDelta = <Map<String, dynamic>>[
          {'insert': 'Rich event description\n'},
        ];
        supabaseEnv.stubSelectResponse([
          {
            'id': 1,
            'name': 'Campobasso festival',
            'description': 'Rich event description',
            'description_delta': descriptionDelta,
            'start_date': '2026-07-01T00:00:00.000',
            'latitude': 0,
            'longitude': 0,
            'category': 'unknown',
            'created_at': '2024-01-01T00:00:00.000',
            'modified_at': '2024-01-02T00:00:00.000',
          },
        ]);

        final initialResult = await repository.prepareSync();
        repository.commitSync((initialResult as Success<List<EventDto>>).value);

        expect(eventBox.get(1)?.descriptionDelta, descriptionDelta);

        supabaseEnv.stubSelectResponse([
          {
            'id': 1,
            'name': 'Campobasso festival',
            'description': 'Legacy event description',
            'start_date': '2026-07-01T00:00:00.000',
            'latitude': 0,
            'longitude': 0,
            'category': 'unknown',
            'created_at': '2024-01-01T00:00:00.000',
            'modified_at': '2024-01-03T00:00:00.000',
          },
        ]);

        final clearingResult = await repository.prepareSync();
        repository.commitSync(
          (clearingResult as Success<List<EventDto>>).value,
        );

        expect(eventBox.get(1)?.descriptionDelta, isNull);
      },
    );

    test(
      'persists assigned and cleared city relations from complete rows',
      () async {
        eventBox.put(
          makeEventEntity(
            remoteId: 1,
            cityId: 7,
            modifiedAt: DateTime.utc(2024),
          ),
        );
        supabaseEnv.stubSelectResponse([
          {
            'id': 1,
            'name': 'Campobasso festival',
            'description': '',
            'start_date': '2024-01-01T00:00:00.000Z',
            'latitude': 0,
            'longitude': 0,
            'category': 'unknown',
            'city_id': 99,
            'created_at': '2024-01-01T00:00:00.000Z',
            'modified_at': '2025-01-01T00:00:00.000Z',
          },
        ]);

        final assignedDtos =
            ((await repository.prepareSync()) as Success<List<EventDto>>).value;
        final assignedResult = repository.commitSync(assignedDtos);

        expect(assignedResult, isA<Success<void>>());
        expect(eventBox.get(1)?.cityToOneId, 99);
        expect(eventBox.get(1)?.city.targetId, 99);

        supabaseEnv.stubSelectResponse([
          {
            'id': 1,
            'name': 'Campobasso festival',
            'description': '',
            'start_date': '2024-01-01T00:00:00.000Z',
            'latitude': 0,
            'longitude': 0,
            'category': 'unknown',
            'city_id': null,
            'created_at': '2024-01-01T00:00:00.000Z',
            'modified_at': '2026-01-01T00:00:00.000Z',
          },
        ]);

        final clearedDtos =
            ((await repository.prepareSync()) as Success<List<EventDto>>).value;
        final clearedResult = repository.commitSync(clearedDtos);

        expect(clearedResult, isA<Success<void>>());
        expect(eventBox.get(1)?.cityToOneId, isNull);
        expect(eventBox.get(1)?.city.targetId, 0);
      },
    );
  });

  group('EventRepositoryImpl - relation scalar preservation', () {
    late TestObjectBoxEnvironment objectBoxEnvironment;
    late Box<EventEntity> eventBox;
    late EventRepositoryImpl repository;

    setUp(() async {
      objectBoxEnvironment = await TestObjectBoxEnvironment.create();
      eventBox = objectBoxEnvironment.store.box<EventEntity>();
      repository = EventRepositoryImpl(
        logger: MockLogger(),
        supabaseI: MockSupabase(),
        objectBoxI: TestObjectBox(objectBoxEnvironment.store),
        nowUtc: () => fixedNowUtc,
      );
    });

    tearDown(() async {
      await objectBoxEnvironment.dispose();
    });

    test(
      'preserves city relations through favourite copies and Keep merges',
      () async {
        eventBox.put(
          makeEventEntity(
            remoteId: 1,
            cityId: 7,
            modifiedAt: DateTime.utc(2024),
          ),
        );

        final favouriteResult = await repository.setFavouriteEvent(1, true);

        expect(favouriteResult, isA<Success<void>>());
        expect(eventBox.get(1)?.cityToOneId, 7);
        expect(eventBox.get(1)?.city.targetId, 7);

        final mergeResult = repository.commitSync([
          _relationTestEventDto(modifiedAt: DateTime.utc(2027)),
        ]);

        expect(mergeResult, isA<Success<void>>());
        expect(eventBox.get(1)?.cityToOneId, 7);
        expect(eventBox.get(1)?.city.targetId, 7);
      },
    );

    test('preserves city relations through soft deletion and a Keep merge', () {
      eventBox.put(
        makeEventEntity(remoteId: 1, cityId: 7, modifiedAt: DateTime.utc(2024)),
      );

      final deleteResult = repository.commitSync([
        _relationTestEventDto(
          modifiedAt: DateTime.utc(2025),
          deletedAt: DateTime.utc(2025),
        ),
      ]);

      expect(deleteResult, isA<Success<void>>());
      expect(eventBox.get(1)?.cityToOneId, 7);
      expect(eventBox.get(1)?.city.targetId, 7);

      final restoreResult = repository.commitSync([
        _relationTestEventDto(modifiedAt: DateTime.utc(2027)),
      ]);

      expect(restoreResult, isA<Success<void>>());
      expect(eventBox.get(1)?.isDeleted, isFalse);
      expect(eventBox.get(1)?.cityToOneId, 7);
      expect(eventBox.get(1)?.city.targetId, 7);
    });
  });

  group('EventRepositoryImpl - shared-snapshot Home discovery', () {
    late TestObjectBoxEnvironment environment;
    late Box<EventEntity> eventBox;
    late EventRepositoryImpl repository;
    final policy = EventTimePolicy();
    final snapshot = DateTime.utc(2026, 3, 15, 12);

    setUp(() async {
      environment = await TestObjectBoxEnvironment.create();
      eventBox = environment.store.box<EventEntity>();
      repository = EventRepositoryImpl(
        logger: MockLogger(),
        supabaseI: MockSupabase(),
        objectBoxI: TestObjectBox(environment.store),
        nowUtc: () => throw StateError('Discovery must not read its own clock'),
      );
    });
    tearDown(() => environment.dispose());

    for (final scenario
        in <
          ({
            String name,
            DateTime start,
            DateTime? end,
            bool deleted,
            bool ongoing,
          })
        >[
          (
            name: 'ranged yesterday to tomorrow',
            start: DateTime.utc(2026, 3, 14, 12),
            end: DateTime.utc(2026, 3, 16, 12),
            deleted: false,
            ongoing: true,
          ),
          (
            name: 'timed active today',
            start: DateTime.utc(2026, 3, 15, 11),
            end: DateTime.utc(2026, 3, 15, 13),
            deleted: false,
            ongoing: true,
          ),
          (
            name: 'future today',
            start: DateTime.utc(2026, 3, 15, 20),
            end: DateTime.utc(2026, 3, 15, 22),
            deleted: false,
            ongoing: false,
          ),
          (
            name: 'ended today',
            start: DateTime.utc(2026, 3, 15, 8),
            end: DateTime.utc(2026, 3, 15, 9),
            deleted: false,
            ongoing: false,
          ),
          (
            name: 'start equals snapshot',
            start: snapshot,
            end: DateTime.utc(2026, 3, 16),
            deleted: false,
            ongoing: true,
          ),
          (
            name: 'end equals snapshot',
            start: DateTime.utc(2026, 3, 14),
            end: snapshot,
            deleted: false,
            ongoing: true,
          ),
          (
            name: 'start and end equal snapshot',
            start: snapshot,
            end: snapshot,
            deleted: false,
            ongoing: true,
          ),
          (
            name: 'null end started today',
            start: DateTime.utc(2026, 3, 15, 10),
            end: null,
            deleted: false,
            ongoing: true,
          ),
          (
            name: 'null end at snapshot',
            start: snapshot,
            end: null,
            deleted: false,
            ongoing: true,
          ),
          (
            name: 'null end future today',
            start: DateTime.utc(2026, 3, 15, 20),
            end: null,
            deleted: false,
            ongoing: false,
          ),
          (
            name: 'null end yesterday',
            start: DateTime.utc(2026, 3, 14, 12),
            end: null,
            deleted: false,
            ongoing: false,
          ),
          (
            name: 'soft-deleted active range',
            start: DateTime.utc(2026, 3, 14),
            end: DateTime.utc(2026, 3, 16),
            deleted: true,
            ongoing: false,
          ),
          (
            name: 'active interval started in previous year',
            start: DateTime.utc(2025, 12),
            end: DateTime.utc(2026, 4),
            deleted: false,
            ongoing: true,
          ),
        ]) {
      test('ongoing: ${scenario.name}', () async {
        eventBox.put(
          makeEventEntity(
            remoteId: 1,
            startDate: scenario.start,
            endDate: scenario.end,
            isDeleted: scenario.deleted,
          ),
        );
        final result = await repository.getOngoingEvents(snapshot);
        expect(result, isA<Success<List<Event>>>());
        expect(
          result.getOrNull()!.map((event) => event.remoteId),
          scenario.ongoing ? [1] : <int>[],
        );
      });
    }

    test('all-day null-end, multi-day and explicit same-day final date '
        'use persisted bounds', () async {
      final today = policy.utcRangeForCalendarDate(
        EventCalendarDate(2026, 3, 15),
      );
      eventBox.putMany([
        makeEventEntity(remoteId: 1, allDay: true, startDate: today.startUtc),
        makeEventEntity(
          remoteId: 2,
          allDay: true,
          startDate: policy
              .utcRangeForCalendarDate(EventCalendarDate(2026, 3, 14))
              .startUtc,
          endDate: policy
              .utcRangeForCalendarDate(EventCalendarDate(2026, 3, 16))
              .endUtc,
        ),
        makeEventEntity(
          remoteId: 3,
          allDay: true,
          startDate: today.startUtc,
          endDate: today.endUtc,
        ),
      ]);
      final result = await repository.getOngoingEvents(snapshot);
      expect(result.getOrNull()!.map((event) => event.remoteId), [2, 1, 3]);
      expect(result.getOrNull()!.every((event) => event.allDay), isTrue);
    });

    test('ongoing start order includes active pre-epoch intervals', () async {
      eventBox.putMany([
        makeEventEntity(
          remoteId: 1,
          startDate: DateTime.utc(2026, 3, 15, 10),
          endDate: DateTime.utc(2027),
        ),
        makeEventEntity(
          remoteId: 2,
          startDate: DateTime.utc(1969, 12, 31),
          endDate: DateTime.utc(2027),
        ),
      ]);
      final result = await repository.getOngoingEvents(snapshot);
      expect(result.getOrNull()!.map((event) => event.remoteId), [2, 1]);
    });

    test(
      'ongoing has no six-result cap and orders equal starts by identity',
      () async {
        for (final id in [9, 7, 3, 8, 2, 6, 1, 5, 4]) {
          eventBox.put(
            makeEventEntity(
              remoteId: id,
              startDate: id == 9
                  ? DateTime.utc(2026, 3, 14)
                  : DateTime.utc(2026, 3, 15, 10),
              endDate: DateTime.utc(2026, 3, 16),
            ),
          );
        }
        final result = await repository.getOngoingEvents(snapshot);
        expect(result.getOrNull()!.map((event) => event.remoteId), [
          9,
          1,
          2,
          3,
          4,
          5,
          6,
          7,
          8,
        ]);
      },
    );

    test(
      'Rome day differs from UTC and is independent of package local timezone',
      () async {
        final currentDay = policy.utcRangeForCalendarDate(
          EventCalendarDate(2026, 7, 2),
        );
        final previousDay = policy.utcRangeForCalendarDate(
          EventCalendarDate(2026, 7, 1),
        );
        final previousLocal = tz.local;
        addTearDown(() => tz.setLocalLocation(previousLocal));
        tz.setLocalLocation(tz.getLocation('America/New_York'));
        eventBox.putMany([
          makeEventEntity(remoteId: 1, startDate: currentDay.startUtc),
          makeEventEntity(remoteId: 2, startDate: previousDay.startUtc),
        ]);
        final result = await repository.getOngoingEvents(
          DateTime.utc(2026, 7, 1, 22, 30),
        );
        expect(result.getOrNull()!.map((event) => event.remoteId), [1]);
        expect(tz.local.name, 'America/New_York');
      },
    );

    for (final date in [
      EventCalendarDate(2026, 7, 1),
      EventCalendarDate(2026, 3, 29),
      EventCalendarDate(2026, 10, 25),
    ]) {
      test('Rome final microsecond and next midnight on $date', () async {
        final day = policy.utcRangeForCalendarDate(date);
        final nextCarrier = DateTime.utc(date.year, date.month, date.day + 1);
        final nextDay = policy.utcRangeForCalendarDate(
          EventCalendarDate(
            nextCarrier.year,
            nextCarrier.month,
            nextCarrier.day,
          ),
        );
        eventBox.putMany([
          makeEventEntity(remoteId: 1, startDate: day.startUtc),
          makeEventEntity(
            remoteId: 2,
            startDate: day.startUtc,
            endDate: day.endUtc,
          ),
          makeEventEntity(remoteId: 3, startDate: nextDay.startUtc),
          makeEventEntity(remoteId: 4, startDate: day.endUtc),
        ]);
        final before = await repository.getOngoingEvents(day.endUtc);
        final atMidnight = await repository.getOngoingEvents(nextDay.startUtc);
        expect(before.getOrNull()!.map((event) => event.remoteId), [1, 2, 4]);
        expect(atMidnight.getOrNull()!.map((event) => event.remoteId), [3]);
        expect(
          nextDay.startUtc.difference(day.endUtc),
          const Duration(microseconds: 1),
        );
        if (date.month == 3 || date.month == 10) {
          expect(
            nextDay.startUtc.difference(day.startUtc).inHours,
            date.month == 3 ? 23 : 25,
          );
        }
      });
    }

    test(
      'upcoming excludes past/equal starts and deletion, includes +1 microsecond and future today',
      () async {
        eventBox.putMany([
          makeEventEntity(
            remoteId: 1,
            startDate: DateTime.utc(2026, 3, 15, 11),
            endDate: DateTime.utc(2026, 3, 16),
          ),
          makeEventEntity(
            remoteId: 2,
            startDate: snapshot,
            endDate: DateTime.utc(2026, 3, 16),
          ),
          makeEventEntity(
            remoteId: 3,
            startDate: snapshot.add(const Duration(microseconds: 1)),
          ),
          makeEventEntity(
            remoteId: 4,
            startDate: DateTime.utc(2026, 3, 15, 20),
          ),
          makeEventEntity(
            remoteId: 5,
            startDate: snapshot.add(const Duration(microseconds: 1)),
            isDeleted: true,
          ),
        ]);
        final result = await repository.getNextEvents(snapshot);
        expect(result.getOrNull()!.map((event) => event.remoteId), [3, 4]);
      },
    );

    test('December snapshot includes January future starts', () async {
      eventBox.put(
        makeEventEntity(remoteId: 1, startDate: DateTime.utc(2027, 1, 3)),
      );
      final result = await repository.getNextEvents(
        DateTime.utc(2026, 12, 20, 12),
      );
      expect(result.getOrNull()!.map((event) => event.remoteId), [1]);
    });

    for (final clock in [
      DateTime.utc(2026, 3, 15, 12),
      DateTime.utc(2026, 10, 15, 12),
      DateTime.utc(2026, 12, 31, 23, 30),
    ]) {
      test('upcoming inclusive civil +30 upper boundary from $clock', () async {
        final today = policy.currentCalendarDate(clock);
        final endCarrier = DateTime.utc(
          today.year,
          today.month,
          today.day + 30,
        );
        final bound = policy
            .utcRangeForCalendarDate(
              EventCalendarDate(
                endCarrier.year,
                endCarrier.month,
                endCarrier.day,
              ),
            )
            .endUtc;
        eventBox.putMany([
          makeEventEntity(remoteId: 1, startDate: bound),
          makeEventEntity(
            remoteId: 2,
            startDate: bound.add(const Duration(microseconds: 1)),
          ),
        ]);
        final result = await repository.getNextEvents(clock);
        expect(result.getOrNull()!.map((event) => event.remoteId), [1]);
      });
    }

    test('upcoming limits six in ascending start order', () async {
      for (var id = 8; id >= 1; id--) {
        eventBox.put(
          makeEventEntity(
            remoteId: id,
            startDate: snapshot.add(Duration(hours: id)),
          ),
        );
      }
      final result = await repository.getNextEvents(snapshot);
      expect(result.getOrNull()!.map((event) => event.remoteId), [
        1,
        2,
        3,
        4,
        5,
        6,
      ]);
    });

    test('same dataset and explicit snapshot produce non-empty disjoint '
        'collections without clock reads', () async {
      eventBox.putMany([
        makeEventEntity(
          remoteId: 1,
          startDate: DateTime.utc(2026, 3, 14),
          endDate: DateTime.utc(2026, 3, 16),
        ),
        makeEventEntity(remoteId: 2, startDate: snapshot, endDate: snapshot),
        makeEventEntity(remoteId: 3, startDate: DateTime.utc(2026, 3, 15, 10)),
        makeEventEntity(
          remoteId: 4,
          startDate: snapshot.add(const Duration(microseconds: 1)),
        ),
        makeEventEntity(remoteId: 5, startDate: DateTime.utc(2026, 3, 15, 20)),
        makeEventEntity(
          remoteId: 6,
          startDate: DateTime.utc(2026, 3, 15, 8),
          endDate: DateTime.utc(2026, 3, 15, 9),
        ),
      ]);
      final ongoing = (await repository.getOngoingEvents(
        snapshot,
      )).getOrNull()!;
      final next = (await repository.getNextEvents(snapshot)).getOrNull()!;
      expect(ongoing.map((event) => event.remoteId), [1, 3, 2]);
      expect(next.map((event) => event.remoteId), [4, 5]);
      expect(
        ongoing
            .map((event) => event.remoteId)
            .toSet()
            .intersection(next.map((event) => event.remoteId).toSet()),
        isEmpty,
      );
    });
  });

  group('EventRepositoryImpl - Rome query boundaries', () {
    late TestObjectBoxEnvironment environment;
    late Box<EventEntity> eventBox;
    late EventRepositoryImpl repository;

    setUp(() async {
      environment = await TestObjectBoxEnvironment.create();
      eventBox = environment.store.box<EventEntity>();
      repository = EventRepositoryImpl(
        logger: MockLogger(),
        supabaseI: MockSupabase(),
        objectBoxI: TestObjectBox(environment.store),
        nowUtc: () => DateTime.utc(2026, 12, 31, 23, 30),
      );
    });

    tearDown(() => environment.dispose());

    test('returns a successful empty direct collection', () async {
      final result = await repository.getNextEvents(
        DateTime.utc(2026, 12, 31, 23, 30),
      );
      expect(result, isA<Success<List<Event>>>());
      expect(result.getOrNull(), isEmpty);
    });

    test('maps at most six visible events in ascending start order', () async {
      for (var i = 8; i >= 1; i--) {
        eventBox.put(
          makeEventEntity(
            remoteId: i,
            name: 'Event $i',
            startDate: DateTime.utc(2027, 1, i),
          ),
        );
      }
      eventBox.put(
        makeEventEntity(
          remoteId: 99,
          isDeleted: true,
          startDate: DateTime.utc(2026, 12, 31, 23),
        ),
      );
      final result = await repository.getNextEvents(
        DateTime.utc(2026, 12, 31, 23, 30),
      );
      expect(result, isA<Success<List<Event>>>());
      final events = result.getOrNull()!;
      expect(events.map((event) => event.remoteId), [1, 2, 3, 4, 5, 6]);
      expect(events.first.name, 'Event 1');
    });

    test(
      'all-day membership, DST overlap, cross-year and start sorting',
      () async {
        final policy = EventTimePolicy();
        eventBox.putMany([
          makeEventEntity(
            remoteId: 40,
            allDay: true,
            startDate: policy
                .utcRangeForCalendarDate(EventCalendarDate(2026, 3, 29))
                .startUtc,
          ),
          makeEventEntity(
            remoteId: 41,
            allDay: true,
            startDate: policy
                .utcRangeForCalendarDate(EventCalendarDate(2026, 3, 28))
                .startUtc,
            endDate: policy
                .utcRangeForCalendarDate(EventCalendarDate(2026, 3, 30))
                .endUtc,
          ),
          makeEventEntity(
            remoteId: 42,
            allDay: true,
            startDate: policy
                .utcRangeForCalendarDate(EventCalendarDate(2026, 12, 31))
                .startUtc,
            endDate: policy
                .utcRangeForCalendarDate(EventCalendarDate(2027, 1, 2))
                .endUtc,
          ),
          makeEventEntity(
            remoteId: 43,
            allDay: true,
            startDate: policy
                .utcRangeForCalendarDate(EventCalendarDate(2027, 1, 1))
                .startUtc,
          ),
        ]);
        final spring = (await repository.getByDate(
          EventCalendarDate(2026, 3, 29),
        )).getOrNull()!;
        expect(spring.map((event) => event.remoteId), [41, 40]);
        final nextDay = (await repository.getByDate(
          EventCalendarDate(2026, 3, 30),
        )).getOrNull()!;
        expect(nextDay.map((event) => event.remoteId), [41]);
        final crossYear = (await repository.getByDateRange(
          EventCalendarDate(2027, 1, 1),
          EventCalendarDate(2027, 1, 2),
        )).getOrNull()!;
        expect(crossYear.map((event) => event.remoteId), [42, 43]);
        expect(
          (await repository.getByCurrentYear()).getOrNull()!.map(
            (event) => event.remoteId,
          ),
          [42, 43],
        );
        // Upcoming remains based on starts: the overlapping earlier event is
        // excluded even though it is an all-day multi-day event.
        expect(
          (await repository.getNextEvents(
            DateTime.utc(2026, 12, 31, 23, 30),
          )).getOrNull()!.map((event) => event.remoteId),
          isEmpty,
        );
      },
    );

    test('uses Rome year bounds and upcoming-day UTC boundaries', () async {
      eventBox.putMany([
        makeEventEntity(remoteId: 1, startDate: DateTime.utc(2026, 12, 31, 23)),
        makeEventEntity(remoteId: 2, startDate: DateTime.utc(2027, 1, 1, 1)),
        makeEventEntity(remoteId: 3, startDate: DateTime.utc(2028, 2, 1, 1)),
        makeEventEntity(
          remoteId: 4,
          startDate: DateTime.utc(2026, 12, 31, 22),
          endDate: DateTime.utc(2027, 1, 2),
        ),
      ]);

      final currentYear = await repository.getByCurrentYear();
      final upcoming = await repository.getNextEvents(
        DateTime.utc(2026, 12, 31, 23, 30),
      );

      expect(
        (currentYear as Success<List<Event>>).value.map((e) => e.remoteId),
        [4, 1, 2],
      );
      expect(
        (upcoming as Success<List<Event>>).value.map((event) => event.remoteId),
        [2],
      );
      expect(upcoming.value, isNot(containsEventId(4)));
    });

    test(
      'uses Rome summer day and inclusive upcoming-window boundaries',
      () async {
        eventBox.putMany([
          makeEventEntity(
            remoteId: 10,
            startDate: DateTime.utc(2026, 6, 1, 21, 59, 59, 999, 999),
          ),
          makeEventEntity(
            remoteId: 11,
            startDate: DateTime.utc(2026, 6, 1, 22),
          ),
          makeEventEntity(
            remoteId: 12,
            startDate: DateTime.utc(2026, 12, 31, 23),
          ),
          makeEventEntity(
            remoteId: 13,
            startDate: DateTime.utc(2027, 1, 31, 22, 59, 59, 999, 999),
          ),
          makeEventEntity(
            remoteId: 14,
            startDate: DateTime.utc(2027, 1, 31, 23),
          ),
        ]);

        final summerDay = await repository.getByDate(
          EventCalendarDate(2026, 6, 1),
        );
        final upcoming = await repository.getNextEvents(
          DateTime.utc(2026, 12, 31, 23, 30),
        );
        final summerEvents = (summerDay as Success<List<Event>>).value;
        final upcomingIds = (upcoming as Success<List<Event>>).value.map(
          (event) => event.remoteId,
        );

        expect(summerEvents, containsEventId(10));
        expect(summerEvents, isNot(containsEventId(11)));
        expect(upcomingIds, contains(13));
        expect(upcomingIds, isNot(contains(12)));
        expect(upcomingIds, isNot(contains(14)));
      },
    );

    test(
      'uses Rome-year overlap for category and coordinate queries',
      () async {
        eventBox.putMany([
          makeEventEntity(
            remoteId: 20,
            startDate: DateTime.utc(2026, 12, 31, 23),
            endDate: DateTime.utc(2027),
            coordinates: const [0.01, 0.01],
            contentCategoryIndex: ContentCategory.nature.index,
          ),
          makeEventEntity(
            remoteId: 21,
            startDate: DateTime.utc(2026, 12, 31, 22, 59),
            endDate: DateTime.utc(2026, 12, 31, 23),
            coordinates: const [0.02, 0.02],
            contentCategoryIndex: ContentCategory.nature.index,
          ),
        ]);

        final categories = await repository.getByCategories({
          ContentCategory.nature,
        });
        final nearby = await repository.getByCoordinates(const [0, 0]);
        final categoryEvents = (categories as Success<List<Event>>).value;
        final nearbyEvents = (nearby as Success<List<Event>>).value;

        expect(categoryEvents, containsEventId(20));
        expect(categoryEvents, containsEventId(21));
        expect(nearbyEvents, containsEventId(20));
        expect(nearbyEvents, containsEventId(21));
      },
    );

    test('includes a 31 December to 1 January event in both Rome years across '
        'yearly, category, and coordinate queries', () async {
      final policy = EventTimePolicy();
      final event = makeEventEntity(
        remoteId: 30,
        startDate: policy
            .utcRangeForCalendarDate(EventCalendarDate(2026, 12, 31))
            .startUtc,
        endDate: policy
            .utcRangeForCalendarDate(EventCalendarDate(2027, 1, 1))
            .endUtc,
        coordinates: const [0.01, 0.01],
        contentCategoryIndex: ContentCategory.nature.index,
      );
      eventBox.put(event);

      final repositoryFor2026 = EventRepositoryImpl(
        logger: MockLogger(),
        supabaseI: MockSupabase(),
        objectBoxI: TestObjectBox(environment.store),
        nowUtc: () => DateTime.utc(2026, 6),
      );
      final repositoryFor2027 = EventRepositoryImpl(
        logger: MockLogger(),
        supabaseI: MockSupabase(),
        objectBoxI: TestObjectBox(environment.store),
        nowUtc: () => DateTime.utc(2027, 6),
      );

      for (final yearlyRepository in [repositoryFor2026, repositoryFor2027]) {
        final currentYear = await yearlyRepository.getByCurrentYear();
        final categories = await yearlyRepository.getByCategories({
          ContentCategory.nature,
        });
        final nearby = await yearlyRepository.getByCoordinates(const [0, 0]);

        expect(
          (currentYear as Success<List<Event>>).value,
          containsEventId(30),
        );
        expect((categories as Success<List<Event>>).value, containsEventId(30));
        expect((nearby as Success<List<Event>>).value, containsEventId(30));
      }
    });
  });
  test(
    'flag-only remote sync replaces mode and preserves locally saved state',
    () async {
      final env = await TestObjectBoxEnvironment.create();
      addTearDown(env.dispose);
      final remote = MockSupabaseEnvironment();
      final repository = EventRepositoryImpl(
        logger: MockLogger(),
        supabaseI: remote.mockSupabase,
        objectBoxI: TestObjectBox(env.store),
        nowUtc: () => fixedNowUtc,
      );
      final eventBox = env.store.box<EventEntity>();
      final previous = makeEventEntity(
        remoteId: 71,
        startDate: DateTime.utc(2026, 10, 11, 22),
        createdAt: DateTime.utc(2026),
        modifiedAt: DateTime.utc(2026, 10),
      ).copyWith(isSaved: true);
      eventBox.put(previous);
      remote.stubSelectResponse([
        {
          'id': 71,
          'name': previous.name,
          'description': previous.description,
          'start_date': previous.startDate!.toIso8601String(),
          'end_date': null,
          'all_day': true,
          'latitude': previous.coordinates[0],
          'longitude': previous.coordinates[1],
          'category': 'unknown',
          'created_at': previous.createdAt.toIso8601String(),
          'modified_at': '2026-10-02T00:00:00.000Z',
        },
      ]);
      final prepared = (await repository.prepareSync()).getOrNull()!;
      expect(prepared.single.allDay, isTrue);
      repository.commitSync(prepared);
      final stored = eventBox.get(71)!;
      expect(stored.allDay, isTrue);
      expect(stored.isSaved, isTrue);
      expect(stored.startDate?.toUtc(), previous.startDate?.toUtc());
      expect(stored.modifiedAt.toUtc(), DateTime.utc(2026, 10, 2));
      expect((await repository.getById(71)).getOrNull()!.allDay, isTrue);
      expect((await repository.getById(71)).getOrNull()!.isSaved, isTrue);
    },
  );
}

Matcher containsEventId(int remoteId) =>
    contains(predicate<Event>((e) => e.remoteId == remoteId));

EventDto _relationTestEventDto({
  required DateTime modifiedAt,
  RelationUpdate<int> cityId = const Keep<int>(),
  DateTime? deletedAt,
}) => EventDto(
  id: 1,
  name: 'Event',
  description: '',
  startDate: DateTime.utc(2024),
  latitude: 0,
  longitude: 0,
  category: ContentCategory.unknown,
  cityId: cityId,
  createdAt: DateTime.utc(2024),
  modifiedAt: modifiedAt,
  deletedAt: deletedAt,
);
