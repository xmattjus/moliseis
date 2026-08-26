import 'dart:collection' show UnmodifiableListView;
import 'dart:io' show File;

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
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
import 'package:moliseis/utils/extensions/extensions.dart';
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
  DateTime? _startDate;
  DateTime? _endDate;
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

  /// Whether this route edits an existing persisted submission.
  bool get isEditMode => submissionId != null;

  /// Selected content category, which is normalized on save when absent.
  ContentCategory? get category => _category;

  /// Editable municipality value.
  String? get city => _city;

  /// Editable place or event name.
  String? get name => _name;

  /// Editable plain-text description projection.
  String? get description => _description;

  /// Editable rich-text Delta projection.
  List<Map<String, dynamic>>? get descriptionDelta => _descriptionDelta;

  /// Editable event start date and time.
  DateTime? get startDate => _startDate;

  /// Editable event end date and time.
  DateTime? get endDate => _endDate;

  /// Whether the editable dates identify an event.
  bool get isEvent => _startDate != null || _endDate != null;

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
      save.running || promote.running || reject.running || assetMutationRunning;

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

  /// Updates the start date while preserving the previous start's clock time.
  ///
  /// A date-only edit changes just the calendar day: the previous start's
  /// hour, minute, and sub-second components and its UTC/local representation
  /// are kept, because date pickers emit local-represented values while
  /// loaded backend timestamps are commonly UTC-represented. An end date that
  /// the new start would overtake is repaired to the end of the start's
  /// calendar day, preserving whether the dates are UTC- or local-represented.
  void setStartDate(DateTime? date) {
    final previousStart = _startDate;
    final startDate = date == null || previousStart == null
        ? date
        : _withCalendarDate(previousStart, date);

    _startDate = startDate;
    if (startDate != null) {
      _ensureEndNotBefore(startDate);
    }
    _markDirty();
  }

  /// Updates the time portion of the selected start date.
  ///
  /// Like [setStartDate], an end date overtaken by the new start time is
  /// repaired to the end of the start's calendar day.
  void setStartTime(DateTime? date) {
    final startDate = _startDate?.copyWith(
      hour: date?.hour,
      minute: date?.minute,
    );

    _startDate = startDate;
    if (startDate != null) {
      _ensureEndNotBefore(startDate);
    }
    _markDirty();
  }

  /// Updates the end date and marks the editor dirty.
  ///
  /// An actively selected date is normalized to the end of that calendar day,
  /// preserving UTC- or local-representation, so a same-day selection can
  /// never land at midnight before a timed start. Loaded persisted values are
  /// hydrated by [_loadDetail] directly and are never normalized here.
  void setEndDate(DateTime? date) {
    _endDate = date == null ? null : _endOfDayPreservingZone(date);
    _markDirty();
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
      _category = submission.category;
      _city = submission.city;
      _name = submission.name;
      _description = submission.description;
      _descriptionDelta = submission.descriptionDelta;
      _startDate = submission.startDate;
      _endDate = submission.endDate;
      // Lossless hydration: double.toString() round-trips exactly, unlike a
      // fixed-precision rendering. A legacy half-pair hydrates asymmetric
      // drafts on purpose so the problem stays visible until corrected.
      _latitudeText = submission.latitude?.toString() ?? '';
      _longitudeText = submission.longitude?.toString() ?? '';
      _contributorName = submission.userName;
      _contributorEmail = submission.userEmail;
      _status = submission.status;
      _promotion = submission.promotion;
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

  /// Returns [current] moved to the calendar day of [picked].
  ///
  /// The result keeps [current]'s hour, minute, second, millisecond,
  /// microsecond, and UTC/local representation so a date-only edit cannot
  /// shift the represented clock time or the instant it denotes.
  DateTime _withCalendarDate(DateTime current, DateTime picked) => current.isUtc
      ? DateTime.utc(
          picked.year,
          picked.month,
          picked.day,
          current.hour,
          current.minute,
          current.second,
          current.millisecond,
          current.microsecond,
        )
      : DateTime(
          picked.year,
          picked.month,
          picked.day,
          current.hour,
          current.minute,
          current.second,
          current.millisecond,
          current.microsecond,
        );

  /// Returns the end of [value]'s calendar day, keeping whether [value] is
  /// UTC- or local-represented.
  ///
  /// The shared `DateTime.endOfDay` extension always builds a local DateTime,
  /// so UTC values are constructed explicitly to avoid changing the
  /// represented zone of repaired or normalized timestamps.
  DateTime _endOfDayPreservingZone(DateTime value) => value.isUtc
      ? DateTime.utc(value.year, value.month, value.day, 23, 59, 59, 999, 999)
      : value.endOfDay;

  /// Repairs an end date that [startDate] would overtake.
  ///
  /// The repaired end becomes the end of the start's calendar day in the
  /// same UTC/local representation as the start. This is an automatic fix
  /// within the setter that triggered it and emits no extra notifications.
  void _ensureEndNotBefore(DateTime startDate) {
    final endDate = _endDate;
    if (endDate != null && endDate.isBefore(startDate)) {
      _endDate = _endOfDayPreservingZone(startDate);
    }
  }

  Future<Result<void>> _save() async {
    if (promote.running || reject.running || assetMutationRunning) {
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

    final startDate = _startDate;
    final endDate = _endDate;
    if (endDate != null && (startDate == null || endDate.isBefore(startDate))) {
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
      startDate: startDate,
      endDate: endDate,
      latitude: latitude,
      longitude: longitude,
    );
    final submissionId = this.submissionId;
    final result = submissionId == null
        ? await _repository.create(input)
        : await _repository.update(submissionId, input);

    return result.map((_) {
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
  /// [isPromoting] excludes the calling command from the mutual-exclusion
  /// check, because its own `running` state is already true while its action
  /// executes.
  Exception? _moderationGuardError({required bool isPromoting}) {
    final submissionId = this.submissionId;
    if (submissionId == null) {
      return Exception('Non puoi moderare un nuovo contributo.');
    }
    if (!_hasLoadedDetail) {
      return Exception('Carica il contributo prima di moderarlo.');
    }
    final otherModerationRunning = isPromoting
        ? reject.running
        : promote.running;
    if (save.running || otherModerationRunning || assetMutationRunning) {
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
    final guard = _moderationGuardError(isPromoting: false);
    if (guard != null) return Result.error(guard);

    final submissionId = this.submissionId!;
    final result = await _repository.reject(submissionId);
    return result.map((_) {
      _status = AdminSubmissionStatus.rejected;
      _notifyListeners();
    });
  }

  Future<Result<AdminSubmissionPromotion>> _promote(
    AdminPromotionTarget target,
  ) async {
    final guard = _moderationGuardError(isPromoting: true);
    if (guard != null) return Result.error(guard);

    final submissionId = this.submissionId!;
    final result = await _repository.promote(submissionId, target);
    return result.map((promotion) {
      // Same-target idempotent retries report the original promotion exactly
      // like a first success; no reload is needed because the repository
      // result already carries the durable linkage.
      _status = AdminSubmissionStatus.accepted;
      _promotion = promotion;
      _notifyListeners();
      return promotion;
    });
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
    if (save.running || promote.running || reject.running || addAsset.running) {
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
