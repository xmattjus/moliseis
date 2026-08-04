import 'dart:async' show Completer, Timer;

/// A callback accepted by [debounce].
///
/// `S` is the asynchronous result type and `T` is the optional parameter
/// forwarded to the callback. Use `T = void` when the callback does not need
/// an argument.
///
/// With a typed parameter, `T` describes the value passed to each call:
///
/// ```dart
/// final characterCount = debounce<int, String>(
///   duration: const Duration(milliseconds: 300),
///   function: ([text]) async => text?.length,
/// );
///
/// final count = await characterCount('Molise');
/// ```
///
/// For a callback without an argument, set `T` to `void` and omit the
/// parameter when calling it:
///
/// ```dart
/// final refresh = debounce<bool, void>(
///   duration: const Duration(seconds: 1),
///   function: ([_]) async => true,
/// );
///
/// final refreshed = await refresh();
/// ```
typedef Debounceable<S, T> = Future<S?> Function([T? parameter]);

/// A cancellable operation that runs only after its calls have settled.
///
/// Each call resets the [duration] delay. When a newer call supersedes an
/// older one, the older call completes with `null` and its [function] is not
/// invoked. Use [cancel] to discard the current pending call explicitly.
///
/// Instances are normally created with [debounce] so that the generic
/// parameter `T` documents the value passed to the callback, or is set to
/// `void` for a callback with no argument.
class Debounced<S, T> {
  /// Creates a debounced operation with the given delay and callback.
  Debounced({required this.duration, required this.function});

  /// The delay that must elapse after the latest call before [function] runs.
  final Duration duration;

  /// The asynchronous operation invoked after the debounce delay.
  final Debounceable<S, T> function;
  _DebounceTimer? _debounceTimer;

  /// Schedules the operation and returns its result after the debounce delay.
  ///
  /// Returns `null` when a newer call or [cancel] cancels this call before the
  /// delay completes. The optional [parameter] is forwarded to [function].
  Future<S?> call([T? parameter]) async {
    if (_debounceTimer != null && !_debounceTimer!.isCompleted) {
      _debounceTimer!.cancel();
    }
    final timer = _DebounceTimer(duration);
    _debounceTimer = timer;
    await timer.future;
    if (timer.isCancelled) return null;
    return function(parameter);
  }

  /// Cancels the pending delay, if any.
  ///
  /// Any awaiting [call] resolves with `null`, and the callback is not
  /// invoked. This method is idempotent and safe when no call is pending.
  void cancel() {
    if (_debounceTimer != null && !_debounceTimer!.isCompleted) {
      _debounceTimer!.cancel();
    }
  }
}

/// Creates a debounced, cancellable unit of work.
///
/// The returned [Debounced] invokes [function] only after no newer call has
/// been made for [duration]. Set `T` to the callback parameter type, or to
/// `void` when the callback takes no argument. A superseded or explicitly
/// cancelled call completes with `null`.
Debounced<S, T> debounce<S, T>({
  required Duration duration,
  required Debounceable<S?, T> function,
}) => Debounced(duration: duration, function: function);

class _DebounceTimer {
  _DebounceTimer(this.duration) {
    _timer = Timer(duration, _onComplete);
  }

  final Duration duration;
  late final Timer _timer;
  final Completer<void> _completer = Completer<void>();
  bool _cancelled = false;

  void _onComplete() => _completer.complete();

  Future<void> get future => _completer.future;
  bool get isCompleted => _completer.isCompleted;
  bool get isCancelled => _cancelled;

  void cancel() {
    _timer.cancel();
    if (_completer.isCompleted) return;
    _cancelled = true;
    _completer.complete();
  }
}
