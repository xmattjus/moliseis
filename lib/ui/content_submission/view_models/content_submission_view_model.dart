import 'dart:async';
import 'dart:collection' show UnmodifiableListView;
import 'dart:io' show File;

import 'package:crypto/crypto.dart' show sha1;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:moliseis/domain/core/event_time.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/content_submission.dart';
import 'package:moliseis/domain/models/content_submission_draft.dart';
import 'package:moliseis/domain/models/submission_asset.dart';
import 'package:moliseis/domain/repositories/content_submission_draft_repository.dart';
import 'package:moliseis/domain/repositories/content_submission_repository.dart';
import 'package:moliseis/utils/command.dart';
import 'package:moliseis/utils/constants.dart';
import 'package:moliseis/utils/debounceable.dart';
import 'package:moliseis/utils/logging/logging.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/string_validator.dart';

/// Pairs a user selected [XFile] asset with its SHA-1 [String] digest for
/// deduplication.
typedef Asset = ({XFile file, String digest});

/// Outcome of an `addAsset` selection session.
///
/// [rejectedNames] lists file names that were skipped because they exceeded
/// [kCloudinaryMaxUploadBytes]. It is retained for logging and diagnostics;
/// UI messages must not expose those names. Under-limit files in the same
/// session are still added, while [rejectedForLimitCount] records files that
/// exceeded the total submission capacity.
final class AssetSelectionOutcome {
  /// Creates an outcome.
  const AssetSelectionOutcome({
    this.rejectedNames = const <String>[],
    this.rejectedForLimitCount = 0,
  }) : assert(
         rejectedForLimitCount >= 0,
         'rejectedForLimitCount cannot be negative',
       );

  /// Names of files skipped for being too large, in selection order.
  ///
  /// This diagnostic information must not be displayed in user-facing
  /// messages.
  final List<String> rejectedNames;

  /// Number of files skipped because the total asset limit was reached.
  final int rejectedForLimitCount;

  /// Whether any file in this session was rejected for being too large.
  bool get hasOversizedRejections => rejectedNames.isNotEmpty;

  /// Whether any file in this session was rejected for exceeding the asset
  /// limit.
  bool get hasAssetLimitRejections => rejectedForLimitCount > 0;

  /// Whether the selection had any soft rejection.
  bool get hasRejections => hasOversizedRejections || hasAssetLimitRejections;
}

enum ContentSubmissionDraftLoadState {
  loading,
  ready,
}

class ContentSubmissionViewModel extends ChangeNotifier {
  ContentSubmissionViewModel({
    required Logger logger,
    required ContentSubmissionRepository contentSubmissionRepository,
    required ContentSubmissionDraftRepository draftRepository,
    ImagePicker? imagePicker,
  }) : _logger = logger,
       _contentSubmissionRepository = contentSubmissionRepository,
       _draftRepository = draftRepository,
       _imagePicker = imagePicker ?? ImagePicker() {
    addAsset = Command0(_addAsset);
    removeAssetAt = Command1(_removeAssetAt);
    submit = Command0(_submit);
    clear = Command0(_clear);
    retrieveLostAssets = Command0(_retrieveLostAssets);
    _debounced = debounce<Result<void>, void>(
      duration: const Duration(seconds: 3),
      function: ([_]) => _draftRepository.saveDraft(state),
    );
  }

  /// Maximum number of assets that a content submission can include.
  static const int maximumAssetCount = kMaximumSubmissionAssetCount;

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _debounced.cancel();
    super.dispose();
  }

  final Logger _logger;
  final ContentSubmissionRepository _contentSubmissionRepository;
  final ContentSubmissionDraftRepository _draftRepository;
  final ImagePicker _imagePicker;
  ContentSubmissionDraft _state = ContentSubmissionDraft();
  ContentSubmissionDraftLoadState _loadState =
      ContentSubmissionDraftLoadState.loading;
  final EventTimePolicy _eventTimePolicy = EventTimePolicy();
  EventTimeIssue? _eventTimeIssue;
  final _assets = <Asset>[];

  ContentSubmissionDraft get state => _state;

  UnmodifiableListView<Asset> get assets => UnmodifiableListView(_assets);

  ContentSubmissionDraftLoadState get loadState => _loadState;

  bool get isEvent => _state.eventDates.enabled;
  EventCalendarDate? get startCalendarDate =>
      _state.eventDates.startCalendarDate;
  EventClockTime? get startClockTime {
    final start = _state.eventDates.startInstantUtc;
    return start == null ? null : _eventTimePolicy.clockTimeForUtc(start);
  }

  EventCalendarDate? get endCalendarDate {
    final end = _state.eventDates.endInstantUtc;
    return end == null ? null : _eventTimePolicy.calendarDateForUtc(end);
  }

  EventTimeIssue? get eventTimeIssue => _eventTimeIssue;

  int get _remainingAssetCapacity {
    final capacity = maximumAssetCount - _assets.length;
    return capacity > 0 ? capacity : 0;
  }

  /// Starts an `image-picker` session to let user select relevant assets.
  ///
  /// The [AssetSelectionOutcome] result exposes soft rejections for oversized
  /// files and the total submission limit. The command succeeds even when
  /// some files were skipped, so the UI can render a warning rather than an
  /// error.
  late Command0<AssetSelectionOutcome> addAsset;

  late Command1<void, int> removeAssetAt;
  late Command0<void> submit;

  /// Clears in-memory form state, then clears the persisted draft on a
  /// best-effort basis. Errors while clearing the draft are logged by the
  /// draft repository but never surfaced to the UI — in-memory state is always
  /// cleared and there is no actionable recovery step for the user.
  late Command0<void> clear;

  /// Recovers assets lost during a previous image-picker session due to
  /// Android activity recreation. Only runs on Android; is a no-op on all
  /// other platforms. Errors are not propagated to the UI because there is no
  /// recoverable alternative path for the user to take.
  late Command0<void> retrieveLostAssets;

  late final Debounced<Result<void>, void> _debounced;

  /// Loads the last [ContentSubmissionDraft] saved to local persistance
  /// if any.
  Future<void> initialize() async {
    final result = await _draftRepository.loadDraft();

    if (result is Success<ContentSubmissionDraft?> && result.value != null) {
      _state = result.value!;
    }
    // On error, fall back to an empty draft — the repository already
    // logged the failure, and blocking the form is worse than losing
    // an unsaved draft.

    _loadState = ContentSubmissionDraftLoadState.ready;

    notifyListeners();
  }

  Future<void> _calculateHashAndAdd(XFile asset) async {
    // SHA-1 is used purely for content-based deduplication; collision
    // resistance beyond accidental duplicates is not required here.
    final digest = await sha1.bind(asset.openRead()).first;
    final digestString = digest.toString();

    if (_assets.length < maximumAssetCount &&
        !_assets.any((e) => e.digest == digestString)) {
      _assets.add((file: asset, digest: digestString));
    }
  }

  Future<Result<AssetSelectionOutcome>> _addAsset() async {
    try {
      final capacityBeforePicking = _remainingAssetCapacity;
      if (capacityBeforePicking == 0) {
        return const Result.success(AssetSelectionOutcome());
      }

      final selectedAssets = await _imagePicker.pickMultipleMedia(
        limit: capacityBeforePicking,
      );

      final capacityAfterPicking = _remainingAssetCapacity;
      final rejectedForLimitCount = selectedAssets.length > capacityAfterPicking
          ? selectedAssets.length - capacityAfterPicking
          : 0;

      final rejectedNames = <String>[];
      for (final asset in selectedAssets.take(capacityAfterPicking)) {
        final length = await asset.length();
        if (length > kCloudinaryMaxUploadBytes) {
          rejectedNames.add(asset.name);
          continue;
        }
        await _calculateHashAndAdd(asset);
      }

      if (rejectedNames.isNotEmpty) {
        _logger.log(
          ContentSubmissionAssetSkippedTooLarge(rejectedNames: rejectedNames),
        );
      }

      notifyListeners();

      return Result.success(
        AssetSelectionOutcome(
          rejectedNames: rejectedNames,
          rejectedForLimitCount: rejectedForLimitCount,
        ),
      );
    } on Exception catch (exception, stackTrace) {
      _logger.log(
        const ContentSubmissionAssetAddFailed(),
        error: exception,
        stackTrace: stackTrace,
      );

      return Result.error(exception);
    }
  }

  Future<Result<void>> _removeAssetAt(int index) async {
    try {
      _assets.removeAt(index);

      notifyListeners();

      return const Result.success(null);
    } on Exception catch (exception, stackTrace) {
      _logger.log(
        const ContentSubmissionAssetRemovalFailed(),
        error: exception,
        stackTrace: stackTrace,
      );

      return Result.error(exception);
    }
  }

  void _emit() {
    unawaited(_debounced.call());
    if (!_disposed) {
      notifyListeners();
    }
  }

  void setCategory(ContentCategory? category) {
    _state = _state.copyWith(category: category);
    _emit();
  }

  void setCity(String? city) {
    _state = _state.copyWith(city: city);
    _emit();
  }

  void setName(String? name) {
    _state = _state.copyWith(name: name);
    _emit();
  }

  /// Stores matching plain-text and Delta description projections in one
  /// update.
  ///
  /// A single state emission keeps the draft debounce from persisting a
  /// transient representation where only one projection has changed.
  void setDescription({
    required String? description,
    required List<Map<String, dynamic>>? descriptionDelta,
  }) {
    _state = _state.copyWith(
      description: description,
      descriptionDelta: descriptionDelta,
    );
    _emit();
  }

  void setEventEnabled(bool enabled) {
    _state = _state.copyWith(
      eventDates: enabled
          ? _eventTimePolicy.enable(_state.eventDates)
          : _eventTimePolicy.disable(_state.eventDates),
    );
    _eventTimeIssue = null;
    _emit();
  }

  /// Updates the selected semantic start calendar day.
  void setStartCalendarDate(EventCalendarDate date) {
    final draft = _eventTimePolicy.enable(_state.eventDates);
    _applyEventEdit(
      _eventTimePolicy.changeStartCalendarDate(
        draft,
        date,
      ),
    );
  }

  /// Updates the selected semantic inclusive end calendar day.
  void setEndCalendarDate(EventCalendarDate date) {
    _applyEventEdit(
      _eventTimePolicy.changeEndCalendarDate(
        _eventTimePolicy.enable(_state.eventDates),
        date,
      ),
    );
  }

  /// Updates the selected semantic start clock time.
  void setStartClockTime(EventClockTime time) {
    final draft = _eventTimePolicy.enable(_state.eventDates);
    _applyEventEdit(
      _eventTimePolicy.changeStartClockTime(
        draft,
        time,
      ),
    );
  }

  void _applyEventEdit(EventTimeEditResult result) {
    _state = _state.copyWith(eventDates: result.draft);
    _eventTimeIssue = result.issue;
    _emit();
  }

  /// Publishes a persistence-blocking event-time issue for the controlled UI.
  ///
  /// Returns whether the current temporal draft is eligible for submission.
  /// The issue is transient and is cleared by the next valid temporal edit.
  bool validateEventTimeForSubmission() {
    final issue =
        _eventTimeIssue ??
        _eventTimePolicy.validateForPersistence(_state.eventDates);
    if (issue == null) return true;

    if (_eventTimeIssue != issue) {
      _eventTimeIssue = issue;
      if (!_disposed) {
        notifyListeners();
      }
    }
    return false;
  }

  void setUserEmail(String? userEmail) {
    _state = _state.copyWith(userEmail: userEmail);
    _emit();
  }

  void setUserName(String? userName) {
    _state = _state.copyWith(userName: userName);
    _emit();
  }

  void setAcceptedTerms(bool? value) {
    _state = _state.copyWith(acceptedTerms: value);
    _emit();
  }

  /// Validates required fields, then uploads each selected asset to
  /// Cloudinary sequentially before submitting the [ContentSubmission].
  ///
  /// Assets are uploaded one at a time and the loop aborts on the first
  /// failure: any asset uploaded before the failure is left in Cloudinary
  /// with no rollback or cleanup performed here. This does NOT, however,
  /// leak on a subsequent retry: `CloudinaryPublicIdGenerator` derives each
  /// asset's public id from the file's SHA-256 digest, and
  /// `CloudinaryUploadClientImpl.uploadImageTask` obtains server-side
  /// duplicate preparation for that id before uploading. Therefore media
  /// already sent to the backend in a previous attempt is detected by its
  /// SHA-256 content hash and reused rather than re-uploaded, so only assets
  /// that were not yet uploaded in the last try are actually transferred.
  Future<Result<void>> _submit() async {
    if (!validateEventTimeForSubmission()) {
      return Result.error(Exception('Cannot submit: invalid event time.'));
    }
    final city = _state.city;
    final name = _state.name;
    final userEmail = _state.userEmail;
    final userName = _state.userName;
    final missing = <String>[
      if (city == null) 'city',
      if (name == null) 'name',
      if (userEmail == null) 'userEmail',
      if (userName == null) 'userName',
    ];

    if (missing.isNotEmpty) {
      return Result.error(
        Exception(
          'Cannot submit: required field${missing.length == 1 ? '' : 's'} '
          '${missing.join(', ')} '
          '${missing.length == 1 ? 'is' : 'are'} missing.',
        ),
      );
    }

    // Dart 3 pattern: a record of null-check (`?`) subpatterns matches only
    // when every field is non-null and promotes each binding to its
    // non-nullable type — no `!` needed below. The guard is guaranteed to
    // succeed because the `missing` check above returned early when any of
    // these was null.
    if ((city, name, userEmail, userName) case (
      final c?,
      final n?,
      final ue?,
      final un?,
    )) {
      final submissionAssets = <SubmissionAsset>[];

      // TODO(xmattjus): On partial failure within this loop, assets
      //  uploaded before the failing one remain in Cloudinary with no
      //  rollback or cancellation of completed uploads. The SHA-256
      //  duplicate-skip path in `CloudinaryUploadClientImpl.uploadImageTask`
      //  makes retries idempotent at the asset level (already-uploaded media
      //  is not re-transferred), but it does not delete the orphaned assets
      //  themselves. Fix this by either:
      //  - tracking completed uploads and cancelling/deleting them on
      //  failure,
      //  - or uploading all assets in parallel with `Future.wait` and
      //  cancelling remaining tasks on the first failure (each
      //  `ImageUploadTask` already exposes a `cancel()` token).
      for (final entry in _assets) {
        final result = await _contentSubmissionRepository
            .uploadImageTask(File(entry.file.path))
            .result;

        switch (result) {
          case Success<SubmissionAsset>():
            submissionAssets.add(result.value);
          case Error<SubmissionAsset>():
            return Result.error(result.error);
        }
      }

      final contentSubmission = ContentSubmission(
        category: _state.category,
        city: c,
        name: n,
        description: _state.description,
        descriptionDelta: _state.descriptionDelta,
        startDate: _state.eventDates.startInstantUtc,
        endDate: _state.eventDates.endInstantUtc,
        userEmail: ue,
        userName: un,
      );

      final result = await _contentSubmissionRepository.upload(
        contentSubmission,
        submissionAssets,
      );

      return result;
    }

    // Unreachable: the `missing` guard above guarantees every required field
    // is non-null, so the if-case branch above always returns.
    return Result.error(
      Exception('Cannot submit: unknown validation failure.'),
    );
  }

  Future<Result<void>> _clear() async {
    // Process 1 — in-memory state clear. Always runs; its outcome is the only
    // one reflected on the UI.
    _logger.log(const ContentSubmissionStateClearStarted());
    _assets.clear();

    _state = ContentSubmissionDraft();
    _eventTimeIssue = null;
    notifyListeners();
    _logger.log(const ContentSubmissionStateClearSuccess());

    // Process 2 — persisted draft clear. Best-effort: the draft repository
    // owns the Started/Success/Failed logging for this step, so its [Result]
    // is intentionally discarded here. In-memory state is already cleared
    // and the user has no actionable recovery path, so no error is ever
    // surfaced to the UI.
    await _draftRepository.clearDraft();

    return const Result.success(null);
  }

  void _handleRetrieveLostMediaErrors(Object error, StackTrace? stackTrace) {
    _logger.log(
      const ContentSubmissionAssetRetrievalFailed(),
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Implements the lost-data recovery pattern recommended by image_picker.
  /// See: https://github.com/flutter/packages/blob/e37fa8ff337214ed3d5dc83f9ba229c6b9ccc1c0/packages/image_picker/image_picker/example/lib/main.dart#L308
  Future<Result<void>> _retrieveLostAssets() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return const Result.success(null);
    }

    final response = await _imagePicker.retrieveLostData();

    if (response.isEmpty) {
      return const Result.success(null);
    }

    if (response.file != null) {
      _logger.log(const ContentSubmissionAssetRetrievalStarted());

      try {
        // When files is non-null it contains all recovered files; file points
        // to the first item. Fall back to file for single-result responses.
        final files = response.files ?? [response.file!];
        final rejectedNames = <String>[];
        for (final file in files.take(_remainingAssetCapacity)) {
          final length = await file.length();
          if (length > kCloudinaryMaxUploadBytes) {
            // Lost-data recovery is best-effort and silent: oversized
            // recovered files are dropped without surfacing to the UI.
            rejectedNames.add(file.name);
            continue;
          }
          await _calculateHashAndAdd(file);
        }

        if (rejectedNames.isNotEmpty) {
          _logger.log(
            ContentSubmissionAssetSkippedTooLarge(rejectedNames: rejectedNames),
          );
        }

        notifyListeners();
      } on Object catch (error, stackTrace) {
        _handleRetrieveLostMediaErrors(error, stackTrace);
      }
    } else if (response.exception != null) {
      final exception = response.exception!;
      _handleRetrieveLostMediaErrors(
        exception,
        StackTrace.fromString(exception.stacktrace ?? ''),
      );
    }

    // Lost media recovery is best-effort; surfacing errors to the UI would
    // block the flow with no actionable recovery step for the user.
    return const Result.success(null);
  }

  bool validateEmail(String? text) => StringValidator.isValidEmail(text);
}
