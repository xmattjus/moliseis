import 'dart:collection' show UnmodifiableListView;
import 'dart:io' show File;

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
import 'package:moliseis/utils/command.dart';
import 'package:moliseis/utils/constants.dart';
import 'package:moliseis/utils/result.dart';

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
    load = Command0<void>(_loadDetail);
    save = Command0<void>(_save);
    reject = Command0<void>(_reject);
    promote = Command1<AdminSubmissionPromotion, AdminPromotionTarget>(
      _promote,
    );
    link = Command1<AdminEventResolution, int>(_link);
    preview = Command0<void>(_preview);
    findCandidates = Command1<void, String>(_findCandidates);
    apply = Command0<AdminEventResolution>(_apply);
    keepCurrent = Command1<void, AdminEventMergeGroup>(_keepCurrent);
    addAsset = Command0<void>(_addAsset);
    deleteAsset = Command1<void, int>(_deleteAsset);
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

  /// Loads a persisted submission when editing.
  late Command0<void> load;

  /// Saves the editor-owned fields by creating or updating a submission.
  late Command0<void> save;

  /// Rejects a clean persisted pending submission.
  late Command0<void> reject;

  /// Publishes a clean persisted pending submission as an explicit target.
  late Command1<AdminSubmissionPromotion, AdminPromotionTarget> promote;

  /// Adds one gallery image to the persisted pending submission.
  late Command0<void> addAsset;

  /// Removes one persisted image association from the pending submission.
  late Command1<void, int> deleteAsset;

  AdminEventCandidates? _candidates;

  /// Candidate discovery is advisory and never changes moderation readiness.
  late Command1<void, String> findCandidates;

  AdminEventCandidates? get candidates => _candidates;

  /// Copies one complete Event group and saves through the ordinary editor.
  late Command1<void, AdminEventMergeGroup> keepCurrent;

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
    _acknowledgeCurrentSource = selected && isSourceStale;
    _acknowledgedSourceHash = _acknowledgeCurrentSource
        ? _externalEvent?.currentHash
        : null;
    _notifyListeners();
  }

  void setIgnoreSource({required bool ignored}) {
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

  /// Accepts against the selected canonical Event without copying media.
  late Command1<AdminEventResolution, int> link;

  /// Loads an authoritative merge preview for the linked Event.
  late Command0<void> preview;

  /// Applies the preview with its untouched concurrency tokens.
  late Command0<AdminEventResolution> apply;

  AdminExternalEvent? get externalEvent => _externalEvent;
  bool get isExternalUpdate =>
      _externalEvent?.mode == AdminExternalEventMode.update;
  int? get targetEventId => _targetEventId;
  AdminEventMergePreview? get mergePreview => _mergePreview;

  /// Selecting a different target invalidates its preview.
  void selectTargetEvent(int? id) {
    _previewGeneration++;
    _targetEventId = id;
    _mergePreview = null;
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
  bool get loading => load.running;

  /// Whether edits have not yet been saved.
  bool get isDirty => _isDirty;

  /// Whether an asset add or delete operation is in progress.
  bool get assetMutationRunning => addAsset.running || deleteAsset.running;

  /// Whether any operation can mutate the editor or its submission.
  bool get operationRunning =>
      save.running ||
      promote.running ||
      reject.running ||
      link.running ||
      apply.running ||
      keepCurrent.running ||
      assetMutationRunning;

  /// Updates the selected category and marks the editor dirty.
  void setCategory(ContentCategory? category) {
    _category = category;
    _markDirty();
  }

  /// Updates the city and marks the editor dirty.
  void setCity(String? city) {
    _city = city;
    _markDirty();
  }

  /// Updates the place or event name and marks the editor dirty.
  void setName(String? name) {
    _name = name;
    _markDirty();
  }

  /// Updates matching plain-text and rich-text description projections.
  void setDescription({
    required String? description,
    required List<Map<String, dynamic>>? descriptionDelta,
  }) {
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

  void setEventEnabled(bool enabled) {
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
    _eventDates = result.draft;
    _eventTimeIssue = result.issue;
    _markDirty();
  }

  /// Publishes a persistence-blocking event-time issue for the controlled UI.
  ///
  /// Returns whether the current temporal draft is eligible for saving. The
  /// issue is transient and is cleared by the next valid temporal edit.
  bool validateEventTimeForSave({EventDateDraft? draft}) {
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
    _latitudeText = value;
    _markDirty();
  }

  /// Updates the raw longitude draft and marks the editor dirty.
  void setLongitudeText(String value) {
    _longitudeText = value;
    _markDirty();
  }

  /// Updates both coordinate drafts from one map selection.
  ///
  /// This is one logical change: both drafts are written with six-decimal
  /// formatting and the editor is marked dirty exactly once.
  void setCoordinates(double latitude, double longitude) {
    _latitudeText = latitude.toStringAsFixed(6);
    _longitudeText = longitude.toStringAsFixed(6);
    _markDirty();
  }

  Future<Result<void>> _loadDetail() async {
    final submissionId = this.submissionId;
    if (submissionId == null) return const Result.success(null);

    final result = await _repository.getById(submissionId);
    return result.map((submission) {
      if (_disposed) return;
      _hydrationRevision++;
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

  Future<Result<void>> _save({bool fromKeepCurrent = false}) async {
    if (promote.running ||
        reject.running ||
        link.running ||
        apply.running ||
        (keepCurrent.running && !fromKeepCurrent) ||
        assetMutationRunning) {
      return Result.error(
        Exception('Attendi il completamento della moderazione.'),
      );
    }
    // Editorial updates are pending-only for existing submissions. The
    // backend enforces the same predicate authoritatively; create mode is
    // unaffected.
    if (isEditMode && _status != AdminSubmissionStatus.pending) {
      return Result.error(
        Exception('I contributi pubblicati o rifiutati non sono modificabili.'),
      );
    }

    final city = _city;
    final name = _name;
    if (city == null || city.isEmpty || name == null || name.isEmpty) {
      return Result.error(Exception('Compila i campi obbligatori.'));
    }

    if (!validateEventTimeForSave()) {
      return Result.error(Exception('Inserisci un intervallo di date valido.'));
    }

    final coordinates = _parsedCoordinates();
    if (coordinates == null) {
      return Result.error(Exception('Inserisci coordinate valide.'));
    }
    final (latitude, longitude) = coordinates;

    final input = AdminSubmissionInput(
      category: _category ?? ContentCategory.unknown,
      city: city,
      name: name,
      description: _description,
      descriptionDelta: _descriptionDelta,
      allDay: _eventDates.allDay,
      startDate: _eventDates.startInstantUtc,
      endDate: _eventDates.endInstantUtc,
      latitude: latitude,
      longitude: longitude,
    );
    final submissionId = this.submissionId;
    final result = submissionId == null
        ? await _repository.create(input)
        : await _repository.update(submissionId, input);

    return result.map((_) {
      _previewGeneration++;
      _mergePreview = null;
      _isDirty = false;
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

  /// Guards shared by both moderation mutations: only a loaded, persisted,
  /// clean, pending submission can be moderated while nothing else runs.
  ///
  /// [caller] excludes the calling command from the mutual-exclusion
  /// check, because its own `running` state is already true while its action
  /// executes.
  Exception? _moderationGuardError({required String caller}) {
    final submissionId = this.submissionId;
    if (submissionId == null) {
      return Exception('Non puoi moderare un nuovo contributo.');
    }
    if (!_hasLoadedDetail) {
      return Exception('Carica il contributo prima di moderarlo.');
    }
    final otherModerationRunning =
        (caller != 'promote' && promote.running) ||
        (caller != 'reject' && reject.running) ||
        (caller != 'link' && link.running) ||
        (caller != 'apply' && apply.running);
    if (save.running ||
        otherModerationRunning ||
        keepCurrent.running ||
        assetMutationRunning) {
      return Exception('Attendi il completamento dell’operazione in corso.');
    }
    if (_isDirty) {
      return Exception('Salva le modifiche prima di pubblicare o rifiutare.');
    }
    if (_status != AdminSubmissionStatus.pending) {
      return Exception('Questo contributo è già stato moderato.');
    }
    return null;
  }

  Future<Result<void>> _reject() async {
    final guard = _moderationGuardError(caller: 'reject');
    if (guard != null) return Result.error(guard);

    final submissionId = this.submissionId!;
    final result = await _repository.reject(
      submissionId,
      ignoreSource: _ignoreSource ? true : null,
      acknowledgeCurrentSource: _acknowledgeCurrentSource ? true : null,
      expectedSourceHash: _acknowledgedSourceHash,
    );
    await _refreshAfterResolution(result);
    return result.map((_) {
      if (_disposed) return;
      _status = AdminSubmissionStatus.rejected;
      _notifyListeners();
    });
  }

  Future<Result<AdminSubmissionPromotion>> _promote(
    AdminPromotionTarget target,
  ) async {
    final guard = _moderationGuardError(caller: 'promote');
    if (guard != null) return Result.error(guard);

    if (!hasPublishableCategory) {
      return Result.error(
        Exception('Seleziona una categoria e salva prima di pubblicare.'),
      );
    }

    if (target == AdminPromotionTarget.event &&
        !validateEventTimeForSave(
          draft: _eventTimePolicy.enable(_eventDates),
        )) {
      return Result.error(
        Exception('Completa i dati temporali prima di pubblicare l’evento.'),
      );
    }

    final submissionId = this.submissionId!;
    final result = await _repository.promote(
      submissionId,
      target,
      acknowledgeCurrentSource: _acknowledgeCurrentSource ? true : null,
      expectedSourceHash: _acknowledgedSourceHash,
    );
    await _refreshAfterResolution(result);
    return result.map((promotion) {
      if (_disposed) return promotion;
      // Same-target idempotent retries report the original promotion exactly
      // like a first success; no reload is needed because the repository
      // result already carries the durable linkage.
      _status = AdminSubmissionStatus.accepted;
      _promotion = promotion;
      _notifyListeners();
      return promotion;
    });
  }

  Future<Result<AdminEventResolution>> _link(int target) async {
    final guard = _moderationGuardError(caller: 'link');
    if (guard != null) return Result.error(guard);
    if (startDate == null) {
      return Result.error(
        Exception('Imposta una data di inizio per collegare un evento.'),
      );
    }
    final result = await _repository.link(
      submissionId!,
      target,
      acknowledgeCurrentSource: _acknowledgeCurrentSource ? true : null,
      expectedSourceHash: _acknowledgedSourceHash,
    );
    await _refreshAfterResolution(result);
    return result.map((resolution) {
      if (_disposed) return resolution;
      _status = AdminSubmissionStatus.accepted;
      _targetEventId = resolution.eventId;
      _notifyListeners();
      return resolution;
    });
  }

  Future<Result<void>> _findCandidates(String search) async {
    final id = submissionId;
    if (id == null || startDate == null) {
      return Result.error(
        Exception('Carica un contributo evento prima di cercare.'),
      );
    }
    final result = await _repository.eventCandidates(
      id,
      searchName: search.trim().isEmpty ? null : search.trim(),
    );
    return result.map((value) {
      if (_disposed) return;
      _candidates = value;
      _notifyListeners();
    });
  }

  Future<Result<void>> _preview({bool fromKeepCurrent = false}) async {
    final id = submissionId;
    final target = _targetEventId;
    if (id == null ||
        target == null ||
        _isDirty ||
        (operationRunning && !fromKeepCurrent)) {
      return Result.error(
        Exception(
          'Seleziona un evento e salva le modifiche prima dell’anteprima.',
        ),
      );
    }
    final generation = _previewGeneration;
    final result = await _repository.mergePreview(id, target);
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

  Future<Result<void>> _keepCurrent(AdminEventMergeGroup group) async {
    if (_mergePreview == null ||
        save.running ||
        promote.running ||
        reject.running ||
        link.running ||
        apply.running ||
        preview.running ||
        assetMutationRunning ||
        !isEditable) {
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
    final result = await _save(fromKeepCurrent: true);
    if (_disposed) return const Result.success(null);
    return await result.asyncFlatMap((_) => _preview(fromKeepCurrent: true));
  }

  Future<Result<AdminEventResolution>> _apply() async {
    final guard = _moderationGuardError(caller: 'apply');
    if (guard != null) return Result.error(guard);
    final value = _mergePreview;
    if (!isExternalUpdate || value == null) {
      return Result.error(
        Exception('Carica una nuova anteprima prima di applicare.'),
      );
    }
    final result = await _repository.apply(
      submissionId!,
      value,
      acknowledgeCurrentSource: _acknowledgeCurrentSource ? true : null,
      expectedSourceHash: _acknowledgedSourceHash,
    );
    await _refreshAfterResolution(result);
    return result.map((resolution) {
      if (_disposed) return resolution;
      _status = AdminSubmissionStatus.accepted;
      _targetEventId = resolution.eventId;
      _mergePreview = null;
      _notifyListeners();
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
    _mergePreview = null;
    _previewGeneration++;
    _notifyListeners();
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

  Future<Result<void>> _addAsset() async {
    final submissionId = this.submissionId;
    if (submissionId == null) {
      return Result.error(
        Exception('Aggiungi foto solo dopo aver creato il contributo.'),
      );
    }
    if (!_hasLoadedDetail) {
      return Result.error(
        Exception('Carica il contributo prima di aggiungere foto.'),
      );
    }
    if (_status != AdminSubmissionStatus.pending) {
      return Result.error(
        Exception('Puoi modificare le foto solo dei contributi in attesa.'),
      );
    }
    if (_assets.length >= kMaximumSubmissionAssetCount) {
      return Result.error(Exception('Hai raggiunto il limite di foto.'));
    }
    if (save.running ||
        promote.running ||
        reject.running ||
        link.running ||
        apply.running ||
        keepCurrent.running ||
        deleteAsset.running) {
      return Result.error(
        Exception('Attendi il completamento dell’operazione in corso.'),
      );
    }

    final selectedImage = await _imagePicker.pickImage(
      source: ImageSource.gallery,
    );
    if (_disposed || selectedImage == null) return const Result.success(null);

    final task = _contentSubmissionRepository.uploadImageTask(
      File(selectedImage.path),
    );
    _activeImageUploadTask = task;

    try {
      final uploadResult = await task.result;
      if (_disposed) return const Result.success(null);

      return await uploadResult.asyncFlatMap((uploadedAsset) async {
        final persistedAsset = await _repository.addAsset(
          submissionId,
          uploadedAsset,
        );
        if (_disposed) return const Result.success(null);

        return persistedAsset.map((asset) {
          _assets.add(asset);
          _notifyListeners();
        });
      });
    } finally {
      if (identical(_activeImageUploadTask, task)) {
        _activeImageUploadTask = null;
      }
    }
  }

  Future<Result<void>> _deleteAsset(int assetId) async {
    final submissionId = this.submissionId;
    if (submissionId == null) {
      return Result.error(
        Exception('Non puoi rimuovere foto da un nuovo contributo.'),
      );
    }
    if (!_hasLoadedDetail) {
      return Result.error(
        Exception('Carica il contributo prima di rimuovere foto.'),
      );
    }
    if (_status != AdminSubmissionStatus.pending) {
      return Result.error(
        Exception('Puoi modificare le foto solo dei contributi in attesa.'),
      );
    }
    if (save.running ||
        promote.running ||
        reject.running ||
        link.running ||
        apply.running ||
        keepCurrent.running ||
        addAsset.running) {
      return Result.error(
        Exception('Attendi il completamento dell’operazione in corso.'),
      );
    }
    if (!_assets.any((asset) => asset.id == assetId)) {
      return Result.error(Exception('La foto non appartiene al contributo.'));
    }

    final result = await _repository.deleteAsset(submissionId, assetId);
    if (_disposed) return const Result.success(null);

    return result.map((_) {
      _assets.removeWhere((asset) => asset.id == assetId);
      _notifyListeners();
    });
  }

  void _markDirty() {
    _previewGeneration++;
    _mergePreview = null;
    _isDirty = true;
    _notifyListeners();
  }

  void _notifyListeners() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _activeImageUploadTask?.cancel();
    _activeImageUploadTask = null;
    super.dispose();
  }
}
