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

/// Immutable action input captured by one admitted editor operation.
typedef _EditorAction<T> = Future<Result<T>> Function();

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

  /// Whether this owner has revoked admission and publication authority.
  bool get isDisposed => _disposed;

  /// A current clean Save success remains close-authorized after settlement.
  bool get canCloseAfterSave =>
      !_disposed &&
      !_isDirty &&
      _savedExecutionId == _saveEffectId &&
      _savedExecutionId != null &&
      _savedDraftRevision == _draftRevision &&
      _saveSnapshot.completed;

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
  bool get loading => _reserved.contains(_loadCommand);

  /// Whether edits have not yet been saved.
  bool get isDirty => _isDirty;

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

  bool get _canChangeContext => !_disposed && !loading && !operationRunning;
  bool get _canChangeFields =>
      !_disposed &&
      !loading &&
      (!operationRunning || _reserved.contains(_saveCommand));

  bool _canAdmit(commands.Command<dynamic, dynamic> command) {
    if (_disposed || _stopped || _reserved.contains(command) || loading) {
      return false;
    }
    if (identical(command, _loadCommand)) {
      return !(_hasLoadedDetail && _isDirty) && _reserved.isEmpty;
    }
    if (identical(command, _candidatesCommand)) return true;
    if (identical(command, _previewCommand)) return !operationRunning;
    return !operationRunning &&
        (!identical(command, _keepCommand) ||
            !_reserved.contains(_previewCommand));
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
  bool get canRequestSave => _canAdmit(_saveCommand);

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
  bool requestLoad() {
    if (!canRequestLoad) return false;
    _loadEffectId = ++_nextEffectId;
    _loadSnapshot = const commands.CommandResult.isLoading();
    return _admit(_loadCommand, _loadDetail);
  }

  /// Captures the complete current draft before notifying or deferred entry.
  bool requestSave() {
    if (!canRequestSave) return false;
    final draft = _captureSave();
    final effectId = _nextEffectId + 1;
    _saveEffectId = ++_nextEffectId;
    _saveSnapshot = const commands.CommandResult.isLoading();
    return _admit(_saveCommand, () => _save(draft, saveEffectId: effectId));
  }

  /// Reserves rejection with immutable source acknowledgment.
  bool requestReject() {
    if (!canRequestReject) return false;
    final guard = _moderationGuardError();
    final source = _sourceAcknowledgment;
    _rejectEffectId = ++_nextEffectId;
    _rejectSnapshot = const commands.CommandResult.isLoading();
    return _admit(_rejectCommand, () => _reject(guard, source));
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
  bool requestLink(int target) {
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
  bool requestPreview() {
    if (!canRequestPreview) return false;
    final target = _targetEventId;
    final generation = _previewGeneration;
    final eligible = submissionId != null && target != null && !_isDirty;
    _previewEffectId = ++_nextEffectId;
    _previewSnapshot = const commands.CommandResult.isLoading();
    return _admit(
      _previewCommand,
      () => _preview(target, generation, eligible: eligible),
    );
  }

  /// Searches desired input; refusal has no observable side effects.
  bool requestFindCandidates() {
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
  bool requestApply() {
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
  bool requestKeepCurrent(AdminEventMergeGroup group) {
    if (!canRequestKeepCurrent) return false;
    final preview = _mergePreview;
    final target = _targetEventId;
    final generation = _previewGeneration;
    final eligible =
        isEditable &&
        !_isDirty &&
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
  bool requestAddAsset() {
    if (!canRequestAddAsset) return false;
    final guard = _assetGuard(add: true);
    _addEffectId = ++_nextEffectId;
    _addSnapshot = const commands.CommandResult.isLoading();
    return _admit(_addCommand, () => _addAsset(guard));
  }

  /// Reserves removal of the exact captured persisted association.
  bool requestDeleteAsset(int assetId) {
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

  Future<Result<void>> _loadDetail() async {
    final submissionId = this.submissionId;
    if (submissionId == null) return const Result.success(null);

    final draftRevision = _draftRevision;
    final result = await _repository.getById(submissionId);
    return result.map((submission) {
      if (_disposed) return;
      if (_draftRevision != draftRevision) {
        if (loading) {
          _loadSnapshot = const commands.CommandResult(null, null, null, false);
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

  Future<Result<void>> _save(_SaveDraft draft, {int? saveEffectId}) async {
    if (draft.error != null) {
      if (!_disposed &&
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
      if (_disposed) return;
      _editorRevision++;
      _invalidatePreview();
      _invalidateCandidates();
      _isDirty = _draftRevision != draft.revision;
      if (saveEffectId != null) {
        _savedExecutionId = saveEffectId;
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
    await _refreshAfterResolution(result);
    return result.map((_) {
      if (_disposed) return;
      _status = AdminSubmissionStatus.rejected;
      _contextCommitted();
    });
  }

  Future<Result<AdminSubmissionPromotion>> _promote(
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
    await _refreshAfterResolution(result);
    return result.map((promotion) {
      if (!_disposed) {
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
    if (guard != null) return Result.error(guard);
    final result = await _repository.link(
      submissionId!,
      target,
      acknowledgeCurrentSource: source.acknowledge,
      expectedSourceHash: source.hash,
    );
    await _refreshAfterResolution(result);
    return result.map((resolution) {
      if (!_disposed) {
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
      if (_disposed ||
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
    if (!eligible) {
      return Result.error(
        Exception(
          'Seleziona un evento e salva le modifiche prima dell’anteprima.',
        ),
      );
    }
    final result = await _repository.mergePreview(submissionId!, target!);
    return result.map((value) {
      if (_disposed ||
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
    if (_disposed) return _unavailable();
    final result = await _save(_captureSave());
    if (_disposed) return _unavailable();
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
        target,
        _previewGeneration,
        eligible: submissionId != null && _targetEventId != null && !_isDirty,
      ),
    );
  }

  Future<Result<AdminEventResolution>> _apply(
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
    ) when !_disposed) {
      if (error.code == 'EVENT_CHANGED' || error.code == 'SUBMISSION_CHANGED') {
        _editorRevision++;
        _invalidatePreview();
        _notifyListeners();
      }
    }
    await _refreshAfterResolution(result);
    return result.map((resolution) {
      if (!_disposed) {
        _status = AdminSubmissionStatus.accepted;
        _targetEventId = resolution.eventId;
        _contextCommitted();
      }
      return resolution;
    });
  }

  Future<void> _refreshAfterResolution<T>(Result<T> result) async {
    if (_disposed || _externalEvent == null) return;
    final sourceChanged = switch (result) {
      Error(:final AdminContentSubmissionApiException error) =>
        error.code == 'SOURCE_CHANGED',
      _ => false,
    };
    if (result is Error && !sourceChanged) return;
    _acknowledgeCurrentSource = false;
    _acknowledgedSourceHash = null;
    _contextCommitted();
    if (_disposed) return;
    await _loadDetail();
    if (_disposed) return;
    final pending = switch (result) {
      Success(:final AdminEventResolution value) => value.pendingId,
      _ => null,
    };
    if (pending != null) {
      final followup = await _repository.getById(pending);
      if (_disposed) return;
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

  Future<Result<void>> _addAsset(Exception? guard) async {
    if (guard != null) return Result.error(guard);
    final selectedImage = await _imagePicker.pickImage(
      source: ImageSource.gallery,
    );
    if (_disposed) return _unavailable();
    if (selectedImage == null) return const Result.success(null);
    final task = _contentSubmissionRepository.uploadImageTask(
      File(selectedImage.path),
    );
    _activeImageUploadTask = task;
    try {
      final upload = await task.result;
      if (_disposed) return _unavailable();
      return await upload.asyncFlatMap((uploadedAsset) async {
        final persisted = await _repository.addAsset(
          submissionId!,
          uploadedAsset,
        );
        if (_disposed) return _unavailable();
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

  Future<Result<void>> _deleteAsset(int assetId, Exception? guard) async {
    if (guard != null) return Result.error(guard);
    final result = await _repository.deleteAsset(submissionId!, assetId);
    return result.map((_) {
      if (_disposed) return;
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
        final terminal = command.results.value;
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
    _reserved.add(command);
    if (identical(command, _saveCommand)) {
      _savedExecutionId = null;
      _savedDraftRevision = null;
    }
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
      command.run(action);
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
