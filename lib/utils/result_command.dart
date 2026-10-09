// Explicit upstream options fix the reviewed execution contract.
// ignore_for_file: avoid_redundant_argument_values

import 'package:command_it/command_it.dart' as command_it;
import 'package:moliseis/utils/result.dart';

/// An ordinary single-flight command preserving the application's Result.
typedef ResultCommand<P, T> = command_it.Command<P, Result<T>?>;

/// Creates an ordinary command with a neutral, never-run initial snapshot.
///
/// Expected failures remain Results; unexpected throws use global reporting.
ResultCommand<P, T> createResultCommand<P, T>(
  Future<Result<T>> Function(P) action, {
  required String debugName,
}) => command_it.Command.createAsync<P, Result<T>?>(
  action,
  initialValue: null,
  includeLastResultInCommandResults: false,
  notifyOnlyWhenValueChanges: false,
  debugName: debugName,
  errorFilterFn: (_, _) => command_it.ErrorReaction.globalHandler,
);

/// Creates the same ordinary Result command for an action without parameters.
ResultCommand<void, T> createResultCommandNoParam<T>(
  Future<Result<T>> Function() action, {
  required String debugName,
}) => command_it.Command.createAsyncNoParam<Result<T>?>(
  action,
  initialValue: null,
  includeLastResultInCommandResults: false,
  notifyOnlyWhenValueChanges: false,
  debugName: debugName,
  errorFilterFn: (_, _) => command_it.ErrorReaction.globalHandler,
);

/// Application state projections distinct from upstream's initial isSuccess.
extension ResultCommandSnapshot<P, T>
    on command_it.CommandResult<P, Result<T>?> {
  /// Whether the command has no running or terminal execution.
  bool get idle => !isRunning && data == null && error == null;

  /// Whether a real execution succeeded, including `Success<void>(null)`.
  bool get completed => !isRunning && error == null && data is Success<T>;

  /// The original expected application failure of a terminal execution.
  Exception? get domainError => !isRunning && error == null && data is Error<T>
      ? (data! as Error<T>).error
      : null;

  /// The original unexpected runtime failure, separate from domain Results.
  Object? get unexpectedError => !isRunning ? error : null;

  /// Whether the terminal execution has either kind of failure.
  bool get hasFailure => domainError != null || unexpectedError != null;
}
