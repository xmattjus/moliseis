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
/// Accepted history writes run FIFO independently of confirmed-history reads.
/// Results and suggestions retain independent commands.
class SearchViewModel extends ChangeNotifier {
  SearchViewModel({required SearchRepository searchRepository}) {
    _historyWriter = createResultCommand<({String query, bool add}), void>(
      (operation) => operation.add
          ? searchRepository.addToPastSearches(operation.query)
          : searchRepository.removeFromPastSearches(operation.query),
      debugName: 'search_history_write',
    );
    _historyWriter.isRunningSync.addListener(_writerRunningChanged);
    _historyReader = createResultCommandNoParam<List<String>>(
      () => _disposed
          ? Future.value(const Result.success(<String>[]))
          : searchRepository.getPastSearches(),
      debugName: 'search_history_read',
    );
    _historyReader.results.addListener(_historyReadChanged);
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

  bool _disposed = false;
  bool _stopped = false;
  bool _writerReleased = false;
  bool _readerReleased = false;
  late final ResultCommand<({String query, bool add}), void> _historyWriter;
  late final ResultCommand<void, List<String>> _historyReader;
  Future<void> _writeTail = Future<void>.value();
  Completer<void>? _writeWaiter;
  Object? _historyFailure;

  /// The original read/write failure, retained until a successful history read.
  Object? get pastSearchesFailure => _historyFailure;

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _readerRunningChanged();
    unawaited(_writeTail.then((_) => _releaseWriter()));
    loadResults.results.removeListener(_commitResults);
    loadSuggestions.results.removeListener(_commitSuggestions);
    loadResults.dispose();
    loadSuggestions.dispose();
    scheduleMicrotask(super.dispose);
  }

  /// Transfers an accepted write to the FIFO before navigation can dispose us.
  void addToPastSearches(String query) {
    if (query.isEmpty ||
        _types.any((type) => type.label.toLowerCase() == query.toLowerCase())) {
      return;
    }
    _acceptWrite((query: query, add: true));
  }

  /// The independent ordinary history read, including loading and failures.
  ValueListenable<commands.CommandResult<void, Result<List<String>>?>>
  get pastSearchesState => _historyReader.results;

  /// Requests one read; a busy read does not retain another refresh demand.
  void requestPastSearchesRefresh() {
    if (_disposed || _stopped || _readerReleased) return;
    _historyReader.run();
  }

  /// Searches places and events matching the query and populates [results].
  ///
  /// No-op for queries shorter than 3 characters.
  late final RestartableCommand<String, List<ContentBase>?> loadResults;

  /// Accepts an exact-case removal without dropping earlier or later writes.
  void removeFromPastSearches(String query) {
    if (_disposed) return;
    _acceptWrite((query: query, add: false));
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

  void _acceptWrite(({String query, bool add}) operation) {
    if (_disposed || _stopped) return;
    _writeTail = _writeTail.then((_) async {
      if (_stopped) return;
      final waiter = Completer<void>();
      _writeWaiter = waiter;
      _historyWriter.run(operation);
      await waiter.future;
    });
  }

  void _writerRunningChanged() {
    if (_writerReleased || _historyWriter.isRunningSync.value) return;
    final waiter = _writeWaiter;
    if (waiter == null) return;
    // Leave upstream terminal dispatch, global error routing and its final
    // running reset before admitting another operation on this fixed command.
    scheduleMicrotask(() {
      unawaited(
        Future<void>(() {
          if (_writerReleased || !identical(waiter, _writeWaiter)) return;
          if (_historyWriter.isRunningSync.value) return;
          final snapshot = _historyWriter.results.value;
          _writeWaiter = null;
          if (snapshot.isRunning) {
            _stopped = true; // AssertionError has no normal terminal outcome.
            _releaseWriter();
          } else if (!_disposed) {
            if (snapshot.hasFailure) {
              _historyFailure =
                  snapshot.unexpectedError ?? snapshot.domainError;
              notifyListeners();
            } else {
              requestPastSearchesRefresh();
            }
          }
          waiter.complete();
        }),
      );
    });
  }

  void _releaseWriter() {
    if (_writerReleased) return;
    _writerReleased = true;
    _historyWriter.isRunningSync.removeListener(_writerRunningChanged);
    _historyWriter.dispose();
  }

  void _historyReadChanged() {
    if (_disposed) return;
    final snapshot = _historyReader.results.value;
    if (snapshot.completed) {
      _pastSearches = List.of(snapshot.data!.getOrNull()!);
      _historyFailure = null;
    } else if (snapshot.hasFailure) {
      _historyFailure = snapshot.unexpectedError ?? snapshot.domainError;
    }
    notifyListeners();
  }

  void _readerRunningChanged() {
    if (_readerReleased || _historyReader.isRunningSync.value) return;
    // Keep a physically pending reader alive through raw-error reporting.
    scheduleMicrotask(() {
      unawaited(
        Future<void>(() {
          if (_readerReleased || _historyReader.isRunningSync.value) return;
          if (_disposed || _historyReader.results.value.isRunning) {
            _readerReleased = true;
            _historyReader.results.removeListener(_historyReadChanged);
            _historyReader.isRunningSync.removeListener(_readerRunningChanged);
            _historyReader.dispose();
          }
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
