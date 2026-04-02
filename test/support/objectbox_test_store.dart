import 'dart:io';

import 'package:moliseis/data/services/objectbox.dart' as app_objectbox;
import 'package:moliseis/generated/objectbox.g.dart';

/// Creates and owns a temporary ObjectBox store for tests.
///
/// Use [dispose] in test teardown to close the store and delete the directory.
final class TestObjectBoxEnvironment {
  TestObjectBoxEnvironment._(this.directory, this.store);

  /// Temporary directory that stores the database files for this test run.
  final Directory directory;

  /// Real ObjectBox store used by tests.
  final Store store;

  bool _closed = false;

  /// Opens a fresh ObjectBox store in a unique temporary directory.
  static Future<TestObjectBoxEnvironment> create() async {
    final directory = await Directory.systemTemp.createTemp(
      'moliseis_objectbox_',
    );
    final store = await openStore(directory: directory.path);
    return TestObjectBoxEnvironment._(directory, store);
  }

  /// Closes the store once.
  void close() {
    if (_closed) return;
    store.close();
    _closed = true;
  }

  /// Closes the store and removes the temporary database directory.
  Future<void> dispose() async {
    close();
    await directory.delete(recursive: true);
  }
}

/// Thin ObjectBox wrapper used by tests to inject a real [Store].
final class TestObjectBox implements app_objectbox.ObjectBox {
  TestObjectBox(Store store) : _store = store;

  @override
  Store get store => _store;

  final Store _store;

  @override
  set store(Store value) {
    throw UnsupportedError('TestObjectBox store is immutable.');
  }
}
