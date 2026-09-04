import 'dart:async' show Completer;
import 'dart:convert' show ascii, jsonEncode, latin1, utf8;
import 'dart:io' show HttpException, HttpRequest, HttpServer, InternetAddress;

/// A loopback HTTP server that mimics Cloudinary's upload API.
///
/// Use [baseUri] as the `baseUrl` override for the upload client so tests do
/// not make real Cloudinary requests.
class FakeCloudinaryServer {
  FakeCloudinaryServer({
    this.cloudName = 'test_cloud',
  });

  final String cloudName;

  HttpServer? _server;
  final _requests = <FakeCloudinaryRecordedRequest>[];
  final _uploadDelays = <String, Completer<void>>{};
  final _slowUploadQueue = <Completer<void>>[];
  final _responseBodyDelays = <Completer<void>>[];
  final _responseBodyStarted = <Completer<void>>[];
  final _uploadResponseQueue = <_FakeUploadOverride>[];
  var _uploadResponseStatus = 200;
  Map<String, dynamic> _uploadResponseBody = const <String, dynamic>{
    'secure_url': 'https://res.cloudinary.com/test_cloud/image/upload/v1/test',
    'width': 100,
    'height': 100,
  };

  /// Base URI of the running server, e.g. `http://127.0.0.1:12345`.
  Uri get baseUri {
    final server = _server;
    if (server == null) {
      throw StateError('FakeCloudinaryServer has not been started');
    }
    return Uri.parse('http://${server.address.host}:${server.port}');
  }

  /// Every request received by the server, in arrival order.
  List<FakeCloudinaryRecordedRequest> get requests =>
      List.unmodifiable(_requests);

  /// Starts the server on `127.0.0.1:0`.
  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server!.listen(_handleRequest);
  }

  /// Stops the server and releases the port.
  ///
  /// Also completes any pending slow-upload [Completer]s so that server-side
  /// handler futures do not remain suspended after the test ends.
  Future<void> stop() async {
    // Complete all pending upload delays before closing so that any
    // server-side async handlers that are blocked on a Completer can finish
    // cleanly instead of being left as dangling async operations.
    for (final completer in _uploadDelays.values) {
      if (!completer.isCompleted) completer.complete();
    }
    _uploadDelays.clear();

    for (final completer in _slowUploadQueue) {
      if (!completer.isCompleted) completer.complete();
    }
    _slowUploadQueue.clear();

    for (final completer in _responseBodyDelays) {
      if (!completer.isCompleted) completer.complete();
    }
    _responseBodyDelays.clear();
    for (final completer in _responseBodyStarted) {
      if (!completer.isCompleted) completer.complete();
    }
    _responseBodyStarted.clear();

    await _server?.close(force: true);
    _server = null;
  }

  /// Configures the response returned by the upload endpoint.
  void setUploadResponse({
    required int status,
    required Map<String, dynamic> body,
  }) {
    _uploadResponseStatus = status;
    _uploadResponseBody = body;
  }

  /// When called, the next upload matching [publicId] will block on a
  /// [Completer] until [completeSlowUpload] is called.
  Completer<void> makeNextUploadSlow(String publicId) {
    final completer = Completer<void>();
    _uploadDelays[publicId] = completer;
    return completer;
  }

  /// Releases any slow upload registered for [publicId].
  void completeSlowUpload(String publicId) {
    _uploadDelays.remove(publicId)?.complete();
  }

  /// Enqueues [count] parking [Completer]s that each upload — regardless of
  /// `public_id` — awaits in arrival order.
  ///
  /// Unlike [makeNextUploadSlow] (which targets a single public id and only
  /// blocks one request), this queue can hold multiple uploads across
  /// retries. Each completer is parked until [releaseNextSlowUpload] or
  /// [releaseAllSlowUploads] completes it (or [stop] clears it).
  void enqueueSlowUploads(int count) {
    for (var i = 0; i < count; i++) {
      _slowUploadQueue.add(Completer<void>());
    }
  }

  /// Number of parkable slow uploads that are still unresolved (i.e. the
  /// remaining backlog after the server has received and unblocked some
  /// uploads). Use this in tests to assert how many uploads actually reached
  /// the server before a client-side timeout.
  int get pendingSlowUploadCount => _slowUploadQueue.length;

  /// Releases the next parked slow-upload [Completer] (FIFO).
  void releaseNextSlowUpload() {
    final completer = _slowUploadQueue.isNotEmpty
        ? _slowUploadQueue.removeAt(0)
        : null;
    completer?.complete();
  }

  /// Completes every parked slow-upload [Completer] still in the queue.
  void releaseAllSlowUploads() {
    for (final completer in _slowUploadQueue) {
      if (!completer.isCompleted) completer.complete();
    }
    _slowUploadQueue.clear();
  }

  /// Makes the next upload send headers before parking its response body.
  ({Completer<void> release, Future<void> headersSent})
  makeNextResponseBodySlow() {
    final release = Completer<void>();
    final headersSent = Completer<void>();
    _responseBodyDelays.add(release);
    _responseBodyStarted.add(headersSent);
    return (release: release, headersSent: headersSent.future);
  }

  /// Enqueues a per-request response override. Each upload — regardless of
  /// `public_id` — pops the next queued override off and uses it instead of
  /// [setUploadResponse]. Use this to script a "fail N times then succeed"
  /// sequence across retries.
  void queueUploadResponses(
    List<({int status, Map<String, dynamic> body})> responses,
  ) {
    for (final response in responses) {
      _uploadResponseQueue.add(
        _FakeUploadOverride(status: response.status, body: response.body),
      );
    }
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final bodyBytes = <int>[];
    try {
      await request.forEach(bodyBytes.addAll);
    } on HttpException {
      // Client closed the connection (e.g. cancellation); nothing to do.
      return;
    }

    final recordedHeaders = <String, List<String>>{};
    request.headers.forEach((name, values) => recordedHeaders[name] = values);

    final path = request.uri.path;
    final uploadPattern = RegExp(r'^/v1_1/([^/]+)/image/upload$');
    final uploadMatch = uploadPattern.firstMatch(path);
    final boundary = request.headers.contentType?.parameters['boundary'];
    final multipart = uploadMatch == null || boundary == null
        ? const _FakeParsedMultipart(fields: {}, fileParts: [])
        : _parseMultipart(bodyBytes, boundary);
    final recorded = FakeCloudinaryRecordedRequest(
      method: request.method,
      path: path,
      headers: recordedHeaders,
      body: bodyBytes,
      multipartFields: multipart.fields,
      fileParts: multipart.fileParts,
    );
    _requests.add(recorded);

    if (uploadMatch != null && request.method == 'POST') {
      await _handleUploadRequest(request, multipart.fields);
      return;
    }

    request.response.statusCode = 404;
    await request.response.close();
  }

  Future<void> _handleUploadRequest(
    HttpRequest request,
    Map<String, String> fields,
  ) async {
    final publicId = fields['public_id'] ?? '';

    final delay = _uploadDelays.remove(publicId);
    if (delay != null && !delay.isCompleted) {
      await delay.future;
    }

    // Per-arrival slow-upload queue: every upload pops the next parked
    // completer regardless of public_id, so retries can be parked multiple
    // times across attempts. The completer is removed up-front so a release
    // happens even if the upload completes (or is aborted by the client)
    // before the server reaches this await — the parked handler simply
    // resumes once the completer is completed by the test (or [stop]).
    if (_slowUploadQueue.isNotEmpty) {
      final slow = _slowUploadQueue.removeAt(0);
      if (!slow.isCompleted) {
        await slow.future;
      }
    }

    final override = _uploadResponseQueue.isNotEmpty
        ? _uploadResponseQueue.removeAt(0)
        : null;
    final status = override?.status ?? _uploadResponseStatus;
    final responseBody = override?.body ?? _uploadResponseBody;
    final responseBodyDelay = _responseBodyDelays.isNotEmpty
        ? _responseBodyDelays.removeAt(0)
        : null;
    final responseBodyStarted = _responseBodyStarted.isNotEmpty
        ? _responseBodyStarted.removeAt(0)
        : null;

    await _respond(
      request,
      status: status,
      body: _jsonEncodeBody(responseBody),
      bodyDelay: responseBodyDelay,
      bodyStarted: responseBodyStarted,
    );
  }

  /// Writes [body] and closes [request] in a way that is resilient to the
  /// client having torn the connection down.
  ///
  /// After [stop] drains the parked slow-upload completers, in-flight
  /// handlers resume and attempt to write their response to an aborted
  /// socket. In dart:io this is usually benign (the write/close throws an
  /// [HttpException] that, if left uncaught, would propagate to the
  /// server's error sink and surface as test flake). Catch and swallow it
  /// here so handlers complete cleanly regardless of socket state.
  Future<void> _respond(
    HttpRequest request, {
    required int status,
    String? body,
    Completer<void>? bodyDelay,
    Completer<void>? bodyStarted,
  }) async {
    request.response.statusCode = status;
    request.response.headers.contentType = null;
    if (bodyDelay != null) {
      await request.response.flush();
      bodyStarted?.complete();
      await bodyDelay.future;
    }
    if (body != null) {
      request.response.write(body);
    }
    try {
      await request.response.close();
    } on HttpException {
      // Client already closed the connection; nothing more to do.
    }
  }

  _FakeParsedMultipart _parseMultipart(List<int> body, String boundary) {
    final boundaryBytes = ascii.encode('--$boundary');
    final nextBoundaryPrefix = <int>[13, 10, ...boundaryBytes];
    const headerSeparator = <int>[13, 10, 13, 10];
    final fields = <String, String>{};
    final fileParts = <FakeCloudinaryMultipartFilePart>[];
    var boundaryStart = _indexOfBytes(body, boundaryBytes);

    while (boundaryStart >= 0) {
      var cursor = boundaryStart + boundaryBytes.length;
      if (_bytesStartWith(body, const [45, 45], cursor)) break;
      if (!_bytesStartWith(body, const [13, 10], cursor)) {
        throw const FormatException('Malformed multipart boundary');
      }
      cursor += 2;

      final headersEnd = _indexOfBytes(body, headerSeparator, cursor);
      if (headersEnd < 0) {
        throw const FormatException('Missing multipart header terminator');
      }
      final headers = _parseMultipartHeaders(body.sublist(cursor, headersEnd));
      final contentStart = headersEnd + headerSeparator.length;
      final nextBoundaryStart = _findMultipartBoundary(
        body,
        nextBoundaryPrefix,
        contentStart,
      );
      if (nextBoundaryStart < 0) {
        throw const FormatException('Missing closing multipart boundary');
      }

      final disposition = headers['content-disposition'];
      final fieldName = disposition == null
          ? null
          : _multipartParameter(disposition, 'name');
      if (fieldName == null) {
        throw const FormatException('Multipart part has no field name');
      }
      final filename = _multipartParameter(disposition!, 'filename');
      final bytes = body.sublist(contentStart, nextBoundaryStart);
      if (filename == null) {
        fields[fieldName] = utf8.decode(bytes);
      } else {
        fileParts.add(
          FakeCloudinaryMultipartFilePart(
            fieldName: fieldName,
            filename: filename,
            contentType: headers['content-type'] ?? '',
            bytes: bytes,
          ),
        );
      }

      boundaryStart = nextBoundaryStart + 2;
    }

    return _FakeParsedMultipart(
      fields: Map.unmodifiable(fields),
      fileParts: List.unmodifiable(fileParts),
    );
  }

  int _findMultipartBoundary(
    List<int> body,
    List<int> boundaryPrefix,
    int start,
  ) {
    var candidate = _indexOfBytes(body, boundaryPrefix, start);
    while (candidate >= 0) {
      final suffixStart = candidate + boundaryPrefix.length;
      if (_bytesStartWith(body, const [45, 45], suffixStart) ||
          _bytesStartWith(body, const [13, 10], suffixStart)) {
        return candidate;
      }
      candidate = _indexOfBytes(body, boundaryPrefix, candidate + 1);
    }
    return -1;
  }

  Map<String, String> _parseMultipartHeaders(List<int> bytes) {
    final headers = <String, String>{};
    for (final line in latin1.decode(bytes).split('\r\n')) {
      final separator = line.indexOf(':');
      if (separator <= 0) {
        throw const FormatException('Malformed multipart header');
      }
      headers[line.substring(0, separator).toLowerCase()] = line
          .substring(separator + 1)
          .trim();
    }
    return headers;
  }

  String? _multipartParameter(String value, String parameter) {
    final match = RegExp(
      '(?:^|;\\s*)${RegExp.escape(parameter)}="([^"]*)"',
      caseSensitive: false,
    ).firstMatch(value);
    return match?.group(1);
  }

  int _indexOfBytes(List<int> bytes, List<int> pattern, [int start = 0]) {
    if (pattern.isEmpty) return start <= bytes.length ? start : -1;
    for (var index = start; index <= bytes.length - pattern.length; index++) {
      if (_bytesStartWith(bytes, pattern, index)) return index;
    }
    return -1;
  }

  bool _bytesStartWith(List<int> bytes, List<int> pattern, int start) {
    if (start < 0 || start + pattern.length > bytes.length) return false;
    for (var index = 0; index < pattern.length; index++) {
      if (bytes[start + index] != pattern[index]) return false;
    }
    return true;
  }

  String _jsonEncodeBody(Map<String, dynamic> body) => jsonEncode(body);
}

/// A recorded request received by [FakeCloudinaryServer].
class FakeCloudinaryRecordedRequest {
  FakeCloudinaryRecordedRequest({
    required this.method,
    required this.path,
    required this.headers,
    required this.body,
    required this.multipartFields,
    required List<FakeCloudinaryMultipartFilePart> fileParts,
  }) : fileParts = List.unmodifiable(fileParts);

  final String method;
  final String path;
  final Map<String, List<String>> headers;
  final List<int> body;
  final Map<String, String> multipartFields;
  final List<FakeCloudinaryMultipartFilePart> fileParts;

  /// Number of parsed multipart file parts in this request.
  int get filePartCount => fileParts.length;
}

/// A binary-safe parsed multipart file part received by the fake server.
class FakeCloudinaryMultipartFilePart {
  FakeCloudinaryMultipartFilePart({
    required this.fieldName,
    required this.filename,
    required this.contentType,
    required List<int> bytes,
  }) : bytes = List.unmodifiable(bytes);

  final String fieldName;
  final String filename;
  final String contentType;
  final List<int> bytes;
}

class _FakeParsedMultipart {
  const _FakeParsedMultipart({required this.fields, required this.fileParts});

  final Map<String, String> fields;
  final List<FakeCloudinaryMultipartFilePart> fileParts;
}

/// Per-request override popped from
/// [FakeCloudinaryServer.queueUploadResponses].
class _FakeUploadOverride {
  const _FakeUploadOverride({required this.status, required this.body});

  final int status;
  final Map<String, dynamic> body;
}
