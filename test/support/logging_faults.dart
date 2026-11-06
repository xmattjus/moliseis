import 'dart:async';

import 'package:moliseis/utils/logging/logging.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

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

  @override
  Future<void> addBreadcrumb(Breadcrumb breadcrumb) => completion.future;
  @override
  void clearBreadcrumbs() {}
  @override
  void setContexts(String key, dynamic value) {}
  @override
  void removeContexts(String key) {}
  @override
  void setUser(SentryUser? user) {}
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
