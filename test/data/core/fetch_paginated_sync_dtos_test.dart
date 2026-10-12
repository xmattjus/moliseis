import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/data/core/fetch_paginated_sync_dtos.dart';
import 'package:moliseis/data/dtos/city_dto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/mock_supabase.dart';

void main() {
  setUpAll(setUpMockSupabase);
  final marker = DateTime.utc(2026);
  final row = <String, dynamic>{
    'id': 1,
    'name': 'City',
    'created_at': marker.toIso8601String(),
    'modified_at': marker.toIso8601String(),
  };

  test(
    'full scan crosses requested-size and short pages until empty',
    () async {
      final env = MockSupabaseEnvironment()
        ..stubSelectPages([
          List.generate(500, (index) => {...row, 'id': index + 1}),
          [
            {...row, 'id': 501},
          ],
          [
            {...row, 'id': 502},
          ],
          [],
        ]);
      final dtos = await fetchPaginatedSyncDtos(
        env.client,
        'cities',
        CityDtoMapper.fromMap,
      );
      expect(
        dtos.map((dto) => dto.id),
        orderedEquals(List.generate(502, (i) => i + 1)),
      );
      expect(env.requests, hasLength(4));
      for (final uri in env.requests) {
        expect(uri.path, '/rest/v1/cities');
        expect(uri.queryParameters['select'], '*');
        expect(uri.queryParameters['order'], 'id.asc.nullslast');
        expect(uri.queryParameters['limit'], '500');
        expect(uri.queryParameters.containsKey('modified_at'), isFalse);
        expect(uri.queryParameters.containsKey('offset'), isFalse);
        expect(uri.queryParameters.containsKey('deleted_at'), isFalse);
      }
      expect(env.requests.first.queryParameters.containsKey('id'), isFalse);
      expect(env.requests[1].queryParameters['id'], 'gt.500');
      expect(env.requests[2].queryParameters['id'], 'gt.501');
      expect(env.requests[3].queryParameters['id'], 'gt.502');
    },
  );

  test(
    'delta equality includes tombstones and later markers on every page',
    () async {
      final env = MockSupabaseEnvironment()
        ..stubSelectResponse([
          {
            ...row,
            'id': 1,
            'modified_at': marker
                .subtract(const Duration(microseconds: 1))
                .toIso8601String(),
          },
          {...row, 'id': 2, 'deleted_at': marker.toIso8601String()},
          {
            ...row,
            'id': 3,
            'modified_at': marker
                .add(const Duration(days: 3))
                .toIso8601String(),
          },
        ]);
      final dtos = await fetchPaginatedSyncDtos(
        env.client,
        'cities',
        CityDtoMapper.fromMap,
        modifiedAtOrAfter: marker,
      );
      expect(dtos.map((dto) => dto.id), orderedEquals([2, 3]));
      expect(dtos.first.deletedAt, marker);
      expect(env.requests, hasLength(2));
      for (final uri in env.requests) {
        expect(
          uri.queryParameters['modified_at'],
          'gte.${marker.toIso8601String()}',
        );
        expect(uri.queryParametersAll['modified_at'], hasLength(1));
      }
      expect(env.requests.first.queryParameters.containsKey('id'), isFalse);
      expect(env.requests.last.queryParameters['id'], 'gt.3');
    },
  );

  test(
    'static fixtures honor ordering and id continuation beyond 500 rows',
    () async {
      final env = MockSupabaseEnvironment()
        ..stubSelectResponse(
          List.generate(501, (index) => {...row, 'id': 501 - index}),
        );
      final dtos = await fetchPaginatedSyncDtos(
        env.client,
        'cities',
        CityDtoMapper.fromMap,
      );
      expect(
        dtos.map((dto) => dto.id),
        orderedEquals(List.generate(501, (index) => index + 1)),
      );
      expect(env.requests, hasLength(3));
      expect(env.requests[1].queryParameters['id'], 'gt.500');
      expect(env.requests[2].queryParameters['id'], 'gt.501');
    },
  );

  test('empty first page makes exactly one request', () async {
    final env = MockSupabaseEnvironment();
    expect(
      await fetchPaginatedSyncDtos(env.client, 'cities', CityDtoMapper.fromMap),
      isEmpty,
    );
    expect(env.requests, hasLength(1));
  });

  test('later page failure rejects all accumulated data', () async {
    final env = MockSupabaseEnvironment()
      ..stubSelectPages(
        [
          [row],
        ],
        errorPage: 1,
        error: const PostgrestException(message: 'page failed'),
      );
    await expectLater(
      fetchPaginatedSyncDtos(env.client, 'cities', CityDtoMapper.fromMap),
      throwsA(isA<PostgrestException>()),
    );
    expect(env.requests, hasLength(2));
  });

  test('later decode failure rejects all accumulated data', () async {
    final env = MockSupabaseEnvironment()
      ..stubSelectPages([
        [row],
        [
          {'id': 2},
        ],
      ]);
    await expectLater(
      fetchPaginatedSyncDtos(env.client, 'cities', CityDtoMapper.fromMap),
      throwsA(isA<Exception>()),
    );
    expect(env.requests, hasLength(2));
  });
}
