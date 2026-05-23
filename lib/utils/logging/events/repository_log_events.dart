part of 'package:moliseis/utils/logging/log_event.dart';

/// Fired when a repository begins a sync with the remote data source.
class RepositorySyncStarted extends LogEvent {
  /// Creates an event for a sync started on [repositoryName].
  const RepositorySyncStarted(this.repositoryName);

  /// Name of the repository that started syncing.
  final String repositoryName;

  @override
  Map<String, Object?> get data => {'repositoryName': repositoryName};

  @override
  AppLogLevel get level => AppLogLevel.info;

  @override
  String get name => 'repository_sync_started';
}

/// Fired when a repository sync fails.
class RepositorySyncFailed extends LogEvent {
  /// Creates an event for a sync failure on [repositoryName].
  const RepositorySyncFailed(this.repositoryName);

  /// Name of the repository that failed to sync.
  final String repositoryName;

  @override
  Map<String, Object?> get data => {'repositoryName': repositoryName};

  @override
  AppLogLevel get level => AppLogLevel.error;

  @override
  String get name => 'repository_sync_failed';
}

/// Fired after an entity insert fails.
class EntityInsertFailed extends LogEvent {
  /// Creates an event for a failed insert of [entityType]
  /// with an optional [remoteId].
  const EntityInsertFailed(this.entityType, [this.remoteId]);

  /// Type label identifying the entity class (e.g. `"Event"`, `"Place"`).
  final String entityType;

  /// Remote (Supabase) id of the entity, if available at failure time.
  final int? remoteId;

  @override
  Map<String, Object?> get data => {
    'entityType': entityType,
    'remoteId': remoteId,
  };

  @override
  AppLogLevel get level => AppLogLevel.error;

  @override
  String get name => 'entity_insert_failed';
}

/// Fired after an entity is successfully inserted into the local database.
class EntityInsertSuccess extends LogEvent {
  /// Creates an event for a successful insert of [entityType] with [remoteId].
  const EntityInsertSuccess(this.entityType, [this.remoteId]);

  /// Type label identifying the entity class (e.g. `"Event"`, `"Place"`).
  final String entityType;

  /// Remote (Supabase) id assigned to the inserted entity.
  final int? remoteId;

  @override
  Map<String, Object?> get data => {
    'entityType': entityType,
    'remoteId': remoteId,
  };

  @override
  AppLogLevel get level => AppLogLevel.info;

  @override
  String get name => 'entity_insert_success';
}

/// Fired after an entity removal fails.
class EntityRemoveFailed extends LogEvent {
  /// Creates an event for a failed removal of [entityType]
  /// with an optional [remoteId].
  const EntityRemoveFailed(this.entityType, [this.remoteId]);

  /// Type label identifying the entity class (e.g. `"Event"`, `"Place"`).
  final String entityType;

  /// Remote (Supabase) id of the entity that failed to be removed.
  final int? remoteId;

  @override
  Map<String, Object?> get data => {
    'entityType': entityType,
    'remoteId': remoteId,
  };

  @override
  AppLogLevel get level => AppLogLevel.error;

  @override
  String get name => 'entity_remove_failed';
}

/// Fired after an entity is successfully updated in the local database.
class EntityUpdateSuccess extends LogEvent {
  /// Creates an event for a successful update of [entityType] with [remoteId].
  const EntityUpdateSuccess(this.entityType, [this.remoteId]);

  /// Type label identifying the entity class (e.g. `"Event"`, `"Place"`).
  final String entityType;

  /// Remote (Supabase) id of the updated entity.
  final int? remoteId;

  @override
  Map<String, Object?> get data => {
    'entityType': entityType,
    'remoteId': remoteId,
  };

  @override
  AppLogLevel get level => AppLogLevel.info;

  @override
  String get name => 'entity_update_success';
}

/// Fired when a remote update for an entity fails.
class EntityUpdateFailed extends LogEvent {
  /// Creates an event for a failed update of [entityType] with [remoteId]
  /// using the given [method].
  const EntityUpdateFailed(
    this.entityType,
    this.remoteId, {
    this.method = 'unknown',
  });

  /// Type label identifying the entity class (e.g. `"Event"`, `"Place"`).
  final String entityType;

  /// Repository method that triggered the update (e.g. `"setFavouriteEvent"`).
  final String method;

  /// Remote (Supabase) id of the entity that failed to update.
  final int remoteId;

  @override
  Map<String, Object?> get data => {
    'entityType': entityType,
    'remoteId': remoteId,
    'method': method,
  };

  @override
  AppLogLevel get level => AppLogLevel.error;

  @override
  String get name => 'entity_update_failed';
}

/// Fired when loading an entity from the local database fails.
class EntityLoadFailed extends LogEvent {
  /// Creates an event for a failed load of [entityType] via [method].
  const EntityLoadFailed(this.entityType, {required this.method});

  /// Type label identifying the entity class (e.g. `"Event"`, `"Place"`).
  final String entityType;

  /// Repository method that triggered the load (e.g. `"getById"`, `"getAll"`).
  final String method;

  @override
  Map<String, Object?> get data => {'entityType': entityType, 'method': method};

  @override
  AppLogLevel get level => AppLogLevel.error;

  @override
  String get name => 'entity_load_failed';
}

/// Fired when loading an entity from the local database starts.
class EntityLoadStarted extends LogEvent {
  /// Creates an event for a load of [entityType] via [method]
  /// with optional [extra] context.
  const EntityLoadStarted(this.entityType, {required this.method, this.extra});

  /// Type label identifying the entity class (e.g. `"Event"`, `"Place"`).
  final String entityType;

  /// Optional structured context carried alongside the request
  /// (e.g. filter parameters).
  final Map<String, Object?>? extra;

  /// Repository method that triggered the load (e.g. `"getById"`, `"getAll"`).
  final String method;

  @override
  Map<String, Object?> get data => {
    'entityType': entityType,
    'method': method,
    ...?extra,
  };

  @override
  AppLogLevel get level => AppLogLevel.info;

  @override
  String get name => 'entity_load_started';
}
