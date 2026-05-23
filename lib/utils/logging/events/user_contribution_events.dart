part of 'package:moliseis/utils/logging/log_event.dart';

class UserContributionMediaAddFailed extends LogEvent {
  const UserContributionMediaAddFailed();

  @override
  Map<String, Object?> get data => const {};

  @override
  AppLogLevel get level => AppLogLevel.error;

  @override
  String get name => 'user_contribution_media_add_failed';
}

/// Fired when removing media from a user contribution fails.
class UserContributionMediaRemovalFailed extends LogEvent {
  const UserContributionMediaRemovalFailed();

  @override
  Map<String, Object?> get data => const {};

  @override
  AppLogLevel get level => AppLogLevel.error;

  @override
  String get name => 'user_contribution_media_removal_failed';
}

/// Fired when retrieving media from a user contribution fails.
class UserContributionMediaRetrievalFailed extends LogEvent {
  const UserContributionMediaRetrievalFailed();

  @override
  Map<String, Object?> get data => const {};

  @override
  AppLogLevel get level => AppLogLevel.warning;

  @override
  String get name => 'user_contribution_media_retrieval_failed';
}

/// Fired when retrieving media from a user contribution starts.
class UserContributionMediaRetrievalStarted extends LogEvent {
  const UserContributionMediaRetrievalStarted();

  @override
  Map<String, Object?> get data => const {};

  @override
  AppLogLevel get level => AppLogLevel.info;

  @override
  String get name => 'user_contribution_media_retrieval_started';
}

/// Fired when a user contribution upload fails.
class UserContributionUploadFailed extends LogEvent {
  const UserContributionUploadFailed();

  @override
  Map<String, Object?> get data => const {};

  @override
  AppLogLevel get level => AppLogLevel.error;

  @override
  String get name => 'user_contribution_upload_failed';
}

/// Fired when a user contribution upload starts.
class UserContributionUploadStarted extends LogEvent {
  const UserContributionUploadStarted();

  @override
  Map<String, Object?> get data => const {};

  @override
  AppLogLevel get level => AppLogLevel.info;

  @override
  String get name => 'user_contribution_upload_started';
}
