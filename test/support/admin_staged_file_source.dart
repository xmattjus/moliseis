import 'dart:io';

/// A real source with a synchronous hook before each read stream is opened.
///
/// This exercises actual copy verification and store failures at deterministic
/// boundaries without faking private files, ObjectBox or write operations.
final class AdminStagedFileSource implements File {
  /// Wraps a source whose read hook can mutate bytes or revoke storage access.
  AdminStagedFileSource(this.file, this.beforeRead);

  /// The actual filesystem source used for length and stream operations.
  final File file;

  /// Invoked with the one-based read count before opening the real stream.
  final void Function(int) beforeRead;

  int _readCount = 0;

  @override
  Future<int> length() => file.length();

  @override
  Stream<List<int>> openRead([int? start, int? end]) {
    beforeRead(++_readCount);
    return file.openRead(start, end);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Unsupported source operation.');
}
