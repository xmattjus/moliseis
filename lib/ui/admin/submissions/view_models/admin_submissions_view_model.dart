import 'dart:collection' show UnmodifiableListView;

import 'package:flutter/foundation.dart';
import 'package:moliseis/domain/models/admin_submission.dart';
import 'package:moliseis/domain/models/admin_submission_status.dart';
import 'package:moliseis/domain/repositories/admin_content_submission_repository.dart';
import 'package:moliseis/utils/command.dart';
import 'package:moliseis/utils/result.dart';

/// Dashboard state that loads submissions and filters them client-side.
class AdminSubmissionsViewModel extends ChangeNotifier {
  /// Creates the submissions dashboard state backed by [repository].
  AdminSubmissionsViewModel({
    required AdminContentSubmissionRepository repository,
  }) : _repository = repository {
    load = Command0<void>(_load);
  }

  final AdminContentSubmissionRepository _repository;
  final List<AdminSubmission> _items = <AdminSubmission>[];
  AdminSubmissionStatus? _filter;
  var _disposed = false;

  /// Loads the latest dashboard summaries.
  late Command0<void> load;

  /// All loaded submission summaries, before filtering.
  UnmodifiableListView<AdminSubmission> get items =>
      UnmodifiableListView(_items);

  /// Loaded summaries matching the currently selected [filter].
  List<AdminSubmission> get filteredItems {
    final filter = _filter;
    return filter == null
        ? items
        : _items.where((item) => item.status == filter).toList();
  }

  /// The active status filter, where null represents all submissions.
  AdminSubmissionStatus? get filter => _filter;

  /// Whether a list request is currently in progress.
  bool get loading => load.running;

  /// Whether the latest list request failed.
  bool get error => load.error;

  /// Whether at least one submission has been loaded.
  bool get hasData => _items.isNotEmpty;

  /// Updates the client-side moderation status filter without reloading.
  void setFilter(AdminSubmissionStatus? status) {
    _filter = status;
    _notifyListeners();
  }

  Future<Result<void>> _load() async {
    final result = await _repository.list();

    return result.map((items) {
      _items
        ..clear()
        ..addAll(items);
      _notifyListeners();
    });
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
