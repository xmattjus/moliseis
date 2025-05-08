import 'dart:async' show Completer, Timer;

typedef Debounceable1<S> = Future<S?> Function();

typedef Debounceable<S, T> = Future<S?> Function(T parameter);

Debounceable1<S> debounce1<S>({
  required Duration duration,
  required Debounceable1<S?> function,
}) {
  _DebounceTimer? debounceTimer;

  return () async {
    if (debounceTimer != null && !debounceTimer!.isCompleted) {
      debounceTimer!.cancel();
    }
    debounceTimer = _DebounceTimer(duration);
    try {
      await debounceTimer!.future;
    } on _CancelException {
      return null;
    }
    return function();
  };
}

/// Returns a new function that is a debounced version of the given function.
///
/// This means that the original function will be called only after no calls
/// have been made for the given [duration].
Debounceable<S, T> debounce<S, T>({
  required Duration duration,
  required Debounceable<S?, T> function,
}) {
  _DebounceTimer? debounceTimer;

  return (T parameter) async {
    if (debounceTimer != null && !debounceTimer!.isCompleted) {
      debounceTimer!.cancel();
    }
    debounceTimer = _DebounceTimer(duration);
    try {
      await debounceTimer!.future;
    } on _CancelException {
      return null;
    }
    return function(parameter);
  };
}

// A wrapper around Timer used for debouncing.
class _DebounceTimer {
  _DebounceTimer(this.duration) {
    _timer = Timer(duration, _onComplete);
  }

  final Duration duration;
  late final Timer _timer;
  final Completer<void> _completer = Completer<void>();

  void _onComplete() {
    _completer.complete();
  }

  Future<void> get future => _completer.future;

  bool get isCompleted => _completer.isCompleted;

  void cancel() {
    _timer.cancel();
    _completer.completeError(const _CancelException());
  }
}

// An exception indicating that the timer was canceled.
class _CancelException implements Exception {
  const _CancelException();
}
