import 'package:mocktail/mocktail.dart';
import 'package:moliseis/data/services/objectbox.dart' as app_objectbox;
import 'package:objectbox/objectbox.dart';

/// A [Store] mock that only supports [Box] of type [T].
///
/// Any other box type throws a [StateError]. Use with [MockEntityBox] and
/// [MockObjectBox] to wire a repository under test without a real ObjectBox
/// store.
final class MockObjectBoxStore<T> extends Mock implements Store {
  MockObjectBoxStore(this._mockBox);

  final Box<T> _mockBox;

  @override
  Box<R> box<R>() {
    if (R == T) return _mockBox as Box<R>;
    throw StateError(
      'MockObjectBoxStore<$T> only supports Box<$T>, got Box<$R>',
    );
  }
}

/// A [Mock] implementing [Box] for a specific entity type [T].
final class MockEntityBox<T> extends Mock implements Box<T> {}

/// An [app_objectbox.ObjectBox] that wraps a [Store] for testing.
final class MockObjectBox implements app_objectbox.ObjectBox {
  MockObjectBox(this._mockStore);

  final Store _mockStore;

  @override
  Store get store => _mockStore;

  @override
  set store(Store value) {
    throw UnsupportedError('MockObjectBox store is immutable.');
  }
}
