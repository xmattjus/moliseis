import 'dart:convert' show utf8;
import 'dart:io' show File;
import 'dart:math' show Random;

/// Builds a streamed multipart/form-data body for a Cloudinary upload.
///
/// The writer streams the file directly from disk and computes an explicit
/// [Content-Length] so the upload client can avoid chunked transfer-encoding.
class CloudinaryMultipartWriter {
  /// Creates a writer for the given [file] and text [fields].
  CloudinaryMultipartWriter({
    required File file,
    required Map<String, String> fields,
    required String fileName,
  }) : _file = file,
       _fields = fields,
       _boundary = _generateBoundary(),
       // Escape double-quotes per RFC 2388 so the Content-Disposition header
       // is well-formed even when the filename contains a literal `"`.
       _escapedFileName = fileName.replaceAll('"', r'\"') {
    _footer = utf8.encode('\r\n--$_boundary--\r\n');
    _filePartHeader = utf8.encode(
      '--$_boundary\r\n'
      'Content-Disposition: form-data; name="file"; '
      'filename="$_escapedFileName"\r\n'
      'Content-Type: application/octet-stream\r\n\r\n',
    );
  }

  final File _file;
  final Map<String, String> _fields;

  /// The filename as it appears in the `Content-Disposition` header.
  final String _escapedFileName;
  final String _boundary;

  late final List<int> _footer;
  late final List<int> _filePartHeader;

  /// The boundary token used to delimit multipart sections.
  String get boundary => _boundary;

  /// Value for the `Content-Type` header.
  String get contentType => 'multipart/form-data; boundary=$_boundary';

  /// Total byte length of the body, suitable for `Content-Length`.
  ///
  /// Uses [File.length] (async) to avoid blocking the event loop.
  Future<int> computeTotalLength() async {
    var length = 0;

    for (final entry in _fields.entries) {
      length += _textPartHeaderLength(entry.key, entry.value);
    }

    length += _filePartHeader.length;
    length += await _file.length();
    length += _footer.length;

    return length;
  }

  /// Emits the multipart body as a stream of byte chunks.
  Stream<List<int>> write() async* {
    for (final entry in _fields.entries) {
      yield _textPartHeader(entry.key);
      yield utf8.encode(entry.value);
      yield utf8.encode('\r\n');
    }

    yield _filePartHeader;

    await for (final chunk in _file.openRead()) {
      yield chunk;
    }

    yield _footer;
  }

  List<int> _textPartHeader(String name) {
    return utf8.encode(
      '--$_boundary\r\n'
      'Content-Disposition: form-data; name="$name"\r\n\r\n',
    );
  }

  int _textPartHeaderLength(String name, String value) {
    return _textPartHeader(name).length +
        utf8.encode(value).length +
        utf8.encode('\r\n').length;
  }

  static String _generateBoundary() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '----DartFormBoundary$hex';
  }
}
