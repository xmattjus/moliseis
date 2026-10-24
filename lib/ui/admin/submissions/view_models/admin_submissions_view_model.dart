import 'dart:async';
import 'dart:collection' show UnmodifiableListView;

import 'package:command_it/command_it.dart' as commands;
import 'package:flutter/foundation.dart';
import 'package:moliseis/domain/models/admin_external_event.dart';
import 'package:moliseis/domain/models/admin_submission.dart';
import 'package:moliseis/domain/models/admin_submission_status.dart';
import 'package:moliseis/domain/repositories/admin_content_submission_repository.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/result_command.dart';

/// One admitted execution, retained independently of presentation listeners.
final class _AdminExecution<P, T> {
  _AdminExecution(this.id, this.command, {this.read = false, this.token});

  final int id;
  final ResultCommand<P, T> command;
  final bool read;
  final Object? token;
  final completion = Completer<void>();
  commands.CommandResult<P?, Result<T>?>? terminal;
  bool started = false;
  bool actionSettled = false;
  bool settled = false;
  bool queued = false;
  int revision = 0;

  bool normalTerminal = false;

  bool get normal => normalTerminal;
}

/// Dashboard reads have independent single-flight lanes. Reactivation reserves
/// both lanes until its ignored-then-submissions refresh has safely settled.
///
/// Accepted refresh Futures acknowledge settlement, including after disposal;
/// they never rethrow failures already reported by their private Commands.
class AdminSubmissionsViewModel extends ChangeNotifier {
  /// Creates the submissions dashboard state backed by [repository].
  AdminSubmissionsViewModel({
    required AdminContentSubmissionRepository repository,
  }) : _repository = repository {
    _load = createResultCommandNoParam(() async {
      final execution = _submissionRead!;
      try {
        if (_disposed) return _unavailable<List<AdminSubmission>>();
        return await _repository.list();
      } finally {
        _actionSettled(execution);
      }
    }, debugName: 'admin_submissions_load');
    _loadIgnored = createResultCommandNoParam(() async {
      final execution = _ignoredRead!;
      try {
        if (_disposed) return _unavailable<List<AdminIgnoredSource>>();
        return await _repository.listIgnoredSources();
      } finally {
        _actionSettled(execution);
      }
    }, debugName: 'admin_submissions_load_ignored');
    _unIgnore = createResultCommand<int, AdminEventResolution>((id) async {
      final execution = _mutation!;
      try {
        if (_disposed) return _unavailable<AdminEventResolution>();
        return await _repository.unIgnoreSource(id);
      } finally {
        _actionSettled(execution);
      }
    }, debugName: 'admin_submissions_unignore');
    _loadSnapshot = _load.results.value;
    _loadIgnoredSnapshot = _loadIgnored.results.value;
    _unIgnoreSnapshot = _unIgnore.results.value;
    _observe(_load, () => _submissionRead, _forwardSubmissions);
    _observe(_loadIgnored, () => _ignoredRead, _forwardIgnored);
    _observe(_unIgnore, () => _mutation, _forwardMutation);
  }

  final AdminContentSubmissionRepository _repository;
  late final ResultCommand<void, List<AdminSubmission>> _load;
  late final ResultCommand<void, List<AdminIgnoredSource>> _loadIgnored;
  late final ResultCommand<int, AdminEventResolution> _unIgnore;
  late commands.CommandResult<void, Result<List<AdminSubmission>>?>
  _loadSnapshot;
  late commands.CommandResult<void, Result<List<AdminIgnoredSource>>?>
  _loadIgnoredSnapshot;
  late commands.CommandResult<int?, Result<AdminEventResolution>?>
  _unIgnoreSnapshot;
  _AdminExecution<void, List<AdminSubmission>>? _submissionRead;
  _AdminExecution<void, List<AdminIgnoredSource>>? _ignoredRead;
  _AdminExecution<int, AdminEventResolution>? _mutation;
  final _removePublic = <VoidCallback>[];
  final _removePrivate = <Object, VoidCallback>{};
  final _released = <Object>{};
  final _items = <AdminSubmission>[];
  final _ignoredSources = <AdminIgnoredSource>[];
  AdminSubmissionStatus? _filter;
  bool _showIgnored = false;
  bool _disposed = false;
  bool _postCommit = false;
  int _nextExecution = 0;
  int? _unignoredPendingId;
  int _editorRevision = 0;
  int _editorReadingRevision = 0;
  bool _editorDrainQueued = false;
  bool _editorNeedsIgnored = false;
  _AdminExecution<void, List<AdminSubmission>>? _editorSubmissionRead;
  _AdminExecution<void, List<AdminIgnoredSource>>? _editorIgnoredRead;
  final _editorWaiters = <({int revision, Completer<void> completion})>[];

  /// Last forwarded submissions outcome, frozen after revocation.
  commands.CommandResult<void, Result<List<AdminSubmission>>?>
  get loadSnapshot => _loadSnapshot;

  /// Last forwarded ignored-source outcome, independent of submissions.
  commands.CommandResult<void, Result<List<AdminIgnoredSource>>?>
  get loadIgnoredSnapshot => _loadIgnoredSnapshot;

  /// Reactivation stays logically running through both post-commit reads.
  commands.CommandResult<int?, Result<AdminEventResolution>?>
  get unIgnoreSnapshot => _unIgnoreSnapshot;

  /// Whether this route owner has revoked publication and admission.
  bool get isDisposed => _disposed;

  /// Whether a reactivation or its coordinated refresh is reserved.
  bool get isUnIgnoring => !_disposed && _mutation != null;

  /// Whether reactivation can reserve both idle read lanes immediately.
  bool get canUnIgnore =>
      !_disposed &&
      _mutation == null &&
      _submissionRead == null &&
      _ignoredRead == null;

  /// Whether the committed revision is safe to open after both refreshes.
  bool get canOpenPendingSubmission =>
      !_disposed &&
      _mutation == null &&
      _unIgnoreSnapshot.completed &&
      _unignoredPendingId != null;

  /// Public revision ID, withheld until coordinated refresh settlement.
  int? get unignoredPendingId => _unignoredPendingId;

  /// All loaded submission summaries, before filtering.
  UnmodifiableListView<AdminSubmission> get items =>
      UnmodifiableListView(_items);

  /// Last successfully loaded ignored sources, retained on refresh failure.
  UnmodifiableListView<AdminIgnoredSource> get ignoredSources =>
      UnmodifiableListView(_ignoredSources);

  /// Whether the ignored-source filter is selected.
  bool get showIgnored => _showIgnored;

  /// The active status filter, where null represents all submissions.
  AdminSubmissionStatus? get filter => _filter;

  /// Loaded summaries matching the current local filter.
  List<AdminSubmission> get filteredItems {
    final filter = _filter;
    return filter == null
        ? items
        : _items.where((item) => item.status == filter).toList();
  }

  /// Whether a submissions read remains reserved through safe settlement.
  bool get loading => !_disposed && _submissionRead != null;

  /// Whether the last submissions read failed in either error channel.
  bool get error => _loadSnapshot.hasFailure;

  /// Whether at least one submission has been loaded.
  bool get hasData => _items.isNotEmpty;

  /// Updates selection without admitting remote work.
  void setIgnoredFilter() {
    if (_disposed) return;
    _showIgnored = true;
    notifyListeners();
  }

  /// Updates the local status filter without reloading.
  void setFilter(AdminSubmissionStatus? status) {
    if (_disposed) return;
    _showIgnored = false;
    _filter = status;
    notifyListeners();
  }

  /// Admits one submissions read; rejection completes without changing state.
  Future<void> refreshSubmissions() =>
      _startSubmissions()?.completion.future ?? Future<void>.value();

  /// Admits one ignored-source read in its independent lane.
  Future<void> refreshIgnoredSources() =>
      _startIgnored()?.completion.future ?? Future<void>.value();

  /// Registers a persisted editor change even while ordinary admission is busy.
  ///
  /// A read admitted before this call cannot satisfy its revision. Changes
  /// waiting for admission coalesce; a later change during a read requires
  /// another read. Ignored sources follow when selected at submissions
  /// settlement. Completion acknowledges processing, not repository success.
  /// Revocation completes these coordination waiters immediately; physical
  /// read receipts keep their separate safe-settlement contract.
  Future<void> refreshAfterEditorChange() {
    if (_disposed) return Future<void>.value();
    final completion = Completer<void>();
    _editorWaiters.add((revision: ++_editorRevision, completion: completion));
    _scheduleEditorDrain();
    return completion.future;
  }

  /// Wake only for an explicit invalidation or a safe lane/phase release.
  void _scheduleEditorDrain() {
    if (_disposed || _editorWaiters.isEmpty || _editorDrainQueued) return;
    _editorDrainQueued = true;
    scheduleMicrotask(() {
      _editorDrainQueued = false;
      if (!_disposed && _editorWaiters.isNotEmpty) _drainEditorChanges();
    });
  }

  /// Advances at most one admission per wake, never polling a busy lane.
  void _drainEditorChanges() {
    if (_editorSubmissionRead case final read?) {
      if (!read.settled) return;
      _editorSubmissionRead = null;
      if (!read.normal) {
        // An assertion is fail-loud, not permission for a normal next phase.
        _completeEditorRevision();
        return;
      }
      // Finish the captured batch even when newer revisions are waiting;
      // old callers do not require a quiet period to complete.
      _editorNeedsIgnored = _showIgnored;
      if (!_editorNeedsIgnored) {
        _completeEditorRevision();
        return;
      }
    }
    if (_editorIgnoredRead case final read?) {
      if (!read.settled) return;
      _editorIgnoredRead = null;
      _editorNeedsIgnored = false;
      _completeEditorRevision();
      return;
    }
    // Internal reactivation reads deliberately do not satisfy editor demand.
    if (_mutation != null) return;
    if (_editorNeedsIgnored) {
      if (_ignoredRead != null) return;
      final read = _startIgnored();
      if (!_disposed) _editorIgnoredRead = read;
      return;
    }
    if (_submissionRead != null) return;
    _editorNeedsIgnored = false;
    // Capture BEFORE _startSubmissions can synchronously register a new change.
    _editorReadingRevision = _editorRevision;
    final read = _startSubmissions();
    if (!_disposed) _editorSubmissionRead = read;
  }

  void _completeEditorRevision() {
    final completed = _editorWaiters
        .where((waiter) => waiter.revision <= _editorReadingRevision)
        .toList();
    _editorWaiters.removeWhere(
      (waiter) => waiter.revision <= _editorReadingRevision,
    );
    for (final waiter in completed) {
      waiter.completion.complete();
    }
    _scheduleEditorDrain();
  }

  bool _canRead(Object? token) =>
      !_disposed &&
      (_mutation == null || (_postCommit && identical(token, _mutation)));

  _AdminExecution<void, List<AdminSubmission>>? _startSubmissions([
    Object? token,
  ]) {
    if (!_canRead(token) || _submissionRead != null) return null;
    final execution = _AdminExecution(
      ++_nextExecution,
      _load,
      read: true,
      token: token,
    );
    _submissionRead = execution;
    _loadSnapshot = const commands.CommandResult.isLoading();
    notifyListeners();
    _run(execution);
    return execution;
  }

  _AdminExecution<void, List<AdminIgnoredSource>>? _startIgnored([
    Object? token,
  ]) {
    if (!_canRead(token) || _ignoredRead != null) return null;
    final execution = _AdminExecution(
      ++_nextExecution,
      _loadIgnored,
      read: true,
      token: token,
    );
    _ignoredRead = execution;
    _loadIgnoredSnapshot = const commands.CommandResult.isLoading();
    notifyListeners();
    _run(execution);
    return execution;
  }

  /// Reserves reactivation synchronously; true denotes admission only.
  bool requestUnIgnore(int recordId) {
    if (!canUnIgnore) return false;
    final execution = _AdminExecution(++_nextExecution, _unIgnore);
    _mutation = execution;
    _unignoredPendingId = null;
    _postCommit = false;
    _unIgnoreSnapshot = commands.CommandResult.isLoading(recordId);
    notifyListeners();
    _run(execution, recordId);
    return true;
  }

  void _run<P, T>(_AdminExecution<P, T> execution, [P? parameter]) {
    if (_disposed) {
      execution.actionSettled = true;
      _scheduleSettlement(execution);
      return;
    }
    execution.started = true;
    execution.command.run(parameter);
  }

  Result<T> _unavailable<T>() =>
      Result.error(Exception('Dashboard non disponibile.'));

  void _observe<P, T>(
    ResultCommand<P, T> command,
    _AdminExecution<P, T>? Function() current,
    VoidCallback forward,
  ) {
    void observe({bool captureResult = false}) {
      final execution = current();
      if (execution == null || execution.settled) return;
      execution.revision++;
      final snapshot = command.results.value;
      if (captureResult && !snapshot.isRunning && !snapshot.idle) {
        execution.normalTerminal = true;
        if (!execution.read) execution.terminal = snapshot;
      }
      _scheduleSettlement(execution);
    }

    // Private capture runs before a public callback can dispose this owner.
    void observeResult() => observe(captureResult: true);
    void observeRunning() => observe();
    command.results.addListener(observeResult);
    command.isRunningSync.addListener(observeRunning);
    command.results.addListener(forward);
    _removePublic.add(() => command.results.removeListener(forward));
    _removePrivate[command] = () {
      command.results.removeListener(observeResult);
      command.isRunningSync.removeListener(observeRunning);
    };
  }

  void _forwardSubmissions() {
    if (_disposed) return;
    _loadSnapshot = _load.results.value;
    if (_loadSnapshot.data case Success<List<AdminSubmission>>(:final value)) {
      _items
        ..clear()
        ..addAll(value);
    }
    notifyListeners();
  }

  void _forwardIgnored() {
    if (_disposed) return;
    _loadIgnoredSnapshot = _loadIgnored.results.value;
    if (_loadIgnoredSnapshot.data case Success<List<AdminIgnoredSource>>(
      :final value,
    )) {
      _ignoredSources
        ..clear()
        ..addAll(value);
    }
    notifyListeners();
  }

  void _forwardMutation() {
    if (_disposed) return;
    final snapshot = _unIgnore.results.value;
    if (snapshot.completed) {
      _postCommit = true;
      // Keep the admitted running snapshot until the two reads settle.
      return;
    }
    _unIgnoreSnapshot = snapshot;
    notifyListeners();
  }

  void _actionSettled<P, T>(_AdminExecution<P, T> execution) {
    execution.actionSettled = true;
    execution.revision++;
    _scheduleSettlement(execution);
  }

  /// Leave upstream result/running dispatch AND its queued finally work before
  /// reopening a lane. The witness also handles fail-loud assertion aborts,
  /// which command_it does not publish as ordinary terminal results.
  void _scheduleSettlement<P, T>(_AdminExecution<P, T> execution) {
    if (execution.queued || execution.settled) return;
    execution.queued = true;
    final revision = execution.revision;
    scheduleMicrotask(() {
      unawaited(
        Future<void>(() {
          execution.queued = false;
          if (execution.settled) return;
          if (execution.command.isRunningSync.value ||
              !execution.actionSettled) {
            return;
          }
          if (revision != execution.revision) {
            _scheduleSettlement(execution);
            return;
          }
          _settle(execution);
        }),
      );
    });
  }

  void _settle<P, T>(_AdminExecution<P, T> execution) {
    if (execution.settled) return;
    execution.settled = true;
    if (identical(_submissionRead, execution)) _submissionRead = null;
    if (identical(_ignoredRead, execution)) _ignoredRead = null;
    final mutation = identical(_mutation, execution);
    final continueMutation =
        mutation && !_disposed && execution.terminal?.completed == true;
    if (mutation && !continueMutation) {
      _mutation = null;
      _postCommit = false;
    }
    execution.completion.complete();
    if (_disposed) {
      _release(execution.command);
      return;
    }
    if (continueMutation) {
      unawaited(_refreshAfterCommit(_mutation!));
    } else {
      notifyListeners();
    }
    _scheduleEditorDrain();
  }

  Future<void> _refreshAfterCommit(
    _AdminExecution<int, AdminEventResolution> mutation,
  ) async {
    if (!_ownsMutation(mutation)) return;
    final ignored = _startIgnored(mutation);
    if (ignored == null) return;
    await ignored.completion.future;
    if (!_ownsMutation(mutation)) return;
    if (!ignored.normal) {
      _abortRefresh(mutation);
      return;
    }
    final submissions = _startSubmissions(mutation);
    if (submissions == null) return;
    await submissions.completion.future;
    if (!_ownsMutation(mutation)) return;
    if (!submissions.normal) {
      _abortRefresh(mutation);
      return;
    }
    final snapshot = mutation.terminal!;
    final resolution = (snapshot.data! as Success<AdminEventResolution>).value;
    _unIgnoreSnapshot = snapshot;
    _unignoredPendingId = resolution.pendingId;
    _mutation = null;
    _postCommit = false;
    notifyListeners();
    _scheduleEditorDrain();
  }

  bool _ownsMutation(_AdminExecution<int, AdminEventResolution> mutation) =>
      !_disposed && identical(_mutation, mutation) && _postCommit;

  void _abortRefresh(_AdminExecution<int, AdminEventResolution> mutation) {
    if (!_ownsMutation(mutation)) return;
    // Fail-loud assertions have no ordinary terminal UI contract. They permit
    // a later explicit intent, never a fabricated success or continuation.
    _mutation = null;
    _postCommit = false;
    notifyListeners();
    _scheduleEditorDrain();
  }

  void _release<P, T>(ResultCommand<P, T> command) {
    if (!_released.add(command)) return;
    _removePrivate.remove(command)?.call();
    command.dispose();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    final editorWaiters = _editorWaiters.toList();
    _editorWaiters.clear();
    _editorSubmissionRead = null;
    _editorIgnoredRead = null;
    _editorNeedsIgnored = false;
    for (final waiter in editorWaiters) {
      waiter.completion.complete();
    }
    for (final remove in _removePublic) {
      remove();
    }
    _removePublic.clear();
    // Even idle resources release outside synchronous owner/upstream dispatch.
    scheduleMicrotask(() {
      unawaited(
        Future<void>(() {
          if (_submissionRead == null) _release(_load);
          if (_ignoredRead == null) _release(_loadIgnored);
          if (_mutation == null || _mutation!.settled) _release(_unIgnore);
        }),
      );
    });
    scheduleMicrotask(super.dispose);
  }
}
