import 'dart:async';
import 'dart:collection' show UnmodifiableListView;

import 'package:command_it/command_it.dart' as commands;
import 'package:flutter/foundation.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/repositories/search_repository.dart';
import 'package:moliseis/utils/extensions/extensions.dart';
import 'package:moliseis/utils/restartable_command.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/result_command.dart';

/// ViewModel for the search screen.
///
/// Manages past search history, live search results, and suggestions.
/// History writes transfer to a private ordered writer; refresh requests use
/// a revision-aware reader. Results and suggestions retain independent
/// commands.
class SearchViewModel extends ChangeNotifier {
  SearchViewModel({required SearchRepository searchRepository})
    : _searchRepository = searchRepository {
    _history = _HistoryWriter(searchRepository)..onChanged = _historyChanged;
    _historyReader = createResultCommandNoParam<void>(
      _readPastSearches,
      debugName: 'search_history_read',
    );
    _historyReader.isRunningSync.addListener(_readerRunningChanged);
    loadResults = RestartableCommand(
      (query) => _fetch(searchRepository, query),
      debugName: 'search_results',
    );
    loadResults.results.addListener(_commitResults);
    loadSuggestions = RestartableCommand(
      (query) => _fetch(searchRepository, query),
      debugName: 'search_suggestions',
    );
    loadSuggestions.results.addListener(_commitSuggestions);
    requestPastSearchesRefresh();
  }

  final SearchRepository _searchRepository;
  bool _disposed = false;
  late final _HistoryWriter _history;
  late final ResultCommand<void, void> _historyReader;
  final _detached = Completer<void>();
  int _requested = 0;
  int _attempted = 0;
  bool _physicalRead = false;
  bool _readerTurnQueued = false;
  bool _readerReleased = false;

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _detached.complete();
    _history.detach();
    _readerRunningChanged();
    loadResults.results.removeListener(_commitResults);
    loadSuggestions.results.removeListener(_commitSuggestions);
    loadResults.dispose();
    loadSuggestions.dispose();
    scheduleMicrotask(super.dispose);
  }

  /// Accepts an ordered history write and immediately updates its projection.
  ///
  /// Accepted persistence survives navigation and presentation disposal.
  void addToPastSearches(String query) {
    if (_disposed || query.isEmpty) return;
    if (_types.any((type) => type.label.toLowerCase() == query.toLowerCase())) {
      return;
    }
    _history.accept(query, add: true, readInFlight: _physicalRead);
  }

  /// Read-only execution state; refresh requests must use the scheduler.
  ValueListenable<commands.CommandResult<void, Result<void>?>>
  get pastSearchesState => _historyReader.results;

  /// Requests a fresh history read through the revision-aware scheduler.
  ///
  /// Registers a new demand synchronously. Physical reading is
  /// deferred until the current writer obligations permit a stable read.
  void requestPastSearchesRefresh() {
    if (_disposed) return;
    _requested++;
    _scheduleRead();
  }

  /// Searches places and events matching the query and populates [results].
  ///
  /// No-op for queries shorter than 3 characters.
  late final RestartableCommand<String, List<ContentBase>?> loadResults;

  /// Accepts an exact-case removal without dropping earlier or later writes.
  void removeFromPastSearches(String query) {
    if (_disposed) return;
    _history.accept(query, add: false, readInFlight: _physicalRead);
  }

  /// Loads search suggestions for a query into [suggestions].
  ///
  /// No-op for queries shorter than 3 characters. Shares the same
  /// underlying search logic as [loadResults].
  late final RestartableCommand<String, List<ContentBase>?> loadSuggestions;

  var _pastSearches = <String>[];
  var _results = <ContentBase>[];
  var _suggestions = <ContentBase>[];
  final List<ContentCategory> _types = ContentCategory.values.minusUnknown;

  /// An unmodifiable view of the persisted past search queries.
  UnmodifiableListView<String> get pastSearches =>
      UnmodifiableListView(_pastSearches);

  /// An unmodifiable view of the current search results.
  UnmodifiableListView<ContentBase> get results =>
      UnmodifiableListView(_results);

  /// An unmodifiable view of the current search suggestions.
  UnmodifiableListView<ContentBase> get suggestions =>
      UnmodifiableListView(_suggestions);

  /// Returns true when [query] is long enough to trigger a search.
  ///
  /// Queries shorter than 3 characters are treated as no-ops by [loadResults]
  /// and [loadSuggestions].
  static bool isSearchQueryValid(String query) => query.length >= 3;

  void _historyChanged({required bool needsRead}) {
    if (_disposed) return;
    if (needsRead) _requested++;
    final projection = _history.projection;
    final changed = !listEquals(_pastSearches, projection);
    if (changed) _pastSearches = List.of(projection);
    _scheduleRead();
    if (!_disposed && changed) notifyListeners();
  }

  void _scheduleRead() {
    if (_disposed ||
        _readerReleased ||
        _history.aborted ||
        _requested == _attempted ||
        _historyReader.isRunningSync.value ||
        _readerTurnQueued) {
      return;
    }
    _historyReader.run();
  }

  Future<Result<void>> _readPastSearches() async {
    while (!_disposed && !_history.aborted) {
      while (_history.hasPending && !_disposed) {
        await Future.any<void>([_history.drained, _detached.future]);
      }
      if (_disposed || _history.aborted || _requested == _attempted) {
        return const Result.success(null);
      }
      final epoch = _history.epoch;
      final demand = _requested;
      _attempted = demand;
      _physicalRead = true;
      final Result<List<String>> result;
      try {
        result = await _searchRepository.getPastSearches();
      } finally {
        _physicalRead = false;
      }
      if (_disposed) return result.map((_) {});
      if (result case Error<List<String>>()) return result.map((_) {});
      if (epoch == _history.epoch &&
          demand == _requested &&
          !_history.hasPending) {
        _history.replaceBase(result.getOrNull()!);
        return const Result.success(null);
      }
      // Only an already registered, newer demand may cause another attempt.
      // An obsolete success never replaces optimistic history.
    }
    return const Result.success(null);
  }

  void _readerRunningChanged() {
    if (_readerReleased ||
        _readerTurnQueued ||
        _historyReader.isRunningSync.value) {
      return;
    }
    _readerTurnQueued = true;
    // Leave both terminal notifier dispatch and upstream global error routing.
    scheduleMicrotask(() {
      unawaited(
        Future<void>(() {
          _readerTurnQueued = false;
          if (_readerReleased || _historyReader.isRunningSync.value) return;
          // An upstream assertion lowers running without a terminal snapshot.
          // Preserve fail-loud routing and release the ordinary reader too.
          if (_disposed || _historyReader.results.value.isRunning) {
            _readerReleased = true;
            _historyReader.isRunningSync.removeListener(_readerRunningChanged);
            _historyReader.dispose();
            return;
          }
          _scheduleRead();
        }),
      );
    });
  }

  static Future<Result<List<ContentBase>?>> _fetch(
    SearchRepository repository,
    String query,
  ) async {
    if (!isSearchQueryValid(query)) return const Result.success(null);
    final result = await repository.getResultsByQuery(query);
    return result.map<List<ContentBase>?>((items) => items);
  }

  void _commitResults() {
    final snapshot = loadResults.results.value;
    if (!snapshot.completed) return;
    snapshot.data!.map((items) {
      if (items == null) return;
      _results = items;
      notifyListeners();
    });
  }

  void _commitSuggestions() {
    final snapshot = loadSuggestions.results.value;
    if (!snapshot.completed) return;
    snapshot.data!.map((items) {
      if (items == null) return;
      _suggestions = items;
      notifyListeners();
    });
  }
}

/// One accepted intent; its receipt denotes settlement, never success.
class _HistoryMutation {
  _HistoryMutation(this.query, {required this.add});

  final String query;
  final bool add;
  final settled = Completer<void>();

  List<String> apply(List<String> source) {
    final result = List<String>.of(source);
    if (add) {
      if (!result.any((item) => item.toLowerCase() == query.toLowerCase())) {
        result.add(query);
      }
    } else {
      result.remove(query);
    }
    return result;
  }
}

/// Owns persistence independently from the presentation that accepted it.
///
/// Only [onChanged] reaches presentation; detach clears it before settlement.
class _HistoryWriter {
  _HistoryWriter(SearchRepository repository) {
    _command = createResultCommand<_HistoryMutation, void>(
      (entry) => entry.add
          ? repository.addToPastSearches(entry.query)
          : repository.removeFromPastSearches(entry.query),
      debugName: 'search_history_write',
    );
    _command.isRunningSync.addListener(_runningChanged);
  }

  late final ResultCommand<_HistoryMutation, void> _command;
  void Function({required bool needsRead})? onChanged;
  final _pending = <_HistoryMutation>[];
  List<String> _base = [];
  List<String> projection = [];
  bool _known = false;
  bool _uncertain = false;
  bool _detached = false;
  bool _released = false;
  bool _turnQueued = false;
  bool aborted = false;
  int epoch = 0;
  _HistoryMutation? _active;
  Completer<void>? _drain;

  bool get hasPending => _pending.isNotEmpty;
  Future<void> get drained => _drain?.future ?? Future<void>.value();

  void accept(String query, {required bool add, required bool readInFlight}) {
    if (_detached || aborted) return;
    final entry = _HistoryMutation(query, add: add);
    final desired = entry.apply(projection);
    if (listEquals(desired, projection)) {
      if (_known && !_uncertain) return;
      // Pending intent proves redundancy even before bootstrap. The most recent
      // relevant opposite intent prevents that proof.
      for (final pending in _pending.reversed) {
        final relevant = add
            ? pending.query.toLowerCase() == query.toLowerCase()
            : pending.query == query;
        if (!relevant) continue;
        if (pending.add == add) return;
        break;
      }
    }
    _drain ??= Completer<void>();
    _pending.add(entry);
    epoch++;
    projection = desired;
    if (_active == null && !_turnQueued) _startHead();
    onChanged?.call(needsRead: readInFlight || !_known || _uncertain);
  }

  void replaceBase(List<String> items) {
    _base = List.of(items);
    _known = true;
    _uncertain = false;
    _project();
    onChanged?.call(needsRead: false);
  }

  void _project() {
    projection = List.of(_base);
    for (final entry in _pending) {
      projection = entry.apply(projection);
    }
  }

  void _startHead() {
    if (_released || aborted || _active != null || _pending.isEmpty) return;
    _active = _pending.first;
    _command.run(_active);
  }

  void _runningChanged() {
    if (_released || _turnQueued || _command.isRunningSync.value) return;
    _turnQueued = true;
    // A single reused command cannot be rerun from its terminal listeners:
    // upstream has not finished clearing its running state/error routing yet.
    scheduleMicrotask(() {
      unawaited(
        Future<void>(() {
          _turnQueued = false;
          if (_released || _command.isRunningSync.value) return;
          final entry = _active;
          if (entry != null) {
            final snapshot = _command.results.value;
            if (snapshot.isRunning) {
              // AssertionError bypasses terminal reporting. Release waiters and
              // resources, without manufacturing success or continuing writes.
              aborted = true;
              for (final pending in _pending) {
                pending.settled.complete();
              }
              _pending.clear();
              _active = null;
              _drain?.complete();
              _drain = null;
              onChanged = null;
              _release();
              return;
            }
            if (!identical(snapshot.paramData, entry)) return;
            final runtime = snapshot.unexpectedError != null;
            if (snapshot.completed || runtime) _base = entry.apply(_base);
            if (runtime) _uncertain = true;
            _pending.removeAt(0);
            _active = null;
            epoch++;
            _project();
            // Register reconciliation before receipts/drain can wake the reader.
            onChanged?.call(needsRead: runtime);
            entry.settled.complete();
          }
          if (_pending.isNotEmpty) {
            _startHead();
          } else {
            _drain?.complete();
            _drain = null;
            if (_detached) _release();
          }
        }),
      );
    });
  }

  void detach() {
    if (_detached) return;
    _detached = true;
    onChanged = null;
    if (!hasPending) _runningChanged();
  }

  void _release() {
    if (_released) return;
    _released = true;
    _command.isRunningSync.removeListener(_runningChanged);
    _command.dispose();
  }
}
