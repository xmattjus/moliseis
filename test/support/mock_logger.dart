import 'package:moliseis/utils/logging/logging.dart';

/// Test double for [Logger] that records every call in [calls] for direct
/// inspection, replacing the need for mocktail's `verify`/`any` matchers.
///
/// Use it as a drop-in for [Logger]:
///
/// ```dart
/// final mockLogger = MockLogger();
/// repository.somethingThatLogs(mockLogger);
///
/// expect(mockLogger.eventsOfType<EntityInsertSuccess>(), hasLength(1));
/// ```
class MockLogger implements Logger {
  final List<
    ({
      LogEvent event,
      Object? error,
      StackTrace? stackTrace,
      Map<String, Object?>? extra,
    })
  >
  calls = [];

  @override
  void log(
    LogEvent event, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? extra,
  }) {
    calls.add((
      event: event,
      error: error,
      stackTrace: stackTrace,
      extra: extra,
    ));
  }

  /// Returns every [LogEvent] of type [T] that was logged, in call order.
  List<T> eventsOfType<T extends LogEvent>() =>
      calls.where((c) => c.event is T).map((c) => c.event as T).toList();

  /// Whether at least one [LogEvent] of type [T] was logged.
  bool containsEvent<T extends LogEvent>() => calls.any((c) => c.event is T);

  /// Returns the recorded call for the first [LogEvent] of type [T], or
  /// `null` if none was logged.
  ({
    LogEvent event,
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? extra,
  })?
  firstCallOfType<T extends LogEvent>() =>
      calls.where((c) => c.event is T).firstOrNull;

  /// Clears the call order list.
  void reset() => calls.clear();
}
