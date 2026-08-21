import 'dart:collection' show UnmodifiableListView;

import 'package:flutter/foundation.dart';
import 'package:moliseis/domain/models/admin_submission_asset.dart';
import 'package:moliseis/domain/models/admin_submission_input.dart';
import 'package:moliseis/domain/models/admin_submission_status.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/repositories/admin_content_submission_repository.dart';
import 'package:moliseis/utils/command.dart';
import 'package:moliseis/utils/result.dart';

/// Route-scoped state for creating or editing an admin submission.
///
/// The editor keeps its draft only in memory and deliberately has no public
/// draft-repository dependency. Persisted assets are read-only in this MVP.
class AdminSubmissionEditorViewModel extends ChangeNotifier {
  /// Creates editor state for a new submission or the supplied [submissionId].
  ///
  /// [creatorName] and [creatorEmail] are display-only context for create mode;
  /// they are never included in an [AdminSubmissionInput].
  AdminSubmissionEditorViewModel({
    required AdminContentSubmissionRepository repository,
    this.submissionId,
    String? creatorName,
    String? creatorEmail,
  }) : _repository = repository,
       _contributorName = creatorName,
       _contributorEmail = creatorEmail {
    load = Command0<void>(_loadDetail);
    save = Command0<void>(_save);
    changeStatus = Command1<void, AdminSubmissionStatus>(_changeStatus);
  }

  final AdminContentSubmissionRepository _repository;

  /// The persisted identifier being edited, or null for a new submission.
  final int? submissionId;

  ContentCategory? _category;
  String? _city;
  String? _name;
  String? _description;
  List<Map<String, dynamic>>? _descriptionDelta;
  DateTime? _startDate;
  DateTime? _endDate;
  String? _contributorName;
  String? _contributorEmail;
  AdminSubmissionStatus? _status;
  DateTime? _createdAt;
  DateTime? _modifiedAt;
  final List<AdminSubmissionAsset> _assets = <AdminSubmissionAsset>[];
  var _hasLoadedDetail = false;
  var _isDirty = false;
  var _disposed = false;

  /// Loads a persisted submission when editing.
  late Command0<void> load;

  /// Saves the editor-owned fields by creating or updating a submission.
  late Command0<void> save;

  /// Changes a clean persisted submission's moderation status.
  late Command1<void, AdminSubmissionStatus> changeStatus;

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

  /// Read-only contributor name from the loaded detail or create context.
  String? get contributorName => _contributorName;

  /// Read-only contributor e-mail from the loaded detail or create context.
  String? get contributorEmail => _contributorEmail;

  /// Current moderation state for an existing submission.
  AdminSubmissionStatus? get status => _status;

  /// Timestamp at which the loaded submission was created.
  DateTime? get createdAt => _createdAt;

  /// Timestamp at which the loaded submission was last modified.
  DateTime? get modifiedAt => _modifiedAt;

  /// Persisted read-only assets from the loaded detail.
  UnmodifiableListView<AdminSubmissionAsset> get assets =>
      UnmodifiableListView<AdminSubmissionAsset>(_assets);

  /// Whether edit-mode detail data has successfully loaded.
  bool get hasLoadedDetail => _hasLoadedDetail;

  /// Whether a detail request is in progress.
  bool get loading => load.running;

  /// Whether edits have not yet been saved.
  bool get isDirty => _isDirty;

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

  /// Updates the start date while preserving its selected time.
  ///
  /// An end date before the new start is clamped to the end of the start day,
  /// matching the public submission ViewModel's date behavior.
  void setStartDate(DateTime? date) {
    var endDate = _endDate;
    final startDate = date?.copyWith(
      hour: _startDate?.hour,
      minute: _startDate?.minute,
    );

    if (startDate != null && endDate != null && endDate.isBefore(startDate)) {
      endDate = startDate.copyWith(hour: 23, minute: 55, second: 55);
    }

    _startDate = startDate;
    _endDate = endDate;
    _markDirty();
  }

  /// Updates the time portion of the selected start date.
  void setStartTime(DateTime? date) {
    _startDate = _startDate?.copyWith(
      hour: date?.hour,
      minute: date?.minute,
    );
    _markDirty();
  }

  /// Updates the end date and marks the editor dirty.
  void setEndDate(DateTime? date) {
    _endDate = date;
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
      _contributorName = submission.userName;
      _contributorEmail = submission.userEmail;
      _status = submission.status;
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

  Future<Result<void>> _save() async {
    final city = _city;
    final name = _name;
    if (city == null || city.isEmpty || name == null || name.isEmpty) {
      return Result.error(Exception('Compila i campi obbligatori.'));
    }

    final input = AdminSubmissionInput(
      category: _category ?? ContentCategory.unknown,
      city: city,
      name: name,
      description: _description,
      descriptionDelta: _descriptionDelta,
      startDate: _startDate,
      endDate: _endDate,
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

  Future<Result<void>> _changeStatus(AdminSubmissionStatus status) async {
    final submissionId = this.submissionId;
    if (submissionId == null) {
      return Result.error(
        Exception('Non puoi cambiare lo stato di un nuovo contributo.'),
      );
    }
    if (_isDirty) {
      return Result.error(
        Exception('Salva le modifiche prima di cambiare lo stato.'),
      );
    }

    final result = await _repository.changeStatus(submissionId, status);
    return result.map((_) {
      _status = status;
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
    super.dispose();
  }
}
