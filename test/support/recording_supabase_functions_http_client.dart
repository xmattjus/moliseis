import 'dart:convert';

import 'package:http/http.dart' as http;

/// Queued-response client for deterministic Supabase Function tests.
final class RecordingSupabaseFunctionsHttpClient extends http.BaseClient {
  final List<
    ({
      String method,
      Uri url,
      Map<String, String> headers,
      Object? body,
    })
  >
  requests = [];
  final List<
    ({
      int status,
      String body,
      Map<String, String> headers,
      String? reasonPhrase,
    })
  >
  _responses = [];
  http.ClientException? error;

  void queueJson(Object? body, {int status = 200, String? reasonPhrase}) {
    _responses.add((
      status: status,
      body: jsonEncode(body),
      headers: const {'content-type': 'application/json; charset=utf-8'},
      reasonPhrase: reasonPhrase,
    ));
  }

  void queueText(String body, {required int status}) {
    _responses.add((
      status: status,
      body: body,
      headers: const {'content-type': 'text/plain'},
      reasonPhrase: null,
    ));
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final requestBody = await request.finalize().transform(utf8.decoder).join();
    requests.add((
      method: request.method,
      url: request.url,
      headers: Map<String, String>.fromEntries(
        request.headers.entries.map(
          (entry) => MapEntry(entry.key.toLowerCase(), entry.value),
        ),
      ),
      body: requestBody.isEmpty ? null : jsonDecode(requestBody),
    ));
    if (error != null) throw error!;
    final response = _responses.removeAt(0);
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(response.body)),
      response.status,
      request: request,
      headers: response.headers,
      reasonPhrase: response.reasonPhrase,
    );
  }
}
