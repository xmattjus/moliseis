import 'dart:collection' show UnmodifiableListView;

import 'package:flutter/foundation.dart';
import 'package:moliseis/domain/models/admin_external_event.dart';
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
    load = Command0<void>(() => _loadRequest = _load());
    loadIgnored = Command0<void>(() => _ignoredLoadRequest = _loadIgnored());
    unIgnore = Command1<AdminEventResolution, int>(_unIgnore);
  }

  final AdminContentSubmissionRepository _repository;
  final List<AdminSubmission> _items = <AdminSubmission>[];
  AdminSubmissionStatus? _filter;
  final List<AdminIgnoredSource> _ignoredSources = [];
  bool _showIgnored = false;
  int? _unignoredPendingId;
  bool _refreshingAfterUnIgnore = false;
  Future<Result<void>>? _loadRequest;
  Future<Result<void>>? _ignoredLoadRequest;

  /// Loads source records independently of the submissions list.
  late Command0<void> loadIgnored;

  /// Reactivates a source and refreshes both ignored and pending lists.
  late Command1<AdminEventResolution, int> unIgnore;

  UnmodifiableListView<AdminIgnoredSource> get ignoredSources =>
      UnmodifiableListView(_ignoredSources);
  bool get showIgnored => _showIgnored;
  int? get unignoredPendingId => _unignoredPendingId;

  void setIgnoredFilter() {
    _showIgnored = true;
    _notifyListeners();
  }

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
    _showIgnored = false;
    _filter = status;
    _notifyListeners();
  }

  Future<Result<void>> _load() async {
    if (unIgnore.running && !_refreshingAfterUnIgnore) {
      return Result.error(Exception('Attendi la riattivazione della fonte.'));
    }
    final result = await _repository.list();

    return result.map((items) {
      if (_disposed) return;
      _items
        ..clear()
        ..addAll(items);
      _notifyListeners();
    });
  }

  Future<Result<void>> _loadIgnored() async {
    if (unIgnore.running && !_refreshingAfterUnIgnore) {
      return Result.error(Exception('Attendi la riattivazione della fonte.'));
    }
    final result = await _repository.listIgnoredSources();
    return result.map((sources) {
      if (_disposed) return;
      _ignoredSources
        ..clear()
        ..addAll(sources);
      _notifyListeners();
    });
  }

  Future<Result<AdminEventResolution>> _unIgnore(int recordId) async {
    if (loadIgnored.running || load.running) {
      return Result.error(Exception('Attendi il caricamento delle fonti.'));
    }
    _unignoredPendingId = null;
    _notifyListeners();
    final result = await _repository.unIgnoreSource(recordId);
    return await result.asyncMap((resolution) async {
      if (_disposed) return resolution;
      _unignoredPendingId = resolution.pendingId;
      // Drain rejected refresh commands before starting the post-commit reads.
      await _ignoredLoadRequest;
      await _loadRequest;
      if (_disposed) return resolution;
      _refreshingAfterUnIgnore = true;
      try {
        await loadIgnored.execute();
        if (_disposed) return resolution;
        await load.execute();
        _notifyListeners();
      } finally {
        _refreshingAfterUnIgnore = false;
      }
      return resolution;
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
