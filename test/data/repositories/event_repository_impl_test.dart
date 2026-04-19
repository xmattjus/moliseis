// ignore_for_file: avoid_redundant_argument_values, always_declare_return_types, type_annotate_public_apis

import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/data/repositories/event_repository_impl.dart';
import 'package:moliseis/data/sources/city.dart';
import 'package:moliseis/data/sources/event.dart';
import 'package:moliseis/data/sources/event_supabase_table.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/generated/objectbox.g.dart';
import 'package:moliseis/utils/result.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:talker_flutter/talker_flutter.dart';

import '../../support/objectbox_test_store.dart';

void main() {
  group('EventRepositoryImpl - DateTime Overlap Logic', () {
    late TestObjectBoxEnvironment objectBoxEnvironment;
    late Box<Event> eventBox;
    late Talker fakeLogger;
    late _FakeSupabase fakeSupabase;
    late _FakeEventSupabaseTable fakeSupabaseTable;
    late EventRepositoryImpl repository;

    setUp(() async {
      objectBoxEnvironment = await TestObjectBoxEnvironment.create();
      eventBox = objectBoxEnvironment.store.box<Event>();
      fakeLogger = Talker();
      fakeSupabase = _FakeSupabase();
      fakeSupabaseTable = _FakeEventSupabaseTable();
      repository = EventRepositoryImpl(
        logger: fakeLogger,
        supabaseI: fakeSupabase,
        supabaseTable: fakeSupabaseTable,
        objectBoxI: TestObjectBox(objectBoxEnvironment.store),
      );
    });

    tearDown(() async {
      await objectBoxEnvironment.dispose();
    });

    Future<void> seedEvents(List<Event> events) async {
      for (final event in events) {
        eventBox.put(event);
      }
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

          await seedEvents([event]);

          final result = await repository.getByDateRange(rangeStart, rangeEnd);

          expect(result, isA<Success<List<Event>>>());
          final success = result as Success<List<Event>>;
          expect(success.value, contains(event));
        },
      );

      test(
        'excludes single-day event when start date is before range',
        () async {
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

        await seedEvents([event]);

        final result = await repository.getByDateRange(
          DateTime(2026, 3, 10),
          DateTime(2026, 3, 20),
        );

        expect(result, isA<Success<List<Event>>>());
        final success = result as Success<List<Event>>;
        expect(success.value, contains(event));
      });

      test('includes single-day event at range end boundary', () async {
        final event = _createEvent(
          remoteId: 1,
          startDate: DateTime(2026, 3, 20),
          endDate: null,
        );

        await seedEvents([event]);

        final result = await repository.getByDateRange(
          DateTime(2026, 3, 10),
          DateTime(2026, 3, 20),
        );

        expect(result, isA<Success<List<Event>>>());
        final success = result as Success<List<Event>>;
        expect(success.value, contains(event));
      });
    });

    group('_getByDateRange with multi-day events (endDate != null)', () {
      test('includes event fully contained within range', () async {
        final event = _createEvent(
          remoteId: 1,
          startDate: DateTime(2026, 3, 5),
          endDate: DateTime(2026, 3, 25),
        );

        await seedEvents([event]);

        final result = await repository.getByDateRange(
          DateTime(2026, 3, 10),
          DateTime(2026, 3, 20),
        );

        expect(result, isA<Success<List<Event>>>());
        final success = result as Success<List<Event>>;
        expect(success.value, contains(event));
      });

      test('includes event overlapping range start', () async {
        final event = _createEvent(
          remoteId: 1,
          startDate: DateTime(2026, 3, 5),
          endDate: DateTime(2026, 3, 15),
        );

        await seedEvents([event]);

        final result = await repository.getByDateRange(
          DateTime(2026, 3, 10),
          DateTime(2026, 3, 20),
        );

        expect(result, isA<Success<List<Event>>>());
        final success = result as Success<List<Event>>;
        expect(success.value, contains(event));
      });

      test('includes event overlapping range end', () async {
        final event = _createEvent(
          remoteId: 1,
          startDate: DateTime(2026, 3, 15),
          endDate: DateTime(2026, 3, 25),
        );

        await seedEvents([event]);

        final result = await repository.getByDateRange(
          DateTime(2026, 3, 10),
          DateTime(2026, 3, 20),
        );

        expect(result, isA<Success<List<Event>>>());
        final success = result as Success<List<Event>>;
        expect(success.value, contains(event));
      });

      test('includes event fully containing range', () async {
        final event = _createEvent(
          remoteId: 1,
          startDate: DateTime(2026, 3, 1),
          endDate: DateTime(2026, 3, 31),
        );

        await seedEvents([event]);

        final result = await repository.getByDateRange(
          DateTime(2026, 3, 10),
          DateTime(2026, 3, 20),
        );

        expect(result, isA<Success<List<Event>>>());
        final success = result as Success<List<Event>>;
        expect(success.value, contains(event));
      });

      test('excludes event before range', () async {
        final result = await repository.getByDateRange(
          DateTime(2026, 3, 10),
          DateTime(2026, 3, 20),
        );

        expect(result, isA<Success<List<Event>>>());
        final success = result as Success<List<Event>>;
        expect(success.value, isEmpty);
      });

      test('excludes event after range', () async {
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

        await seedEvents([event]);

        final result = await repository.getByDateRange(
          DateTime(2026, 3, 10),
          DateTime(2026, 3, 20),
        );

        expect(result, isA<Success<List<Event>>>());
        final success = result as Success<List<Event>>;
        expect(success.value, contains(event));
      });

      test('includes event at range end boundary', () async {
        final event = _createEvent(
          remoteId: 1,
          startDate: DateTime(2026, 3, 15),
          endDate: DateTime(2026, 3, 20),
        );

        await seedEvents([event]);

        final result = await repository.getByDateRange(
          DateTime(2026, 3, 10),
          DateTime(2026, 3, 20),
        );

        expect(result, isA<Success<List<Event>>>());
        final success = result as Success<List<Event>>;
        expect(success.value, contains(event));
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

        await seedEvents([singleDay, multiDay]);

        final result = await repository.getByDateRange(
          DateTime(2026, 3, 10),
          DateTime(2026, 3, 20),
        );

        expect(result, isA<Success<List<Event>>>());
        final success = result as Success<List<Event>>;
        expect(success.value, hasLength(2));
        expect(success.value, containsAll([singleDay, multiDay]));
      });
    });

    group('getByDate - single day normalization', () {
      test('normalizes date to full day range', () async {
        final event = _createEvent(
          remoteId: 1,
          startDate: DateTime(2026, 3, 15, 14, 30),
          endDate: null,
        );

        await seedEvents([event]);

        final result = await repository.getByDate(DateTime(2026, 3, 15));

        expect(result, isA<Success<List<Event>>>());
        final success = result as Success<List<Event>>;
        expect(success.value, contains(event));
      });
    });
  });

  group('EventRepositoryImpl - getByCurrentYear', () {
    late TestObjectBoxEnvironment objectBoxEnvironment;
    late Box<Event> eventBox;
    late EventRepositoryImpl repository;

    setUp(() async {
      objectBoxEnvironment = await TestObjectBoxEnvironment.create();
      eventBox = objectBoxEnvironment.store.box<Event>();
      repository = EventRepositoryImpl(
        logger: Talker(),
        supabaseI: _FakeSupabase(),
        supabaseTable: _FakeEventSupabaseTable(),
        objectBoxI: TestObjectBox(objectBoxEnvironment.store),
      );
    });

    tearDown(() async {
      await objectBoxEnvironment.dispose();
    });

    test('includes multi-day event that starts and ends within current year',
        () async {
      final now = DateTime.now();
      final event = _createEvent(
        remoteId: 1,
        startDate: DateTime(now.year, 6, 1),
        endDate: DateTime(now.year, 6, 10),
      );
      eventBox.put(event);

      final result = await repository.getByCurrentYear();

      expect(result, isA<Success<List<Event>>>());
      expect((result as Success<List<Event>>).value, contains(event));
    });

    test('includes single-day event (null endDate) whose startDate is in current year',
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
      expect((result as Success<List<Event>>).value, contains(event));
    });

    test('excludes multi-day event from a past year', () async {
      final event = _createEvent(
        remoteId: 3,
        startDate: DateTime(2020, 8, 1),
        endDate: DateTime(2020, 8, 10),
      );
      eventBox.put(event);

      final result = await repository.getByCurrentYear();

      expect(result, isA<Success<List<Event>>>());
      expect((result as Success<List<Event>>).value, isNot(contains(event)));
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
      expect((result as Success<List<Event>>).value, isNot(contains(event)));
    });

    test('returns empty list when store is empty', () async {
      final result = await repository.getByCurrentYear();

      expect(result, isA<Success<List<Event>>>());
      expect((result as Success<List<Event>>).value, isEmpty);
    });
  });

  group('EventRepositoryImpl - getByCategories', () {
    late TestObjectBoxEnvironment objectBoxEnvironment;
    late Box<Event> eventBox;
    late EventRepositoryImpl repository;

    setUp(() async {
      objectBoxEnvironment = await TestObjectBoxEnvironment.create();
      eventBox = objectBoxEnvironment.store.box<Event>();
      repository = EventRepositoryImpl(
        logger: Talker(),
        supabaseI: _FakeSupabase(),
        supabaseTable: _FakeEventSupabaseTable(),
        objectBoxI: TestObjectBox(objectBoxEnvironment.store),
      );
    });

    tearDown(() async {
      await objectBoxEnvironment.dispose();
    });

    test('includes current-year multi-day event matching the requested category',
        () async {
      final now = DateTime.now();
      final event = _createEvent(
        remoteId: 1,
        startDate: DateTime(now.year, 7, 1),
        endDate: DateTime(now.year, 7, 5),
        category: ContentCategory.food,
      );
      eventBox.put(event);

      final result = await repository.getByCategories({ContentCategory.food});

      expect(result, isA<Success<List<Event>>>());
      expect((result as Success<List<Event>>).value, contains(event));
    });

    test(
        'includes current-year single-day event (null endDate) matching the requested category',
        () async {
      final now = DateTime.now();
      final event = _createEvent(
        remoteId: 2,
        startDate: DateTime(now.year, 9, 10),
        endDate: null,
        category: ContentCategory.folklore,
      );
      eventBox.put(event);

      final result =
          await repository.getByCategories({ContentCategory.folklore});

      expect(result, isA<Success<List<Event>>>());
      expect((result as Success<List<Event>>).value, contains(event));
    });

    test('excludes past-year event even when category matches', () async {
      final event = _createEvent(
        remoteId: 3,
        startDate: DateTime(2020, 4, 1),
        endDate: DateTime(2020, 4, 5),
        category: ContentCategory.nature,
      );
      eventBox.put(event);

      final result = await repository.getByCategories({ContentCategory.nature});

      expect(result, isA<Success<List<Event>>>());
      expect((result as Success<List<Event>>).value, isNot(contains(event)));
    });

    test('excludes current-year event whose category does not match', () async {
      final now = DateTime.now();
      final event = _createEvent(
        remoteId: 4,
        startDate: DateTime(now.year, 6, 1),
        endDate: DateTime(now.year, 6, 5),
        category: ContentCategory.history,
      );
      eventBox.put(event);

      final result =
          await repository.getByCategories({ContentCategory.nature});

      expect(result, isA<Success<List<Event>>>());
      expect((result as Success<List<Event>>).value, isNot(contains(event)));
    });
  });
}

Event _createEvent({
  required int remoteId,
  required DateTime startDate,
  required DateTime? endDate,
  String? name,
  ContentCategory category = ContentCategory.unknown,
}) {
  final now = DateTime.now();
  return Event(
    remoteId: remoteId,
    name: name ?? 'Test Event $remoteId',
    startDate: startDate,
    endDate: endDate,
    category: category,
    createdAt: now,
    modifiedAt: now,
    city: ToOne<City>(),
    media: ToMany(),
  );
}

final class _FakeSupabase implements Supabase {
  @override
  noSuchMethod(Invocation invocation) {
    throw UnsupportedError(
      'Supabase should not be used in EventRepositoryImpl date-range tests.',
    );
  }
}

final class _FakeEventSupabaseTable implements EventSupabaseTable {
  @override
  String get tableName => 'events';

  @override
  String get idTitle => 'title';

  @override
  String get idDescription => 'description';

  @override
  String get startDate => 'start_date';

  @override
  String get endDate => 'end_date';

  @override
  String get idCreatedAt => 'created_at';

  @override
  String get idModifiedAt => 'modified_at';

  @override
  String get idPlace => 'place_id';
}
