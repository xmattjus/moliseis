import 'dart:async' show Completer, unawaited;
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
import 'package:moliseis/domain/models/content_submission_staged_asset.dart';
import 'package:moliseis/domain/models/submission_asset.dart';
import 'package:moliseis/domain/repositories/content_submission_draft_repository.dart';
import 'package:moliseis/domain/repositories/content_submission_repository.dart';
import 'package:moliseis/domain/repositories/content_submission_staged_asset_repository.dart';
import 'package:moliseis/utils/command.dart';
import 'package:moliseis/utils/constants.dart';
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

/// Whether initialization authoritatively determined persisted draft state.
///
/// A failed read is deliberately distinct from a successfully absent draft: it
/// must not authorize orphan cleanup or a fresh draft write.
enum _PersistedDraftState {
  unknown,
  absent,
  restored,
}

enum _AssetCandidateDisposition {
  added,
  duplicate,
  oversized,
  overCapacity,
  discarded,
}

class ContentSubmissionViewModel extends ChangeNotifier {
  ContentSubmissionViewModel({
    required Logger logger,
    required ContentSubmissionRepository contentSubmissionRepository,
    required ContentSubmissionDraftRepository draftRepository,
    required ContentSubmissionStagedAssetRepository stagedAssetRepository,
    ImagePicker? imagePicker,
  }) : _logger = logger,
       _contentSubmissionRepository = contentSubmissionRepository,
       _draftRepository = draftRepository,
       _stagedAssetRepository = stagedAssetRepository,
       _imagePicker = imagePicker ?? ImagePicker() {
    _checkpointedDraft = _state;
    addAsset = Command0(_addAsset);
    removeAssetAt = Command1(_removeAssetAt);
    submit = Command0(_submit);
    clear = Command0(_clear);
    retrieveLostAssets = Command0(_retrieveLostAssets);
  }

  /// Maximum number of assets that a content submission can include.
  static const int maximumAssetCount = kMaximumSubmissionAssetCount;

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  final Logger _logger;
  final ContentSubmissionRepository _contentSubmissionRepository;
  final ContentSubmissionDraftRepository _draftRepository;
  final ContentSubmissionStagedAssetRepository _stagedAssetRepository;
  final ImagePicker _imagePicker;
  ContentSubmissionDraft _state = ContentSubmissionDraft();
  late ContentSubmissionDraft _checkpointedDraft;
  bool _hasDurableCheckpoint = false;
  _PersistedDraftState _persistedDraftState = _PersistedDraftState.unknown;
  Exception? _draftLoadError;
  Future<void>? _initializationFuture;
  final Completer<void> _initializationBarrier = Completer<void>();
  Future<void> _lifecycleTail = Future<void>.value();
  bool _stagedStateAvailable = false;
  Exception? _stagedReconciliationError;
  String? _recoveryEligibleClientSubmissionId;
  ContentSubmissionDraftLoadState _loadState =
      ContentSubmissionDraftLoadState.loading;
  final EventTimePolicy _eventTimePolicy = EventTimePolicy();
  EventTimeIssue? _eventTimeIssue;
  final _assets = <Asset>[];

  ContentSubmissionDraft get state => _state;

  bool get hasUnsavedChanges => _state != _checkpointedDraft;

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

  /// Clears persisted draft state before resetting the in-memory session.
  late Command0<void> clear;

  /// Recovers assets lost during a previous image-picker session due to
  /// Android activity recreation. Only runs on Android; is a no-op on all
  /// other platforms. Errors are not propagated to the UI because there is no
  /// recoverable alternative path for the user to take.
  late Command0<void> retrieveLostAssets;

  /// Loads the last [ContentSubmissionDraft] saved to local persistance
  /// if any.
  Future<void> initialize() => _initializationFuture ??= _initialize();

  Future<void> _initialize() async {
    var draftReadCompleted = false;
    try {
      final result = await _draftRepository.loadDraft();
      draftReadCompleted = true;
      switch (result) {
        case Success<ContentSubmissionDraft?>(value: final draft):
          _draftLoadError = null;
          if (draft == null) {
            _persistedDraftState = _PersistedDraftState.absent;
            await _reconcileStagedAssets(null);
          } else {
            _persistedDraftState = _PersistedDraftState.restored;
            _state = draft;
            _checkpointedDraft = _state;
            _hasDurableCheckpoint = true;
            final reconciled = await _reconcileStagedAssets(
              _state.clientSubmissionId,
            );
            if (reconciled is Success<void>) {
              _recoveryEligibleClientSubmissionId = _state.clientSubmissionId;
            }
          }
        case Error<ContentSubmissionDraft?>(:final error):
          // A failed read leaves existing persisted ownership unknown. Do not
          // reconcile with null, because that contract removes all orphans.
          _persistedDraftState = _PersistedDraftState.unknown;
          _draftLoadError = error;
          _stagedStateAvailable = false;
          _stagedReconciliationError = error;
          _assets.clear();
      }
    } on Object catch (error) {
      final exception = error is Exception
          ? error
          : Exception(error.toString());
      if (!draftReadCompleted) {
        _persistedDraftState = _PersistedDraftState.unknown;
        _draftLoadError = exception;
      }
      _stagedStateAvailable = false;
      _stagedReconciliationError = exception;
      _assets.clear();
    } finally {
      _loadState = ContentSubmissionDraftLoadState.ready;
      if (!_initializationBarrier.isCompleted) {
        _initializationBarrier.complete();
      }
      if (!_disposed) {
        notifyListeners();
      }
    }
  }

  /// Reconciles durable staged descriptors and publishes only a complete,
  /// validated runtime list. A failure leaves the current list unavailable so
  /// a subsequent pre-picker retry cannot mutate uncertain state.
  Future<Result<void>> _reconcileStagedAssets(
    String? activeClientSubmissionId,
  ) async {
    final staged = await _stagedAssetRepository.reconcileAndLoad(
      activeClientSubmissionId,
    );
    if (staged case Error<List<ContentSubmissionStagedAsset>>(:final error)) {
      _stagedStateAvailable = false;
      _stagedReconciliationError = error;
      _assets.clear();
      return Result.error(error);
    }

    final descriptors =
        (staged as Success<List<ContentSubmissionStagedAsset>>).value;
    if (descriptors.length > maximumAssetCount) {
      final error = Exception('Restored staged assets exceed the asset limit.');
      _stagedStateAvailable = false;
      _stagedReconciliationError = error;
      _assets.clear();
      return Result.error(error);
    }

    final restored = <Asset>[];
    for (final descriptor in descriptors) {
      final resolved = await _stagedAssetRepository.resolveAbsolutePath(
        descriptor,
      );
      if (resolved case Error<File>(:final error)) {
        _stagedStateAvailable = false;
        _stagedReconciliationError = error;
        _assets.clear();
        return Result.error(error);
      }
      restored.add((
        file: XFile((resolved as Success<File>).value.path),
        digest: descriptor.digest,
      ));
    }

    _assets
      ..clear()
      ..addAll(restored);
    _stagedStateAvailable = true;
    _stagedReconciliationError = null;
    return const Result.success(null);
  }

  /// Validates and commits one picker/recovery candidate into staged storage.
  ///
  /// Both picker and Android-recovery flows use this routine so their capacity,
  /// size, SHA-1 deduplication, and runtime-path ownership rules cannot drift.
  Future<Result<_AssetCandidateDisposition>> _processAssetCandidate(
    XFile asset,
  ) async {
    if (_disposed) {
      return const Result.success(_AssetCandidateDisposition.discarded);
    }
    if (_remainingAssetCapacity == 0) {
      return const Result.success(_AssetCandidateDisposition.overCapacity);
    }
    if (await asset.length() > kCloudinaryMaxUploadBytes) {
      return const Result.success(_AssetCandidateDisposition.oversized);
    }
    if (_disposed) {
      return const Result.success(_AssetCandidateDisposition.discarded);
    }

    // SHA-1 is used purely for content-based deduplication; collision
    // resistance beyond accidental duplicates is not required here.
    final digest = await sha1.bind(asset.openRead()).first;
    final digestString = digest.toString();

    if (_disposed) {
      return const Result.success(_AssetCandidateDisposition.discarded);
    }

    if (_assets.any((e) => e.digest == digestString)) {
      return const Result.success(_AssetCandidateDisposition.duplicate);
    }
    final staged = await _stagedAssetRepository.acquire(
      clientSubmissionId: _state.clientSubmissionId,
      digest: digestString,
      source: File(asset.path),
    );
    if (staged case Error<ContentSubmissionStagedAsset>(:final error)) {
      return Result.error(error);
    }
    if (_disposed) {
      return const Result.success(_AssetCandidateDisposition.discarded);
    }
    final descriptor = (staged as Success<ContentSubmissionStagedAsset>).value;
    // Acquisition has durably committed the descriptor and final file. Until
    // its runtime path is resolved and published, submission must not observe
    // the previous (now incomplete) runtime attachment list.
    _stagedStateAvailable = false;
    final resolved = await _stagedAssetRepository.resolveAbsolutePath(
      descriptor,
    );
    if (_disposed) {
      return const Result.success(_AssetCandidateDisposition.discarded);
    }
    if (resolved case Error<File>(:final error)) {
      _stagedReconciliationError = error;
      _assets.clear();
      return Result.error(error);
    }
    _assets.add((
      file: XFile((resolved as Success<File>).value.path),
      digest: digestString,
    ));
    _stagedStateAvailable = true;
    _stagedReconciliationError = null;
    return const Result.success(_AssetCandidateDisposition.added);
  }

  Future<Result<AssetSelectionOutcome>> _addAsset() async {
    try {
      await initialize();
      if (_disposed) return const Result.success(AssetSelectionOutcome());
      final prePicker = await _serialize<String?>(() async {
        if (_disposed) return const Result.success(null);
        if (_remainingAssetCapacity == 0) return const Result.success(null);
        if (_persistedDraftState == _PersistedDraftState.unknown) {
          return Result.error(
            _draftLoadError ??
                Exception(
                  'Cannot add assets while persisted draft state is unknown.',
                ),
          );
        }
        if (!_stagedStateAvailable) {
          final reconciled = await _reconcileStagedAssets(
            _hasDurableCheckpoint ? _state.clientSubmissionId : null,
          );
          if (reconciled case Error<void>(:final error)) {
            return Result.error(_stagedReconciliationError ?? error);
          }
        }
        final checkpoint = await _checkpointDraftInsideBoundary();
        if (checkpoint case Error<void>(:final error)) {
          return Result.error(error);
        }
        return Result.success(_state.clientSubmissionId);
      });
      if (prePicker case Error<String?>(:final error)) {
        return Result.error(error);
      }
      final capturedClientSubmissionId = (prePicker as Success<String?>).value;
      if (capturedClientSubmissionId == null) {
        return const Result.success(AssetSelectionOutcome());
      }

      final capacityBeforePicking = _remainingAssetCapacity;

      final selectedAssets = await _imagePicker.pickMultipleMedia(
        limit: capacityBeforePicking,
      );

      final committed = await _serialize<AssetSelectionOutcome>(() async {
        if (_disposed ||
            _state.clientSubmissionId != capturedClientSubmissionId) {
          return const Result.success(AssetSelectionOutcome());
        }
        final capacityAfterPicking = _remainingAssetCapacity;
        final rejectedForLimitCount =
            selectedAssets.length > capacityAfterPicking
            ? selectedAssets.length - capacityAfterPicking
            : 0;
        final rejectedNames = <String>[];
        for (final asset in selectedAssets.take(capacityAfterPicking)) {
          final result = await _processAssetCandidate(asset);
          switch (result) {
            case Error<_AssetCandidateDisposition>(:final error):
              return Result.error(error);
            case Success<_AssetCandidateDisposition>(
              value: _AssetCandidateDisposition.oversized,
            ):
              rejectedNames.add(asset.name);
            case Success<_AssetCandidateDisposition>():
              // Duplicates retain the existing soft-skip behavior. Capacity is
              // represented by the picker-result overflow count above.
              break;
          }
        }
        return Result.success(
          AssetSelectionOutcome(
            rejectedNames: rejectedNames,
            rejectedForLimitCount: rejectedForLimitCount,
          ),
        );
      });
      if (committed case Error<AssetSelectionOutcome>(:final error)) {
        if (!_disposed) {
          notifyListeners();
        }
        return Result.error(error);
      }
      final outcome = (committed as Success<AssetSelectionOutcome>).value;

      if (outcome.rejectedNames.isNotEmpty) {
        _logger.log(
          ContentSubmissionAssetSkippedTooLarge(
            rejectedNames: outcome.rejectedNames,
          ),
        );
      }

      if (!_disposed) {
        notifyListeners();
      }

      return Result.success(outcome);
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
      // Preserve the meaning of the user's request at Command action entry.
      // Initialization and lifecycle work must never make an invalid index
      // valid or reinterpret it as a newly restored/replacement asset.
      if (index < 0 || index >= _assets.length) {
        return Result.error(Exception(RangeError.index(index, _assets)));
      }
      final captured = (
        clientSubmissionId: _state.clientSubmissionId,
        digest: _assets[index].digest,
      );
      await initialize();
      if (_disposed) return const Result.success(null);
      final result = await _serialize<void>(() async {
        if (_disposed ||
            _state.clientSubmissionId != captured.clientSubmissionId ||
            !_assets.any((asset) => asset.digest == captured.digest)) {
          return const Result.success(null);
        }
        final removed = await _stagedAssetRepository.remove(
          clientSubmissionId: captured.clientSubmissionId,
          digest: captured.digest,
        );
        if (removed case Error<void>(:final error)) return Result.error(error);
        if (_disposed) return const Result.success(null);
        _assets.removeWhere((asset) => asset.digest == captured.digest);
        return const Result.success(null);
      });
      if (result case Error<void>(:final error)) return Result.error(error);

      if (!_disposed) {
        notifyListeners();
      }

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
    if (!_disposed) {
      notifyListeners();
    }
  }

  Future<Result<void>> checkpointDraft() async {
    unawaited(initialize());
    await _initializationBarrier.future;
    return _serialize(_checkpointDraftInsideBoundary);
  }

  Future<Result<void>> _checkpointDraftInsideBoundary() async {
    if (_persistedDraftState == _PersistedDraftState.unknown) {
      return Result.error(
        _draftLoadError ??
            Exception(
              'Cannot checkpoint while persisted draft state is unknown.',
            ),
      );
    }
    final snapshot = _state;
    if (_hasDurableCheckpoint && snapshot == _checkpointedDraft) {
      return const Result.success(null);
    }

    final result = await _draftRepository.saveDraft(snapshot);
    if (result is Success<void>) {
      _checkpointedDraft = snapshot;
      _hasDurableCheckpoint = true;
      _persistedDraftState = _PersistedDraftState.restored;
      _draftLoadError = null;
      if (!_disposed) {
        notifyListeners();
      }
    }
    return result;
  }

  Future<Result<T>> _serialize<T>(
    Future<Result<T>> Function() action,
  ) async {
    final previous = _lifecycleTail;
    final release = Completer<void>();
    _lifecycleTail = release.future;
    await previous;
    try {
      return await action();
    } on Exception catch (exception) {
      return Result.error(exception);
    } on Object catch (error) {
      return Result.error(Exception(error));
    } finally {
      release.complete();
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
  /// A single emission ensures both projections appear together in the same
  /// current and checkpoint snapshot.
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
    await initialize();
    if (!_stagedStateAvailable) {
      return Result.error(
        Exception('Cannot submit: staged assets unavailable.'),
      );
    }
    if (_assets.length > maximumAssetCount) {
      return Result.error(Exception('Cannot submit: too many assets.'));
    }
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
    await initialize();
    _logger.log(const ContentSubmissionStateClearStarted());
    final result = await _serialize<void>(() async {
      final persistedStateBeforeClear = _persistedDraftState;
      final oldClientSubmissionId = _state.clientSubmissionId;
      final cleared = await _draftRepository.clearDraft();
      if (cleared is Error<void>) return cleared;
      if (persistedStateBeforeClear == _PersistedDraftState.unknown) {
        // A successful persistence-first clear authoritatively establishes that
        // no draft owns the quarantined staged state, so clean it as orphans
        // rather than targeting this fresh in-memory identity.
        await _stagedAssetRepository.reconcileAndLoad(null);
      } else {
        await _stagedAssetRepository.clearSession(oldClientSubmissionId);
      }
      _persistedDraftState = _PersistedDraftState.absent;
      _draftLoadError = null;
      _assets.clear();
      _eventTimeIssue = null;
      _state = ContentSubmissionDraft();
      _checkpointedDraft = _state;
      _hasDurableCheckpoint = false;
      _stagedStateAvailable = true;
      _recoveryEligibleClientSubmissionId = null;
      return const Result.success(null);
    });
    if (result is Error<void>) {
      _logger.log(
        const ContentSubmissionStateClearFailed(),
        error: result.error,
      );
      return result;
    }

    if (!_disposed) {
      notifyListeners();
    }
    _logger.log(const ContentSubmissionStateClearSuccess());
    return result;
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

    LostDataResponse? response;
    try {
      response = await _imagePicker.retrieveLostData();
    } on Object catch (error, stackTrace) {
      _handleRetrieveLostMediaErrors(error, stackTrace);
    }
    await initialize();

    if (response == null) return const Result.success(null);

    if (response.isEmpty) {
      return const Result.success(null);
    }

    if (response.exception != null) {
      final exception = response.exception!;
      _handleRetrieveLostMediaErrors(
        exception,
        StackTrace.fromString(exception.stacktrace ?? ''),
      );
      return const Result.success(null);
    }

    // Prefer the complete multi-file response; `file` is only the legacy
    // single-result fallback and must not gate a files-only response.
    final files =
        response.files ??
        (response.file == null ? const <XFile>[] : [response.file!]);
    if (files.isEmpty) return const Result.success(null);

    final capturedClientSubmissionId = _recoveryEligibleClientSubmissionId;
    if (capturedClientSubmissionId == null) {
      return const Result.success(null);
    }

    _logger.log(const ContentSubmissionAssetRetrievalStarted());

    try {
      final rejectedNames = <String>[];
      final processed = await _serialize<void>(() async {
        if (_state.clientSubmissionId != capturedClientSubmissionId ||
            !_stagedStateAvailable) {
          return const Result.success(null);
        }
        for (final file in files) {
          final added = await _processAssetCandidate(file);
          switch (added) {
            case Error<_AssetCandidateDisposition>(:final error):
              return Result.error(error);
            case Success<_AssetCandidateDisposition>(
              value: _AssetCandidateDisposition.oversized,
            ):
              rejectedNames.add(file.name);
            case Success<_AssetCandidateDisposition>():
              break;
          }
        }
        return const Result.success(null);
      });
      if (processed case Error<void>(:final error)) {
        _handleRetrieveLostMediaErrors(error, null);
      }

      if (rejectedNames.isNotEmpty) {
        _logger.log(
          ContentSubmissionAssetSkippedTooLarge(rejectedNames: rejectedNames),
        );
      }

      if (!_disposed) {
        notifyListeners();
      }
    } on Object catch (error, stackTrace) {
      _handleRetrieveLostMediaErrors(error, stackTrace);
    }

    // Lost media recovery is best-effort; surfacing errors to the UI would
    // block the flow with no actionable recovery step for the user.
    return const Result.success(null);
  }

  bool validateEmail(String? text) => StringValidator.isValidEmail(text);
}
