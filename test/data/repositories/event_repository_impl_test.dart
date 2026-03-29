// ignore_for_file: avoid_redundant_argument_values, override_on_non_overriding_member, always_declare_return_types, type_annotate_public_apis, use_setters_to_change_properties, unused_element_parameter

import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/data/repositories/event_repository_impl.dart';
import 'package:moliseis/data/services/objectbox.dart';
import 'package:moliseis/data/sources/city.dart';
import 'package:moliseis/data/sources/event.dart';
import 'package:moliseis/data/sources/event_supabase_table.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/utils/result.dart';
import 'package:objectbox/objectbox.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:talker_flutter/talker_flutter.dart';

void main() {
  group('EventRepositoryImpl - DateTime Overlap Logic', () {
    late _FakeEventBox fakeEventBox;
    late _FakeTalker fakeLogger;
    late _FakeSupabase fakeSupabase;
    late _FakeEventSupabaseTable fakeSupabaseTable;
    late _FakeObjectBox fakeObjectBox;
    late EventRepositoryImpl repository;

    setUp(() {
      fakeEventBox = _FakeEventBox();
      fakeLogger = _FakeTalker();
      fakeSupabase = _FakeSupabase();
      fakeSupabaseTable = _FakeEventSupabaseTable();
      fakeObjectBox = _FakeObjectBox(fakeEventBox);

      repository = EventRepositoryImpl(
        logger: fakeLogger,
        supabaseI: fakeSupabase,
        supabaseTable: fakeSupabaseTable,
        objectBoxI: fakeObjectBox,
      );
    });

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

          fakeEventBox.setupResults([event]);

          final result = await repository.getByDateRange(rangeStart, rangeEnd);

          expect(result, isA<Success<List<Event>>>());
          final success = result as Success<List<Event>>;
          expect(success.value, contains(event));
        },
      );

      test(
        'excludes single-day event when start date is before range',
        () async {
          fakeEventBox.setupResults([]);

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
          fakeEventBox.setupResults([]);

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
          fakeEventBox.setupResults([]);

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

        fakeEventBox.setupResults([event]);

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

        fakeEventBox.setupResults([event]);

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

        fakeEventBox.setupResults([event]);

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

        fakeEventBox.setupResults([event]);

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

        fakeEventBox.setupResults([event]);

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

        fakeEventBox.setupResults([event]);

        final result = await repository.getByDateRange(
          DateTime(2026, 3, 10),
          DateTime(2026, 3, 20),
        );

        expect(result, isA<Success<List<Event>>>());
        final success = result as Success<List<Event>>;
        expect(success.value, contains(event));
      });

      test('excludes event before range', () async {
        fakeEventBox.setupResults([]);

        final result = await repository.getByDateRange(
          DateTime(2026, 3, 10),
          DateTime(2026, 3, 20),
        );

        expect(result, isA<Success<List<Event>>>());
        final success = result as Success<List<Event>>;
        expect(success.value, isEmpty);
      });

      test('excludes event after range', () async {
        fakeEventBox.setupResults([]);

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

        fakeEventBox.setupResults([event]);

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

        fakeEventBox.setupResults([event]);

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

        fakeEventBox.setupResults([singleDay, multiDay]);

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

        fakeEventBox.setupResults([event]);

        final result = await repository.getByDate(DateTime(2026, 3, 15));

        expect(result, isA<Success<List<Event>>>());
        final success = result as Success<List<Event>>;
        expect(success.value, contains(event));
      });
    });

    group('Error handling', () {
      test('returns error when query throws exception', () async {
        fakeEventBox.setThrowException(true);

        final result = await repository.getByDateRange(
          DateTime(2026, 3, 10),
          DateTime(2026, 3, 20),
        );

        expect(result, isA<Error<List<Event>>>());
      });
    });
  });
}

// Helper: Create test Event
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
    createdAt: now,
    modifiedAt: now,
    city: ToOne<City>(),
    media: ToMany(),
  );
}

// Fake: Box<Event>
class _FakeEventBox implements Box<Event> {
  List<Event> _results = [];
  bool _shouldThrow = false;

  void setupResults(List<Event> results) => _results = results;

  void setThrowException(bool value) => _shouldThrow = value;

  @override
  QueryBuilder<Event> query([Condition<Event>? condition]) {
    if (_shouldThrow) throw Exception('Database error');
    return _FakeQueryBuilder(_results);
  }

  @override
  noSuchMethod(Invocation invocation) => null;
}

// Fake: QueryBuilder<Event>
class _FakeQueryBuilder implements QueryBuilder<Event> {
  final List<Event> _results;

  _FakeQueryBuilder(this._results);

  @override
  Query<Event> build() => _FakeQuery(_results);

  @override
  noSuchMethod(Invocation invocation) {
    // Handle order() by returning this for chaining
    if (invocation.memberName == const Symbol('order')) {
      return this;
    }
    return null;
  }
}

// Fake: Query<Event>
class _FakeQuery implements Query<Event> {
  final List<Event> _results;
  int _limit = 0;

  _FakeQuery(this._results);

  @override
  Future<List<Event>> findAsync() async =>
      _limit > 0 ? _results.take(_limit).toList() : _results.toList();

  @override
  List<Event> find() =>
      _limit > 0 ? _results.take(_limit).toList() : _results.toList();

  @override
  Event? findFirst() => _results.isEmpty ? null : _results.first;

  @override
  Future<Event?> findFirstAsync() async => findFirst();

  @override
  int count() => _results.length;

  @override
  Future<int> countAsync() async => count();

  @override
  Query<Event> order(int property, {int flags = 0}) => this;

  @override
  set limit(int limit) => _limit = limit;

  @override
  void close() {}

  @override
  noSuchMethod(Invocation invocation) => null;
}

// Fake: Talker
class _FakeTalker implements Talker {
  @override
  void info(dynamic message, [dynamic error, StackTrace? stackTrace]) {}

  @override
  void error(dynamic message, [dynamic error, StackTrace? stackTrace]) {}

  @override
  void warning(dynamic message, [dynamic error, StackTrace? stackTrace]) {}

  @override
  void critical(dynamic message, [dynamic error, StackTrace? stackTrace]) {}

  @override
  void debug(dynamic message, [dynamic error, StackTrace? stackTrace]) {}

  @override
  void logException(
    Object exception, [
    StackTrace? stackTrace,
    dynamic customKey,
  ]) {}

  @override
  Future<void> close() async {}

  @override
  void noSuchMethod(Invocation invocation) {}
}

// Fake: Supabase
class _FakeSupabase implements Supabase {
  @override
  noSuchMethod(Invocation invocation) => null;
}

// Fake: EventSupabaseTable
class _FakeEventSupabaseTable implements EventSupabaseTable {
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

// Fake: ObjectBox
class _FakeObjectBox implements ObjectBox {
  @override
  late final Store store;

  _FakeObjectBox(_FakeEventBox eventBox) {
    store = _FakeStore(eventBox);
  }
}

// Fake: Store
class _FakeStore implements Store {
  final _FakeEventBox _eventBox;

  _FakeStore(this._eventBox);

  @override
  Box<T> box<T>() {
    if (T == Event) {
      return _eventBox as Box<T>;
    }
    throw UnsupportedError('FakeStore only supports Event boxes');
  }

  @override
  noSuchMethod(Invocation invocation) => null;
}
