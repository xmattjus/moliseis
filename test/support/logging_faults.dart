import 'dart:async';

import 'package:moliseis/utils/logging/logging.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Controls processing completion without sleeps or transport ordering rules.
class CallbackEventProcessor implements EventProcessor {
  CallbackEventProcessor(this.callback);

  final FutureOr<SentryEvent?> Function(SentryEvent event, Hint hint) callback;

  @override
  FutureOr<SentryEvent?> apply(SentryEvent event, Hint hint) =>
      callback(event, hint);
}

/// A real event with deliberately broken optional diagnostic accessors.
class FaultyRepositoryEvent extends EntityLoadFailed {
  const FaultyRepositoryEvent({
    this.failData = false,
    this.failLevel = false,
    this.failName = false,
  }) : super('event', method: 'getById');

  final bool failData;
  final bool failLevel;
  final bool failName;

  @override
  Map<String, Object?> get data =>
      failData ? throw StateError('metadata') : super.data;
  @override
  AppLogLevel get level => failLevel ? throw StateError('level') : super.level;
  @override
  String get name => failName ? throw StateError('name') : super.name;
}

/// Injects a delayed native breadcrumb observer rejection.
class FailingBreadcrumbObserver implements ScopeObserver {
  final completion = Completer<void>();
  int clearCalls = 0;
  final List<SentryUser?> users = [];

  @override
  Future<void> addBreadcrumb(Breadcrumb breadcrumb) => completion.future;
  @override
  void clearBreadcrumbs() => clearCalls++;
  @override
  void setContexts(String key, dynamic value) {}
  @override
  void removeContexts(String key) {}
  @override
  void setUser(SentryUser? user) => users.add(user);
  @override
  Future<void> setExtra(String key, dynamic value) async {}
  @override
  Future<void> removeExtra(String key) async {}
  @override
  Future<void> setTag(String key, String value) async {}
  @override
  Future<void> removeTag(String key) async {}
}

/// An exception whose optional diagnostic rendering fails.
class DiagnosticRenderingFailure implements Exception {
  @override
  String toString() => throw StateError('diagnostic rendering');
}

/// Exercises filtering failure after the SDK has prepared an exception.
class FaultySentryStackFrame extends SentryStackFrame {
  @override
  String? get absPath => throw StateError('broken optional frame');
}

/// Supplies an actual exception cause to the SDK's recursive extractor.
class ChainedDiagnosticException implements Exception {
  ChainedDiagnosticException(this.cause, this.stack);

  final Object cause;
  final StackTrace stack;
}

/// Exercises installed extraction and exception-group processing together.
class DiagnosticCauseExtractor
    extends ExceptionCauseExtractor<ChainedDiagnosticException> {
  @override
  ExceptionCause cause(ChainedDiagnosticException error) =>
      ExceptionCause(error.cause, error.stack);
}
