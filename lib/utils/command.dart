// Copyright 2024 The Flutter team. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';

import 'package:moliseis/utils/result.dart';

typedef CommandAction0<T> = Future<Result<T>> Function();
typedef CommandAction1<T, A> = Future<Result<T>> Function(A);

/// Facilitates interaction with a ViewModel.
///
/// Encapsulates an action,
/// exposes its running and error states,
/// and ensures that it can't be launched again until it finishes.
///
/// Use [Command0] for actions without arguments.
/// Use [Command1] for actions with one argument.
///
/// Actions must return a [Result]. Unexpected exceptions thrown by `action`
/// — whether before its first `await` or during an awaited step — are
/// captured and surfaced as [Error] results, so the UI is never left in a
/// silent [idle] state with [running] false.
abstract class Command<T> extends ChangeNotifier {
  Command();

  bool _running = false;

  /// True when the action is running.
  bool get running => _running;

  /// True when the action has never been executed yet.
  ///
  /// Distinct from [completed] and [error], which both return false when no
  /// result has been produced. Use this to render an "about to start" /
  /// neutral state instead of a false success state.
  bool get idle => !_running && _result == null;

  Result<T>? _result;

  /// true if action completed with error
  bool get error => _result is Error;

  /// true if action completed successfully
  bool get completed => _result is Success;

  /// Get last action result
  Result<T>? get result => _result;

  /// Internal execute implementation.
  ///
  /// Any [Object] thrown by [action] is captured into [_result] as an
  /// [Error] so the UI always observes a terminal state instead of being
  /// stuck in [idle] with [running] false. A synchronous throw before the
  /// action's first `await` (e.g. a `!` on a null field evaluated while
  /// building the request) would otherwise leave [_result] == null and the
  /// user trapped on a no-button progress screen.
  Future<void> _execute(CommandAction0<T> action) async {
    // Ensure the action can't launch multiple times.
    // e.g. avoid multiple taps on button
    if (_running) return;

    // Notify listeners.
    // e.g. button shows loading state
    _running = true;
    _result = null;
    notifyListeners();

    try {
      _result = await action();
    } on Object catch (error, stackTrace) {
      // [Result.error] only accepts [Exception]. Actions are expected to
      // return a [Result] themselves, so any throw reaching here is an
      // unexpected error (e.g. a `TypeError` from `!` on a null field). Wrap
      // non-Exceptions so the UI observes a terminal [error] state instead of
      // being trapped in [idle] with [running] false. Keep reporting the
      // original object so crash reporting preserves the real type.
      final exception = error is Exception ? error : Exception(error);
      _result = Result.error(exception);
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'moliseis.utils.command',
        ),
      );
    } finally {
      _running = false;
      notifyListeners();
    }
  }
}

/// [Command] without arguments.
/// Takes a [CommandAction0] as action.
class Command0<T> extends Command<T> {
  Command0(this._action);

  final CommandAction0<T> _action;

  /// Executes the action.
  Future<void> execute() async {
    await _execute(_action);
  }
}

/// [Command] with one argument.
/// Takes a [CommandAction1] as action.
class Command1<T, A> extends Command<T> {
  Command1(this._action);

  final CommandAction1<T, A> _action;

  /// Executes the action with the argument.
  Future<void> execute(A argument) async {
    await _execute(() => _action(argument));
  }
}
