import 'dart:async';

import 'package:command_it/command_it.dart' as commands;
import 'package:flutter/foundation.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/result_command.dart';
import 'package:stream_transform/stream_transform.dart';

/// Latest-intent execution composed from ordinary commands and switchMap.
///
/// Actions only retrieve/compute Results. Application commits belong in a
/// synchronous [results] observer. Obsolete physical work can continue, but
/// loses publication authority before [run] returns.
class RestartableCommand<P, T> {
  /// Creates a latest-intent boundary with a constant, non-sensitive name.
  RestartableCommand(this._action, {required String debugName})
    : _debugName = debugName {
    _subscription = _intents.stream.switchMap(_executionStream).listen((event) {
      if (!_owns(event.execution)) return;
      if (!event.snapshot.isRunning) _runningSync.value = false;
      _publish(event.execution, event.snapshot);
    });
  }

  final Future<Result<T>> Function(P) _action;
  final String _debugName;
  final _intents = StreamController<_Execution<P, T>>();
  final _results = ValueNotifier<commands.CommandResult<P?, Result<T>?>>(
    commands.CommandResult<P?, Result<T>?>.blank(),
  );
  final _running = ValueNotifier<bool>(false);
  final _runningSync = ValueNotifier<bool>(false);
  final _liveChildren = <_Execution<P, T>>{};
  late final StreamSubscription<_Emission<P, T>> _subscription;
  _Execution<P, T>? _current;
  bool _disposed = false;
  int _retiredChildren = 0;

  /// Deferred snapshots for UI observation, including neutral initial state.
  ValueListenable<commands.CommandResult<P?, Result<T>?>> get results =>
      _results;

  /// Deferred running state for the latest logical execution only.
  ValueListenable<bool> get isRunning => _running;

  /// Immediate logical running state for coordination, not UI observation.
  ValueListenable<bool> get isRunningSync => _runningSync;

  /// Number of started children still awaiting private cleanup.
  @visibleForTesting
  int get debugLiveChildCount => _liveChildren.length;

  /// Exactly-once retirements, observed by lifecycle regression tests.
  @visibleForTesting
  int get debugRetiredChildCount => _retiredChildren;

  /// Accepts an intent and immediately revokes prior publication authority.
  void run(P parameter) {
    if (_disposed) return;
    _admit(_Execution<P, T>(parameter), running: true);
  }

  /// Revokes pending work and publishes neutral state without an action.
  void invalidate() {
    if (_disposed) return;
    _admit(_Execution<P, T>.neutral(), running: false);
  }

  void _admit(_Execution<P, T> execution, {required bool running}) {
    _current?.authoritative = false;
    _current = execution;
    _runningSync.value = running;
    // Coordination listeners can also reenter admission or disposal.
    if (!_owns(execution)) return;
    _publish(
      execution,
      running
          ? commands.CommandResult<P?, Result<T>?>.isLoading(
              execution.parameter,
            )
          : commands.CommandResult<P?, Result<T>?>.blank(),
    );
    _intents.add(execution);
  }

  bool _owns(_Execution<P, T> execution) =>
      !_disposed && execution.authoritative && identical(_current, execution);

  void _publish(
    _Execution<P, T> execution,
    commands.CommandResult<P?, Result<T>?> snapshot,
  ) {
    scheduleMicrotask(() {
      if (!_owns(execution)) return;
      _results.value = snapshot;
      // A result observer may synchronously admit another intent or dispose.
      if (!_owns(execution)) return;
      _running.value = snapshot.isRunning;
    });
  }

  Stream<_Emission<P, T>> _executionStream(_Execution<P, T> execution) {
    // switchMap constructs streams before cancellation settles. Only onListen
    // may create/run a child; obsolete queued envelopes perform no work.
    late final StreamController<_Emission<P, T>> inner;
    inner = StreamController<_Emission<P, T>>(
      onListen: () {
        execution.connected = true;
        if (!_owns(execution) || execution.neutral) {
          execution.closeInner();
          return;
        }
        final child = createResultCommand<P, T>(_action, debugName: _debugName);
        _liveChildren.add(execution);

        void retire() {
          if (execution.cleaned) return;
          execution.cleaned = true;
          child.results.removeListener(execution.resultListener!);
          child.isRunningSync.removeListener(execution.runningListener!);
          execution
            ..resultListener = null
            ..runningListener = null
            ..closeInner();
          child.dispose();
          _liveChildren.remove(execution);
          _retiredChildren++;
        }

        execution.resultListener = () {
          final snapshot = child.results.value;
          if (snapshot.isRunning) return;
          execution.settled = true;
          if (_owns(execution) && execution.connected) {
            inner.add(_Emission(execution, snapshot));
          }
          execution.closeInner();
          // Outside upstream notifier dispatch and after its error routing.
          scheduleMicrotask(retire);
        };
        execution.runningListener = () {
          if (child.isRunningSync.value) {
            execution.started = true;
          } else if (execution.started && child.results.value.isRunning) {
            // Assertions bypass terminal result routing but finally lowers
            // synchronous running. Allow normal deferred notifications first.
            Timer.run(() {
              if (execution.cleaned || !child.results.value.isRunning) return;
              execution.settled = true;
              retire();
            });
          }
        };
        child.results.addListener(execution.resultListener!);
        child.isRunningSync.addListener(execution.runningListener!);
        child.run(execution.parameter);
      },
      onCancel: () {
        execution.connected = false;
        // Normal terminal stream completion must retain terminal authority.
        if (!execution.settled) execution.authoritative = false;
        execution.closeInner();
        // Never return/await the noncooperative physical action Future.
        return Future<void>.value();
      },
    );
    execution.inner = inner;
    return inner.stream;
  }

  /// Stops observation immediately; live children retire after settlement.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _current?.authoritative = false;
    unawaited(_subscription.cancel());
    unawaited(_intents.close());
    // A synchronous public observer can dispose from inside notifier dispatch.
    // Authority is already revoked; teardown waits only for that stack to exit.
    scheduleMicrotask(() {
      _results.dispose();
      _running.dispose();
      _runningSync.dispose();
    });
  }
}

/// Identity and resource ownership for a single switchMap inner stream.
class _Execution<P, T> {
  _Execution(this.parameter) : neutral = false;
  _Execution.neutral() : parameter = null, neutral = true;

  final P? parameter;
  final bool neutral;
  bool authoritative = true;
  bool connected = false;
  bool started = false;
  bool settled = false;
  bool cleaned = false;
  bool _innerClosed = false;
  VoidCallback? resultListener;
  VoidCallback? runningListener;
  StreamController<_Emission<P, T>>? inner;

  void closeInner() {
    if (_innerClosed) return;
    _innerClosed = true;
    unawaited(inner?.close());
  }
}

class _Emission<P, T> {
  _Emission(this.execution, this.snapshot);
  final _Execution<P, T> execution;
  final commands.CommandResult<P?, Result<T>?> snapshot;
}
