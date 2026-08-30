import 'dart:async' show Completer, unawaited;
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
  var _lastListRequestId = 0;
  int? _postEditorRefreshRequestId;
  Completer<void>? _postEditorRefreshCompleter;
  var _waitingForLoadIdle = false;
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

  /// Reloads summaries after an editor route returns.
  ///
  /// A list action that started before the editor returned cannot satisfy this
  /// request. Wait for the command to become idle, then run one coalesced
  /// follow-up action without starting concurrent repository requests.
  Future<void> reloadAfterEditor() {
    if (_disposed) return Future<void>.value();

    final requestId = _lastListRequestId + 1;
    final pendingRequestId = _postEditorRefreshRequestId;
    if (pendingRequestId == null || requestId > pendingRequestId) {
      _postEditorRefreshRequestId = requestId;
    }

    final completer = _postEditorRefreshCompleter ??= Completer<void>();
    _startPostEditorRefreshWhenLoadIsIdle();
    return completer.future;
  }

  Future<Result<void>> _load() async {
    final requestId = ++_lastListRequestId;
    try {
      final result = await _repository.list();
      if (_disposed) return const Result.success(null);

      final postEditorRefreshRequestId = _postEditorRefreshRequestId;
      if (postEditorRefreshRequestId != null &&
          requestId < postEditorRefreshRequestId) {
        return result.map((_) {});
      }

      return result.map((items) {
        _items
          ..clear()
          ..addAll(items);
        _notifyListeners();
      });
    } finally {
      final postEditorRefreshRequestId = _postEditorRefreshRequestId;
      if (_disposed ||
          (postEditorRefreshRequestId != null &&
              requestId >= postEditorRefreshRequestId)) {
        _completePostEditorRefresh();
      }
    }
  }

  void _startPostEditorRefreshWhenLoadIsIdle() {
    if (_disposed) {
      _completePostEditorRefresh();
      return;
    }

    if (load.running) {
      if (!_waitingForLoadIdle) {
        _waitingForLoadIdle = true;
        load.addListener(_onLoadChanged);
      }
      return;
    }

    unawaited(load.execute());
  }

  void _onLoadChanged() {
    if (!load.running && _postEditorRefreshRequestId != null) {
      _startPostEditorRefreshWhenLoadIsIdle();
    }
  }

  void _completePostEditorRefresh() {
    _postEditorRefreshRequestId = null;
    if (_waitingForLoadIdle) {
      load.removeListener(_onLoadChanged);
      _waitingForLoadIdle = false;
    }
    final completer = _postEditorRefreshCompleter;
    _postEditorRefreshCompleter = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  void _notifyListeners() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _completePostEditorRefresh();
    super.dispose();
  }
}
