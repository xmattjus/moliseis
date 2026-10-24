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
import 'package:moliseis/domain/models/admin_submission_input.dart';
import 'package:moliseis/domain/models/admin_submission_promotion.dart';
import 'package:moliseis/domain/models/admin_submission_status.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/image_upload_task.dart';
import 'package:moliseis/domain/repositories/admin_content_submission_repository.dart';
import 'package:moliseis/domain/repositories/content_submission_repository.dart';
import 'package:moliseis/utils/constants.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/result_command.dart';

/// A reusable physical command lane with one independently owned attempt.
final class _EditorLane<T> {
  late final ResultCommand<void, T> command;
  commands.CommandResult<void, Result<T>?> snapshot =
      const commands.CommandResult(null, null, null, false);
  _EditorExecution<T>? current;
  int? executionId;
  VoidCallback? removePublic;
  VoidCallback? removePrivate;
  bool released = false;
  int settlements = 0;
}

/// Immutable admitted work and its private physical settlement witnesses.
final class _EditorExecution<T> {
  _EditorExecution(
    this.id,
    this.action, {
    required this.candidateRevision,
    required this.contextRevision,
  });
  final int id;
  final int candidateRevision;
  final int contextRevision;
  final Future<Result<T>> Function(_EditorExecution<T>) action;
  bool publish = true;
  bool started = false;
  bool actionSettled = false;
  bool settled = false;
  bool queued = false;
  int revision = 0;
}

typedef _SaveDraft = ({
  AdminSubmissionInput? input,
  Exception? error,
  EventTimeIssue? issue,
  int revision,
});
typedef _SourceAcknowledgment = ({
  bool? acknowledge,
  String? hash,
  bool? ignore,
});

/// Route-scoped state for creating or editing an admin submission.
///
/// The editor keeps its draft only in memory and deliberately has no public
/// draft-repository dependency.
class AdminSubmissionEditorViewModel extends ChangeNotifier {
  /// Creates editor state for a new submission or the supplied [submissionId].
  ///
  /// [creatorName] and [creatorEmail] are display-only context for create mode;
  /// they are never included in an [AdminSubmissionInput].
  AdminSubmissionEditorViewModel({
    required AdminContentSubmissionRepository repository,
    required ContentSubmissionRepository contentSubmissionRepository,
    ImagePicker? imagePicker,
    this.submissionId,
    String? creatorName,
    String? creatorEmail,
  }) : _repository = repository,
       _contentSubmissionRepository = contentSubmissionRepository,
       _imagePicker = imagePicker ?? ImagePicker(),
       _contributorName = creatorName,
       _contributorEmail = creatorEmail {
    _load = _createLane<void>('load');
    _saveLane = _createLane<void>('save');
    _rejectLane = _createLane<void>('reject');
    _promoteLane = _createLane<AdminSubmissionPromotion>('promote');
    _linkLane = _createLane<AdminEventResolution>('link');
    _previewLane = _createLane<void>('preview');
    _candidatesLane = _createLane<void>('find_candidates');
    _applyLane = _createLane<AdminEventResolution>('apply');
    _keepLane = _createLane<void>('keep_current');
    _addLane = _createLane<void>('add_asset');
    _deleteLane = _createLane<void>('delete_asset');
  }

  final AdminContentSubmissionRepository _repository;
  final ContentSubmissionRepository _contentSubmissionRepository;
  final ImagePicker _imagePicker;

  /// The persisted identifier being edited, or null for a new submission.
  final int? submissionId;

  ContentCategory? _category;
  String? _city;
  String? _name;
  String? _description;
  List<Map<String, dynamic>>? _descriptionDelta;
  final EventTimePolicy _eventTimePolicy = EventTimePolicy();
  EventDateDraft _eventDates = const EventDateDraft.disabled();
  EventTimeIssue? _eventTimeIssue;
  String _latitudeText = '';
  String _longitudeText = '';
  String? _contributorName;
  String? _contributorEmail;
  AdminSubmissionStatus? _status;
  AdminSubmissionPromotion? _promotion;
  DateTime? _createdAt;
  DateTime? _modifiedAt;
  final List<AdminSubmissionAsset> _assets = <AdminSubmissionAsset>[];
  ImageUploadTask? _activeImageUploadTask;
  var _hasLoadedDetail = false;
  var _isDirty = false;
  var _disposed = false;

  late final _EditorLane<void> _load;
  late final _EditorLane<void> _saveLane;
  late final _EditorLane<void> _rejectLane;
  late final _EditorLane<AdminSubmissionPromotion> _promoteLane;
  late final _EditorLane<AdminEventResolution> _linkLane;
  late final _EditorLane<void> _previewLane;
  late final _EditorLane<void> _candidatesLane;
  late final _EditorLane<AdminEventResolution> _applyLane;
  late final _EditorLane<void> _keepLane;
  late final _EditorLane<void> _addLane;
  late final _EditorLane<void> _deleteLane;
  int _nextExecution = 0;
  int _draftRevision = 0;
  int _editorRevision = 0;
  int? _savedExecutionId;
  int? _savedDraftRevision;
  String _candidateSearch = '';
  int _candidateRevision = 0;
  AdminEventCandidates? _candidates;

  /// Candidate discovery is advisory and never changes moderation readiness.
  AdminEventCandidates? get candidates => _candidates;

  /// Desired candidate input, independent of a physically pending search.
  String get candidateSearch => _candidateSearch;

  /// Current editor context for correlating dialog confirmations.
  int get editorRevision => _editorRevision;

  /// Physical identity is separate from execution IDs; no Command is exposed.
  @visibleForTesting
  List<int> get debugCommandIdentities =>
      List.unmodifiable(_lanes.map((lane) => identityHashCode(lane.command)));

  /// Safe receipt releases, in load/mutations/preview/candidates lane order.
  @visibleForTesting
  List<int> get debugSettlementCounts =>
      List.unmodifiable(_lanes.map((lane) => lane.settlements));

  /// Physical release counts, separate from safe receipt settlement.
  @visibleForTesting
  List<int> get debugCommandDisposalCounts =>
      List.unmodifiable(_lanes.map((lane) => lane.released ? 1 : 0));

  /// Stable private observer pairs remain across live retries.
  @visibleForTesting
  List<int> get debugPrivateObserverCounts => List.unmodifiable(
    _lanes.map((lane) => lane.removePrivate == null ? 0 : 2),
  );

  /// Whether this owner has revoked admission and publication authority.
  bool get isDisposed => _disposed;

  /// A current clean Save success remains close-authorized after settlement.
  bool get canCloseAfterSave =>
      !_disposed &&
      !_isDirty &&
      _savedExecutionId == _saveLane.executionId &&
      _savedExecutionId != null &&
      _savedDraftRevision == _draftRevision &&
      _saveLane.snapshot.completed;

  bool _acknowledgeCurrentSource = false;
  String? _acknowledgedSourceHash;
  bool _ignoreSource = false;
  AdminSubmission? _followupSubmission;

  /// Only the currently displayed stale source revision can be acknowledged.
  bool get isSourceStale => _externalEvent?.stale ?? false;
  bool get acknowledgeCurrentSource => _acknowledgeCurrentSource;
  bool get ignoreSource => _ignoreSource;
  AdminSubmission? get followupSubmission => _followupSubmission;

  void setAcknowledgeCurrentSource({required bool selected}) {
    if (!_canChangeContext) return;
    _acknowledgeCurrentSource = selected && isSourceStale;
    _acknowledgedSourceHash = _acknowledgeCurrentSource
        ? _externalEvent?.currentHash
        : null;
    _notifyListeners();
  }

  void setIgnoreSource({required bool ignored}) {
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
  void selectTargetEvent(int? id) {
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
      !isEditMode || _status == AdminSubmissionStatus.pending;

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
  bool get loading => _load.current != null;

  /// Whether edits have not yet been saved.
  bool get isDirty => _isDirty;

  /// Whether an asset add or delete operation is in progress.
  bool get assetMutationRunning =>
      _addLane.current != null || _deleteLane.current != null;

  /// Whether an admitted operation can mutate the editor or its submission.
  bool get operationRunning => _mutations.any((lane) => lane.current != null);

  List<_EditorLane<dynamic>> get _mutations => [
    _saveLane,
    _rejectLane,
    _promoteLane,
    _linkLane,
    _applyLane,
    _keepLane,
    _addLane,
    _deleteLane,
  ];
  List<_EditorLane<dynamic>> get _lanes => [
    _load,
    ..._mutations,
    _previewLane,
    _candidatesLane,
  ];

  bool get _canChangeContext => !_disposed && !loading && !operationRunning;
  bool get _canChangeFields =>
      !_disposed &&
      !loading &&
      (!operationRunning || _saveLane.current != null);

  bool _canAdmit(_EditorLane<dynamic> lane) {
    if (_disposed || lane.current != null || loading) return false;
    if (identical(lane, _load)) {
      return !(_hasLoadedDetail && _isDirty) &&
          _lanes.every((value) => value.current == null);
    }
    if (identical(lane, _candidatesLane)) return true;
    if (identical(lane, _previewLane)) return !operationRunning;
    return !operationRunning &&
        (!identical(lane, _keepLane) || _previewLane.current == null);
  }

  /// Updates the selected category and marks the editor dirty.
  void setCategory(ContentCategory? category) {
    if (!_canChangeFields) return;
    _category = category;
    _markDirty();
  }

  /// Updates the city and marks the editor dirty.
  void setCity(String? city) {
    if (!_canChangeFields) return;
    _city = city;
    _markDirty();
  }

  /// Updates the place or event name and marks the editor dirty.
  void setName(String? name) {
    if (!_canChangeFields) return;
    _name = name;
    _markDirty();
  }

  /// Updates matching plain-text and rich-text description projections.
  void setDescription({
    required String? description,
    required List<Map<String, dynamic>>? descriptionDelta,
  }) {
    if (!_canChangeFields) return;
    _description = description;
    _descriptionDelta = descriptionDelta;
    _markDirty();
  }

  /// Enables or disables event mode without inventing an instant.
  /// Changes precision without restoring an old or technical clock.
  void setAllDay({required bool allDay}) {
    _applyTemporalEdit(
      _eventTimePolicy.changeAllDay(_eventDates, allDay: allDay),
    );
  }

  void setEventEnabled({required bool enabled}) {
    if (!_canChangeFields) return;
    if (_externalEvent != null && !enabled) return;
    _eventDates = enabled
        ? _eventTimePolicy.enable(_eventDates)
        : _eventTimePolicy.disable(_eventDates);
    _eventTimeIssue = null;
    _markDirty();
  }

  /// Changes the start's Rome calendar day while preserving exact precision.
  void setStartCalendarDate(EventCalendarDate date) {
    _applyTemporalEdit(
      _eventTimePolicy.changeStartCalendarDate(
        _eventTimePolicy.enable(_eventDates),
        date,
      ),
    );
  }

  /// Changes the start's Rome clock time while preserving sub-minute precision.
  void setStartClockTime(EventClockTime time) {
    final draft = _eventTimePolicy.enable(_eventDates);
    _applyTemporalEdit(_eventTimePolicy.changeStartClockTime(draft, time));
  }

  /// Changes the inclusive Rome calendar day for the event end.
  void setEndCalendarDate(EventCalendarDate date) {
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
  void setLatitudeText(String value) {
    if (!_canChangeFields) return;
    _latitudeText = value;
    _markDirty();
  }

  /// Updates the raw longitude draft and marks the editor dirty.
  void setLongitudeText(String value) {
    if (!_canChangeFields) return;
    _longitudeText = value;
    _markDirty();
  }

  /// Updates both coordinate drafts from one map selection.
  ///
  /// This is one logical change: both drafts are written with six-decimal
  /// formatting and the editor is marked dirty exactly once.
  void setCoordinates(double latitude, double longitude) {
    if (!_canChangeFields) return;
    _latitudeText = latitude.toStringAsFixed(6);
    _longitudeText = longitude.toStringAsFixed(6);
    _markDirty();
  }

  /// Changes desired query and invalidates older results without starting I/O.
  void setCandidateSearch(String value) {
    if (_disposed || value == _candidateSearch) return;
    _candidateSearch = value;
    _candidateRevision++;
    _invalidateCandidates();
    _notifyListeners();
  }

  /// Last authorized load state, frozen when the owner is revoked.
  commands.CommandResult<void, Result<void>?> get loadSnapshot =>
      _load.snapshot;

  /// Identity of the last admitted load execution.
  int? get loadExecutionId => _load.executionId;

  /// Whether load can synchronously reserve its lane.
  bool get canRequestLoad => _canAdmit(_load);

  /// Last authorized save state, frozen when the owner is revoked.
  commands.CommandResult<void, Result<void>?> get saveSnapshot =>
      _saveLane.snapshot;

  /// Identity of the last admitted save execution.
  int? get saveExecutionId => _saveLane.executionId;

  /// Whether save can synchronously reserve its lane.
  bool get canRequestSave => _canAdmit(_saveLane);

  /// Last authorized reject state, frozen when the owner is revoked.
  commands.CommandResult<void, Result<void>?> get rejectSnapshot =>
      _rejectLane.snapshot;

  /// Identity of the last admitted reject execution.
  int? get rejectExecutionId => _rejectLane.executionId;

  /// Whether reject can synchronously reserve its lane.
  bool get canRequestReject => _canAdmit(_rejectLane);

  /// Last authorized promote state, frozen when the owner is revoked.
  commands.CommandResult<void, Result<AdminSubmissionPromotion>?>
  get promoteSnapshot => _promoteLane.snapshot;

  /// Identity of the last admitted promote execution.
  int? get promoteExecutionId => _promoteLane.executionId;

  /// Whether promote can synchronously reserve its lane.
  bool get canRequestPromote => _canAdmit(_promoteLane);

  /// Last authorized link state, frozen when the owner is revoked.
  commands.CommandResult<void, Result<AdminEventResolution>?>
  get linkSnapshot => _linkLane.snapshot;

  /// Identity of the last admitted link execution.
  int? get linkExecutionId => _linkLane.executionId;

  /// Whether link can synchronously reserve its lane.
  bool get canRequestLink => _canAdmit(_linkLane);

  /// Last authorized preview state, frozen when the owner is revoked.
  commands.CommandResult<void, Result<void>?> get previewSnapshot =>
      _previewLane.snapshot;

  /// Identity of the last admitted preview execution.
  int? get previewExecutionId => _previewLane.executionId;

  /// Whether preview can synchronously reserve its lane.
  bool get canRequestPreview => _canAdmit(_previewLane);

  /// Last authorized findCandidates state, frozen when the owner is revoked.
  commands.CommandResult<void, Result<void>?> get findCandidatesSnapshot =>
      _candidatesLane.snapshot;

  /// Identity of the last admitted findCandidates execution.
  int? get findCandidatesExecutionId => _candidatesLane.executionId;

  /// Whether findCandidates can synchronously reserve its lane.
  bool get canRequestFindCandidates => _canAdmit(_candidatesLane);

  /// Last authorized apply state, frozen when the owner is revoked.
  commands.CommandResult<void, Result<AdminEventResolution>?>
  get applySnapshot => _applyLane.snapshot;

  /// Identity of the last admitted apply execution.
  int? get applyExecutionId => _applyLane.executionId;

  /// Whether apply can synchronously reserve its lane.
  bool get canRequestApply => _canAdmit(_applyLane);

  /// Last authorized keepCurrent state, frozen when the owner is revoked.
  commands.CommandResult<void, Result<void>?> get keepCurrentSnapshot =>
      _keepLane.snapshot;

  /// Identity of the last admitted keepCurrent execution.
  int? get keepCurrentExecutionId => _keepLane.executionId;

  /// Whether keepCurrent can synchronously reserve its lane.
  bool get canRequestKeepCurrent => _canAdmit(_keepLane);

  /// Last authorized addAsset state, frozen when the owner is revoked.
  commands.CommandResult<void, Result<void>?> get addAssetSnapshot =>
      _addLane.snapshot;

  /// Identity of the last admitted addAsset execution.
  int? get addAssetExecutionId => _addLane.executionId;

  /// Whether addAsset can synchronously reserve its lane.
  bool get canRequestAddAsset => _canAdmit(_addLane);

  /// Last authorized deleteAsset state, frozen when the owner is revoked.
  commands.CommandResult<void, Result<void>?> get deleteAssetSnapshot =>
      _deleteLane.snapshot;

  /// Identity of the last admitted deleteAsset execution.
  int? get deleteAssetExecutionId => _deleteLane.executionId;

  /// Whether deleteAsset can synchronously reserve its lane.
  bool get canRequestDeleteAsset => _canAdmit(_deleteLane);

  /// Reserves an exclusive initial or explicit detail refresh.
  bool requestLoad() => _admit(_load, _loadDetail);

  /// Captures the complete current draft before notifying or deferred entry.
  bool requestSave() {
    if (!canRequestSave) return false;
    final draft = _captureSave();
    return _admit(_saveLane, (execution) => _save(execution, draft));
  }

  /// Reserves rejection with immutable source acknowledgment.
  bool requestReject() {
    if (!canRequestReject) return false;
    final guard = _moderationGuardError();
    final source = _sourceAcknowledgment;
    return _admit(
      _rejectLane,
      (execution) => _reject(execution, guard, source),
    );
  }

  /// Reserves publication to the explicitly selected target.
  bool requestPromote(AdminPromotionTarget target) {
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
    return _admit(_promoteLane, (execution) {
      if (_live(execution) && issue != null) {
        _eventTimeIssue = issue;
        _notifyListeners();
      }
      return _promote(execution, target, guard, source);
    });
  }

  /// Reserves a link without copying canonical Event fields or media.
  bool requestLink(int target) {
    if (!canRequestLink) return false;
    final guard =
        _moderationGuardError() ??
        (startDate == null
            ? Exception('Imposta una data di inizio per collegare un evento.')
            : null);
    final source = _sourceAcknowledgment;
    return _admit(
      _linkLane,
      (execution) => _link(execution, target, guard, source),
    );
  }

  /// Captures current target and generation for an explicit preview.
  bool requestPreview() {
    if (!canRequestPreview) return false;
    final target = _targetEventId;
    final generation = _previewGeneration;
    final eligible = submissionId != null && target != null && !_isDirty;
    return _admit(
      _previewLane,
      (execution) =>
          _preview(execution, target, generation, eligible: eligible),
    );
  }

  /// Searches desired input; refusal has no observable side effects.
  bool requestFindCandidates() {
    if (!canRequestFindCandidates) return false;
    final search = _candidateSearch.trim();
    final eligible = submissionId != null && startDate != null;
    return _admit(
      _candidatesLane,
      (execution) => _findCandidates(execution, search, eligible),
    );
  }

  /// Captures opaque preview tokens and source acknowledgment unchanged.
  bool requestApply() {
    if (!canRequestApply) return false;
    final guard = _moderationGuardError();
    final value = _mergePreview;
    final external = isExternalUpdate;
    final source = _sourceAcknowledgment;
    return _admit(
      _applyLane,
      (execution) => _apply(execution, value, external, guard, source),
    );
  }

  /// Owns one complete copy, private persistence and private preview chain.
  bool requestKeepCurrent(AdminEventMergeGroup group) {
    if (!canRequestKeepCurrent) return false;
    final preview = _mergePreview;
    final target = _targetEventId;
    final generation = _previewGeneration;
    final eligible =
        isEditable &&
        !_isDirty &&
        preview?.groups.any((value) => identical(value, group)) == true;
    return _admit(
      _keepLane,
      (execution) => _keepCurrent(
        execution,
        group,
        eligible,
        target: target,
        generation: generation,
        preview: preview,
      ),
    );
  }

  /// Reserves picker, upload and persisted association as one attempt.
  bool requestAddAsset() {
    if (!canRequestAddAsset) return false;
    final guard = _assetGuard(add: true);
    return _admit(_addLane, (execution) => _addAsset(execution, guard));
  }

  /// Reserves removal of the exact captured persisted association.
  bool requestDeleteAsset(int assetId) {
    if (!canRequestDeleteAsset) return false;
    final guard =
        _assetGuard(add: false) ??
        (!_assets.any((asset) => asset.id == assetId)
            ? Exception('La foto non appartiene al contributo.')
            : null);
    return _admit(
      _deleteLane,
      (execution) => _deleteAsset(execution, assetId, guard),
    );
  }

  _SourceAcknowledgment get _sourceAcknowledgment => (
    acknowledge: _acknowledgeCurrentSource ? true : null,
    hash: _acknowledgedSourceHash,
    ignore: _ignoreSource ? true : null,
  );

  Future<Result<void>> _loadDetail(_EditorExecution<dynamic> execution) async {
    final submissionId = this.submissionId;
    if (submissionId == null) return const Result.success(null);

    final draftRevision = _draftRevision;
    final result = await _repository.getById(submissionId);
    return result.map((submission) {
      if (!_live(execution)) return;
      if (_draftRevision != draftRevision) {
        if (identical(_load.current, execution)) {
          execution.publish = false;
          _load.snapshot = const commands.CommandResult(
            null,
            null,
            null,
            false,
          );
        }
        return;
      }
      _hydrationRevision++;
      _editorRevision++;
      _draftRevision++;
      _invalidateCandidates();
      _invalidatePreview();
      _category = submission.category;
      _city = submission.city;
      _name = submission.name;
      _description = submission.description;
      _descriptionDelta = submission.descriptionDelta;
      final start = submission.startDate?.toUtc();
      final end = submission.endDate?.toUtc();
      _eventDates = switch ((start, end)) {
        (final start?, final end) => EventDateDraft.exact(
          startCalendarDate: _eventTimePolicy.calendarDateForUtc(start),
          startInstantUtc: start,
          endInstantUtc: end,
          allDay: submission.allDay,
        ),
        (null, final end?) => throw StateError(
          'Persisted submission $submissionId has an end date without a '
          'start date: $end.',
        ),
        (null, null) => const EventDateDraft.disabled(),
      };
      _eventTimeIssue = null;
      // Lossless hydration: double.toString() round-trips exactly, unlike a
      // fixed-precision rendering.
      _latitudeText = submission.latitude?.toString() ?? '';
      _longitudeText = submission.longitude?.toString() ?? '';
      _contributorName = submission.userName;
      _contributorEmail = submission.userEmail;
      _status = submission.status;
      _promotion = submission.promotion;
      _externalEvent = submission.externalEvent;
      _acknowledgeCurrentSource = false;
      _acknowledgedSourceHash = null;
      _ignoreSource = false;
      _targetEventId =
          submission.externalEvent?.eventId ?? submission.targetEventId;
      _previewGeneration++;
      _mergePreview = null;
      _createdAt = submission.createdAt;
      _modifiedAt = submission.modifiedAt;
      _assets
        ..clear()
        ..addAll(submission.assets);
      _hasLoadedDetail = true;
      _isDirty = false;
      _notifyListeners();
    });
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
    if (city == null || city.isEmpty || name == null || name.isEmpty) {
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
    return (input: input, error: error, issue: issue, revision: _draftRevision);
  }

  Future<Result<void>> _save(
    _EditorExecution<dynamic> execution,
    _SaveDraft draft, {
    bool publicSave = true,
  }) async {
    if (draft.error != null) {
      if (_live(execution) &&
          draft.issue != null &&
          draft.revision == _draftRevision) {
        _eventTimeIssue = draft.issue;
        _notifyListeners();
      }
      return Result.error(draft.error!);
    }
    final id = submissionId;
    final result = id == null
        ? await _repository.create(draft.input!)
        : await _repository.update(id, draft.input!);
    return result.map((_) {
      if (!_live(execution)) return;
      _editorRevision++;
      _invalidatePreview();
      _invalidateCandidates();
      _isDirty = _draftRevision != draft.revision;
      if (publicSave) {
        _savedExecutionId = execution.id;
        _savedDraftRevision = draft.revision;
      }
      _notifyListeners();
    });
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
    if (!_hasLoadedDetail) {
      return Exception('Carica il contributo prima di moderarlo.');
    }
    if (_isDirty) {
      return Exception('Salva le modifiche prima di pubblicare o rifiutare.');
    }
    if (_status != AdminSubmissionStatus.pending) {
      return Exception('Questo contributo è già stato moderato.');
    }
    return null;
  }

  Future<Result<void>> _reject(
    _EditorExecution<void> execution,
    Exception? guard,
    _SourceAcknowledgment source,
  ) async {
    if (guard != null) return Result.error(guard);
    final result = await _repository.reject(
      submissionId!,
      ignoreSource: source.ignore,
      acknowledgeCurrentSource: source.acknowledge,
      expectedSourceHash: source.hash,
    );
    await _refreshAfterResolution(execution, result);
    return result.map((_) {
      if (!_live(execution)) return;
      _status = AdminSubmissionStatus.rejected;
      _contextCommitted();
    });
  }

  Future<Result<AdminSubmissionPromotion>> _promote(
    _EditorExecution<AdminSubmissionPromotion> execution,
    AdminPromotionTarget target,
    Exception? guard,
    _SourceAcknowledgment source,
  ) async {
    if (guard != null) return Result.error(guard);
    final result = await _repository.promote(
      submissionId!,
      target,
      acknowledgeCurrentSource: source.acknowledge,
      expectedSourceHash: source.hash,
    );
    await _refreshAfterResolution(execution, result);
    return result.map((promotion) {
      if (_live(execution)) {
        _status = AdminSubmissionStatus.accepted;
        _promotion = promotion;
        _contextCommitted();
      }
      return promotion;
    });
  }

  Future<Result<AdminEventResolution>> _link(
    _EditorExecution<AdminEventResolution> execution,
    int target,
    Exception? guard,
    _SourceAcknowledgment source,
  ) async {
    if (guard != null) return Result.error(guard);
    final result = await _repository.link(
      submissionId!,
      target,
      acknowledgeCurrentSource: source.acknowledge,
      expectedSourceHash: source.hash,
    );
    await _refreshAfterResolution(execution, result);
    return result.map((resolution) {
      if (_live(execution)) {
        _status = AdminSubmissionStatus.accepted;
        _targetEventId = resolution.eventId;
        _contextCommitted();
      }
      return resolution;
    });
  }

  Future<Result<void>> _findCandidates(
    _EditorExecution<void> execution,
    String search,
    bool eligible,
  ) async {
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
      if (!_live(execution) ||
          !execution.publish ||
          execution.candidateRevision != _candidateRevision ||
          execution.contextRevision != _editorRevision) {
        return;
      }
      _candidates = value;
      _notifyListeners();
    });
  }

  Future<Result<void>> _preview(
    _EditorExecution<dynamic> execution,
    int? target,
    int generation, {
    required bool eligible,
  }) async {
    if (!eligible) {
      return Result.error(
        Exception(
          'Seleziona un evento e salva le modifiche prima dell’anteprima.',
        ),
      );
    }
    final result = await _repository.mergePreview(submissionId!, target!);
    return result.map((value) {
      if (!_live(execution) ||
          !execution.publish ||
          _isDirty ||
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
    _EditorExecution<void> execution,
    AdminEventMergeGroup group,
    bool eligible, {
    required int? target,
    required int generation,
    required AdminEventMergePreview? preview,
  }) async {
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
    if (!_live(execution)) return _unavailable();
    final result = await _save(execution, _captureSave(), publicSave: false);
    if (!_live(execution)) return _unavailable();
    if (result is Success<void> && _isDirty) {
      return Result.error(
        Exception('Salva le nuove modifiche prima dell’anteprima.'),
      );
    }
    if (_targetEventId != target) {
      return Result.error(Exception('Carica una nuova anteprima.'));
    }
    return await result.asyncFlatMap(
      (_) => _preview(
        execution,
        target,
        _previewGeneration,
        eligible: submissionId != null && _targetEventId != null && !_isDirty,
      ),
    );
  }

  Future<Result<AdminEventResolution>> _apply(
    _EditorExecution<AdminEventResolution> execution,
    AdminEventMergePreview? preview,
    bool external,
    Exception? guard,
    _SourceAcknowledgment source,
  ) async {
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
    ) when _live(execution)) {
      if (error.code == 'EVENT_CHANGED' || error.code == 'SUBMISSION_CHANGED') {
        _editorRevision++;
        _invalidatePreview();
        _notifyListeners();
      }
    }
    await _refreshAfterResolution(execution, result);
    return result.map((resolution) {
      if (_live(execution)) {
        _status = AdminSubmissionStatus.accepted;
        _targetEventId = resolution.eventId;
        _contextCommitted();
      }
      return resolution;
    });
  }

  Future<void> _refreshAfterResolution<T>(
    _EditorExecution<dynamic> execution,
    Result<T> result,
  ) async {
    if (!_live(execution) || _externalEvent == null) return;
    final sourceChanged = switch (result) {
      Error(:final AdminContentSubmissionApiException error) =>
        error.code == 'SOURCE_CHANGED',
      _ => false,
    };
    if (result is Error && !sourceChanged) return;
    _acknowledgeCurrentSource = false;
    _acknowledgedSourceHash = null;
    _contextCommitted();
    if (!_live(execution)) return;
    await _loadDetail(execution);
    if (!_live(execution)) return;
    final pending = switch (result) {
      Success(:final AdminEventResolution value) => value.pendingId,
      _ => null,
    };
    if (pending != null) {
      final followup = await _repository.getById(pending);
      if (!_live(execution)) return;
      followup.map((value) => _followupSubmission = value);
      _notifyListeners();
    }
  }

  Exception? _assetGuard({required bool add}) {
    if (submissionId == null) {
      return Exception(
        add
            ? 'Aggiungi foto solo dopo aver creato il contributo.'
            : 'Non puoi rimuovere foto da un nuovo contributo.',
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
    if (add && _assets.length >= kMaximumSubmissionAssetCount) {
      return Exception('Hai raggiunto il limite di foto.');
    }
    return null;
  }

  Future<Result<void>> _addAsset(
    _EditorExecution<void> execution,
    Exception? guard,
  ) async {
    if (guard != null) return Result.error(guard);
    final selectedImage = await _imagePicker.pickImage(
      source: ImageSource.gallery,
    );
    if (!_live(execution)) return _unavailable();
    if (selectedImage == null) return const Result.success(null);
    final task = _contentSubmissionRepository.uploadImageTask(
      File(selectedImage.path),
    );
    _activeImageUploadTask = task;
    try {
      final upload = await task.result;
      if (!_live(execution)) return _unavailable();
      return await upload.asyncFlatMap((uploadedAsset) async {
        final persisted = await _repository.addAsset(
          submissionId!,
          uploadedAsset,
        );
        if (!_live(execution)) return _unavailable();
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
  }

  Future<Result<void>> _deleteAsset(
    _EditorExecution<void> execution,
    int assetId,
    Exception? guard,
  ) async {
    if (guard != null) return Result.error(guard);
    final result = await _repository.deleteAsset(submissionId!, assetId);
    return result.map((_) {
      if (!_live(execution)) return;
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
    _candidatesLane.current?.publish = false;
    _candidatesLane.snapshot = const commands.CommandResult(
      null,
      null,
      null,
      false,
    );
  }

  void _invalidatePreview() {
    _previewGeneration++;
    _mergePreview = null;
    _previewLane.current?.publish = false;
    _previewLane.snapshot = const commands.CommandResult(
      null,
      null,
      null,
      false,
    );
  }

  void _markDirty() {
    _draftRevision++;
    _editorRevision++;
    _invalidatePreview();
    _invalidateCandidates();
    _isDirty = true;
    _notifyListeners();
  }

  bool _live(_EditorExecution<dynamic> execution) =>
      !_disposed && !execution.settled;

  Result<T> _unavailable<T>() =>
      Result.error(Exception('Editor non disponibile.'));

  _EditorLane<T> _createLane<T>(String name) {
    final lane = _EditorLane<T>();
    lane.command = createResultCommandNoParam<T>(() async {
      final execution = lane.current!;
      try {
        if (!_live(execution)) return _unavailable<T>();
        return await execution.action(execution);
      } finally {
        execution.actionSettled = true;
        execution.revision++;
        _scheduleSettlement(lane, execution);
      }
    }, debugName: 'admin_submission_editor_$name');
    void observe() {
      final execution = lane.current;
      if (execution == null || execution.settled) return;
      execution.revision++;
      _scheduleSettlement(lane, execution);
    }

    void forward() {
      final execution = lane.current;
      if (_disposed ||
          execution == null ||
          !execution.started ||
          execution.settled ||
          !execution.publish) {
        return;
      }
      final snapshot = lane.command.results.value;
      if (snapshot.isRunning || snapshot.idle) return;
      lane.snapshot = snapshot;
      _notifyListeners();
    }

    lane.command.results.addListener(observe);
    lane.command.isRunningSync.addListener(observe);
    lane.command.results.addListener(forward);
    lane.removePublic = () => lane.command.results.removeListener(forward);
    lane.removePrivate = () {
      lane.command.results.removeListener(observe);
      lane.command.isRunningSync.removeListener(observe);
    };
    return lane;
  }

  bool _admit<T>(
    _EditorLane<T> lane,
    Future<Result<T>> Function(_EditorExecution<T>) action,
  ) {
    if (!_canAdmit(lane)) return false;
    final execution = _EditorExecution(
      ++_nextExecution,
      action,
      candidateRevision: _candidateRevision,
      contextRevision: _editorRevision,
    );
    lane
      ..current = execution
      ..executionId = execution.id
      ..snapshot = const commands.CommandResult.isLoading();
    if (identical(lane, _saveLane)) {
      _savedExecutionId = null;
      _savedDraftRevision = null;
    }
    if (_mutations.any((value) => identical(value, lane))) {
      _invalidateCandidates();
      // Apply already captured its committed tokens in the request closure.
      _invalidatePreview();
    }
    _notifyListeners();
    if (_disposed) {
      execution.actionSettled = true;
      _scheduleSettlement(lane, execution);
    } else if (identical(lane.current, execution)) {
      execution.started = true;
      lane.command.run();
    }
    return true;
  }

  void _scheduleSettlement<T>(
    _EditorLane<T> lane,
    _EditorExecution<T> execution,
  ) {
    if (execution.queued || execution.settled) return;
    execution.queued = true;
    final revision = execution.revision;
    scheduleMicrotask(() {
      unawaited(
        Future<void>(() {
          execution.queued = false;
          if (execution.settled || !identical(lane.current, execution)) return;
          if (lane.command.isRunningSync.value || !execution.actionSettled) {
            return;
          }
          if (revision != execution.revision) {
            _scheduleSettlement(lane, execution);
            return;
          }
          execution.settled = true;
          lane
            ..settlements += 1
            ..current = null;
          if (_disposed) {
            _release(lane);
          } else {
            _notifyListeners();
          }
        }),
      );
    });
  }

  void _release<T>(_EditorLane<T> lane) {
    if (lane.released || lane.current != null) return;
    lane.released = true;
    lane.removePrivate?.call();
    lane.removePrivate = null;
    lane.command.dispose();
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
    for (final lane in _lanes) {
      lane.removePublic?.call();
      lane.removePublic = null;
    }
    _activeImageUploadTask?.cancel();
    _activeImageUploadTask = null;
    scheduleMicrotask(() {
      unawaited(
        Future<void>(() {
          for (final lane in _lanes) {
            if (lane.current == null) _release(lane);
          }
        }),
      );
    });
    if (_notifyDepth == 0) {
      super.dispose();
    } else if (!_superDisposeQueued) {
      _superDisposeQueued = true;
      scheduleMicrotask(super.dispose);
    }
  }
}
