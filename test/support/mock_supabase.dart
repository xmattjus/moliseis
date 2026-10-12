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
  List<Map<String, dynamic>> _data = [];
  List<List<Map<String, dynamic>>>? _pages;
  int _pageIndex = 0;
  int? _errorPage;
  PostgrestException? _error;
  Object? _rpcResponse;
  PostgrestException? _rpcError;
  Exception? _rpcNetworkError;
  final requests = <Uri>[];

  void configureSuccess(List<Map<String, dynamic>> data) {
    _data = data;
    _pages = null;
    _error = null;
  }

  void configurePages(
    List<List<Map<String, dynamic>>> pages, {
    int? errorPage,
    PostgrestException? error,
  }) {
    _pages = pages;
    _pageIndex = 0;
    _errorPage = errorPage;
    _error = error;
  }

  void configureError(PostgrestException error) {
    _error = error;
    _errorPage = null;
    _pages = null;
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request.url);
    if (request.url.path.contains('/rpc/')) {
      if (_rpcNetworkError != null) throw _rpcNetworkError!;
      if (_rpcError != null) return _errorResponse(_rpcError!, request);
      return _stream(jsonEncode(_rpcResponse), 200, request: request);
    }
    final pageIndex = _pageIndex++;
    if (_error != null && (_errorPage == null || _errorPage == pageIndex)) {
      return _errorResponse(_error!, request);
    }
    if (_pages != null) {
      final page = pageIndex < _pages!.length
          ? _pages![pageIndex]
          : <Map<String, dynamic>>[];
      return _stream(jsonEncode(page), 200, request: request);
    }
    final parameters = request.url.queryParameters;
    var rows = List<Map<String, dynamic>>.of(_data);
    final idFilter = parameters['id'];
    if (idFilter != null && idFilter.startsWith('gt.')) {
      final lastId = int.parse(idFilter.substring(3));
      rows = rows.where((row) => (row['id'] as int) > lastId).toList();
    }
    final markerFilter = parameters['modified_at'];
    if (markerFilter != null && markerFilter.startsWith('gte.')) {
      final lowerBound = DateTime.parse(markerFilter.substring(4));
      rows = rows.where((row) {
        final marker = DateTime.parse(row['modified_at'] as String);
        return !marker.isBefore(lowerBound);
      }).toList();
    }
    if (parameters['order']?.startsWith('id.asc') ?? false) {
      rows.sort((a, b) => (a['id'] as int).compareTo(b['id'] as int));
    }
    final limit = int.tryParse(parameters['limit'] ?? '');
    if (limit != null) rows = rows.take(limit).toList();
    return _stream(jsonEncode(rows), 200, request: request);
  }

  static http.StreamedResponse _errorResponse(
    PostgrestException error,
    http.BaseRequest request,
  ) => _stream(
    jsonEncode({
      'message': error.message,
      'code': error.code ?? '',
      'details': error.details,
      'hint': error.hint,
    }),
    400,
    request: request,
  );

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

  /// Real client backed by this environment's recording transport.
  SupabaseClient get client => _supabaseClient;

  /// Request URIs in arrival order, including cursor RPC calls.
  List<Uri> get requests => List.unmodifiable(_httpClient.requests);

  /// Scripts successive pages; an exhausted script returns an empty page.
  ///
  /// [errorPage] is zero-based and fails only that page with [error].
  void stubSelectPages(
    List<List<Map<String, dynamic>>> pages, {
    int? errorPage,
    PostgrestException? error,
  }) => _httpClient.configurePages(pages, errorPage: errorPage, error: error);

  /// Configures a scalar RPC result, including malformed or null payloads.
  void stubRpcResponse(Object? value) {
    _httpClient._rpcResponse = value;
    _httpClient._rpcError = null;
    _httpClient._rpcNetworkError = null;
  }

  /// Configures a recoverable PostgREST RPC failure.
  void stubRpcError(PostgrestException error) {
    _httpClient._rpcError = error;
    _httpClient._rpcNetworkError = null;
  }

  /// Configures a transport exception before any RPC response.
  void stubRpcNetworkError(Exception error) {
    _httpClient._rpcNetworkError = error;
    _httpClient._rpcError = null;
  }

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
