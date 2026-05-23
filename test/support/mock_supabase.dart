import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabase extends Mock implements Supabase {}

/// Configurable HTTP stub for `SupabaseClient` query calls.
///
/// Intercepts every HTTP request from the Supabase client and returns either a
/// configured success payload or a [PostgrestException]-shaped error response.
/// All responses use `application/json; charset=utf-8` so that postgrest can
/// parse them correctly.
final class _StubHttpClient extends http.BaseClient {
  List<Map<String, dynamic>>? _data;
  PostgrestException? _error;

  void configureSuccess(List<Map<String, dynamic>> data) {
    _data = data;
    _error = null;
  }

  void configureError(PostgrestException error) {
    _error = error;
    _data = null;
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (_error != null) {
      final e = _error!;
      return _stream(
        jsonEncode({
          'message': e.message,
          'code': e.code ?? '',
          'details': e.details,
          'hint': e.hint,
        }),
        400,
        request: request,
      );
    }
    return _stream(jsonEncode(_data ?? []), 200, request: request);
  }

  static http.StreamedResponse _stream(
    String body,
    int statusCode, {
    required http.BaseRequest? request,
  }) => http.StreamedResponse(
    Stream.value(utf8.encode(body)),
    statusCode,
    request: request,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

/// Pre-configured mock Supabase environment for repository tests.
///
/// Creates a [MockSupabase] whose `.client` getter returns a real
/// [SupabaseClient] backed by an in-memory [_StubHttpClient]. This makes
/// `from(table).select()` type-safe and testable without a live backend.
///
/// ## Usage
///
/// ```dart
/// setUpAll(setUpMockSupabase);
///
/// test('synchronize inserts a new city', () async {
///   final env = MockSupabaseEnvironment()
///     ..stubSelectResponse([
///       {
///         'id': 1,
///         'name': 'Campobasso',
///         'created_at': '2024-01-01T00:00:00.000',
///         'modified_at': '2024-01-01T00:00:00.000',
///       },
///     ]);
///
///   final repo = CityRepositoryImpl(supabaseI: env.mockSupabase, ...);
///   expect(await repo.synchronize(), isA<Success<void>>());
/// });
/// ```
///
/// ## Important notes
///
/// - [setUpMockSupabase] **must** be called (via `setUpAll`) before
///   constructing any [MockSupabaseEnvironment]; otherwise mocktail will
///   throw `MissingFallbackValueError`.
/// - By default, `select()` returns an empty list. Configure the response
///   first via [stubSelectResponse] or [stubSelectError].
/// - Create a fresh instance in `setUp()` or directly inside each test.
///   Do not reuse instances across tests.
class MockSupabaseEnvironment {
  MockSupabaseEnvironment() {
    _httpClient = _StubHttpClient();
    _supabaseClient = SupabaseClient(
      'http://localhost',
      'test-anon-key',
      httpClient: _httpClient,
    );
    when(() => mockSupabase.client).thenAnswer((_) {
      if (_unavailable) {
        throw Exception('Supabase unavailable (test stub)');
      }
      return _supabaseClient;
    });
  }

  final mockSupabase = MockSupabase();
  late final _StubHttpClient _httpClient;
  late final SupabaseClient _supabaseClient;
  bool _unavailable = false;

  /// Configures `from(table).select()` to return [data] successfully.
  void stubSelectResponse(List<Map<String, dynamic>> data) {
    _httpClient.configureSuccess(data);
  }

  /// Configures `from(table).select()` to return a [PostgrestException].
  void stubSelectError(PostgrestException error) {
    _httpClient.configureError(error);
  }

  /// Makes `mockSupabase.client` throw, simulating a client-side failure
  /// (e.g., Supabase not yet initialised). This does **not** simulate a
  /// network-level outage; for that, use [stubSelectError] with a
  /// [PostgrestException].
  void stubUnavailable() {
    _unavailable = true;
  }
}

/// Registers fallback values for [MockSupabaseEnvironment] verification
/// with mocktail. Call once per test suite in `setUpAll`.
void setUpMockSupabase() {
  registerFallbackValue('');
}
