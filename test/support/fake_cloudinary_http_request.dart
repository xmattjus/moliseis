import 'dart:async';
import 'dart:io';

/// A passive completion future with observable cancellation.
class FakeCloudinaryHttpRequest implements HttpClientRequest {
  FakeCloudinaryHttpRequest({this.doneFuture});

  final Future<HttpClientResponse>? doneFuture;

  bool aborted = false;

  @override
  void abort([Object? exception, StackTrace? stackTrace]) {
    aborted = true;
  }

  @override
  Future<HttpClientResponse> get done =>
      doneFuture ??
      Future<HttpClientResponse>.value(FakeCloudinaryHttpResponse());

  // -------------------------------------------------------------------------
  // Unused stubs required by the interface.
  // -------------------------------------------------------------------------
  @override
  void noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A response placeholder; unsupported reads fail immediately.
class FakeCloudinaryHttpResponse implements HttpClientResponse {
  @override
  void noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// An HTTP client that fails at a deterministic request boundary.
class FaultingCloudinaryHttpClient implements HttpClient {
  FaultingCloudinaryHttpClient({required this.beforeClose});

  final bool beforeClose;
  final failure = const HttpException('synthetic request failure');
  final completion = Completer<HttpClientResponse>();
  bool closeCalled = false;

  @override
  Future<HttpClientRequest> postUrl(Uri url) async =>
      FaultingCloudinaryHttpRequest(this);

  @override
  set connectionTimeout(Duration? value) {}
  @override
  set idleTimeout(Duration value) {}
  @override
  set userAgent(String? value) {}
  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Fails before or during close using the exact same done future.
class FaultingCloudinaryHttpRequest implements HttpClientRequest {
  FaultingCloudinaryHttpRequest(this.client);
  final FaultingCloudinaryHttpClient client;

  @override
  HttpHeaders get headers => CloudinaryTestHttpHeaders();

  @override
  Future<HttpClientResponse> get done => client.completion.future;

  @override
  void add(List<int> data) {
    if (client.beforeClose) {
      client.completion.completeError(client.failure);
      throw client.failure;
    }
  }

  @override
  Future<HttpClientResponse> close() {
    client.closeCalled = true;
    client.completion.completeError(client.failure);
    return done;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Accepts only the header writes made by the upload client.
class CloudinaryTestHttpHeaders implements HttpHeaders {
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
