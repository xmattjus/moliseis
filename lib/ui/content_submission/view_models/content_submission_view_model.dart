import 'dart:async';
import 'dart:collection' show UnmodifiableListView;
import 'dart:core' as core show Error;
import 'dart:core' hide Error;
import 'dart:io' show File, FileSystemException;

import 'package:command_it/command_it.dart' as commands;
import 'package:crypto/crypto.dart' show sha1;
import 'package:flutter/foundation.dart'
    show
        ErrorDescription,
        FlutterError,
        FlutterErrorDetails,
        defaultTargetPlatform,
        kIsWeb;
import 'package:flutter/services.dart' show PlatformException;
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/domain/core/event_time.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/content_submission.dart';
import 'package:moliseis/domain/models/content_submission_draft.dart';
import 'package:moliseis/domain/models/content_submission_staged_asset.dart';
import 'package:moliseis/domain/models/submission_asset.dart';
import 'package:moliseis/domain/repositories/content_submission_draft_repository.dart';
import 'package:moliseis/domain/repositories/content_submission_repository.dart';
import 'package:moliseis/domain/repositories/content_submission_staged_asset_repository.dart';
import 'package:moliseis/utils/constants.dart';
import 'package:moliseis/utils/logging/logging.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/result_command.dart';
import 'package:moliseis/utils/string_validator.dart';

/// Pairs a user selected [XFile] asset with its SHA-1 [String] digest for
/// deduplication.
typedef Asset = ({XFile file, String digest});

typedef _SubmissionAttempt = ({
  ContentSubmissionDraft draft,
  List<Asset> assets,
});

/// The single bootstrap outcome is sealed before initialization is published.
typedef _InitializationOutcome = ({
  ContentSubmissionDraft draft,
  bool restored,
  List<Asset> assets,
  String? recoveryIdentity,
  Exception? initializationError,
  Object? runtimeError,
  StackTrace? runtimeStack,
});

typedef _MembershipOutcome = ({
  Result<List<Asset>>? result,
  Object? runtimeError,
  StackTrace? runtimeStack,
});

/// Provenance is retained only for direct file reads owned by this feature.
typedef _AssetCandidateOutcome = ({
  Result<_AssetCandidateDisposition> result,
  (FileSystemException, StackTrace)? fileFailure,
});

/// Immutable intent captured before command_it defers action entry.
class _SessionRequest {
  _SessionRequest({
    required this.draft,
    required this.issue,
    required this.ticket,
    required this.recoveryIdentity,
    this.initializationError,
  });

  final ContentSubmissionDraft draft;
  final EventTimeIssue? issue;
  final Future<_InitializationOutcome>? ticket;
  final String? recoveryIdentity;
  final Exception? initializationError;
}

class _RemoveRequest {
  _RemoveRequest(this.session, this.digest, this.error);

  final _SessionRequest session;
  final String? digest;
  final Exception? error;
}

class _SubmitRequest {
  _SubmitRequest(
    this.session,
    this.membership,
    this.finalizationIdentity, {
    required this.finalizationOnly,
  });

  final _SessionRequest session;
  final Future<_MembershipOutcome>? membership;
  final String? finalizationIdentity;
  final bool finalizationOnly;
}

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

enum ContentSubmissionDraftLoadState { loading, ready }

/// Whether initialization authoritatively determined persisted draft state.
///
/// A failed read is deliberately distinct from a successfully absent draft: it
/// must not authorize orphan cleanup or a fresh draft write.
enum _PersistedDraftState { unknown, absent, restored }

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
    _addAssetCommand = createResultCommandNoParam<AssetSelectionOutcome>(
      () async {
        final request = _addRequest!;
        try {
          return await _addAsset(request);
        } finally {
          if (identical(_addRequest, request)) _addRequest = null;
        }
      },
      debugName: 'content_submission_add_asset',
    );
    _removeAssetAtCommand = createResultCommandNoParam<void>(() async {
      final request = _removeRequest!;
      try {
        return await _removeAssetAt(request);
      } finally {
        if (identical(_removeRequest, request)) _removeRequest = null;
      }
    }, debugName: 'content_submission_remove_asset');
    _submitCommand = createResultCommandNoParam<void>(() async {
      final request = _submitRequest!;
      try {
        return await _submit(request);
      } finally {
        if (identical(_submitRequest, request)) _submitRequest = null;
      }
    }, debugName: 'content_submission_submit');
    _clearCommand = createResultCommandNoParam<void>(() async {
      final request = _clearRequest!;
      try {
        return await _clear(request);
      } finally {
        if (identical(_clearRequest, request)) _clearRequest = null;
      }
    }, debugName: 'content_submission_clear');
    _retrieveLostAssetsCommand = createResultCommandNoParam<void>(() async {
      final request = _recoveryRequest!;
      try {
        return await _retrieveLostAssets(request);
      } finally {
        if (identical(_recoveryRequest, request)) _recoveryRequest = null;
      }
    }, debugName: 'content_submission_retrieve_lost_assets');
    _cacheCommandSnapshots();
    for (final command in _commands) {
      command.results.addListener(_forwardCommandState);
      void forwardRunning() {
        if (_disposed) return;
        if (command.isRunningSync.value) {
          _forwardCommandState();
        } else {
          // command_it clears sync-running before its old run's finally.
          // Publish idle only after that stack, so a reentrant admission
          // cannot have its busy state cleared by the previous execution.
          scheduleMicrotask(_forwardCommandState);
        }
      }

      _runningForwarders[command] = forwardRunning;
      command.isRunningSync.addListener(forwardRunning);
    }
  }

  /// Maximum number of assets that a content submission can include.
  static const int maximumAssetCount = kMaximumSubmissionAssetCount;

  bool _disposed = false;

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final command in _commands) {
      command.results.removeListener(_forwardCommandState);
      command.isRunningSync.removeListener(_runningForwarders.remove(command)!);
      _disposeWhenSettled(command);
    }
    scheduleMicrotask(super.dispose);
  }

  final Logger _logger;
  final ContentSubmissionRepository _contentSubmissionRepository;
  final ContentSubmissionDraftRepository _draftRepository;
  final ContentSubmissionStagedAssetRepository _stagedAssetRepository;
  final ImagePicker _imagePicker;
  ContentSubmissionDraft _state = ContentSubmissionDraft();
  late ContentSubmissionDraft _checkpointedDraft;
  _PersistedDraftState _persistedDraftState = _PersistedDraftState.unknown;
  Exception? _draftLoadError;
  Future<void>? _initializationFuture;
  final _initializationTicket = Completer<_InitializationOutcome>();
  Future<void> _lifecycleTail = Future<void>.value();
  bool _stagedStateAvailable = false;
  Exception? _stagedReconciliationError;
  String? _recoveryEligibleClientSubmissionId;
  bool _submissionFinalizationPending = false;
  String? _activeSubmissionClientSubmissionId;
  ContentSubmissionDraftLoadState _loadState =
      ContentSubmissionDraftLoadState.loading;
  final EventTimePolicy _eventTimePolicy = EventTimePolicy();
  EventTimeIssue? _eventTimeIssue;
  final _assets = <Asset>[];

  ContentSubmissionDraft get state => _state;

  bool get hasUnsavedChanges => _state != _checkpointedDraft;

  /// Whether remote submission succeeded but local session retirement failed.
  bool get submissionFinalizationPending => _submissionFinalizationPending;

  /// Whether executing the current immediate manual retry action is safe.
  ///
  /// Retry is available only after confirmed remote success when local session
  /// finalization has stopped with an error. Ordinary submission failures,
  /// idle, running, and successful states fail closed.
  bool get canRetrySubmissionImmediately =>
      !_disposed &&
      !isSubmitting &&
      submitSnapshot.hasFailure &&
      submissionFinalizationPending;

  UnmodifiableListView<Asset> get assets => UnmodifiableListView(_assets);

  ContentSubmissionDraftLoadState get loadState => _loadState;

  bool get isEvent => _state.eventDates.enabled;
  EventCalendarDate? get startCalendarDate =>
      _state.eventDates.startCalendarDate;

  /// Whether the event has no meaningful initial clock.
  bool get allDay => _state.eventDates.allDay;

  EventClockTime? get startClockTime {
    final start = _state.eventDates.startInstantUtc;
    return allDay || start == null
        ? null
        : _eventTimePolicy.clockTimeForUtc(start);
  }

  EventCalendarDate? get endCalendarDate => _state.eventDates.endCalendarDate;

  EventTimeIssue? get eventTimeIssue => _eventTimeIssue;

  int get _remainingAssetCapacity {
    final capacity = maximumAssetCount - _assets.length;
    return capacity > 0 ? capacity : 0;
  }

  late final ResultCommand<void, AssetSelectionOutcome> _addAssetCommand;
  late final ResultCommand<void, void> _removeAssetAtCommand;
  late final ResultCommand<void, void> _submitCommand;
  late final ResultCommand<void, void> _clearCommand;
  late final ResultCommand<void, void> _retrieveLostAssetsCommand;
  _SessionRequest? _addRequest;
  _RemoveRequest? _removeRequest;
  _SubmitRequest? _submitRequest;
  _SessionRequest? _clearRequest;
  _SessionRequest? _recoveryRequest;
  final _runningForwarders = <ResultCommand<void, dynamic>, VoidCallback>{};

  late commands.CommandResult<void, Result<AssetSelectionOutcome>?>
  _addAssetSnapshot;
  late commands.CommandResult<void, Result<void>?> _removeAssetAtSnapshot;
  late commands.CommandResult<void, Result<void>?> _submitSnapshot;
  late commands.CommandResult<void, Result<void>?> _clearSnapshot;
  late commands.CommandResult<void, Result<void>?> _retrieveLostAssetsSnapshot;

  commands.CommandResult<void, Result<AssetSelectionOutcome>?>
  get addAssetSnapshot => _addAssetSnapshot;
  commands.CommandResult<void, Result<void>?> get removeAssetAtSnapshot =>
      _removeAssetAtSnapshot;
  commands.CommandResult<void, Result<void>?> get submitSnapshot =>
      _submitSnapshot;
  commands.CommandResult<void, Result<void>?> get clearSnapshot =>
      _clearSnapshot;
  commands.CommandResult<void, Result<void>?> get retrieveLostAssetsSnapshot =>
      _retrieveLostAssetsSnapshot;

  bool get isAddingAsset => !_disposed && _addAssetCommand.isRunningSync.value;
  bool get isRemovingAsset =>
      !_disposed && _removeAssetAtCommand.isRunningSync.value;
  bool get isSubmitting => !_disposed && _submitCommand.isRunningSync.value;
  bool get isClearing => !_disposed && _clearCommand.isRunningSync.value;
  bool get isRetrievingLostAssets =>
      !_disposed && _retrieveLostAssetsCommand.isRunningSync.value;

  List<ResultCommand<void, dynamic>> get _commands => [
    _addAssetCommand,
    _removeAssetAtCommand,
    _submitCommand,
    _clearCommand,
    _retrieveLostAssetsCommand,
  ];

  void _cacheCommandSnapshots() {
    _addAssetSnapshot = _addAssetCommand.results.value;
    _removeAssetAtSnapshot = _removeAssetAtCommand.results.value;
    _submitSnapshot = _submitCommand.results.value;
    _clearSnapshot = _clearCommand.results.value;
    _retrieveLostAssetsSnapshot = _retrieveLostAssetsCommand.results.value;
  }

  void _forwardCommandState() {
    if (_disposed) return;
    _cacheCommandSnapshots();
    notifyListeners();
  }

  _SessionRequest _captureSession() => _SessionRequest(
    draft: _state,
    issue: _eventTimeIssue,
    ticket: _loadState == ContentSubmissionDraftLoadState.loading
        ? _initializationTicket.future
        : null,
    recoveryIdentity: _recoveryEligibleClientSubmissionId,
  );

  Future<_SessionRequest?> _resolveSession(_SessionRequest request) async {
    if (_disposed) return null;
    final ticket = request.ticket;
    if (ticket == null) return request;
    await initialize();
    final outcome = await ticket;
    if (outcome.runtimeError != null) {
      core.Error.throwWithStackTrace(
        outcome.runtimeError!,
        outcome.runtimeStack!,
      );
    }
    if (_disposed) return null;
    return _SessionRequest(
      draft: outcome.restored ? outcome.draft : request.draft,
      issue: outcome.restored ? null : request.issue,
      ticket: null,
      recoveryIdentity: outcome.recoveryIdentity,
      initializationError: outcome.initializationError,
    );
  }

  /// Admits one picker request; true denotes admission, not success.
  bool requestAddAsset() {
    if (_disposed || isAddingAsset) return false;
    _addRequest = _captureSession();
    _addAssetCommand.run();
    return true;
  }

  /// Binds the original session and digest before deferred action entry.
  bool requestRemoveAssetAt(int index) {
    if (_disposed || isRemovingAsset) return false;
    final valid = index >= 0 && index < _assets.length;
    _removeRequest = _RemoveRequest(
      _captureSession(),
      valid ? _assets[index].digest : null,
      valid ? null : Exception(RangeError.index(index, _assets)),
    );
    _removeAssetAtCommand.run();
    return true;
  }

  /// Registers the membership position in the existing arbiter before run.
  bool requestSubmit() {
    if (_disposed || isSubmitting) return false;
    final session = _captureSession();
    final finalizationOnly = _submissionFinalizationPending;
    final finalizationIdentity = finalizationOnly
        ? _activeSubmissionClientSubmissionId
        : null;
    Future<_MembershipOutcome>? membership;
    if (session.ticket == null && !finalizationOnly) {
      membership =
          _serialize<List<Asset>>(() async {
            if (_disposed) return const Result.success(<Asset>[]);
            if (_state.clientSubmissionId != session.draft.clientSubmissionId) {
              return Result.error(
                Exception('Submission session is no longer current.'),
              );
            }
            if (!_stagedStateAvailable) {
              return Result.error(
                Exception('Cannot submit: staged assets unavailable.'),
              );
            }
            return Result.success(List<Asset>.unmodifiable(_assets));
          }).then<_MembershipOutcome>(
            (result) =>
                (result: result, runtimeError: null, runtimeStack: null),
            onError: (Object error, StackTrace stack) =>
                (result: null, runtimeError: error, runtimeStack: stack),
          );
    }
    _submitRequest = _SubmitRequest(
      session,
      membership,
      finalizationIdentity,
      finalizationOnly: finalizationOnly,
    );
    _submitCommand.run();
    return true;
  }

  /// Admits persistence-first retirement of the captured session.
  bool requestClear() {
    if (_disposed || isClearing) return false;
    _clearRequest = _captureSession();
    _clearCommand.run();
    return true;
  }

  /// Binds Android recovery to the current initialization outcome.
  bool requestRetrieveLostAssets() {
    if (_disposed || isRetrievingLostAssets) return false;
    _recoveryRequest = _captureSession();
    _retrieveLostAssetsCommand.run();
    return true;
  }

  void _disposeWhenSettled<T>(ResultCommand<void, T> command) {
    var queued = false;
    var invalidated = false;
    var released = false;
    late VoidCallback onRunningChanged;
    void requestCleanup() {
      if (queued || released) return;
      queued = true;
      invalidated = false;
      scheduleMicrotask(() {
        unawaited(
          Future<void>(() {
            queued = false;
            if (released || command.isRunningSync.value) return;
            if (invalidated) {
              requestCleanup();
              return;
            }
            command.isRunningSync.removeListener(onRunningChanged);
            released = true;
            command.dispose();
          }),
        );
      });
    }

    onRunningChanged = () {
      invalidated = true;
      if (!command.isRunningSync.value) requestCleanup();
    };
    command.isRunningSync.addListener(onRunningChanged);
    if (!command.isRunningSync.value) requestCleanup();
  }

  /// Loads the last [ContentSubmissionDraft] saved to local persistance
  /// if any.
  Future<void> initialize() {
    if (_disposed) return _initializationFuture ?? Future<void>.value();
    return _initializationFuture ??= _initialize();
  }

  Future<void> _initialize() async {
    var draftReadCompleted = false;
    var initializedDraft = _state;
    var restored = false;
    Object? runtimeError;
    StackTrace? runtimeStack;
    try {
      final result = await _draftRepository.loadDraft();
      if (_disposed) return;
      draftReadCompleted = true;
      switch (result) {
        case Success<ContentSubmissionDraft?>(value: final draft):
          _draftLoadError = null;
          if (draft == null) {
            _persistedDraftState = _PersistedDraftState.absent;
            await _reconcileStagedAssets(null);
          } else {
            _persistedDraftState = _PersistedDraftState.restored;
            initializedDraft = draft;
            restored = true;
            _state = draft;
            _checkpointedDraft = draft;
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
    } on Object catch (error, stack) {
      if (error is AssertionError) {
        runtimeError = error;
        runtimeStack = stack;
        rethrow;
      }
      if (_disposed) return;
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
      _initializationTicket.complete((
        draft: initializedDraft,
        restored: restored,
        assets: List<Asset>.unmodifiable(_assets),
        recoveryIdentity: _recoveryEligibleClientSubmissionId,
        initializationError: _draftLoadError ?? _stagedReconciliationError,
        runtimeError: runtimeError,
        runtimeStack: runtimeStack,
      ));
      if (!_disposed) {
        _loadState = ContentSubmissionDraftLoadState.ready;
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
    if (_disposed) return const Result.success(null);
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
      if (_disposed) return const Result.success(null);
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
  Future<_AssetCandidateOutcome> _processAssetCandidate(XFile asset) async {
    if (_disposed) {
      return (
        result: const Result.success(_AssetCandidateDisposition.discarded),
        fileFailure: null,
      );
    }
    if (_remainingAssetCapacity == 0) {
      return (
        result: const Result.success(_AssetCandidateDisposition.overCapacity),
        fileFailure: null,
      );
    }
    int length;
    try {
      length = await asset.length();
    } on FileSystemException catch (error, stack) {
      return (
        result: Result<_AssetCandidateDisposition>.error(error),
        fileFailure: (error, stack),
      );
    }
    if (_disposed) {
      return (
        result: const Result.success(_AssetCandidateDisposition.discarded),
        fileFailure: null,
      );
    }
    if (length > kCloudinaryMaxUploadBytes) {
      return const (
        result: Result.success(_AssetCandidateDisposition.oversized),
        fileFailure: null,
      );
    }

    // SHA-1 is used purely for content-based deduplication; collision
    // resistance beyond accidental duplicates is not required here.
    String digestString;
    try {
      digestString = (await sha1.bind(asset.openRead()).first).toString();
    } on FileSystemException catch (error, stack) {
      return (
        result: Result<_AssetCandidateDisposition>.error(error),
        fileFailure: (error, stack),
      );
    }
    if (_disposed) {
      return (
        result: const Result.success(_AssetCandidateDisposition.discarded),
        fileFailure: null,
      );
    }

    if (_assets.any((e) => e.digest == digestString)) {
      return (
        result: const Result.success(_AssetCandidateDisposition.duplicate),
        fileFailure: null,
      );
    }
    final staged = await _stagedAssetRepository.acquire(
      clientSubmissionId: _state.clientSubmissionId,
      digest: digestString,
      source: File(asset.path),
    );
    if (_disposed) {
      return (
        result: const Result.success(_AssetCandidateDisposition.discarded),
        fileFailure: null,
      );
    }
    if (staged case Error<ContentSubmissionStagedAsset>(:final error)) {
      return (
        result: Result<_AssetCandidateDisposition>.error(error),
        fileFailure: null,
      );
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
      return (
        result: const Result.success(_AssetCandidateDisposition.discarded),
        fileFailure: null,
      );
    }
    if (resolved case Error<File>(:final error)) {
      _stagedReconciliationError = error;
      _assets.clear();
      return (
        result: Result<_AssetCandidateDisposition>.error(error),
        fileFailure: null,
      );
    }
    _assets.add((
      file: XFile((resolved as Success<File>).value.path),
      digest: digestString,
    ));
    _stagedStateAvailable = true;
    _stagedReconciliationError = null;
    return (
      result: const Result.success(_AssetCandidateDisposition.added),
      fileFailure: null,
    );
  }

  Future<Result<AssetSelectionOutcome>> _addAsset(
    _SessionRequest request,
  ) async {
    if (_disposed) return const Result.success(AssetSelectionOutcome());
    final session = await _resolveSession(request);
    if (session == null) return const Result.success(AssetSelectionOutcome());
    final prePicker = await _serialize<String?>(() async {
      if (_disposed ||
          _state.clientSubmissionId != session.draft.clientSubmissionId) {
        return const Result.success(null);
      }
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
          _persistedDraftState == _PersistedDraftState.restored
              ? _state.clientSubmissionId
              : null,
        );
        if (reconciled case Error<void>(:final error)) {
          return Result.error(_stagedReconciliationError ?? error);
        }
      }
      if (_disposed ||
          _state.clientSubmissionId != session.draft.clientSubmissionId) {
        return const Result.success(null);
      }
      final checkpoint = await _checkpointDraftInsideBoundary();
      if (checkpoint case Error<void>(:final error)) {
        return Result.error(error);
      }
      if (_disposed) return const Result.success(null);
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

    if (_disposed || _state.clientSubmissionId != capturedClientSubmissionId) {
      return const Result.success(AssetSelectionOutcome());
    }
    List<XFile> selectedAssets;
    try {
      selectedAssets = await _imagePicker.pickMultipleMedia(
        limit: capacityBeforePicking,
      );
    } on PlatformException catch (error, stack) {
      _logger.log(
        const ContentSubmissionAssetAddFailed(),
        error: error,
        stackTrace: stack,
      );
      return Result.error(error);
    }
    if (_disposed || _state.clientSubmissionId != capturedClientSubmissionId) {
      return const Result.success(AssetSelectionOutcome());
    }
    (FileSystemException, StackTrace)? fileFailure;

    final committed = await _serialize<AssetSelectionOutcome>(() async {
      if (_disposed ||
          _state.clientSubmissionId != capturedClientSubmissionId) {
        return const Result.success(AssetSelectionOutcome());
      }
      final capacityAfterPicking = _remainingAssetCapacity;
      final rejectedForLimitCount = selectedAssets.length > capacityAfterPicking
          ? selectedAssets.length - capacityAfterPicking
          : 0;
      final rejectedNames = <String>[];
      for (final asset in selectedAssets.take(capacityAfterPicking)) {
        if (_disposed) return const Result.success(AssetSelectionOutcome());
        final processed = await _processAssetCandidate(asset);
        fileFailure = processed.fileFailure;
        final result = processed.result;
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
      if (fileFailure case (final fileError, final stack)) {
        _logger.log(
          const ContentSubmissionAssetAddFailed(),
          error: fileError,
          stackTrace: stack,
        );
      }
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
  }

  Future<Result<void>> _removeAssetAt(_RemoveRequest request) async {
    if (_disposed) return const Result.success(null);
    if (request.error != null) return Result.error(request.error!);
    final session = await _resolveSession(request.session);
    if (session == null) return const Result.success(null);
    final result = await _serialize<void>(() async {
      if (_disposed ||
          _state.clientSubmissionId != session.draft.clientSubmissionId ||
          !_assets.any((asset) => asset.digest == request.digest)) {
        return const Result.success(null);
      }
      final removed = await _stagedAssetRepository.remove(
        clientSubmissionId: session.draft.clientSubmissionId,
        digest: request.digest!,
      );
      if (removed case Error<void>(:final error)) return Result.error(error);
      if (_disposed) return const Result.success(null);
      _assets.removeWhere((asset) => asset.digest == request.digest);
      return const Result.success(null);
    });
    if (result case Error<void>(:final error)) return Result.error(error);
    if (!_disposed) notifyListeners();
    return const Result.success(null);
  }

  void _emit() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  Future<Result<void>> checkpointDraft() async {
    if (_disposed) return const Result.success(null);
    await initialize();
    if (_disposed) return const Result.success(null);
    return await _serialize(_checkpointDraftInsideBoundary);
  }

  /// Restores the current draft fields to their last durable checkpoint.
  ///
  /// Durable staged assets remain owned by the current session and are not
  /// part of this field-level restore operation.
  Future<Result<void>> restoreCheckpointDraft() async {
    if (_disposed) return const Result.success(null);
    await initialize();
    if (_disposed) return const Result.success(null);
    return await _serialize(() async {
      if (_disposed) return const Result.success(null);
      if (_persistedDraftState == _PersistedDraftState.unknown) {
        return Result.error(
          _draftLoadError ??
              Exception(
                'Cannot restore while persisted draft state is unknown.',
              ),
        );
      }
      if (_state == _checkpointedDraft) return const Result.success(null);

      _state = _checkpointedDraft;
      _eventTimeIssue = null;
      if (!_disposed) notifyListeners();
      return const Result.success(null);
    });
  }

  Future<Result<void>> _checkpointDraftInsideBoundary() async {
    return await _checkpointDraftSnapshotInsideBoundary(_state);
  }

  Future<Result<void>> _checkpointDraftSnapshotInsideBoundary(
    ContentSubmissionDraft snapshot,
  ) async {
    if (_disposed) return const Result.success(null);
    if (_persistedDraftState == _PersistedDraftState.unknown) {
      return Result.error(
        _draftLoadError ??
            Exception(
              'Cannot checkpoint while persisted draft state is unknown.',
            ),
      );
    }
    if (_persistedDraftState == _PersistedDraftState.restored &&
        snapshot == _checkpointedDraft) {
      return const Result.success(null);
    }

    final result = await _draftRepository.saveDraft(snapshot);
    if (_disposed) return result;
    if (result is Success<void>) {
      _checkpointedDraft = snapshot;
      _persistedDraftState = _PersistedDraftState.restored;
      _draftLoadError = null;
      if (!_disposed) {
        notifyListeners();
      }
    }
    return result;
  }

  Future<Result<T>> _serialize<T>(Future<Result<T>> Function() action) async {
    final previous = _lifecycleTail;
    final release = Completer<void>();
    _lifecycleTail = release.future;
    await previous;
    try {
      return await action();
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

  /// Changes precision without restoring an old or technical clock.
  void setAllDay({required bool allDay}) {
    _applyEventEdit(
      _eventTimePolicy.changeAllDay(_state.eventDates, allDay: allDay),
    );
  }

  void setEventEnabled({required bool enabled}) {
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
    _applyEventEdit(_eventTimePolicy.changeStartCalendarDate(draft, date));
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
    _applyEventEdit(_eventTimePolicy.changeStartClockTime(draft, time));
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

  void setAcceptedTerms({required bool? value}) {
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
  Future<Result<void>> _submit(_SubmitRequest request) async {
    List<Asset>? capturedAssets;
    final membership = request.membership;
    if (membership != null) {
      final outcome = await membership;
      if (outcome.runtimeError != null) {
        core.Error.throwWithStackTrace(
          outcome.runtimeError!,
          outcome.runtimeStack!,
        );
      }
      if (_disposed) return const Result.success(null);
      final result = outcome.result!;
      if (result case Error<List<Asset>>(:final error)) {
        return Result.error(error);
      }
      capturedAssets = (result as Success<List<Asset>>).value;
    }
    if (_disposed) return const Result.success(null);
    if (request.finalizationOnly) {
      if (request.finalizationIdentity == null) {
        return Result.error(
          Exception('Acknowledged submission identity is unavailable.'),
        );
      }
      return await _finalizeSubmittedSession(request.finalizationIdentity);
    }
    final session = await _resolveSession(request.session);
    if (session == null) return const Result.success(null);
    if (session.initializationError != null) {
      return Result.error(session.initializationError!);
    }
    if (request.session.ticket != null) {
      capturedAssets = (await request.session.ticket!).assets;
    }
    final prepared = await _prepareSubmissionAttempt(session, capturedAssets!);
    if (prepared case Error<_SubmissionAttempt>(:final error)) {
      return Result.error(error);
    }
    final attempt = (prepared as Success<_SubmissionAttempt>).value;
    final draft = attempt.draft;
    var acknowledged = false;
    Result<void>? primaryResult;
    Object? primaryError;
    StackTrace? primaryStack;

    Future<Result<void>> performAttempt() async {
      if (_disposed) return const Result.success(null);
      final city = draft.city!;
      final name = draft.name!;
      final userEmail = draft.userEmail!;
      final userName = draft.userName!;
      final submissionAssets = <SubmissionAsset>[];
      for (final entry in attempt.assets) {
        if (_disposed) return const Result.success(null);
        final result = await _contentSubmissionRepository
            .uploadImageTask(File(entry.file.path))
            .result;
        switch (result) {
          case Success<SubmissionAsset>():
            if (_disposed) return const Result.success(null);
            submissionAssets.add(result.value);
          case Error<SubmissionAsset>():
            return Result.error(result.error);
        }
      }
      if (_disposed) return const Result.success(null);
      final contentSubmission = ContentSubmission(
        category: draft.category,
        city: city,
        name: name,
        description: draft.description,
        descriptionDelta: draft.descriptionDelta,
        allDay: draft.eventDates.allDay,
        startDate: draft.eventDates.startInstantUtc,
        endDate: draft.eventDates.endInstantUtc,
        userEmail: userEmail,
        userName: userName,
      );
      final result = await _contentSubmissionRepository.submit(
        clientSubmissionId: draft.clientSubmissionId,
        contentSubmission: contentSubmission,
        submissionAssets: List<SubmissionAsset>.unmodifiable(submissionAssets),
      );
      if (result is Error<void>) return result;
      // A valid late acknowledgement is private settlement only. It grants
      // no permission for a new local phase or a public pending-state change.
      acknowledged = true;
      if (_disposed) return const Result.success(null);
      _submissionFinalizationPending = true;
      return await _finalizeSubmittedSession(draft.clientSubmissionId);
    }

    try {
      primaryResult = await performAttempt();
    } on Object catch (error, stack) {
      primaryError = error;
      primaryStack = stack;
    } finally {
      if (!acknowledged) {
        try {
          await _releaseSubmissionOwnership(draft.clientSubmissionId);
        } on Object catch (secondaryError, secondaryStack) {
          if (primaryError == null && primaryResult is! Error<void>) rethrow;
          try {
            FlutterError.reportError(
              FlutterErrorDetails(
                exception: secondaryError,
                stack: secondaryStack,
                context: ErrorDescription(
                  'releasing a content submission attempt',
                ),
              ),
            );
          } on Object {
            // Even a failing diagnostic handler cannot replace the primary
            // domain failure or its original runtime object/stack.
          }
        }
      }
    }
    if (primaryError != null) {
      core.Error.throwWithStackTrace(primaryError, primaryStack!);
    }
    return primaryResult!;
  }

  Future<Result<_SubmissionAttempt>> _prepareSubmissionAttempt(
    _SessionRequest request,
    List<Asset> assets,
  ) {
    return _serialize(() async {
      if (_disposed ||
          _state.clientSubmissionId != request.draft.clientSubmissionId) {
        return Result.error(
          Exception('Submission session is no longer current.'),
        );
      }
      if (!_stagedStateAvailable) {
        return Result.error(
          Exception('Cannot submit: staged assets unavailable.'),
        );
      }
      if (assets.length > maximumAssetCount) {
        return Result.error(Exception('Cannot submit: too many assets.'));
      }

      final draft = request.draft;
      final issue =
          request.issue ??
          _eventTimePolicy.validateForPersistence(draft.eventDates);
      if (issue != null) {
        if (_state == draft && _eventTimeIssue != issue) {
          _eventTimeIssue = issue;
          if (!_disposed) notifyListeners();
        }
        return Result.error(Exception('Cannot submit: invalid event time.'));
      }

      final missing = <String>[
        if (draft.city == null) 'city',
        if (draft.name == null) 'name',
        if (draft.userEmail == null) 'userEmail',
        if (draft.userName == null) 'userName',
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

      final checkpoint = await _checkpointDraftSnapshotInsideBoundary(draft);
      if (checkpoint case Error<void>(:final error)) return Result.error(error);
      if (_disposed || _state.clientSubmissionId != draft.clientSubmissionId) {
        return Result.error(
          Exception('Submission owner is no longer current.'),
        );
      }
      if (_activeSubmissionClientSubmissionId != null) {
        return Result.error(Exception('Another submission session is active.'));
      }
      final attempt = (draft: draft, assets: assets);
      _activeSubmissionClientSubmissionId = draft.clientSubmissionId;
      return Result.success(attempt);
    });
  }

  Future<void> _releaseSubmissionOwnership(String clientSubmissionId) async {
    await _serialize<void>(() async {
      if (_activeSubmissionClientSubmissionId == clientSubmissionId) {
        _activeSubmissionClientSubmissionId = null;
      }
      return const Result.success(null);
    });
  }

  Future<Result<void>> _finalizeSubmittedSession([
    String? acknowledgedClientSubmissionId,
  ]) async {
    if (_disposed) return const Result.success(null);
    final expectedClientSubmissionId =
        acknowledgedClientSubmissionId ?? _activeSubmissionClientSubmissionId;
    final result = await _serialize<void>(() async {
      if (_disposed) return const Result.success(null);
      if (!_submissionFinalizationPending ||
          expectedClientSubmissionId == null ||
          _activeSubmissionClientSubmissionId != expectedClientSubmissionId ||
          _state.clientSubmissionId != expectedClientSubmissionId) {
        return Result.error(
          Exception('Cannot finalize a submission for a different session.'),
        );
      }
      final retired = await _retireCurrentSessionInsideBoundary();
      if (retired case Error<void>(:final error)) return Result.error(error);
      if (_disposed) return const Result.success(null);
      _submissionFinalizationPending = false;
      _activeSubmissionClientSubmissionId = null;
      return const Result.success(null);
    });
    if (result is Error<void>) return result;
    if (!_disposed) notifyListeners();
    return result;
  }

  Future<Result<void>> _clear(_SessionRequest request) async {
    final session = await _resolveSession(request);
    if (session == null) return const Result.success(null);
    final result = await _serialize<void>(() async {
      if (_disposed ||
          _state.clientSubmissionId != session.draft.clientSubmissionId) {
        return const Result.success(null);
      }
      if (_activeSubmissionClientSubmissionId != null) {
        return Result.error(
          Exception('Cannot clear while a submission session is active.'),
        );
      }
      return await _retireCurrentSessionInsideBoundary();
    });
    if (result is Error<void>) return result;

    if (!_disposed) {
      notifyListeners();
    }
    return result;
  }

  Future<Result<void>> _retireCurrentSessionInsideBoundary() async {
    if (_disposed) return const Result.success(null);
    final persistedStateBeforeClear = _persistedDraftState;
    final oldClientSubmissionId = _state.clientSubmissionId;
    final cleared = await _draftRepository.clearDraft();
    if (cleared is Error<void>) return cleared;
    if (_disposed) return const Result.success(null);
    if (persistedStateBeforeClear == _PersistedDraftState.unknown) {
      // A successful persistence-first clear authoritatively establishes that
      // no draft owns the quarantined staged state, so clean it as orphans
      // rather than targeting this fresh in-memory identity.
      await _stagedAssetRepository.reconcileAndLoad(null);
    } else {
      await _stagedAssetRepository.clearSession(oldClientSubmissionId);
    }
    if (_disposed) return const Result.success(null);
    _persistedDraftState = _PersistedDraftState.absent;
    _draftLoadError = null;
    _assets.clear();
    _eventTimeIssue = null;
    _state = ContentSubmissionDraft();
    _checkpointedDraft = _state;
    _stagedStateAvailable = true;
    _recoveryEligibleClientSubmissionId = null;
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
  Future<Result<void>> _retrieveLostAssets(_SessionRequest request) async {
    if (_disposed) return const Result.success(null);
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return const Result.success(null);
    }

    LostDataResponse? response;
    try {
      response = await _imagePicker.retrieveLostData();
    } on PlatformException catch (error, stackTrace) {
      _handleRetrieveLostMediaErrors(error, stackTrace);
    }
    if (_disposed) return const Result.success(null);
    final session = await _resolveSession(request);
    if (session == null) return const Result.success(null);
    if (response == null || response.isEmpty) return const Result.success(null);
    if (response.exception case final exception?) {
      _handleRetrieveLostMediaErrors(
        exception,
        StackTrace.fromString(exception.stacktrace ?? ''),
      );
      return const Result.success(null);
    }
    final files =
        response.files ??
        (response.file == null ? const <XFile>[] : [response.file!]);
    if (files.isEmpty) return const Result.success(null);
    final capturedClientSubmissionId = session.recoveryIdentity;
    if (capturedClientSubmissionId == null ||
        _state.clientSubmissionId != capturedClientSubmissionId) {
      return const Result.success(null);
    }
    _logger.log(const ContentSubmissionAssetRetrievalStarted());
    if (_disposed) return const Result.success(null);
    final rejectedNames = <String>[];
    (FileSystemException, StackTrace)? fileFailure;
    final processed = await _serialize<void>(() async {
      if (_disposed ||
          _state.clientSubmissionId != capturedClientSubmissionId ||
          !_stagedStateAvailable) {
        return const Result.success(null);
      }
      for (final file in files) {
        if (_disposed) return const Result.success(null);
        final candidate = await _processAssetCandidate(file);
        fileFailure = candidate.fileFailure;
        switch (candidate.result) {
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
      _handleRetrieveLostMediaErrors(error, fileFailure?.$2);
    }
    if (!_disposed && rejectedNames.isNotEmpty) {
      _logger.log(
        ContentSubmissionAssetSkippedTooLarge(rejectedNames: rejectedNames),
      );
    }
    if (!_disposed) notifyListeners();
    // Expected recovery failures remain best-effort; raw defects reach Command.
    return const Result.success(null);
  }

  bool validateEmail(String? text) => StringValidator.isValidEmail(text);
}
