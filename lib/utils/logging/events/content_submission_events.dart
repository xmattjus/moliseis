part of 'package:moliseis/utils/logging/log_event.dart';

/// Fired when one or more selected assets are skipped because they exceed
/// `kCloudinaryMaxUploadBytes`.
///
/// This is a soft warning, not a hard failure: under-limit files in the
/// same selection session are still added.
class ContentSubmissionAssetSkippedTooLarge extends LogEvent {
  const ContentSubmissionAssetSkippedTooLarge({required this.rejectedNames});

  /// Names of the files that were skipped for being too large.
  final List<String> rejectedNames;

  @override
  Map<String, Object?> get data => {'rejectedNames': rejectedNames};

  @override
  AppLogLevel get level => AppLogLevel.warning;

  @override
  String get name => 'content_submission_asset_skipped_too_large';
}

/// Fired when adding an asset to a content submission fails.
class ContentSubmissionAssetAddFailed extends LogEvent {
  const ContentSubmissionAssetAddFailed();

  @override
  Map<String, Object?> get data => const {};

  @override
  AppLogLevel get level => AppLogLevel.error;

  @override
  String get name => 'content_submission_asset_add_failed';
}

/// Fired when removing an asset from a content submission fails.
class ContentSubmissionAssetRemovalFailed extends LogEvent {
  const ContentSubmissionAssetRemovalFailed();

  @override
  Map<String, Object?> get data => const {};

  @override
  AppLogLevel get level => AppLogLevel.error;

  @override
  String get name => 'content_submission_asset_removal_failed';
}

/// Fired when retrieving an asset from the previously killed activity fails.
class ContentSubmissionAssetRetrievalFailed extends LogEvent {
  const ContentSubmissionAssetRetrievalFailed();

  @override
  Map<String, Object?> get data => const {};

  @override
  AppLogLevel get level => AppLogLevel.warning;

  @override
  String get name => 'content_submission_asset_retrieval_failed';
}

/// Fired when retrieving an asset from the previously killed activity starts.
class ContentSubmissionAssetRetrievalStarted extends LogEvent {
  const ContentSubmissionAssetRetrievalStarted();

  @override
  Map<String, Object?> get data => const {};

  @override
  AppLogLevel get level => AppLogLevel.info;

  @override
  String get name => 'content_submission_asset_retrieval_started';
}

/// Evidence available after a failed association request.
enum AssociationOutcome { rejected, unconfirmed }

/// Fired when the final whole-submission request fails.
class ContentSubmissionUploadFailed extends LogEvent {
  const ContentSubmissionUploadFailed({
    this.outcome = AssociationOutcome.unconfirmed,
    this.statusCode,
  });

  final AssociationOutcome outcome;
  final int? statusCode;

  @override
  Map<String, Object?> get data => {
    'outcome': outcome.name,
    if (statusCode case final int status when status >= 100 && status <= 599)
      'status_code': status,
  };

  @override
  AppLogLevel get level => AppLogLevel.error;

  @override
  String get name => 'content_submission_upload_failed';
}

/// Fired when a content submission upload starts.
class ContentSubmissionUploadStarted extends LogEvent {
  const ContentSubmissionUploadStarted();

  @override
  Map<String, Object?> get data => const {};

  @override
  AppLogLevel get level => AppLogLevel.info;

  @override
  String get name => 'content_submission_upload_started';
}

/// Fired after a valid whole-submission acknowledgement.
/// Replay acknowledgements use their existing separate event.
class ContentSubmissionConfirmed extends LogEvent {
  const ContentSubmissionConfirmed();

  @override
  Map<String, Object?> get data => const {};

  @override
  AppLogLevel get level => AppLogLevel.info;

  @override
  String get name => 'content_submission_request_confirmed';
}

/// Fired when the backend acknowledges an already submitted session.
class ContentSubmissionReplayAcknowledged extends LogEvent {
  const ContentSubmissionReplayAcknowledged();

  @override
  Map<String, Object?> get data => const {};

  @override
  AppLogLevel get level => AppLogLevel.info;

  @override
  String get name => 'content_submission_replay_acknowledged';
}

/// Fired when a content submission draft loading starts.
class ContentSubmissionDraftLoadStarted extends LogEvent {
  const ContentSubmissionDraftLoadStarted();

  @override
  Map<String, Object?> get data => const {};

  @override
  AppLogLevel get level => AppLogLevel.info;

  @override
  String get name => 'content_submission_draft_load_started';
}

/// Fired when a content submission draft loading fails.
class ContentSubmissionDraftLoadFailed extends LogEvent {
  const ContentSubmissionDraftLoadFailed();

  @override
  Map<String, Object?> get data => const {};

  @override
  AppLogLevel get level => AppLogLevel.error;

  @override
  String get name => 'content_submission_draft_load_failed';
}

/// Fired when a content submission draft loading finishes successfully.
class ContentSubmissionDraftLoadSuccess extends LogEvent {
  const ContentSubmissionDraftLoadSuccess();

  @override
  Map<String, Object?> get data => const {};

  @override
  AppLogLevel get level => AppLogLevel.info;

  @override
  String get name => 'content_submission_draft_load_success';
}

/// Fired when a content submission draft clear starts.
class ContentSubmissionDraftClearStarted extends LogEvent {
  const ContentSubmissionDraftClearStarted();

  @override
  Map<String, Object?> get data => const {};

  @override
  AppLogLevel get level => AppLogLevel.info;

  @override
  String get name => 'content_submission_draft_clear_started';
}

/// Fired when a content submission draft clear fails.
class ContentSubmissionDraftClearFailed extends LogEvent {
  const ContentSubmissionDraftClearFailed();

  @override
  Map<String, Object?> get data => const {};

  @override
  AppLogLevel get level => AppLogLevel.error;

  @override
  String get name => 'content_submission_draft_clear_failed';
}

/// Fired when a content submission draft clear finishes successfully.
class ContentSubmissionDraftClearSuccess extends LogEvent {
  const ContentSubmissionDraftClearSuccess();

  @override
  Map<String, Object?> get data => const {};

  @override
  AppLogLevel get level => AppLogLevel.info;

  @override
  String get name => 'content_submission_draft_clear_success';
}

/// Fired when a content submission draft save starts.
class ContentSubmissionDraftSaveStarted extends LogEvent {
  const ContentSubmissionDraftSaveStarted({required this.draft});

  final String draft;

  @override
  Map<String, Object?> get data => {'draft': draft};

  @override
  AppLogLevel get level => AppLogLevel.info;

  @override
  String get name => 'content_submission_draft_save_started';
}

/// Fired when a content submission draft save fails.
class ContentSubmissionDraftSaveFailed extends LogEvent {
  const ContentSubmissionDraftSaveFailed();

  @override
  Map<String, Object?> get data => const {};

  @override
  AppLogLevel get level => AppLogLevel.error;

  @override
  String get name => 'content_submission_draft_save_failed';
}

/// Fired when a content submission draft save finishes successfully.
class ContentSubmissionDraftSaveSuccess extends LogEvent {
  const ContentSubmissionDraftSaveSuccess({required this.draft});

  final String draft;

  @override
  Map<String, Object?> get data => {'draft': draft};

  @override
  AppLogLevel get level => AppLogLevel.info;

  @override
  String get name => 'content_submission_draft_save_success';
}
