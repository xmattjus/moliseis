import 'package:sentry_flutter/sentry_flutter.dart';

// Validate the original spelling: URI normalization could hide traversal.
final _sourceUri = RegExp(
  '^(?:package:(?:moliseis|flutter)/|dart:[a-z_][a-z0-9_-]*/)'
  r'(?:[a-z_][a-z0-9_-]*/)*[a-z_][a-z0-9_]*\.dart$',
);

/// Recognizes bounded canonical source identities, without proving provenance.
bool _isCanonicalSourceUri(String? value) {
  if (value == null || value.length > 512) return false;
  // Checking the match end also excludes a trailing newline at the anchor.
  return _sourceUri.matchAsPrefix(value)?.end == value.length;
}

/// Keeps validated app, Flutter and Dart source URIs and numeric locations.
///
/// Functions, absolute paths and unsupported/generated sources are omitted.
/// Automatic AOT errors may retain numeric addresses for symbolication.
SentryStackTrace? safeDiagnosticFrames(
  Iterable<SentryStackFrame> frames, {
  bool allowNative = false,
}) {
  final safe = <SentryStackFrame>[];
  for (final frame in frames.take(256)) {
    if (allowNative &&
        frame.platform == 'native' &&
        _address(frame.instructionAddr) != null) {
      safe.add(
        SentryStackFrame(
          instructionAddr: _address(frame.instructionAddr),
          imageAddr: _address(frame.imageAddr),
          platform: 'native',
        ),
      );
      continue;
    }
    final path = frame.absPath;
    if (!_isCanonicalSourceUri(path)) continue;
    safe.add(
      SentryStackFrame(
        fileName: path,
        absPath: path,
        lineNo: _sourcePosition(frame.lineNo),
        colNo: _sourcePosition(frame.colNo),
        inApp: path!.startsWith('package:moliseis/'),
        platform: 'dart',
      ),
    );
  }
  return safe.isEmpty ? null : SentryStackTrace(frames: safe);
}

String? _address(String? value) =>
    value != null && RegExp(r'^0x[0-9a-fA-F]{1,16}$').hasMatch(value)
    ? value
    : null;

String? _debugId(String? value) =>
    value != null &&
        RegExp(
          '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
          r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}(?:-[0-9a-fA-F]{1,8})?$',
        ).hasMatch(value)
    ? value
    : null;

/// Keeps build identifiers needed to resolve AOT addresses, without file paths.
DebugMeta? safeAutomaticImages(DebugMeta? meta) {
  if (meta == null) return null;
  final safe = DebugMeta();
  for (final image in meta.images.take(256)) {
    if (!const {'macho', 'elf', 'pe'}.contains(image.type)) continue;
    final debugId = _debugId(image.debugId ?? image.uuid);
    if (debugId == null) continue;
    safe.addDebugImage(
      DebugImage(
        type: image.type,
        debugId: debugId,
        imageAddr: _address(image.imageAddr),
        imageVmAddr: _address(image.imageVmAddr),
        imageSize:
            image.imageSize != null &&
                image.imageSize! > 0 &&
                image.imageSize! <= 9007199254740991
            ? image.imageSize
            : null,
        arch:
            const {
              'arm',
              'arm64',
              'arm64e',
              'x86',
              'x86_64',
            }.contains(image.arch)
            ? image.arch
            : null,
        codeId:
            image.codeId != null &&
                RegExp(r'^[0-9a-fA-F]{8,64}$').hasMatch(image.codeId!)
            ? image.codeId
            : null,
      ),
    );
  }
  return safe.images.isEmpty ? null : safe;
}

int? _sourcePosition(int? value) =>
    value != null && value > 0 && value <= 1000000 ? value : null;

/// Reads the VM's source-line shape without forwarding unparsed stack text.
SentryStackTrace? safeApplicationStack(StackTrace? stack) {
  if (stack == null) return null;
  try {
    final text = stack.toString();
    if (text.length > 65536) return null;
    final frames = <SentryStackFrame>[];
    final pattern = RegExp(r'^#\d+\s+.* \(([^()]+):(\d+):(\d+)\)$');
    for (final line in text.split('\n').take(256)) {
      final match = pattern.firstMatch(line.trim());
      if (match == null) continue;
      frames.add(
        SentryStackFrame(
          absPath: match[1],
          lineNo: int.tryParse(match[2]!),
          colNo: int.tryParse(match[3]!),
        ),
      );
    }
    return safeDiagnosticFrames(frames.reversed);
  } on Object catch (_) {
    return null;
  }
}

/// Rebuilds automatic exceptions independently of application report families.
SentryException safeAutomaticException(SentryException exception) {
  final mechanism = exception.mechanism;
  return SentryException(
    type:
        const {
          'StateError',
          'NoSuchMethodError',
          'LateError',
          'UnsupportedError',
          'ConcurrentModificationError',
          'FormatException',
          'TypeError',
          '_TypeError',
          'RangeError',
          'ArgumentError',
          'AssertionError',
          'FlutterError',
          'PlatformException',
          'Exception',
          'TimeoutException',
          'SocketException',
          'FileSystemException',
          'PostgrestException',
          'FunctionException',
        }.contains(exception.type)
        ? exception.type
        : 'DartError',
    value: 'SDK error',
    stackTrace: exception.stackTrace == null
        ? null
        : safeDiagnosticFrames(exception.stackTrace!.frames, allowNative: true),
    mechanism: mechanism == null
        ? null
        : Mechanism(
            type:
                const {
                  'runZonedGuarded',
                  'FlutterError',
                  'PlatformDispatcher.onError',
                  'PlatformException',
                  'generic',
                  'chained',
                }.contains(mechanism.type)
                ? mechanism.type
                : 'generic',
            handled: mechanism.handled,
            isExceptionGroup: mechanism.isExceptionGroup,
            exceptionId: mechanism.exceptionId == 0
                ? 0
                : _sourcePosition(mechanism.exceptionId),
            parentId: mechanism.parentId == 0
                ? 0
                : _sourcePosition(mechanism.parentId),
          ),
  );
}
