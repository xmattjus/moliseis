import 'dart:async';
import 'dart:collection' show UnmodifiableListView;
import 'dart:io' show File;

import 'package:command_it/command_it.dart' as commands;
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:moliseis/data/repositories/admin_content_submission_api_exception.dart';
import 'package:moliseis/domain/core/event_time.dart';
import 'package:moliseis/domain/models/admin_external_event.dart';
import 'package:moliseis/domain/models/admin_submission.dart';
import 'package:moliseis/domain/models/admin_submission_asset.dart';
import 'package:moliseis/domain/models/admin_submission_draft.dart';
import 'package:moliseis/domain/models/admin_submission_input.dart';
import 'package:moliseis/domain/models/admin_submission_promotion.dart';
import 'package:moliseis/domain/models/admin_submission_staged_asset.dart';
import 'package:moliseis/domain/models/admin_submission_status.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/image_upload_task.dart';
import 'package:moliseis/domain/models/submission_asset.dart';
import 'package:moliseis/domain/repositories/admin_content_submission_repository.dart';
import 'package:moliseis/domain/repositories/content_submission_repository.dart';
import 'package:moliseis/domain/use_cases/admin_draft_session.dart';
import 'package:moliseis/ui/admin/auth/view_models/admin_auth_view_model.dart';
import 'package:moliseis/utils/constants.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/result_command.dart';

/// Immutable action input captured by one admitted editor operation.
typedef _EditorAction<T> = Future<Result<T>> Function();

typedef _SaveDraft = ({
  AdminSubmissionInput? input,
  Exception? error,
  EventTimeIssue? issue,
  int revision,
  AdminDraftSnapshot snapshot,
  List<AdminSubmissionStagedAsset> assets,
  AdminSubmissionDraft? physicalCheckpoint,
});
typedef _SourceAcknowledgment = ({
  bool? acknowledge,
  String? hash,
  bool? ignore,
});
typedef _RejectedFieldWrite = ({
  AdminFieldWriteIntent intent,
  Exception error,
  bool conflict,
});

/// Visible phase of the existing single-flight Save command.
enum AdminSavePhase {
  idle,
  checkpoint,
  fields,
  adoption,
  upload,
  association,
  completed,
  partialFailure,
  failed,
  unknownOutcome,
  conflict,
}

/// Application-owned Admin editor, composed with the exact-owner local session.
class AdminSubmissionEditorViewModel extends ChangeNotifier {
  /// Creates editor state for a new submission or the supplied [submissionId].
  ///
  /// [creatorName] and [creatorEmail] are display-only context for create mode;
  /// they are never included in an [AdminSubmissionInput].
  AdminSubmissionEditorViewModel({
    required AdminContentSubmissionRepository repository,
    required ContentSubmissionRepository contentSubmissionRepository,
    ImagePicker? imagePicker,
    int? submissionId,
    AdminDraftSession? draftSession,
    String? creatorName,
    String? creatorEmail,
  }) : _legacySubmissionId = submissionId,
       _draftSession = draftSession,
       _repository = repository,
       _contentSubmissionRepository = contentSubmissionRepository,
       _imagePicker = imagePicker ?? ImagePicker(),
       _contributorName = creatorName,
       _contributorEmail = creatorEmail {
    _loadCommand = _createCommand<void>('load', (snapshot) {
      if (_loadSnapshot.isRunning) _loadSnapshot = snapshot;
    });
    _saveCommand = _createCommand<void>('save', (snapshot) {
      if (_saveSnapshot.isRunning) _saveSnapshot = snapshot;
    });
    _rejectCommand = _createCommand<void>('reject', (snapshot) {
      if (_rejectSnapshot.isRunning) _rejectSnapshot = snapshot;
    });
    _promoteCommand = _createCommand<AdminSubmissionPromotion>('promote', (
      snapshot,
    ) {
      if (_promoteSnapshot.isRunning) _promoteSnapshot = snapshot;
    });
    _linkCommand = _createCommand<AdminEventResolution>('link', (snapshot) {
      if (_linkSnapshot.isRunning) _linkSnapshot = snapshot;
    });
    _previewCommand = _createCommand<void>('preview', (snapshot) {
      if (_previewSnapshot.isRunning) _previewSnapshot = snapshot;
    });
    _candidatesCommand = _createCommand<void>('find_candidates', (snapshot) {
      if (_candidatesSnapshot.isRunning) _candidatesSnapshot = snapshot;
    });
    _applyCommand = _createCommand<AdminEventResolution>('apply', (snapshot) {
      if (_applySnapshot.isRunning) _applySnapshot = snapshot;
    });
    _keepCommand = _createCommand<void>('keep_current', (snapshot) {
      if (_keepSnapshot.isRunning) _keepSnapshot = snapshot;
    });
    _addCommand = _createCommand<void>('add_asset', (snapshot) {
      if (_addSnapshot.isRunning) _addSnapshot = snapshot;
    });
    _deleteCommand = _createCommand<void>('delete_asset', (snapshot) {
      if (_deleteSnapshot.isRunning) _deleteSnapshot = snapshot;
    });
  }

  final AdminContentSubmissionRepository _repository;
  final ContentSubmissionRepository _contentSubmissionRepository;
  final ImagePicker _imagePicker;

  final AdminDraftSession? _draftSession;
  final int? _legacySubmissionId;
  AdminDraftSnapshot _legacySnapshot = AdminDraftSnapshot();
  int _generation = 0;
  bool _revoked = false;
  AdminAuthViewModel? _auth;
  String? _activeAccountId;
  final _commandGenerations = <commands.Command<dynamic, dynamic>, int>{};

  /// Current local activation, captured when establishing rendered callbacks.
  AdminDraftActivation? get activation => _draftSession?.captureActivation();

  /// Whether this exact session has a verified durable owner.
  bool get hasDurableDraft =>
      _draftSession?.state?.durability == AdminDraftDurability.durable;

  /// Original authenticated owner, independently of contributor identity.
  String? get accountId => _activeAccountId;

  /// Stable local UUID, retained after Create adoption.
  String? get sessionId => _draftSession?.state?.owner.sessionId;

  /// Current persisted target, including an adopted Create identity.
  int? get submissionId =>
      _draftSession?.state?.owner.submissionId ?? _legacySubmissionId;

  /// Whether the supplied rendered callback still owns this exact activation.
  bool isActivationCurrent(AdminDraftActivation? token) {
    if (_disposed || _revoked) return false;
    if (_draftSession == null) return token == null;
    return _draftSession.isActivationCurrent(token);
  }

  bool _authority(AdminDraftActivation? token) => isActivationCurrent(token);
  bool _obsolete(int generation) =>
      _disposed || _revoked || generation != _generation;

  /// Attaches directly so auth revocation precedes deferred Provider rebuilds.
  void bindAuth(AdminAuthViewModel auth) {
    if (identical(_auth, auth)) return;
    _auth?.removeListener(_onAuthChanged);
    _auth = auth;
    auth.addListener(_onAuthChanged);
    _onAuthChanged();
  }

  void _onAuthChanged() {
    final auth = _auth;
    if (auth == null) return;
    if (!auth.isAdmin ||
        (_activeAccountId != null &&
            auth.currentUser?.id != _activeAccountId)) {
      revoke();
    }
  }

  /// Synchronously removes every old continuation's publication authority.
  void revoke() {
    if (_disposed) return;
    _generation++;
    _revoked = true;
    _abandonPicker();
    _activeImageUploadTask?.cancel();
    _draftSession?.revoke();
    _activeAccountId = null;
    _clearContext();
    _notifyListeners();
  }

  /// Activates a durable target without replacing dirty or admitted work.
  Future<Result<void>> activate({
    required String accountId,
    int? submissionId,
    String? sessionId,
    String? creatorName,
    String? creatorEmail,
  }) async {
    final session = _draftSession;
    if (_disposed ||
        session == null ||
        (_auth != null &&
            (!_auth!.isAdmin || _auth!.currentUser?.id != accountId))) {
      return _unavailable();
    }
    final activationGeneration = _generation;
    final previous = session.state?.owner;
    if (sessionId != null &&
        previous?.accountId == accountId &&
        previous?.sessionId == sessionId &&
        submissionId != null &&
        previous?.submissionId != submissionId) {
      return _unavailable();
    }
    final same =
        !_revoked &&
        previous?.accountId == accountId &&
        (sessionId != null
            ? previous?.sessionId == sessionId
            : previous?.submissionId == submissionId);
    if (same) return await session.initialize();
    if (!_revoked && operationRunning) {
      return Result.error(
        Exception('Attendi il completamento dell’operazione corrente.'),
      );
    }
    final result = sessionId == null
        ? await session.activate(
            AdminDraftOwner(accountId: accountId, submissionId: submissionId),
          )
        : await session.activateBySession(
            accountId: accountId,
            sessionId: sessionId,
            expectedSubmissionId: submissionId,
          );
    if (_disposed ||
        activationGeneration != _generation ||
        (_auth != null &&
            (!_auth!.isAdmin || _auth!.currentUser?.id != accountId))) {
      return _unavailable();
    }
    if (result is Error<void>) return result;
    _generation++;
    _revoked = false;
    _activeAccountId = accountId;
    _clearContext();
    _contributorName = creatorName;
    _contributorEmail = creatorEmail;
    _hydrationRevision++;
    _notifyListeners();
    return const Result.success(null);
  }

  void _clearContext() {
    _isDirty = false;
    _loadEffectId = null;
    _saveEffectId = null;
    _rejectEffectId = null;
    _promoteEffectId = null;
    _linkEffectId = null;
    _previewEffectId = null;
    _candidatesEffectId = null;
    _applyEffectId = null;
    _keepEffectId = null;
    _addEffectId = null;
    _deleteEffectId = null;
    _saveSessionId = null;
    _lastSaveAttempt = null;
    _pendingFieldSettlement = null;
    _retryableUpdateAttempt = null;
    _correctableCreateAttempt = null;
    _eventTimeIssue = null;
    _status = null;
    _promotion = null;
    _externalEvent = null;
    _createdAt = null;
    _modifiedAt = null;
    _modifiedAtToken = null;
    _assets.clear();
    _hasLoadedDetail = false;
    _contributorName = null;
    _contributorEmail = null;
    _targetEventId = null;
    _mergePreview = null;
    _candidates = null;
    _acknowledgeCurrentSource = false;
    _acknowledgedSourceHash = null;
    _ignoreSource = false;
    _candidateSearch = '';
    _editorRevision++;
    _draftRevision++;
    _savePhase =
        _draftSession?.state?.physicalCheckpoint?.fieldWriteIntent != null
        ? AdminSavePhase.unknownOutcome
        : AdminSavePhase.idle;
    _remoteUnavailable = false;
    _confirmedFields = null;
    _liveReceipts.clear();
    _loadSnapshot = const commands.CommandResult(null, null, null, false);
    _saveSnapshot = const commands.CommandResult(null, null, null, false);
    _rejectSnapshot = const commands.CommandResult(null, null, null, false);
    _promoteSnapshot = const commands.CommandResult(null, null, null, false);
    _linkSnapshot = const commands.CommandResult(null, null, null, false);
    _applySnapshot = const commands.CommandResult(null, null, null, false);
    _keepSnapshot = const commands.CommandResult(null, null, null, false);
    _addSnapshot = const commands.CommandResult(null, null, null, false);
    _deleteSnapshot = const commands.CommandResult(null, null, null, false);
    _previewSnapshot = const commands.CommandResult(null, null, null, false);
    _candidatesSnapshot = const commands.CommandResult(null, null, null, false);
  }

  /// Whether explicit local parking can be admitted without remote work.
  bool get canCheckpoint =>
      !_disposed && !_revoked && (_draftSession?.state?.ready ?? false);

  /// Durably parks incomplete values without executing a remote mutation.
  Future<Result<void>> checkpointLocal() async {
    if (!canCheckpoint) return _unavailable();
    final ownerGeneration = _generation;
    final result = await _draftSession!.checkpoint(requireDurableOwner: true);
    if (_obsolete(ownerGeneration)) return _unavailable();
    _notifyListeners();
    return result;
  }

  AdminDraftSnapshot get _fields =>
      _draftSession?.state?.current ?? _legacySnapshot;
  void _writeFields(AdminDraftSnapshot value) {
    final session = _draftSession;
    if (session == null) {
      _legacySnapshot = value;
      return;
    }
    final token = activation;
    if (token != null) session.setSnapshot(value, activation: token);
  }

  ContentCategory? get _category => _fields.category;
  set _category(ContentCategory? value) =>
      _writeFields(_fields.copyWith(category: value));
  String? get _city => _fields.city;
  set _city(String? value) => _writeFields(_fields.copyWith(city: value));
  String? get _name => _fields.name;
  set _name(String? value) => _writeFields(_fields.copyWith(name: value));
  String? get _description => _fields.description;
  set _description(String? value) =>
      _writeFields(_fields.copyWith(description: value));
  List<Map<String, dynamic>>? get _descriptionDelta => _fields.descriptionDelta;
  set _descriptionDelta(List<Map<String, dynamic>>? value) =>
      _writeFields(_fields.copyWith(descriptionDelta: value));
  EventDateDraft get _eventDates => _fields.eventDates;
  set _eventDates(EventDateDraft value) =>
      _writeFields(_fields.copyWith(eventDates: value));
  String get _latitudeText => _fields.latitudeText;
  set _latitudeText(String value) =>
      _writeFields(_fields.copyWith(latitudeText: value));
  String get _longitudeText => _fields.longitudeText;
  set _longitudeText(String value) =>
      _writeFields(_fields.copyWith(longitudeText: value));
  final EventTimePolicy _eventTimePolicy = EventTimePolicy();
  EventTimeIssue? _eventTimeIssue;
  String? _contributorName;
  String? _contributorEmail;
  AdminSubmissionStatus? _status;
  AdminSubmissionPromotion? _promotion;
  DateTime? _createdAt;
  DateTime? _modifiedAt;
  String? _modifiedAtToken;
  bool _remoteUnavailable = false;
  ({AdminFieldWriteIntent intent, AdminSubmission detail, bool replayed})?
  _confirmedFields;
  final _liveReceipts = <String, AdminStagedAssetProgress>{};
  AdminSavePhase _savePhase = AdminSavePhase.idle;
  String? _saveSessionId;
  _SaveDraft? _lastSaveAttempt;
  _RejectedFieldWrite? _pendingFieldSettlement;
  String? _retryableUpdateAttempt;
  String? _correctableCreateAttempt;

  /// Current operation phase, separate from command admission.
  AdminSavePhase get savePhase => _savePhase;

  /// Exact session that admitted the displayed Save.
  String? get saveSessionId => _saveSessionId;

  /// Private committed files awaiting remote persistence.
  List<AdminSubmissionStagedAsset> get stagedAssets =>
      _draftSession?.state?.assets ?? const [];
  final List<AdminSubmissionAsset> _assets = <AdminSubmissionAsset>[];
  ImageUploadTask? _activeImageUploadTask;
  Completer<void>? _pickerAbandonment;
  String? _pickerNonce;

  /// Whether this Admin request is awaiting its original native callback.
  bool get pickerWaiting => _pickerNonce != null;

  /// Identity captured by the currently rendered local escape action.
  String? get pickerRequestNonce => _pickerNonce;

  /// Releases only the rendered request; native cancellation is not claimed.
  void abandonPicker({required String requestNonce}) {
    if (_pickerNonce != requestNonce) return;
    _abandonPicker();
    _notifyListeners();
  }

  void _abandonPicker() {
    final pending = _pickerAbandonment;
    _pickerNonce = null;
    _pickerAbandonment = null;
    if (pending != null && !pending.isCompleted) pending.complete();
  }

  /// Resolves committed private bytes for an owner-checked preview.
  Future<Result<File>> stagedAssetFile(AdminSubmissionStagedAsset asset) =>
      _draftSession?.resolveAssetFile(asset) ??
      Future.value(_unavailable<File>());

  /// Removes only a captured local descriptor while no mutation owns it.
  bool requestRemoveStagedAsset(
    AdminSubmissionStagedAsset asset, {
    AdminDraftActivation? activation,
  }) {
    if (!_authority(activation) ||
        !_canAdmit(_deleteCommand) ||
        _draftSession == null) {
      return false;
    }
    final ownerGeneration = _generation;
    _deleteEffectId = ++_nextEffectId;
    _deleteSnapshot = const commands.CommandResult.isLoading();
    return _admit(_deleteCommand, () async {
      if (_obsolete(ownerGeneration) || !_authority(activation)) {
        return _unavailable<void>();
      }
      final result = await _draftSession.remove(asset);
      if (!_obsolete(ownerGeneration)) _notifyListeners();
      return result;
    });
  }

  var _hasLoadedDetail = false;
  var _isDirty = false;
  var _disposed = false;

  late final ResultCommand<_EditorAction<void>, void> _loadCommand;
  commands.CommandResult<void, Result<void>?> _loadSnapshot =
      const commands.CommandResult(null, null, null, false);
  int? _loadEffectId;
  late final ResultCommand<_EditorAction<void>, void> _saveCommand;
  commands.CommandResult<void, Result<void>?> _saveSnapshot =
      const commands.CommandResult(null, null, null, false);
  int? _saveEffectId;
  late final ResultCommand<_EditorAction<void>, void> _rejectCommand;
  commands.CommandResult<void, Result<void>?> _rejectSnapshot =
      const commands.CommandResult(null, null, null, false);
  int? _rejectEffectId;
  late final ResultCommand<
    _EditorAction<AdminSubmissionPromotion>,
    AdminSubmissionPromotion
  >
  _promoteCommand;
  commands.CommandResult<void, Result<AdminSubmissionPromotion>?>
  _promoteSnapshot = const commands.CommandResult(null, null, null, false);
  int? _promoteEffectId;
  late final ResultCommand<
    _EditorAction<AdminEventResolution>,
    AdminEventResolution
  >
  _linkCommand;
  commands.CommandResult<void, Result<AdminEventResolution>?> _linkSnapshot =
      const commands.CommandResult(null, null, null, false);
  int? _linkEffectId;
  late final ResultCommand<_EditorAction<void>, void> _previewCommand;
  commands.CommandResult<void, Result<void>?> _previewSnapshot =
      const commands.CommandResult(null, null, null, false);
  int? _previewEffectId;
  late final ResultCommand<_EditorAction<void>, void> _candidatesCommand;
  commands.CommandResult<void, Result<void>?> _candidatesSnapshot =
      const commands.CommandResult(null, null, null, false);
  int? _candidatesEffectId;
  late final ResultCommand<
    _EditorAction<AdminEventResolution>,
    AdminEventResolution
  >
  _applyCommand;
  commands.CommandResult<void, Result<AdminEventResolution>?> _applySnapshot =
      const commands.CommandResult(null, null, null, false);
  int? _applyEffectId;
  late final ResultCommand<_EditorAction<void>, void> _keepCommand;
  commands.CommandResult<void, Result<void>?> _keepSnapshot =
      const commands.CommandResult(null, null, null, false);
  int? _keepEffectId;
  late final ResultCommand<_EditorAction<void>, void> _addCommand;
  commands.CommandResult<void, Result<void>?> _addSnapshot =
      const commands.CommandResult(null, null, null, false);
  int? _addEffectId;
  late final ResultCommand<_EditorAction<void>, void> _deleteCommand;
  commands.CommandResult<void, Result<void>?> _deleteSnapshot =
      const commands.CommandResult(null, null, null, false);
  int? _deleteEffectId;
  int _nextEffectId = 0;
  bool _stopped = false;
  final _reserved = Set<commands.Command<dynamic, dynamic>>.identity();
  final _released = Set<commands.Command<dynamic, dynamic>>.identity();
  final _completionObservers =
      Map<commands.Command<dynamic, dynamic>, VoidCallback>.identity();
  int _draftRevision = 0;
  int _editorRevision = 0;
  String _candidateSearch = '';
  int _candidateRevision = 0;
  AdminEventCandidates? _candidates;

  /// Candidate discovery is advisory and never changes moderation readiness.
  AdminEventCandidates? get candidates => _candidates;

  /// Desired candidate input, independent of a physically pending search.
  String get candidateSearch => _candidateSearch;

  /// Current editor context for correlating dialog confirmations.
  int get editorRevision => _editorRevision;

  /// Whether this owner has revoked admission and publication authority.
  bool get isDisposed => _disposed;

  bool _acknowledgeCurrentSource = false;
  String? _acknowledgedSourceHash;
  bool _ignoreSource = false;
  AdminSubmission? _followupSubmission;

  /// Only the currently displayed stale source revision can be acknowledged.
  bool get isSourceStale => _externalEvent?.stale ?? false;
  bool get acknowledgeCurrentSource => _acknowledgeCurrentSource;
  bool get ignoreSource => _ignoreSource;
  AdminSubmission? get followupSubmission => _followupSubmission;

  void setAcknowledgeCurrentSource({
    required bool selected,
    AdminDraftActivation? activation,
  }) {
    if (!_authority(activation)) return;
    if (!_canChangeContext) return;
    _acknowledgeCurrentSource = selected && isSourceStale;
    _acknowledgedSourceHash = _acknowledgeCurrentSource
        ? _externalEvent?.currentHash
        : null;
    _notifyListeners();
  }

  void setIgnoreSource({
    required bool ignored,
    AdminDraftActivation? activation,
  }) {
    if (!_authority(activation)) return;
    if (!_canChangeContext) return;
    _ignoreSource = ignored && _externalEvent != null;
    _notifyListeners();
  }

  AdminExternalEvent? _externalEvent;
  int? _targetEventId;
  AdminEventMergePreview? _mergePreview;
  int _previewGeneration = 0;
  int _hydrationRevision = 0;

  /// Only explicit backend reload or keep-current replaces field widget state.
  int get hydrationRevision => _hydrationRevision;

  AdminExternalEvent? get externalEvent => _externalEvent;
  bool get isExternalUpdate =>
      _externalEvent?.mode == AdminExternalEventMode.update;
  int? get targetEventId => _targetEventId;
  AdminEventMergePreview? get mergePreview => _mergePreview;

  /// Selecting a different target invalidates its preview.
  void selectTargetEvent(int? id, {AdminDraftActivation? activation}) {
    if (!_authority(activation)) return;
    if (!_canChangeContext) return;
    _targetEventId = id;
    _editorRevision++;
    _invalidatePreview();
    _invalidateCandidates();
    _notifyListeners();
  }

  /// Whether this route edits an existing persisted submission.
  bool get isEditMode => submissionId != null;

  /// Selected content category, which is normalized on save when absent.
  ContentCategory? get category => _category;

  /// Whether the persisted category is concrete enough for publication.
  bool get hasPublishableCategory =>
      _category != null && _category != ContentCategory.unknown;

  /// Editable municipality value.
  String? get city => _city;

  /// Editable place or event name.
  String? get name => _name;

  /// Editable plain-text description projection.
  String? get description => _description;

  /// Editable rich-text Delta projection.
  List<Map<String, dynamic>>? get descriptionDelta => _descriptionDelta;

  /// Event temporal state shared with the public editor.
  EventDateDraft get eventDates => _eventDates;

  /// Exact UTC event start used at the save boundary.
  DateTime? get startDate => _eventDates.startInstantUtc;

  /// Exact UTC event end used at the save boundary.
  DateTime? get endDate => _eventDates.endInstantUtc;

  /// Whether the controlled temporal draft identifies an event.
  bool get isEvent => _eventDates.enabled;

  /// Selected Rome calendar day for the event start.
  EventCalendarDate? get startCalendarDate => _eventDates.startCalendarDate;

  /// Whether the event has no meaningful initial clock.
  bool get allDay => _eventDates.allDay;

  /// Selected meaningful Rome start clock time when resolved.
  EventClockTime? get startClockTime {
    final start = _eventDates.startInstantUtc;
    return allDay || start == null
        ? null
        : _eventTimePolicy.clockTimeForUtc(start);
  }

  /// Selected Rome calendar day for the inclusive event end.
  EventCalendarDate? get endCalendarDate => _eventDates.endCalendarDate;

  /// Transient validation issue from an attempted temporal edit.
  EventTimeIssue? get eventTimeIssue => _eventTimeIssue;

  /// Raw editable latitude draft text.
  ///
  /// May be empty, partial, or invalid while the user types; validation
  /// happens at save time and in the location widget.
  String get latitudeText => _latitudeText;

  /// Raw editable longitude draft text.
  String get longitudeText => _longitudeText;

  /// Read-only contributor name from the loaded detail or create context.
  String? get contributorName => _contributorName;

  /// Read-only contributor e-mail from the loaded detail or create context.
  String? get contributorEmail => _contributorEmail;

  /// Current moderation state for an existing submission.
  AdminSubmissionStatus? get status => _status;

  /// Durable promotion linkage of the loaded submission, when promoted.
  AdminSubmissionPromotion? get promotion => _promotion;

  /// Whether this editor's content can currently be modified at all.
  ///
  /// Create mode is always editable; an existing submission stays editable
  /// only while it is pending. Accepted and rejected rows are read-only.
  bool get isEditable =>
      !_revoked &&
      (!isEditMode ||
          _status == AdminSubmissionStatus.pending ||
          (_status == null &&
              _draftSession?.state?.remoteBaseline?.status ==
                  AdminSubmissionStatus.pending));

  /// Timestamp at which the loaded submission was created.
  DateTime? get createdAt => _createdAt;

  /// Timestamp at which the loaded submission was last modified.
  DateTime? get modifiedAt => _modifiedAt;

  /// Persisted assets from the loaded detail and confirmed asset mutations.
  UnmodifiableListView<AdminSubmissionAsset> get assets =>
      UnmodifiableListView<AdminSubmissionAsset>(_assets);

  /// Whether edit-mode detail data has successfully loaded.
  bool get hasLoadedDetail => _hasLoadedDetail;

  /// Whether a detail request is in progress.
  bool get loading => _reserved.contains(_loadCommand);

  /// Whether edits have not yet been saved.
  bool get isDirty {
    final state = _draftSession?.state;
    if (state == null) return _isDirty;
    return state.remoteBaseline == null ||
        !state.current.sameRemoteProjection(state.remoteBaseline!.snapshot) ||
        state.assets.isNotEmpty ||
        state.physicalCheckpoint?.fieldWriteIntent != null;
  }

  /// Whether an asset add or delete operation is in progress.
  bool get assetMutationRunning =>
      _reserved.contains(_addCommand) || _reserved.contains(_deleteCommand);

  /// Whether an admitted operation can mutate the editor or its submission.
  bool get operationRunning => _mutations.any(_reserved.contains);

  List<commands.Command<dynamic, dynamic>> get _mutations => [
    _saveCommand,
    _rejectCommand,
    _promoteCommand,
    _linkCommand,
    _applyCommand,
    _keepCommand,
    _addCommand,
    _deleteCommand,
  ];
  List<commands.Command<dynamic, dynamic>> get _commands => [
    _loadCommand,
    ..._mutations,
    _previewCommand,
    _candidatesCommand,
  ];

  bool get _canChangeContext =>
      !_disposed && !_revoked && !loading && !operationRunning;
  bool get _canChangeFields =>
      !_disposed &&
      !_revoked &&
      (_draftSession != null || !loading) &&
      (!_mutations.any(
        (command) =>
            _reserved.contains(command) &&
            _commandGenerations[command] == _generation &&
            !identical(command, _saveCommand),
      ));

  bool _canAdmit(commands.Command<dynamic, dynamic> command) {
    if (_disposed ||
        _revoked ||
        (_draftSession != null && !(_draftSession.state?.ready ?? false)) ||
        _stopped ||
        _reserved.contains(command) ||
        loading) {
      return false;
    }
    if (identical(command, _loadCommand)) {
      return (_draftSession != null || !(_hasLoadedDetail && isDirty)) &&
          _reserved.isEmpty;
    }
    if (identical(command, _candidatesCommand)) return true;
    if (identical(command, _previewCommand)) return !operationRunning;
    return !operationRunning &&
        (!identical(command, _keepCommand) ||
            !_reserved.contains(_previewCommand));
  }

  /// Updates the selected category and marks the editor dirty.
  void setCategory(
    ContentCategory? category, {
    AdminDraftActivation? activation,
  }) {
    if (!_authority(activation)) return;
    if (!_canChangeFields) return;
    _category = category;
    _markDirty();
  }

  /// Updates the city and marks the editor dirty.
  void setCity(String? city, {AdminDraftActivation? activation}) {
    if (!_authority(activation)) return;
    if (!_canChangeFields) return;
    _city = city;
    _markDirty();
  }

  /// Updates the place or event name and marks the editor dirty.
  void setName(String? name, {AdminDraftActivation? activation}) {
    if (!_authority(activation)) return;
    if (!_canChangeFields) return;
    _name = name;
    _markDirty();
  }

  /// Updates matching plain-text and rich-text description projections.
  void setDescription({
    required String? description,
    required List<Map<String, dynamic>>? descriptionDelta,
    AdminDraftActivation? activation,
  }) {
    if (!_authority(activation)) return;
    if (!_canChangeFields) return;
    _description = description;
    _descriptionDelta = descriptionDelta;
    _markDirty();
  }

  /// Enables or disables event mode without inventing an instant.
  /// Changes precision without restoring an old or technical clock.
  void setAllDay({required bool allDay, AdminDraftActivation? activation}) {
    if (!_authority(activation)) return;
    _applyTemporalEdit(
      _eventTimePolicy.changeAllDay(_eventDates, allDay: allDay),
    );
  }

  void setEventEnabled({
    required bool enabled,
    AdminDraftActivation? activation,
  }) {
    if (!_authority(activation)) return;
    if (!_canChangeFields) return;
    if (_externalEvent != null && !enabled) return;
    _eventDates = enabled
        ? _eventTimePolicy.enable(_eventDates)
        : _eventTimePolicy.disable(_eventDates);
    _eventTimeIssue = null;
    _markDirty();
  }

  /// Changes the start's Rome calendar day while preserving exact precision.
  void setStartCalendarDate(
    EventCalendarDate date, {
    AdminDraftActivation? activation,
  }) {
    if (!_authority(activation)) return;
    _applyTemporalEdit(
      _eventTimePolicy.changeStartCalendarDate(
        _eventTimePolicy.enable(_eventDates),
        date,
      ),
    );
  }

  /// Changes the start's Rome clock time while preserving sub-minute precision.
  void setStartClockTime(
    EventClockTime time, {
    AdminDraftActivation? activation,
  }) {
    if (!_authority(activation)) return;
    final draft = _eventTimePolicy.enable(_eventDates);
    _applyTemporalEdit(_eventTimePolicy.changeStartClockTime(draft, time));
  }

  /// Changes the inclusive Rome calendar day for the event end.
  void setEndCalendarDate(
    EventCalendarDate date, {
    AdminDraftActivation? activation,
  }) {
    if (!_authority(activation)) return;
    _applyTemporalEdit(
      _eventTimePolicy.changeEndCalendarDate(
        _eventTimePolicy.enable(_eventDates),
        date,
      ),
    );
  }

  void _applyTemporalEdit(EventTimeEditResult result) {
    if (!_canChangeFields) return;
    _eventDates = result.draft;
    _eventTimeIssue = result.issue;
    _markDirty();
  }

  /// Publishes a persistence-blocking event-time issue for the controlled UI.
  ///
  /// Returns whether the current temporal draft is eligible for saving. The
  /// issue is transient and is cleared by the next valid temporal edit.
  bool validateEventTimeForSave({EventDateDraft? draft}) {
    if (_disposed) return false;
    final issue =
        _eventTimeIssue ??
        _eventTimePolicy.validateForPersistence(draft ?? _eventDates);
    if (issue == null) return true;

    if (_eventTimeIssue != issue) {
      _eventTimeIssue = issue;
      _notifyListeners();
    }
    return false;
  }

  /// Updates the raw latitude draft and marks the editor dirty.
  ///
  /// Invalid or partial text is kept as-is so it stays visible and blocks
  /// Save until corrected.
  void setLatitudeText(String value, {AdminDraftActivation? activation}) {
    if (!_authority(activation)) return;
    if (!_canChangeFields) return;
    _latitudeText = value;
    _markDirty();
  }

  /// Updates the raw longitude draft and marks the editor dirty.
  void setLongitudeText(String value, {AdminDraftActivation? activation}) {
    if (!_authority(activation)) return;
    if (!_canChangeFields) return;
    _longitudeText = value;
    _markDirty();
  }

  /// Updates both coordinate drafts from one map selection.
  ///
  /// This is one logical change: both drafts are written with six-decimal
  /// formatting and the editor is marked dirty exactly once.
  void setCoordinates(
    double latitude,
    double longitude, {
    AdminDraftActivation? activation,
  }) {
    if (!_authority(activation)) return;
    if (!_canChangeFields) return;
    _latitudeText = latitude.toStringAsFixed(6);
    _longitudeText = longitude.toStringAsFixed(6);
    _markDirty();
  }

  /// Changes desired query and invalidates older results without starting I/O.
  void setCandidateSearch(String value, {AdminDraftActivation? activation}) {
    if (!_authority(activation)) return;
    if (_disposed || value == _candidateSearch) return;
    _candidateSearch = value;
    _candidateRevision++;
    _invalidateCandidates();
    _notifyListeners();
  }

  /// Last authorized load state, frozen when the owner is revoked.
  commands.CommandResult<void, Result<void>?> get loadSnapshot => _loadSnapshot;

  /// Identity of the last admitted load execution.
  int? get loadExecutionId => _loadEffectId;

  /// Whether load can synchronously reserve its operation.
  bool get canRequestLoad => _canAdmit(_loadCommand);

  /// Last authorized save state, frozen when the owner is revoked.
  commands.CommandResult<void, Result<void>?> get saveSnapshot => _saveSnapshot;

  /// Identity of the last admitted save execution.
  int? get saveExecutionId => _saveEffectId;

  /// Whether save can synchronously reserve its operation.
  bool get canRequestSave =>
      _canAdmit(_saveCommand) &&
      _pendingFieldSettlement == null &&
      !_remoteUnavailable &&
      (_draftSession?.state?.physicalCheckpoint?.fieldWriteIntent?.kind !=
              AdminFieldWriteKind.update ||
          _confirmedFields != null);

  /// Whether explicit continuation can retain captured fields and staged work.
  bool get canResumeCapturedSave {
    final pending = _draftSession?.state?.physicalCheckpoint?.fieldWriteIntent;
    if (_pendingFieldSettlement == null &&
        _canAdmit(_saveCommand) &&
        !_remoteUnavailable &&
        pending?.kind == AdminFieldWriteKind.update &&
        pending?.attemptId == _retryableUpdateAttempt) {
      return true;
    }
    if (!canRequestSave) return false;
    if (_draftSession?.state?.physicalCheckpoint?.fieldWriteIntent?.kind ==
            AdminFieldWriteKind.create ||
        _confirmedFields != null) {
      return true;
    }
    final previous = _lastSaveAttempt;
    if (previous != null) {
      final captured = previous.assets.map((item) => item.digest).toSet();
      return stagedAssets.any((item) => captured.contains(item.digest));
    }
    return _hasLoadedDetail &&
        stagedAssets.isNotEmpty &&
        _draftSession?.state?.remoteBaseline?.modifiedAtToken != null;
  }

  _SaveDraft _captureContinuation(_SaveDraft current) {
    final intent = _draftSession?.state?.physicalCheckpoint?.fieldWriteIntent;
    if (intent != null) {
      return (
        input: _inputFor(intent.snapshot),
        error: null,
        issue: null,
        revision: current.revision,
        snapshot: intent.snapshot,
        assets: current.assets,
        physicalCheckpoint: current.physicalCheckpoint,
      );
    }
    final previous = _lastSaveAttempt;
    if (previous != null) {
      final remaining = stagedAssets.map((item) => item.digest).toSet();
      return (
        input: previous.input,
        error: null,
        issue: null,
        revision: previous.revision,
        snapshot: previous.snapshot,
        assets: previous.assets
            .where((item) => remaining.contains(item.digest))
            .toList(growable: false),
        physicalCheckpoint: previous.physicalCheckpoint,
      );
    }
    final baseline = _draftSession!.state!.remoteBaseline!;
    return (
      input: _inputFor(baseline.snapshot),
      error: null,
      issue: null,
      revision: current.revision,
      snapshot: baseline.snapshot,
      assets: current.assets,
      physicalCheckpoint: current.physicalCheckpoint,
    );
  }

  /// Physical Save reservation, including its synchronous admission turn.
  bool get isSaveRunning => _reserved.contains(_saveCommand);

  /// Explicit observation is the only recovery for unresolved Update intent.
  bool get canRequestSaveReadBack =>
      _pendingFieldSettlement == null &&
      _canAdmit(_loadCommand) &&
      _draftSession?.state?.physicalCheckpoint?.fieldWriteIntent?.kind ==
          AdminFieldWriteKind.update;

  /// Reads back captured A without resending an uncertain Update.
  bool requestSaveReadBack({AdminDraftActivation? activation}) {
    if (!_authority(activation) || !canRequestSaveReadBack) return false;
    _loadEffectId = ++_nextEffectId;
    _loadSnapshot = const commands.CommandResult.isLoading();
    return _admit(_loadCommand, _readBackSave);
  }

  /// Local-only repair of a proven rejection whose metadata commit failed.
  bool get canRequestFieldSettlement =>
      _pendingFieldSettlement != null && _canAdmit(_saveCommand);

  /// A rejected/fenced write cannot reuse its cached field-version authority.
  bool get canRefreshSaveAuthority =>
      _remoteUnavailable &&
      _pendingFieldSettlement == null &&
      _draftSession?.state?.physicalCheckpoint?.fieldWriteIntent == null &&
      canRequestLoad;

  bool requestFieldSettlement({AdminDraftActivation? activation}) {
    if (!_authority(activation) || !canRequestFieldSettlement) return false;
    final rejected = _pendingFieldSettlement!;
    _saveSessionId = sessionId;
    _saveEffectId = ++_nextEffectId;
    _saveSnapshot = const commands.CommandResult.isLoading();
    return _admit(
      _saveCommand,
      () => _settleRejectedWrite(rejected, activation!),
    );
  }

  /// Last authorized reject state, frozen when the owner is revoked.
  commands.CommandResult<void, Result<void>?> get rejectSnapshot =>
      _rejectSnapshot;

  /// Identity of the last admitted reject execution.
  int? get rejectExecutionId => _rejectEffectId;

  /// Whether reject can synchronously reserve its operation.
  bool get canRequestReject => _canAdmit(_rejectCommand);

  /// Last authorized promote state, frozen when the owner is revoked.
  commands.CommandResult<void, Result<AdminSubmissionPromotion>?>
  get promoteSnapshot => _promoteSnapshot;

  /// Identity of the last admitted promote execution.
  int? get promoteExecutionId => _promoteEffectId;

  /// Whether promote can synchronously reserve its operation.
  bool get canRequestPromote => _canAdmit(_promoteCommand);

  /// Last authorized link state, frozen when the owner is revoked.
  commands.CommandResult<void, Result<AdminEventResolution>?>
  get linkSnapshot => _linkSnapshot;

  /// Identity of the last admitted link execution.
  int? get linkExecutionId => _linkEffectId;

  /// Whether link can synchronously reserve its operation.
  bool get canRequestLink => _canAdmit(_linkCommand);

  /// Last authorized preview state, frozen when the owner is revoked.
  commands.CommandResult<void, Result<void>?> get previewSnapshot =>
      _previewSnapshot;

  /// Identity of the last admitted preview execution.
  int? get previewExecutionId => _previewEffectId;

  /// Whether preview can synchronously reserve its operation.
  bool get canRequestPreview => _canAdmit(_previewCommand);

  /// Last authorized findCandidates state, frozen when the owner is revoked.
  commands.CommandResult<void, Result<void>?> get findCandidatesSnapshot =>
      _candidatesSnapshot;

  /// Identity of the last admitted findCandidates execution.
  int? get findCandidatesExecutionId => _candidatesEffectId;

  /// Whether findCandidates can synchronously reserve its operation.
  bool get canRequestFindCandidates => _canAdmit(_candidatesCommand);

  /// Last authorized apply state, frozen when the owner is revoked.
  commands.CommandResult<void, Result<AdminEventResolution>?>
  get applySnapshot => _applySnapshot;

  /// Identity of the last admitted apply execution.
  int? get applyExecutionId => _applyEffectId;

  /// Whether apply can synchronously reserve its operation.
  bool get canRequestApply => _canAdmit(_applyCommand);

  /// Last authorized keepCurrent state, frozen when the owner is revoked.
  commands.CommandResult<void, Result<void>?> get keepCurrentSnapshot =>
      _keepSnapshot;

  /// Identity of the last admitted keepCurrent execution.
  int? get keepCurrentExecutionId => _keepEffectId;

  /// Whether keepCurrent can synchronously reserve its operation.
  bool get canRequestKeepCurrent => _canAdmit(_keepCommand);

  /// Last authorized addAsset state, frozen when the owner is revoked.
  commands.CommandResult<void, Result<void>?> get addAssetSnapshot =>
      _addSnapshot;

  /// Identity of the last admitted addAsset execution.
  int? get addAssetExecutionId => _addEffectId;

  /// Whether addAsset can synchronously reserve its operation.
  bool get canRequestAddAsset => _canAdmit(_addCommand);

  /// Last authorized deleteAsset state, frozen when the owner is revoked.
  commands.CommandResult<void, Result<void>?> get deleteAssetSnapshot =>
      _deleteSnapshot;

  /// Identity of the last admitted deleteAsset execution.
  int? get deleteAssetExecutionId => _deleteEffectId;

  /// Whether deleteAsset can synchronously reserve its operation.
  bool get canRequestDeleteAsset => _canAdmit(_deleteCommand);

  /// Reserves an exclusive initial or explicit detail refresh.
  bool requestLoad({AdminDraftActivation? activation}) {
    if (!_authority(activation)) return false;
    if (!canRequestLoad) return false;
    _loadEffectId = ++_nextEffectId;
    _loadSnapshot = const commands.CommandResult.isLoading();
    return _admit(_loadCommand, _loadDetail);
  }

  /// Captures the complete current draft before notifying or deferred entry.
  bool requestSave({
    AdminDraftActivation? activation,
    bool resumeCaptured = false,
  }) {
    if (!_authority(activation)) return false;
    final allowedResume = resumeCaptured && canResumeCapturedSave;
    if ((!canRequestSave && !allowedResume) ||
        (resumeCaptured && !allowedResume)) {
      return false;
    }
    var draft = _captureSave();
    final pending = _draftSession?.state?.physicalCheckpoint?.fieldWriteIntent;
    final correctingCreate =
        !resumeCaptured &&
        draft.error == null &&
        pending?.kind == AdminFieldWriteKind.create &&
        pending?.attemptId == _correctableCreateAttempt;
    final retryUpdate = allowedResume ? _retryableUpdateAttempt : null;
    if (!correctingCreate &&
        (resumeCaptured ||
            _draftSession?.state?.physicalCheckpoint?.fieldWriteIntent !=
                null)) {
      draft = _captureContinuation(draft);
    }
    if (draft.error == null) _lastSaveAttempt = draft;
    _saveSessionId = sessionId;
    _savePhase = AdminSavePhase.checkpoint;
    _saveEffectId = ++_nextEffectId;
    _saveSnapshot = const commands.CommandResult.isLoading();
    _retryableUpdateAttempt = null;
    return _admit(
      _saveCommand,
      () => _save(
        draft,
        retryUpdateAttempt: retryUpdate,
        replaceCreateAttempt: correctingCreate ? pending!.attemptId : null,
      ),
    );
  }

  /// Reserves rejection with immutable source acknowledgment.
  bool requestReject({AdminDraftActivation? activation}) {
    if (!_authority(activation)) return false;
    if (!canRequestReject) return false;
    final guard = _moderationGuardError();
    final source = _sourceAcknowledgment;
    _rejectEffectId = ++_nextEffectId;
    _rejectSnapshot = const commands.CommandResult.isLoading();
    return _admit(_rejectCommand, () => _reject(guard, source));
  }

  /// Reserves publication to the explicitly selected target.
  bool requestPromote(
    AdminPromotionTarget target, {
    AdminDraftActivation? activation,
  }) {
    if (!_authority(activation)) return false;
    if (!canRequestPromote) return false;
    var guard = _moderationGuardError();
    EventTimeIssue? issue;
    if (guard == null && !hasPublishableCategory) {
      guard = Exception('Seleziona una categoria e salva prima di pubblicare.');
    }
    if (guard == null && target == AdminPromotionTarget.event) {
      issue =
          _eventTimeIssue ??
          _eventTimePolicy.validateForPersistence(
            _eventTimePolicy.enable(_eventDates),
          );
      if (issue != null) {
        guard = Exception(
          'Completa i dati temporali prima di pubblicare l’evento.',
        );
      }
    }
    final source = _sourceAcknowledgment;
    _promoteEffectId = ++_nextEffectId;
    _promoteSnapshot = const commands.CommandResult.isLoading();
    return _admit(_promoteCommand, () {
      if (!_disposed && issue != null) {
        _eventTimeIssue = issue;
        _notifyListeners();
      }
      return _promote(target, guard, source);
    });
  }

  /// Reserves a link without copying canonical Event fields or media.
  bool requestLink(int target, {AdminDraftActivation? activation}) {
    if (!_authority(activation)) return false;
    if (!canRequestLink) return false;
    final guard =
        _moderationGuardError() ??
        (startDate == null
            ? Exception('Imposta una data di inizio per collegare un evento.')
            : null);
    final source = _sourceAcknowledgment;
    _linkEffectId = ++_nextEffectId;
    _linkSnapshot = const commands.CommandResult.isLoading();
    return _admit(_linkCommand, () => _link(target, guard, source));
  }

  /// Captures current target and generation for an explicit preview.
  bool requestPreview({AdminDraftActivation? activation}) {
    if (!_authority(activation)) return false;
    if (!canRequestPreview) return false;
    final target = _targetEventId;
    final generation = _previewGeneration;
    final eligible = submissionId != null && target != null && !isDirty;
    _previewEffectId = ++_nextEffectId;
    _previewSnapshot = const commands.CommandResult.isLoading();
    return _admit(
      _previewCommand,
      () => _preview(target, generation, eligible: eligible),
    );
  }

  /// Searches desired input; refusal has no observable side effects.
  bool requestFindCandidates({AdminDraftActivation? activation}) {
    if (!_authority(activation)) return false;
    if (!canRequestFindCandidates) return false;
    final search = _candidateSearch.trim();
    final revision = _candidateRevision;
    final context = _editorRevision;
    final eligible = submissionId != null && startDate != null;
    _candidatesEffectId = ++_nextEffectId;
    _candidatesSnapshot = const commands.CommandResult.isLoading();
    return _admit(
      _candidatesCommand,
      () => _findCandidates(search, eligible, revision, context),
    );
  }

  /// Captures opaque preview tokens and source acknowledgment unchanged.
  bool requestApply({AdminDraftActivation? activation}) {
    if (!_authority(activation)) return false;
    if (!canRequestApply) return false;
    final guard = _moderationGuardError();
    final value = _mergePreview;
    final external = isExternalUpdate;
    final source = _sourceAcknowledgment;
    _applyEffectId = ++_nextEffectId;
    _applySnapshot = const commands.CommandResult.isLoading();
    return _admit(_applyCommand, () => _apply(value, external, guard, source));
  }

  /// Owns one complete copy, private persistence and private preview chain.
  bool requestKeepCurrent(
    AdminEventMergeGroup group, {
    AdminDraftActivation? activation,
  }) {
    if (!_authority(activation)) return false;
    if (!canRequestKeepCurrent) return false;
    final preview = _mergePreview;
    final target = _targetEventId;
    final generation = _previewGeneration;
    final eligible =
        isEditable &&
        !isDirty &&
        preview?.groups.any((value) => identical(value, group)) == true;
    _keepEffectId = ++_nextEffectId;
    _keepSnapshot = const commands.CommandResult.isLoading();
    return _admit(
      _keepCommand,
      () => _keepCurrent(
        group,
        eligible,
        target: target,
        generation: generation,
        preview: preview,
      ),
    );
  }

  /// Reserves picker, upload and persisted association as one attempt.
  bool requestAddAsset({AdminDraftActivation? activation}) {
    if (!_authority(activation)) return false;
    if (!canRequestAddAsset) return false;
    final guard = _assetGuard(add: true);
    _addEffectId = ++_nextEffectId;
    _addSnapshot = const commands.CommandResult.isLoading();
    return _admit(_addCommand, () => _addAsset(guard));
  }

  /// Reserves removal of the exact captured persisted association.
  bool requestDeleteAsset(int assetId, {AdminDraftActivation? activation}) {
    if (!_authority(activation)) return false;
    if (!canRequestDeleteAsset) return false;
    final guard =
        _assetGuard(add: false) ??
        (!_assets.any((asset) => asset.id == assetId)
            ? Exception('La foto non appartiene al contributo.')
            : null);
    _deleteEffectId = ++_nextEffectId;
    _deleteSnapshot = const commands.CommandResult.isLoading();
    return _admit(_deleteCommand, () => _deleteAsset(assetId, guard));
  }

  _SourceAcknowledgment get _sourceAcknowledgment => (
    acknowledge: _acknowledgeCurrentSource ? true : null,
    hash: _acknowledgedSourceHash,
    ignore: _ignoreSource ? true : null,
  );

  AdminDraftSnapshot _snapshotFor(AdminSubmission submission) {
    final start = submission.startDate?.toUtc();
    final end = submission.endDate?.toUtc();
    final dates = switch ((start, end)) {
      (final start?, final end) => EventDateDraft.exact(
        startCalendarDate: _eventTimePolicy.calendarDateForUtc(start),
        startInstantUtc: start,
        endInstantUtc: end,
        allDay: submission.allDay,
      ),
      (null, null) => const EventDateDraft.disabled(),
      _ => throw StateError('Persisted end date without start date.'),
    };
    return AdminDraftSnapshot(
      category: submission.category,
      city: submission.city,
      name: submission.name,
      description: submission.description,
      descriptionDelta: submission.descriptionDelta,
      eventDates: dates,
      latitudeText: submission.latitude?.toString() ?? '',
      longitudeText: submission.longitude?.toString() ?? '',
    );
  }

  AdminRemoteBaseline _baselineFor(AdminSubmission detail) =>
      AdminRemoteBaseline(
        snapshot: _snapshotFor(detail),
        status: detail.status,
        modifiedAt: detail.modifiedAt,
        modifiedAtToken: detail.modifiedAtToken,
      );

  void _publishDetail(
    AdminSubmission detail, {
    bool completeAssets = true,
    bool replaceSelection = false,
  }) {
    _contributorName = detail.userName;
    _contributorEmail = detail.userEmail;
    _status = detail.status;
    _promotion = detail.promotion;
    _externalEvent = detail.externalEvent;
    if (replaceSelection) {
      _targetEventId = detail.externalEvent?.eventId ?? detail.targetEventId;
    }
    _createdAt = detail.createdAt;
    _modifiedAt = detail.modifiedAt;
    _modifiedAtToken = detail.modifiedAtToken;
    if (completeAssets) {
      _assets
        ..clear()
        ..addAll(detail.assets);
    }
    _hasLoadedDetail = true;
    _editorRevision++;
    _invalidateCandidates();
    _invalidatePreview();
  }

  Future<Result<void>> _loadDetail() async {
    final ownerGeneration = _generation;
    final id = submissionId;
    if (id == null) return const Result.success(null);
    final session = _draftSession;
    final token = session?.admitHydration();
    final revision = _draftRevision;
    final result = await _repository.getById(id);
    if (_obsolete(ownerGeneration)) return _unavailable();
    if (result case Error<AdminSubmission>(:final error)) {
      if (session != null) _remoteUnavailable = true;
      if (session != null && token != null) {
        await session.rejectHydration(token, error);
      }
      return Result.error(error);
    }
    final detail = (result as Success<AdminSubmission>).value;
    if (session != null) {
      if (token == null) return _unavailable();
      final accepted = await session.acceptHydration(
        token,
        _baselineFor(detail),
        associatedCount: detail.assets.length,
      );
      if (_obsolete(ownerGeneration)) return _unavailable();
      if (accepted case Error<bool>(:final error)) return Result.error(error);
      _remoteUnavailable = !(accepted as Success<bool>).value;
      _publishDetail(detail, replaceSelection: true);
      if (_remoteUnavailable) {
        _savePhase = AdminSavePhase.conflict;
        _notifyListeners();
        return Result.error(
          Exception(
            'La bozza locale è protetta. '
            'Ricarica per verificare il contenuto remoto.',
          ),
        );
      }
    } else {
      if (_draftRevision != revision) return const Result.success(null);
      _legacySnapshot = _snapshotFor(detail);
      _publishDetail(detail, replaceSelection: true);
      _isDirty = false;
    }
    _hydrationRevision++;
    _eventTimeIssue = null;
    _notifyListeners();
    return const Result.success(null);
  }

  // These codes are proven by this endpoint's validation/zero-row branches.
  // They describe one request, never all requests for a restored intent.
  bool _preDispatchRejection(Exception error) =>
      error is AdminContentSubmissionApiException &&
      ((error.statusCode == 400 && error.code == 'VALIDATION_ERROR') ||
          (error.statusCode == 422 &&
              error.code == 'ADMIN_PROFILE_INCOMPLETE'));

  bool _definitiveFieldRejection(Exception error, AdminFieldWriteKind kind) =>
      _preDispatchRejection(error) ||
      (kind == AdminFieldWriteKind.update &&
          error is AdminContentSubmissionApiException &&
          ((error.statusCode == 409 &&
                  const [
                    'SUBMISSION_CHANGED',
                    'INVALID_STATUS_TRANSITION',
                  ].contains(error.code)) ||
              (error.statusCode == 422 &&
                  error.code == 'START_DATE_REQUIRED') ||
              (error.statusCode == 404 && error.code == 'NOT_FOUND')));

  Future<Result<void>> _settleRejectedWrite(
    _RejectedFieldWrite rejected,
    AdminDraftActivation token,
  ) async {
    final generation = _generation;
    if (!_authority(token)) return _unavailable();
    _pendingFieldSettlement = rejected;
    _retryableUpdateAttempt = null;
    final saved = await _draftSession!.settleFieldWriteIntent(
      activation: token,
      attemptId: rejected.intent.attemptId,
      kind: rejected.intent.kind,
    );
    if (_obsolete(generation) || !_authority(token)) return _unavailable();
    if (saved is Error<void>) {
      _phase(AdminSavePhase.partialFailure);
      return saved;
    }
    _pendingFieldSettlement = null;
    _confirmedFields = null;
    _lastSaveAttempt = null;
    _correctableCreateAttempt = null;
    if (rejected.intent.kind == AdminFieldWriteKind.update) {
      _modifiedAtToken = null;
      _remoteUnavailable = true;
    }
    _phase(rejected.conflict ? AdminSavePhase.conflict : AdminSavePhase.failed);
    // Settlement is local repair, not a successful remote Save.
    return Result.error(rejected.error);
  }

  Future<Result<void>> _fieldWriteFailed(
    AdminFieldWriteIntent intent,
    Exception error,
    AdminDraftActivation token, {
    required bool noEarlierDispatch,
  }) async {
    if (noEarlierDispatch && _definitiveFieldRejection(error, intent.kind)) {
      return await _settleRejectedWrite((
        intent: intent,
        error: error,
        conflict: intent.kind == AdminFieldWriteKind.update,
      ), token);
    }
    if (intent.kind == AdminFieldWriteKind.create &&
        _preDispatchRejection(error)) {
      // Keep the uncertain chain. Explicit correction still uses its UUID.
      _correctableCreateAttempt = intent.attemptId;
    }
    _phase(AdminSavePhase.unknownOutcome);
    return Result.error(error);
  }

  Future<Result<void>> _readBackSave() async {
    final ownerGeneration = _generation;
    final token = activation;
    final session = _draftSession;
    final intent = session?.state?.physicalCheckpoint?.fieldWriteIntent;
    final id = submissionId;
    if (token == null ||
        session == null ||
        id == null ||
        intent?.kind != AdminFieldWriteKind.update) {
      return _unavailable();
    }
    _retryableUpdateAttempt = null;
    final result = await _repository.getById(id);
    if (_obsolete(ownerGeneration) || !_authority(token)) return _unavailable();
    if (result case Error<AdminSubmission>(:final error)) {
      final missing =
          error is AdminContentSubmissionApiException &&
          error.statusCode == 404 &&
          error.code == 'NOT_FOUND';
      if (missing) _remoteUnavailable = true;
      _phase(missing ? AdminSavePhase.conflict : AdminSavePhase.unknownOutcome);
      return Result.error(error);
    }
    final detail = (result as Success<AdminSubmission>).value;
    _publishDetail(detail);
    final compatible =
        detail.status == AdminSubmissionStatus.pending &&
        detail.modifiedAtToken != null &&
        !(detail.externalEvent != null &&
            intent!.snapshot.eventDates.startInstantUtc == null);
    final matches = intent!.snapshot.sameRemoteProjection(_snapshotFor(detail));
    if (compatible &&
        !matches &&
        detail.modifiedAtToken == intent.expectedModifiedAt) {
      // Observation does not cancel old HTTP. Only original A/V is retryable.
      _retryableUpdateAttempt = intent.attemptId;
      _remoteUnavailable = false;
      _phase(AdminSavePhase.unknownOutcome);
      return const Result.success(null);
    }
    if (!compatible || !matches) {
      if (detail.modifiedAtToken != null &&
          detail.modifiedAtToken != intent.expectedModifiedAt) {
        // V is obsolete: an old A/V cannot apply after this observed version.
        // This does not claim that A never committed historically.
        return await _settleRejectedWrite((
          intent: intent,
          error: Exception(
            'Il contributo remoto è cambiato. Conserva la bozza.',
          ),
          conflict: true,
        ), token);
      }
      _savePhase = AdminSavePhase.conflict;
      _remoteUnavailable = true;
      _notifyListeners();
      return Result.error(
        Exception('Esito remoto non confermato: conserva la bozza e ricarica.'),
      );
    }
    final confirmed = await session.confirmFieldWrite(
      activation: token,
      attemptId: intent.attemptId,
      baseline: _baselineFor(detail),
    );
    if (_obsolete(ownerGeneration)) return _unavailable();
    if (confirmed is Success<void>) {
      _confirmedFields = null;
      _lastSaveAttempt = null;
      _remoteUnavailable = false;
      _savePhase = stagedAssets.isEmpty
          ? AdminSavePhase.completed
          : AdminSavePhase.partialFailure;
    }
    _notifyListeners();
    return confirmed;
  }

  _SaveDraft _captureSave() {
    Exception? error;
    if (isEditMode && _status != AdminSubmissionStatus.pending) {
      error = Exception(
        'I contributi pubblicati o rifiutati non sono modificabili.',
      );
    }
    final city = _city;
    final name = _name;
    if (city == null ||
        city.trim().isEmpty ||
        name == null ||
        name.trim().isEmpty) {
      error ??= Exception('Compila i campi obbligatori.');
    }
    final issue =
        _eventTimeIssue ?? _eventTimePolicy.validateForPersistence(_eventDates);
    if (issue != null) {
      error ??= Exception('Inserisci un intervallo di date valido.');
    }
    final coordinates = _parsedCoordinates();
    if (coordinates == null) {
      error ??= Exception('Inserisci coordinate valide.');
    }
    final input = error == null
        ? AdminSubmissionInput(
            category: _category ?? ContentCategory.unknown,
            city: city!,
            name: name!,
            description: _description,
            descriptionDelta: _descriptionDelta,
            allDay: _eventDates.allDay,
            startDate: _eventDates.startInstantUtc,
            endDate: _eventDates.endInstantUtc,
            latitude: coordinates!.$1,
            longitude: coordinates.$2,
          )
        : null;
    return (
      input: input,
      error: error,
      issue: issue,
      revision: _draftRevision,
      snapshot: _fields,
      assets: List.unmodifiable(stagedAssets),
      physicalCheckpoint: _draftSession?.state?.physicalCheckpoint,
    );
  }

  AdminSubmissionInput _inputFor(AdminDraftSnapshot fields) {
    double? coordinate(String value) => value.trim().isEmpty
        ? null
        : double.parse(value.trim().replaceFirst(',', '.'));
    return AdminSubmissionInput(
      category: fields.category ?? ContentCategory.unknown,
      city: fields.city!,
      name: fields.name!,
      description: fields.description,
      descriptionDelta: fields.descriptionDelta,
      allDay: fields.eventDates.allDay,
      startDate: fields.eventDates.startInstantUtc,
      endDate: fields.eventDates.endInstantUtc,
      latitude: coordinate(fields.latitudeText),
      longitude: coordinate(fields.longitudeText),
    );
  }

  void _phase(AdminSavePhase phase) {
    _savePhase = phase;
    _notifyListeners();
  }

  Future<Result<void>> _save(
    _SaveDraft draft, {
    String? retryUpdateAttempt,
    String? replaceCreateAttempt,
  }) async {
    final ownerGeneration = _generation;
    final session = _draftSession;
    if (session == null) {
      if (draft.error != null) {
        if (draft.issue != null && draft.revision == _draftRevision) {
          _eventTimeIssue = draft.issue;
          _notifyListeners();
        }
        return Result.error(draft.error!);
      }
      final id = submissionId;
      final Result<dynamic> result = id == null
          ? await _repository.create(draft.input!)
          : await _repository.update(
              id,
              draft.input!,
              expectedModifiedAt: _modifiedAtToken,
            );
      if (_obsolete(ownerGeneration)) return _unavailable();
      return result.map((_) {
        _isDirty = _draftRevision != draft.revision;
        _contextCommitted();
      });
    }
    var token = activation;
    if (token == null) return _unavailable();
    var intent = session.state?.physicalCheckpoint?.fieldWriteIntent;
    // Only an intent first captured by this invocation has no earlier sender.
    // Restored, replayed and corrected Create chains remain conservative.
    final noEarlierDispatch = intent == null && replaceCreateAttempt == null;
    if (intent?.kind == AdminFieldWriteKind.update &&
        _confirmedFields == null &&
        intent?.attemptId != retryUpdateAttempt) {
      _phase(AdminSavePhase.unknownOutcome);
      return Result.error(
        Exception('Verifica il salvataggio remoto prima di riprovare.'),
      );
    }
    if (draft.error != null && intent == null) {
      _phase(AdminSavePhase.failed);
      return Result.error(draft.error!);
    }
    final capturedDigests = draft.assets
        .map((item) => item.digest)
        .toList(growable: false);
    final baseline = session.state?.remoteBaseline;
    if (replaceCreateAttempt != null) {
      if (intent?.kind != AdminFieldWriteKind.create ||
          intent?.attemptId != replaceCreateAttempt ||
          draft.error != null) {
        return _unavailable();
      }
      intent = AdminFieldWriteIntent(
        kind: AdminFieldWriteKind.create,
        attemptId: AdminDraftOwner(accountId: token.owner.accountId).sessionId,
        snapshot: draft.snapshot,
      );
    }
    final skipFields =
        intent == null &&
        submissionId != null &&
        baseline?.modifiedAtToken != null &&
        draft.snapshot.sameRemoteProjection(baseline!.snapshot);
    if (!skipFields) {
      if (intent == null) {
        final id = submissionId;
        if (id != null && (!_hasLoadedDetail || _modifiedAtToken == null)) {
          _phase(AdminSavePhase.failed);
          return Result.error(
            Exception('Ricarica il contributo prima di salvare.'),
          );
        }
        intent = AdminFieldWriteIntent(
          kind: id == null
              ? AdminFieldWriteKind.create
              : AdminFieldWriteKind.update,
          attemptId: AdminDraftOwner(
            accountId: token.owner.accountId,
          ).sessionId,
          snapshot: draft.snapshot,
          expectedModifiedAt: id == null ? null : _modifiedAtToken,
        );
      }
      _phase(AdminSavePhase.checkpoint);
      if (_obsolete(ownerGeneration) || !_authority(token)) {
        return _unavailable();
      }
      final checkpoint = replaceCreateAttempt == null
          ? await session.beginFieldWrite(
              intent,
              activation: token,
              checkpointAtCapture: draft.physicalCheckpoint,
            )
          : await session.replaceRejectedCreateIntent(
              activation: token,
              attemptId: replaceCreateAttempt,
              replacement: intent,
              checkpointAtCapture: draft.physicalCheckpoint,
            );
      if (_obsolete(ownerGeneration) || !_authority(token)) {
        return _unavailable();
      }
      if (checkpoint is Error<void>) {
        _phase(AdminSavePhase.failed);
        return checkpoint;
      }
      if (replaceCreateAttempt != null) _correctableCreateAttempt = null;
      _phase(AdminSavePhase.fields);
      if (_obsolete(ownerGeneration) || !_authority(token)) {
        return _unavailable();
      }
      var confirmation = _confirmedFields;
      if (confirmation == null || confirmation.intent != intent) {
        final id = submissionId;
        late final AdminSubmission detail;
        var replayed = false;
        if (intent.kind == AdminFieldWriteKind.create) {
          final created = await _repository.create(
            _inputFor(intent.snapshot),
            clientSubmissionId: token.owner.sessionId,
          );
          if (_obsolete(ownerGeneration) || !_authority(token)) {
            return _unavailable();
          }
          if (created case Error<AdminSubmissionCreateResult>(:final error)) {
            return await _fieldWriteFailed(
              intent,
              error,
              token,
              noEarlierDispatch: noEarlierDispatch,
            );
          }
          final value = (created as Success<AdminSubmissionCreateResult>).value;
          detail = value.submission;
          replayed = value.replayed;
        } else {
          final updated = await _repository.update(
            id!,
            _inputFor(intent.snapshot),
            expectedModifiedAt: intent.expectedModifiedAt,
          );
          if (_obsolete(ownerGeneration) || !_authority(token)) {
            return _unavailable();
          }
          if (updated case Error<AdminSubmission>(:final error)) {
            return await _fieldWriteFailed(
              intent,
              error,
              token,
              noEarlierDispatch: noEarlierDispatch,
            );
          }
          detail = (updated as Success<AdminSubmission>).value;
        }
        confirmation = (intent: intent, detail: detail, replayed: replayed);
        _confirmedFields = confirmation;
      }
      final detail = confirmation.detail;
      final compatible =
          intent.snapshot.sameRemoteProjection(_snapshotFor(detail)) &&
          detail.status == AdminSubmissionStatus.pending;
      _phase(AdminSavePhase.adoption);
      if (_obsolete(ownerGeneration) || !_authority(token)) {
        return _unavailable();
      }
      final settled = intent.kind == AdminFieldWriteKind.create
          ? await session.adoptRemoteIdentity(
              activation: token,
              attemptId: intent.attemptId,
              submissionId: detail.id,
              baseline: _baselineFor(detail),
            )
          : await session.confirmFieldWrite(
              activation: token,
              attemptId: intent.attemptId,
              baseline: _baselineFor(detail),
            );
      if (_obsolete(ownerGeneration)) return _unavailable();
      if (settled is Error<void>) {
        _phase(AdminSavePhase.partialFailure);
        return settled;
      }
      token = activation;
      if (token == null) return _unavailable();
      _confirmedFields = null;
      _publishDetail(
        detail,
        completeAssets: intent.kind == AdminFieldWriteKind.create,
      );
      if (!compatible) {
        _remoteUnavailable = true;
        _phase(AdminSavePhase.conflict);
        return Result.error(
          Exception(
            'Il contributo remoto è cambiato. La bozza locale è conservata.',
          ),
        );
      }
    } else {
      final checkpoint = await session.checkpoint(requireDurableOwner: true);
      if (_obsolete(ownerGeneration) || !_authority(token)) {
        return _unavailable();
      }
      if (checkpoint is Error<void>) {
        _phase(AdminSavePhase.failed);
        return checkpoint;
      }
    }
    final remoteId = token.owner.submissionId;
    if (remoteId == null) return _unavailable();
    for (final digest in capturedDigests) {
      if (_obsolete(ownerGeneration) || !_authority(token)) {
        return _unavailable();
      }
      final matches = stagedAssets.where((item) => item.digest == digest);
      if (matches.isEmpty) {
        _phase(AdminSavePhase.partialFailure);
        return Result.error(
          Exception('La foto selezionata non è più disponibile.'),
        );
      }
      var asset = matches.single;
      if (asset.progressInvalid) {
        _phase(AdminSavePhase.partialFailure);
        return Result.error(
          Exception('Conferma locale della foto non leggibile.'),
        );
      }
      var progress = _liveReceipts[digest] ?? asset.progress;
      if (progress == null) {
        _phase(AdminSavePhase.upload);
        if (_obsolete(ownerGeneration) || !_authority(token)) {
          return _unavailable();
        }
        final file = await session.resolveAssetFile(asset);
        if (_obsolete(ownerGeneration) || !_authority(token)) {
          return _unavailable();
        }
        if (file case Error<File>(:final error)) {
          _phase(AdminSavePhase.partialFailure);
          return Result.error(error);
        }
        final task = _contentSubmissionRepository.uploadImageTask(
          (file as Success<File>).value,
        );
        _activeImageUploadTask = task;
        late final Result<SubmissionAsset> uploaded;
        try {
          uploaded = await task.result;
        } finally {
          if (identical(_activeImageUploadTask, task)) {
            _activeImageUploadTask = null;
          }
        }
        if (_obsolete(ownerGeneration) || !_authority(token)) {
          return _unavailable();
        }
        if (uploaded case Error(:final error)) {
          _phase(AdminSavePhase.partialFailure);
          return Result.error(error);
        }
        progress = AdminStagedAssetProgress(
          upload: (uploaded as Success<SubmissionAsset>).value,
        );
        _liveReceipts[digest] = progress;
      }
      var persisted = await session.saveAssetProgress(
        asset,
        progress,
        activation: token,
      );
      if (_obsolete(ownerGeneration) || !_authority(token)) {
        return _unavailable();
      }
      if (persisted is Error<void>) {
        _phase(AdminSavePhase.partialFailure);
        return persisted;
      }
      if (progress.associationId == null) {
        _phase(AdminSavePhase.association);
        if (_obsolete(ownerGeneration) || !_authority(token)) {
          return _unavailable();
        }
        final associated = await _repository.associateStagedAsset(
          remoteId,
          progress.upload,
        );
        if (_obsolete(ownerGeneration) || !_authority(token)) {
          return _unavailable();
        }
        if (associated case Error<AdminSubmissionAsset>(:final error)) {
          final terminal =
              error is AdminContentSubmissionApiException &&
              const {
                'NOT_FOUND',
                'INVALID_STATUS_TRANSITION',
                'ASSET_LIMIT_REACHED',
                'ASSET_METADATA_CONFLICT',
              }.contains(error.code);
          if (terminal) _remoteUnavailable = true;
          _phase(
            terminal ? AdminSavePhase.conflict : AdminSavePhase.partialFailure,
          );
          return Result.error(error);
        }
        final remote = (associated as Success<AdminSubmissionAsset>).value;
        progress = AdminStagedAssetProgress(
          upload: progress.upload,
          associationId: remote.id,
        );
        _liveReceipts[digest] = progress;
        asset = stagedAssets.firstWhere((item) => item.digest == digest);
        persisted = await session.saveAssetProgress(
          asset,
          progress,
          activation: token,
        );
        if (_obsolete(ownerGeneration) || !_authority(token)) {
          return _unavailable();
        }
        if (persisted is Error<void>) {
          _phase(AdminSavePhase.partialFailure);
          return persisted;
        }
        if (!_assets.any((item) => item.id == remote.id)) _assets.add(remote);
      }
      asset = stagedAssets.firstWhere((item) => item.digest == digest);
      final removed = await session.remove(asset);
      if (_obsolete(ownerGeneration) || !_authority(token)) {
        return _unavailable();
      }
      if (removed is Error<void>) {
        _phase(AdminSavePhase.partialFailure);
        return removed;
      }
      _liveReceipts.remove(digest);
    }
    // Refresh complete associations only; this never overwrites current fields.
    if (_obsolete(ownerGeneration) || !_authority(token)) return _unavailable();
    final refreshed = await _repository.getById(remoteId);
    if (_obsolete(ownerGeneration) || !_authority(token)) return _unavailable();
    if (refreshed case Error<AdminSubmission>(:final error)) {
      _remoteUnavailable = true;
      _phase(AdminSavePhase.partialFailure);
      return Result.error(error);
    }
    final complete = (refreshed as Success<AdminSubmission>).value;
    final capacity = await session.confirmAssociatedContext(
      activation: token,
      baseline: _baselineFor(complete),
      associatedCount: complete.assets.length,
    );
    if (_obsolete(ownerGeneration) || !_authority(token)) return _unavailable();
    _publishDetail(complete);
    if (capacity is Error<void>) {
      _remoteUnavailable = true;
      _phase(AdminSavePhase.conflict);
      return capacity;
    }
    _phase(AdminSavePhase.completed);
    return const Result.success(null);
  }

  /// Parses the coordinate drafts into a nullable pair at the save boundary.
  ///
  /// Returns `null` when the draft is not a valid optional pair: both blank is
  /// valid `(null, null)`; a half-pair, unparsable text, non-finite spellings,
  /// or out-of-range values are all invalid.
  (double?, double?)? _parsedCoordinates() {
    final latitude = _parseCoordinateDraft(
      _latitudeText,
      minimum: -90,
      maximum: 90,
    );
    if (latitude == null && _latitudeText.trim().isNotEmpty) {
      return null;
    }
    final longitude = _parseCoordinateDraft(
      _longitudeText,
      minimum: -180,
      maximum: 180,
    );
    if (longitude == null && _longitudeText.trim().isNotEmpty) {
      return null;
    }
    if ((latitude == null) != (longitude == null)) {
      return null;
    }
    return (latitude, longitude);
  }

  /// Parses one trimmed draft with narrow decimal-comma support.
  ///
  /// Returns `null` for blank input or any invalid value; blankness must be
  /// distinguished by the caller.
  double? _parseCoordinateDraft(
    String raw, {
    required double minimum,
    required double maximum,
  }) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    if (','.allMatches(trimmed).length > 1) return null;
    final value = double.tryParse(trimmed.replaceFirst(',', '.'));
    if (value == null || !value.isFinite) return null;
    if (value < minimum || value > maximum) return null;
    return value;
  }

  /// Domain eligibility is captured before reserving the operation itself.
  Exception? _moderationGuardError() {
    if (submissionId == null) {
      return Exception('Non puoi moderare un nuovo contributo.');
    }
    if (!_hasLoadedDetail || _remoteUnavailable) {
      return Exception('Carica il contributo prima di moderarlo.');
    }
    if (isDirty) {
      return Exception('Salva le modifiche prima di pubblicare o rifiutare.');
    }
    if (_status != AdminSubmissionStatus.pending) {
      return Exception('Questo contributo è già stato moderato.');
    }
    return null;
  }

  Future<Result<void>> _reject(
    Exception? guard,
    _SourceAcknowledgment source,
  ) async {
    final ownerGeneration = _generation;
    if (guard != null) return Result.error(guard);
    final result = await _repository.reject(
      submissionId!,
      ignoreSource: source.ignore,
      acknowledgeCurrentSource: source.acknowledge,
      expectedSourceHash: source.hash,
    );
    if (_obsolete(ownerGeneration)) return _unavailable();
    await _refreshAfterResolution(result);
    return result.map((_) {
      if (_obsolete(ownerGeneration)) return;
      _status = AdminSubmissionStatus.rejected;
      _contextCommitted();
    });
  }

  Future<Result<AdminSubmissionPromotion>> _promote(
    AdminPromotionTarget target,
    Exception? guard,
    _SourceAcknowledgment source,
  ) async {
    final ownerGeneration = _generation;
    if (guard != null) return Result.error(guard);
    final result = await _repository.promote(
      submissionId!,
      target,
      acknowledgeCurrentSource: source.acknowledge,
      expectedSourceHash: source.hash,
    );
    if (_obsolete(ownerGeneration)) return _unavailable();
    await _refreshAfterResolution(result);
    return result.map((promotion) {
      if (!_obsolete(ownerGeneration)) {
        _status = AdminSubmissionStatus.accepted;
        _promotion = promotion;
        _contextCommitted();
      }
      return promotion;
    });
  }

  Future<Result<AdminEventResolution>> _link(
    int target,
    Exception? guard,
    _SourceAcknowledgment source,
  ) async {
    final ownerGeneration = _generation;
    if (guard != null) return Result.error(guard);
    final result = await _repository.link(
      submissionId!,
      target,
      acknowledgeCurrentSource: source.acknowledge,
      expectedSourceHash: source.hash,
    );
    if (_obsolete(ownerGeneration)) return _unavailable();
    await _refreshAfterResolution(result);
    return result.map((resolution) {
      if (!_obsolete(ownerGeneration)) {
        _status = AdminSubmissionStatus.accepted;
        _targetEventId = resolution.eventId;
        _contextCommitted();
      }
      return resolution;
    });
  }

  Future<Result<void>> _findCandidates(
    String search,
    bool eligible,
    int revision,
    int context,
  ) async {
    final ownerGeneration = _generation;
    if (!eligible) {
      return Result.error(
        Exception('Carica un contributo evento prima di cercare.'),
      );
    }
    final result = await _repository.eventCandidates(
      submissionId!,
      searchName: search.isEmpty ? null : search,
    );
    return result.map((value) {
      if (_obsolete(ownerGeneration) ||
          revision != _candidateRevision ||
          context != _editorRevision) {
        return;
      }
      _candidates = value;
      _notifyListeners();
    });
  }

  Future<Result<void>> _preview(
    int? target,
    int generation, {
    required bool eligible,
  }) async {
    final ownerGeneration = _generation;
    if (!eligible) {
      return Result.error(
        Exception(
          'Seleziona un evento e salva le modifiche prima dell’anteprima.',
        ),
      );
    }
    final result = await _repository.mergePreview(submissionId!, target!);
    return result.map((value) {
      if (_obsolete(ownerGeneration) ||
          isDirty ||
          _targetEventId != target ||
          _previewGeneration != generation) {
        return;
      }
      _mergePreview = value;
      final external = _externalEvent;
      if (external != null && value.currentSourceHash != null) {
        if (external.currentHash != value.currentSourceHash) {
          _acknowledgeCurrentSource = false;
          _acknowledgedSourceHash = null;
          _editorRevision++;
          _invalidateCandidates();
        }
        _externalEvent = AdminExternalEvent(
          recordId: external.recordId,
          snapshotHash: external.snapshotHash,
          snapshotVersion: external.snapshotVersion,
          snapshot: external.snapshot,
          mode: external.mode,
          eventId: external.eventId,
          currentHash: value.currentSourceHash,
          currentSnapshot: value.currentSourceSnapshot,
        );
      }
      _notifyListeners();
    });
  }

  Future<Result<void>> _keepCurrent(
    AdminEventMergeGroup group,
    bool eligible, {
    required int? target,
    required int generation,
    required AdminEventMergePreview? preview,
  }) async {
    final ownerGeneration = _generation;
    // Mutation admission itself invalidates the old preview once.
    if (!eligible ||
        preview == null ||
        _targetEventId != target ||
        _previewGeneration != generation + 1) {
      return Result.error(Exception('Attendi e carica una nuova anteprima.'));
    }
    final values = group.current;
    switch (group.name) {
      case 'name':
        _name = values['name'] as String;
      case 'category':
        _category = ContentCategory.values.byName(values['category'] as String);
      case 'description':
        _description = values['description'] as String?;
        _descriptionDelta = (values['description_delta'] as List?)
            ?.map((value) => Map<String, dynamic>.from(value as Map))
            .toList();
      case 'location':
        _city = values['city'] as String?;
        _latitudeText = values['latitude']?.toString() ?? '';
        _longitudeText = values['longitude']?.toString() ?? '';
      case 'schedule':
        final start = DateTime.parse(values['start_date'] as String).toUtc();
        final end = values['end_date'] == null
            ? null
            : DateTime.parse(values['end_date'] as String).toUtc();
        _eventDates = EventDateDraft.exact(
          startCalendarDate: _eventTimePolicy.calendarDateForUtc(start),
          startInstantUtc: start,
          endInstantUtc: end,
          allDay: values['all_day'] as bool,
        );
        _eventTimeIssue = null;
    }
    _hydrationRevision++;
    _markDirty();
    if (_obsolete(ownerGeneration)) return _unavailable();
    final result = await _save(_captureSave());
    if (_obsolete(ownerGeneration)) return _unavailable();
    if (result is Success<void> && isDirty) {
      return Result.error(
        Exception('Salva le nuove modifiche prima dell’anteprima.'),
      );
    }
    if (_targetEventId != target) {
      return Result.error(Exception('Carica una nuova anteprima.'));
    }
    return await result.asyncFlatMap(
      (_) => _preview(
        target,
        _previewGeneration,
        eligible: submissionId != null && _targetEventId != null && !isDirty,
      ),
    );
  }

  Future<Result<AdminEventResolution>> _apply(
    AdminEventMergePreview? preview,
    bool external,
    Exception? guard,
    _SourceAcknowledgment source,
  ) async {
    final ownerGeneration = _generation;
    if (guard != null) return Result.error(guard);
    if (!external || preview == null) {
      return Result.error(
        Exception('Carica una nuova anteprima prima di applicare.'),
      );
    }
    final result = await _repository.apply(
      submissionId!,
      preview,
      acknowledgeCurrentSource: source.acknowledge,
      expectedSourceHash: source.hash,
    );
    if (result case Error(
      :final AdminContentSubmissionApiException error,
    ) when !_obsolete(ownerGeneration)) {
      if (error.code == 'EVENT_CHANGED' || error.code == 'SUBMISSION_CHANGED') {
        _editorRevision++;
        _invalidatePreview();
        _notifyListeners();
      }
    }
    if (_obsolete(ownerGeneration)) return _unavailable();
    await _refreshAfterResolution(result);
    return result.map((resolution) {
      if (!_obsolete(ownerGeneration)) {
        _status = AdminSubmissionStatus.accepted;
        _targetEventId = resolution.eventId;
        _contextCommitted();
      }
      return resolution;
    });
  }

  Future<void> _refreshAfterResolution<T>(Result<T> result) async {
    final ownerGeneration = _generation;
    if (_obsolete(ownerGeneration) || _externalEvent == null) return;
    final sourceChanged = switch (result) {
      Error(:final AdminContentSubmissionApiException error) =>
        error.code == 'SOURCE_CHANGED',
      _ => false,
    };
    if (result is Error && !sourceChanged) return;
    _acknowledgeCurrentSource = false;
    _acknowledgedSourceHash = null;
    _contextCommitted();
    if (_obsolete(ownerGeneration)) return;
    await _loadDetail();
    if (_obsolete(ownerGeneration)) return;
    final pending = switch (result) {
      Success(:final AdminEventResolution value) => value.pendingId,
      _ => null,
    };
    if (pending != null) {
      final followup = await _repository.getById(pending);
      if (_obsolete(ownerGeneration)) return;
      followup.map((value) => _followupSubmission = value);
      _notifyListeners();
    }
  }

  /// Remote associations and unfinished files.
  ///
  /// Each confirmed receipt occupies one capacity slot.
  int get imageCount {
    final associatedIds = _assets.map((asset) => asset.id).toSet();
    var unconfirmedCount = 0;
    for (final asset in stagedAssets) {
      final associationId =
          (_liveReceipts[asset.digest] ?? asset.progress)?.associationId;
      if (associationId == null) {
        unconfirmedCount++;
      } else {
        associatedIds.add(associationId);
      }
    }
    return associatedIds.length + unconfirmedCount;
  }

  Exception? _assetGuard({required bool add}) {
    if (submissionId == null) {
      if (_draftSession != null &&
          add &&
          (_draftSession.state?.ready ?? false)) {
        return stagedAssets.length >= kMaximumSubmissionAssetCount
            ? Exception('Hai raggiunto il limite di foto.')
            : null;
      }
      return Exception('Contributo non disponibile.');
    }
    if (_remoteUnavailable ||
        _draftSession?.state?.physicalCheckpoint?.fieldWriteIntent?.kind ==
            AdminFieldWriteKind.update) {
      return Exception(
        'Verifica il salvataggio remoto prima di modificare le foto.',
      );
    }
    if (!_hasLoadedDetail) {
      return Exception(
        add
            ? 'Carica il contributo prima di aggiungere foto.'
            : 'Carica il contributo prima di rimuovere foto.',
      );
    }
    if (_status != AdminSubmissionStatus.pending) {
      return Exception(
        'Puoi modificare le foto solo dei contributi in attesa.',
      );
    }
    if (add && imageCount >= kMaximumSubmissionAssetCount) {
      return Exception('Hai raggiunto il limite di foto.');
    }
    return null;
  }

  Future<Result<void>> _addAsset(Exception? guard) async {
    final ownerGeneration = _generation;
    if (guard != null) return Result.error(guard);
    final session = _draftSession;
    final token = activation;
    final id = submissionId;
    final nonce = token == null
        ? 'legacy'
        : AdminDraftOwner(accountId: token.owner.accountId).sessionId;
    if (session != null) {
      if (token == null) return _unavailable();
      final persisted = await session.setNavigationIntent(
        activation: token,
        requestNonce: nonce,
      );
      if (_obsolete(ownerGeneration) || !_authority(token)) {
        return _unavailable();
      }
      if (persisted is Error<void>) return persisted;
    }
    final abandoned = Completer<void>();
    _pickerNonce = nonce;
    _pickerAbandonment = abandoned;
    _notifyListeners();
    var normalTerminal = false;
    try {
      if (_obsolete(ownerGeneration) ||
          !_authority(token) ||
          _pickerNonce != nonce) {
        return _unavailable();
      }
      final selected = await Future.any<({XFile? image, bool abandoned})>([
        _imagePicker
            .pickImage(source: ImageSource.gallery)
            .then((image) => (image: image, abandoned: false)),
        abandoned.future.then((_) => (image: null, abandoned: true)),
      ]);
      if (selected.abandoned ||
          _obsolete(ownerGeneration) ||
          _pickerNonce != nonce ||
          !_authority(token)) {
        return _unavailable();
      }
      normalTerminal = true;
      _pickerNonce = null;
      _pickerAbandonment = null;
      _notifyListeners();
      if (_obsolete(ownerGeneration) || !_authority(token)) {
        return _unavailable();
      }
      final image = selected.image;
      if (image == null) return const Result.success(null);
      if (id == null && session != null) {
        final acquired = await session.acquire(
          File(image.path),
          capacity: session.capacityContext,
        );
        if (_obsolete(ownerGeneration) || !_authority(token)) {
          return _unavailable();
        }
        _notifyListeners();
        return acquired.map((_) {});
      }
      final task = _contentSubmissionRepository.uploadImageTask(
        File(image.path),
      );
      _activeImageUploadTask = task;
      try {
        final upload = await task.result;
        if (_obsolete(ownerGeneration) || !_authority(token)) {
          return _unavailable();
        }
        return await upload.asyncFlatMap((uploaded) async {
          final persisted = await _repository.addAsset(id!, uploaded);
          if (_obsolete(ownerGeneration) || !_authority(token)) {
            return _unavailable();
          }
          return persisted.map((asset) {
            _assets.add(asset);
            _contextCommitted();
          });
        });
      } finally {
        if (identical(_activeImageUploadTask, task)) {
          _activeImageUploadTask = null;
        }
      }
    } finally {
      // Native errors settle normally while this request retains authority.
      if (_pickerNonce == nonce && !_obsolete(ownerGeneration)) {
        normalTerminal = true;
        _pickerNonce = null;
        _pickerAbandonment = null;
      }
      if (normalTerminal &&
          !_obsolete(ownerGeneration) &&
          _authority(token) &&
          session != null &&
          token != null) {
        await session.clearNavigationIntent(
          activation: token,
          requestNonce: nonce,
        );
      }
      if (!_obsolete(ownerGeneration)) _notifyListeners();
    }
  }

  Future<Result<void>> _deleteAsset(int assetId, Exception? guard) async {
    final ownerGeneration = _generation;
    if (guard != null) return Result.error(guard);
    final result = await _repository.deleteAsset(submissionId!, assetId);
    return result.map((_) {
      if (_obsolete(ownerGeneration)) return;
      _assets.removeWhere((asset) => asset.id == assetId);
      _contextCommitted();
    });
  }

  void _contextCommitted() {
    _editorRevision++;
    _invalidateCandidates();
    _invalidatePreview();
    _notifyListeners();
  }

  void _invalidateCandidates() {
    _candidateRevision++;
    _candidates = null;
    _candidatesSnapshot = const commands.CommandResult(null, null, null, false);
  }

  void _invalidatePreview() {
    _previewGeneration++;
    _mergePreview = null;
    _previewSnapshot = const commands.CommandResult(null, null, null, false);
  }

  void _markDirty() {
    _draftRevision++;
    _editorRevision++;
    _invalidatePreview();
    _invalidateCandidates();
    _isDirty = true;
    _notifyListeners();
  }

  Result<T> _unavailable<T>() =>
      Result.error(Exception('Editor non disponibile.'));

  ResultCommand<_EditorAction<T>, T> _createCommand<T>(
    String name,
    void Function(commands.CommandResult<void, Result<T>?>) publish,
  ) {
    final command = createResultCommand<_EditorAction<T>, T>((action) async {
      if (_disposed) return _unavailable<T>();
      return await action();
    }, debugName: 'admin_submission_editor_$name');
    void observeCompletion() {
      if (_released.contains(command) ||
          command.isRunningSync.value ||
          !_reserved.contains(command)) {
        return;
      }
      _afterCommandTurn(() {
        if (_released.contains(command) || command.isRunningSync.value) return;
        if (!_reserved.remove(command)) return;
        if (_disposed) {
          _release(command);
          return;
        }
        if (_commandGenerations.remove(command) != _generation || _revoked) {
          _notifyListeners();
          return;
        }
        final terminal = command.results.value;
        if (identical(command, _saveCommand) &&
            (terminal.error != null || terminal.isRunning)) {
          _savePhase = _savePhase == AdminSavePhase.fields
              ? AdminSavePhase.unknownOutcome
              : AdminSavePhase.failed;
        }
        if (terminal.isRunning) {
          // An assertion bypasses normal terminal routing. Keep it fail-loud
          // and require a new owner without reporting synthetic success.
          _stopped = true;
        } else {
          publish(
            commands.CommandResult(
              null,
              terminal.data,
              terminal.error,
              false,
              stackTrace: terminal.stackTrace,
              errorReaction: terminal.errorReaction,
              isUndoValue: terminal.isUndoValue,
            ),
          );
        }
        _notifyListeners();
      });
    }

    command.isRunningSync.addListener(observeCompletion);
    _completionObservers[command] = observeCompletion;
    return command;
  }

  bool _admit<T>(
    ResultCommand<_EditorAction<T>, T> command,
    _EditorAction<T> action,
  ) {
    final ownerGeneration = _generation;
    _commandGenerations[command] = ownerGeneration;
    _reserved.add(command);
    if (_mutations.contains(command)) {
      _invalidateCandidates();
      // Apply already captured its committed tokens in the request closure.
      _invalidatePreview();
    }
    _notifyListeners();
    if (_disposed) {
      // Disposal from admission notification happens before run(), so no
      // physical completion notification will arrive for this reservation.
      _reserved.remove(command);
      _afterCommandTurn(() => _release(command));
    } else {
      command.run(
        () => _obsolete(ownerGeneration)
            ? Future.value(_unavailable<T>())
            : action(),
      );
    }
    return true;
  }

  /// Leaves upstream result dispatch, error reporting and finally together.
  void _afterCommandTurn(VoidCallback callback) {
    scheduleMicrotask(() => unawaited(Future<void>(callback)));
  }

  /// Permanently claims release before touching a private observer or Command.
  void _release(commands.Command<dynamic, dynamic> command) {
    if (_released.contains(command) ||
        !_disposed ||
        command.isRunningSync.value) {
      return;
    }
    _released.add(command);
    _reserved.remove(command);
    final observer = _completionObservers.remove(command);
    if (observer != null) command.isRunningSync.removeListener(observer);
    command.dispose();
  }

  int _notifyDepth = 0;
  bool _superDisposeQueued = false;
  void _notifyListeners() {
    if (_disposed) return;
    _notifyDepth++;
    try {
      notifyListeners();
    } finally {
      _notifyDepth--;
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _auth?.removeListener(_onAuthChanged);
    if (_draftSession != null) _abandonPicker();
    _draftSession?.revoke();
    _activeImageUploadTask?.cancel();
    _activeImageUploadTask = null;
    _afterCommandTurn(() {
      _commands.forEach(_release);
    });
    if (_notifyDepth == 0) {
      super.dispose();
    } else if (!_superDisposeQueued) {
      _superDisposeQueued = true;
      scheduleMicrotask(super.dispose);
    }
  }
}
