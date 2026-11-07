// Canonical diagnostic phase labels intentionally use snake_case.
// ignore_for_file: constant_identifier_names

part of 'package:moliseis/utils/logging/log_event.dart';

/// Persisted cursor mode captured before synchronization.
enum SyncMode { bootstrap, delta }

/// Fixed orchestration phases, independent of completion order.
enum SyncPhase {
  cursor,
  prepare_city,
  prepare_place,
  prepare_event,
  prepare_media,
  commit,
  settings,
}

/// Safe reporting ownership, without repository or contributor text.
enum SyncFailureOwner { cursor, prepare, commit, settings, command }

/// Remote-safe classification; original causes remain local.
enum SyncFailureCategory { connectivity, contract, storage, unexpected }

/// An admitted synchronization.
final class SyncStarted extends LogEvent {
  const SyncStarted(this.mode);
  final SyncMode mode;
  @override
  String get name => 'content_sync_started';
  @override
  AppLogLevel get level => AppLogLevel.info;
  @override
  Map<String, Object?> get data => {'mode': mode.name};
}

/// Exactly one terminal outcome, published after the last completed phase.
final class SyncFinished extends LogEvent {
  const SyncFinished({
    required this.mode,
    required this.phase,
    required this.succeeded,
    required this.elapsedMs,
    this.cityFetched,
    this.placeFetched,
    this.eventFetched,
    this.mediaFetched,
    this.category,
  });
  final SyncMode mode;
  final SyncPhase phase;
  final bool succeeded;
  final int elapsedMs;
  final int? cityFetched;
  final int? placeFetched;
  final int? eventFetched;
  final int? mediaFetched;
  final SyncFailureCategory? category;
  @override
  String get name =>
      succeeded ? 'content_sync_succeeded' : 'content_sync_failed';
  @override
  AppLogLevel get level => succeeded ? AppLogLevel.info : AppLogLevel.error;
  @override
  Map<String, Object?> get data => {
    'mode': mode.name,
    'phase': phase.name,
    'elapsed_ms': elapsedMs.clamp(0, 9007199254740991),
    if (cityFetched != null)
      'city_fetched': cityFetched!.clamp(0, 9007199254740991),
    if (placeFetched != null)
      'place_fetched': placeFetched!.clamp(0, 9007199254740991),
    if (eventFetched != null)
      'event_fetched': eventFetched!.clamp(0, 9007199254740991),
    if (mediaFetched != null)
      'media_fetched': mediaFetched!.clamp(0, 9007199254740991),
    if (category != null) 'category': category!.name,
  };
}

/// Content is durable; cursor persistence may still fail.
final class SyncContentCommitSucceeded extends LogEvent {
  const SyncContentCommitSucceeded();
  @override
  String get name => 'content_commit_succeeded';
  @override
  AppLogLevel get level => AppLogLevel.info;
  @override
  Map<String, Object?> get data => const {};
}

/// A cause owned by one boundary, with remote forwarding explicitly controlled.
final class SyncFailure extends LogEvent {
  const SyncFailure({
    required this.owner,
    required this.category,
    this.report = true,
    this.repository,
  });
  final SyncFailureOwner owner;
  final SyncFailureCategory category;
  final bool report;

  /// Technical repository origin; remote forwarding accepts known names only.
  final String? repository;
  @override
  String get name => 'content_sync_cause_failed';
  @override
  AppLogLevel get level => AppLogLevel.error;
  @override
  Map<String, Object?> get data => {
    'owner': owner.name,
    'category': category.name,
    if (repository != null) 'repository': repository,
  };
}
