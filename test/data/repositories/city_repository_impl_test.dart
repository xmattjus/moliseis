// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/data/data-sources/city_supabase_table.dart';
import 'package:moliseis/data/repositories/city_repository_impl.dart';
import 'package:moliseis/utils/result.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:talker_flutter/talker_flutter.dart';

import '../../support/objectbox_test_store.dart';

// CityRepositoryImpl's only public method is synchronize(), which makes a
// Supabase network call. The success path (insert/update/remove logic) requires
// a Supabase fake that is not achievable without mockito due to the
// SupabaseQueryBuilder type hierarchy. We test the error path, which exercises
// the `on Exception catch` handler and confirms Result.error propagation.

void main() {
  group('CityRepositoryImpl - synchronize error handling', () {
    late TestObjectBoxEnvironment objectBoxEnvironment;
    late CityRepositoryImpl repository;

    setUp(() async {
      objectBoxEnvironment = await TestObjectBoxEnvironment.create();
      repository = CityRepositoryImpl(
        logger: Talker(),
        supabaseI: _ThrowingSupabase(),
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
    });
  });
}

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

// Throws Exception on any Supabase access. The exception propagates before the
// SupabaseClient type cast, so it is caught by the repository's
// `on Exception catch` handler and returned as Result.error.
final class _ThrowingSupabase implements Supabase {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw Exception('Supabase unavailable');
}
