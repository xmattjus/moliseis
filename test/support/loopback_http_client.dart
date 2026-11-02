import 'package:http/http.dart' as http;

/// Sends production URL requests through real HTTP to an isolated test server.
final class LoopbackHttpClient extends http.BaseClient {
  /// Keeps the real client and redirects only the request destination.
  LoopbackHttpClient(this.client, this.baseUri);

  /// The actual transport whose ownership is under test.
  final http.Client client;

  /// The loopback server destination; path and query are preserved.
  final Uri baseUri;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final redirected =
        http.Request(
            request.method,
            baseUri.replace(path: request.url.path, query: request.url.query),
          )
          ..headers.addAll(request.headers)
          ..bodyBytes = await request.finalize().toBytes();
    return await client.send(redirected);
  }

  @override
  void close() => client.close();
}
