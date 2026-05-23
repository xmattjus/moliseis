import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moliseis/data/data-sources/city_entity.dart';
import 'package:moliseis/data/data-sources/city_supabase_table.dart';
import 'package:moliseis/data/repositories/city_repository_impl.dart';
import 'package:moliseis/generated/objectbox.g.dart';
import 'package:moliseis/utils/logging/log_event.dart';
import 'package:moliseis/utils/result.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/mock_logger.dart';
import '../../support/mock_supabase.dart';
import '../../support/objectbox_test_store.dart';

void main() {
  setUpAll(() {
    setUpMockLogger();
    setUpMockSupabase();
  });

  // ---------------------------------------------------------------------------
  // synchronize — error path
  // ---------------------------------------------------------------------------

  group('CityRepositoryImpl - synchronize error handling', () {
    late MockLogger mockLogger;
    late MockSupabaseEnvironment supabaseEnv;
    late TestObjectBoxEnvironment objectBoxEnvironment;
    late CityRepositoryImpl repository;

    setUp(() async {
      mockLogger = MockLogger();
      supabaseEnv = MockSupabaseEnvironment()..stubUnavailable();
      objectBoxEnvironment = await TestObjectBoxEnvironment.create();
      repository = CityRepositoryImpl(
        logger: mockLogger,
        supabaseI: supabaseEnv.mockSupabase,
        supabaseTable: CitySupabaseTable(),
        objectBoxI: TestObjectBox(objectBoxEnvironment.store),
      );
    });

    tearDown(() async {
      await objectBoxEnvironment.dispose();
    });

    test('returns Error when Supabase throws an exception', () async {
      final result = await repository.synchronize();

      expect(result, isA<Error<void>>());
      verify(
        () {
          mockLogger.log(
            const RepositorySyncStarted('city'),
          );
        },
      ).called(1);
      verify(
        () => mockLogger.log(
          const RepositorySyncFailed('city'),
          error: any(named: 'error'),
          stackTrace: any(named: 'stackTrace'),
        ),
      ).called(1);
    });
  });

  // ---------------------------------------------------------------------------
  // synchronize — success path
  // ---------------------------------------------------------------------------

  group('CityRepositoryImpl - synchronize success path', () {
    late MockLogger mockLogger;
    late MockSupabaseEnvironment supabaseEnv;
    late TestObjectBoxEnvironment objectBoxEnvironment;
    late Box<CityEntity> cityBox;
    late CityRepositoryImpl repository;

    setUp(() async {
      mockLogger = MockLogger();
      supabaseEnv = MockSupabaseEnvironment();
      objectBoxEnvironment = await TestObjectBoxEnvironment.create();
      cityBox = objectBoxEnvironment.store.box<CityEntity>();
      repository = CityRepositoryImpl(
        logger: mockLogger,
        supabaseI: supabaseEnv.mockSupabase,
        supabaseTable: CitySupabaseTable(),
        objectBoxI: TestObjectBox(objectBoxEnvironment.store),
      );
    });

    tearDown(() async {
      await objectBoxEnvironment.dispose();
    });

    test('inserts a new city that is absent from the local store', () async {
      supabaseEnv.stubSelectResponse([
        {
          'id': 1,
          'name': 'Campobasso',
          'created_at': '2024-01-01T00:00:00.000',
          'modified_at': '2024-01-01T00:00:00.000',
        },
      ]);

      final result = await repository.synchronize();

      expect(result, isA<Success<void>>());
      expect(cityBox.get(1)?.name, equals('Campobasso'));
      verify(
        () => mockLogger.log(any(that: isA<EntityInsertSuccess>())),
      ).called(1);
    });

    test('updates an existing city when remote data differs', () async {
      // Seed the local store with an older version.
      cityBox.put(
        CityEntity(
          remoteId: 1,
          name: 'Campobasso',
          createdAt: DateTime(2024),
          modifiedAt: DateTime(2024),
          places: ToMany(),
          events: ToMany(),
        ),
      );

      // Remote returns the same city with a new name and modifiedAt.
      supabaseEnv.stubSelectResponse([
        {
          'id': 1,
          'name': 'Campobasso Aggiornato',
          'created_at': '2024-01-01T00:00:00.000',
          'modified_at': '2025-06-01T00:00:00.000',
        },
      ]);

      final result = await repository.synchronize();

      expect(result, isA<Success<void>>());
      expect(cityBox.get(1)?.name, equals('Campobasso Aggiornato'));
      verify(
        () => mockLogger.log(any(that: isA<EntityUpdateSuccess>())),
      ).called(1);
    });

    test('skips a city that already matches the local copy', () async {
      cityBox.put(
        CityEntity(
          remoteId: 1,
          name: 'Campobasso',
          createdAt: DateTime(2024),
          modifiedAt: DateTime(2024),
          places: ToMany(),
          events: ToMany(),
        ),
      );

      supabaseEnv.stubSelectResponse([
        {
          'id': 1,
          'name': 'Campobasso',
          'created_at': '2024-01-01T00:00:00.000',
          'modified_at': '2024-01-01T00:00:00.000',
        },
      ]);

      final result = await repository.synchronize();

      expect(result, isA<Success<void>>());
      // Box must be unchanged — city is identical to remote, no write occurs.
      expect(cityBox.get(1)?.name, equals('Campobasso'));
      verifyNever(() => mockLogger.log(any(that: isA<EntityInsertSuccess>())));
      verifyNever(() => mockLogger.log(any(that: isA<EntityUpdateSuccess>())));
    });

    test('returns Error when Supabase query fails', () async {
      supabaseEnv.stubSelectError(
        const PostgrestException(message: 'relation "cities" does not exist'),
      );

      final result = await repository.synchronize();

      expect(result, isA<Error<void>>());
      verify(
        () => mockLogger.log(
          const RepositorySyncFailed('city'),
          error: any(named: 'error'),
          stackTrace: any(named: 'stackTrace'),
        ),
      ).called(1);
    });
  });
}
