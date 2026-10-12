import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/data/data-sources/city_entity.dart';
import 'package:moliseis/data/dtos/city_dto.dart';
import 'package:moliseis/data/repositories/city_repository_impl.dart';
import 'package:moliseis/generated/objectbox.g.dart';
import 'package:moliseis/utils/logging/log_event.dart';
import 'package:moliseis/utils/result.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/fixtures.dart';
import '../../support/mock_logger.dart';
import '../../support/mock_supabase.dart';
import '../../support/objectbox_test_store.dart';

void main() {
  setUpAll(setUpMockSupabase);

  test('City prepare rejects a later page without local publication', () async {
    final environment = await TestObjectBoxEnvironment.create();
    addTearDown(environment.dispose);
    final remote = MockSupabaseEnvironment()
      ..stubSelectPages(
        [
          [
            {
              'id': 1,
              'name': 'Row',
              'created_at': '2026-01-01T00:00:00Z',
              'modified_at': '2026-01-01T00:00:00Z',
            },
          ],
        ],
        errorPage: 1,
        error: const PostgrestException(message: 'later page failed'),
      );
    final repository = CityRepositoryImpl(
      logger: MockLogger(),
      supabaseI: remote.mockSupabase,
      objectBoxI: TestObjectBox(environment.store),
    );
    final result = await repository.prepareSync(
      modifiedAtOrAfter: DateTime.utc(2026),
    );
    expect(result, isA<Error<List<CityDto>>>());
    expect(environment.store.box<CityEntity>().count(), 0);
    expect(remote.requests, hasLength(2));
    expect(
      remote.requests.every((uri) => uri.path.endsWith('/cities')),
      isTrue,
    );
    expect(remote.requests.last.queryParameters['id'], 'gt.1');
    expect(
      remote.requests.last.queryParameters['modified_at'],
      'gte.2026-01-01T00:00:00.000Z',
    );
  });

  // ---------------------------------------------------------------------------
  // prepareSync — error path
  // ---------------------------------------------------------------------------

  group('CityRepositoryImpl - prepareSync error handling', () {
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
        objectBoxI: TestObjectBox(objectBoxEnvironment.store),
      );
    });

    tearDown(() async {
      await objectBoxEnvironment.dispose();
    });

    test('returns Error when Supabase throws an exception', () async {
      final result = await repository.prepareSync();

      expect(result, isA<Error<List<CityDto>>>());
      final failedCall = mockLogger.firstCallOfType<RepositorySyncFailed>();
      expect(failedCall, isNotNull);
      final event = failedCall!.event as RepositorySyncFailed;
      expect(event.repositoryName, 'city');
      expect(failedCall.error, isNotNull);
      expect(failedCall.stackTrace, isNotNull);
    });
  });

  // ---------------------------------------------------------------------------
  // commitSync — success path
  // ---------------------------------------------------------------------------

  group('CityRepositoryImpl - commitSync', () {
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

      final prepareResult = await repository.prepareSync();
      final dtos = (prepareResult as Success<List<CityDto>>).value;
      repository.commitSync(dtos);

      expect(cityBox.get(1)?.name, equals('Campobasso'));
      expect(mockLogger.eventsOfType<EntityInsertSuccess>(), hasLength(1));
    });

    test('updates an existing city when remote data differs', () async {
      // Seed the local store with an older version.
      cityBox.put(
        makeCityEntity(
          remoteId: 1,
          name: 'Campobasso',
          createdAt: DateTime(2024),
          modifiedAt: DateTime(2024),
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

      final prepareResult = await repository.prepareSync();
      final dtos = (prepareResult as Success<List<CityDto>>).value;
      repository.commitSync(dtos);

      expect(cityBox.get(1)?.name, equals('Campobasso Aggiornato'));
      expect(mockLogger.eventsOfType<EntityUpdateSuccess>(), hasLength(1));
    });

    test('skips a city that already matches the local copy', () async {
      cityBox.put(
        makeCityEntity(
          remoteId: 1,
          name: 'Campobasso',
          createdAt: DateTime(2024),
          modifiedAt: DateTime(2024),
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

      final prepareResult = await repository.prepareSync();
      final dtos = (prepareResult as Success<List<CityDto>>).value;
      repository.commitSync(dtos);

      // Box must be unchanged — city is identical to remote, no write occurs.
      expect(cityBox.get(1)?.name, equals('Campobasso'));
      expect(mockLogger.containsEvent<EntityInsertSuccess>(), isFalse);
      expect(mockLogger.containsEvent<EntityUpdateSuccess>(), isFalse);
    });

    test(
      'City newer lifecycle merges preserve relations and replay freshness',
      () {
        cityBox.put(
          makeCityEntity(remoteId: 1, modifiedAt: DateTime.utc(2024)),
        );
        for (final state in [(2025, true), (2026, true), (2027, false)]) {
          final dto = CityDto(
            id: 1,
            name: 'City ${state.$1}',
            createdAt: DateTime.utc(2024),
            modifiedAt: DateTime.utc(state.$1),
            deletedAt: state.$2 ? DateTime.utc(state.$1) : null,
          );
          expect(repository.commitSync([dto]), isA<Success<void>>());
          final stored = cityBox.get(1)!;
          expect(stored.remoteId, 1);
          expect(stored.isDeleted, state.$2);
          expect(stored.name, dto.name);
          expect(stored.modifiedAt.toUtc(), dto.modifiedAt);
        }
        expect(
          repository.commitSync([
            CityDto(
              id: 1,
              name: 'Stale',
              createdAt: DateTime.utc(2024),
              modifiedAt: DateTime.utc(2026),
              deletedAt: DateTime.utc(2026),
            ),
          ]),
          isA<Success<void>>(),
        );
        expect(cityBox.get(1)!.isDeleted, isFalse);
        expect(cityBox.get(1)!.name, 'City 2027');
        expect(
          repository.commitSync([
            CityDto(
              id: 2,
              name: 'Absent tombstone',
              createdAt: DateTime.utc(2024),
              modifiedAt: DateTime.utc(2027),
              deletedAt: DateTime.utc(2027),
            ),
          ]),
          isA<Success<void>>(),
        );
        expect(cityBox.get(2), isNull);
      },
    );

    test('prepareSync returns Error when Supabase query fails', () async {
      supabaseEnv.stubSelectError(
        const PostgrestException(message: 'relation "cities" does not exist'),
      );

      final result = await repository.prepareSync();

      expect(result, isA<Error<List<CityDto>>>());
      final failedCall = mockLogger.firstCallOfType<RepositorySyncFailed>();
      expect(failedCall, isNotNull);
      final event = failedCall!.event as RepositorySyncFailed;
      expect(event.repositoryName, 'city');
      expect(failedCall.error, isNotNull);
      expect(failedCall.stackTrace, isNotNull);
    });
  });
}
