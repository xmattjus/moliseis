import 'dart:collection' show UnmodifiableListView;

import 'package:material_ui/material_ui.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/repositories/search_repository.dart';
import 'package:moliseis/utils/command.dart';
import 'package:moliseis/utils/extensions/extensions.dart';
import 'package:moliseis/utils/result.dart';

/// ViewModel for the search screen.
///
/// Manages past search history, live search results, and suggestions.
/// All async actions are exposed as [Command]s so that
/// UI widgets can observe running, completed, and error states without
/// direct async/await wiring.
class SearchViewModel extends ChangeNotifier {
  SearchViewModel({required SearchRepository searchRepository})
    : _searchRepository = searchRepository {
    addToPastSearches = Command1(_addToPastSearches);
    loadPastSearches = Command0(_loadPastSearches)..execute();
    loadResults = Command1(_loadResults);
    removeFromPastSearches = Command1(_removeFromPastSearches);
    loadSuggestions = Command1(_loadSuggestions);
  }

  final SearchRepository _searchRepository;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Adds a query string to the persistent search history.
  ///
  /// Uses an optimistic update: the entry is added locally before the write
  /// succeeds and rolled back on error.
  late Command1<void, String> addToPastSearches;

  /// Loads the persisted search history into [pastSearches].
  ///
  /// Executed automatically on construction.
  late Command0<void> loadPastSearches;

  /// Searches places and events matching the query and populates [results].
  ///
  /// No-op for queries shorter than 3 characters.
  late Command1<void, String> loadResults;

  /// Removes a query string from the persistent search history.
  ///
  /// Uses an optimistic update: the entry is removed locally before the delete
  /// succeeds and restored on error.
  late Command1<void, String> removeFromPastSearches;

  /// Loads search suggestions for a query into [suggestions].
  ///
  /// No-op for queries shorter than 3 characters. Shares the same
  /// underlying search logic as [loadResults].
  late Command1<void, String> loadSuggestions;

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

  Future<Result<void>> _addToPastSearches(String query) async {
    if (query.isEmpty) {
      return const Result.success(null);
    }

    final historyToLowerCase = _pastSearches.map((e) => e.toLowerCase());
    final lowerCaseText = query.toLowerCase();
    final typeSuggestions = _types.map((e) => e.label.toLowerCase());

    // Does not add the text to history since it's equal to one of the type
    // suggestions or is already present in history.
    if (typeSuggestions.contains(lowerCaseText) ||
        historyToLowerCase.contains(lowerCaseText)) {
      return const Result.success(null);
    }

    // Optimistically adds the query to past searches.
    _pastSearches.add(query);
    notifyListeners();

    final result = await _searchRepository.addToPastSearches(query);
    if (_disposed) return result;

    return result.mapError((error) {
      // Removes again the query from past searches on errors.
      _pastSearches.remove(query);
      notifyListeners();
      return error;
    });
  }

  Future<Result<void>> _loadPastSearches() async {
    final result = await _searchRepository.getPastSearches();
    if (_disposed) return result.map((_) {});

    return result.map((pastSearches) {
      _pastSearches = pastSearches;
      notifyListeners();
    });
  }

  Future<Result<void>> _loadResults(String query) => _search(query, (results) {
    _results = results;
  });

  Future<Result<void>> _removeFromPastSearches(String query) async {
    // Optimistically removes the query from past searches.
    _pastSearches.remove(query);
    notifyListeners();

    final result = await _searchRepository.removeFromPastSearches(query);
    if (_disposed) return result;

    return result.mapError((error) {
      // Adds again the query to past searches on error.
      _pastSearches.add(query);
      notifyListeners();
      return error;
    });
  }

  Future<Result<void>> _loadSuggestions(String query) =>
      _search(query, (results) {
        _suggestions = results;
      });

  Future<Result<void>> _search(
    String query,
    void Function(List<ContentBase>) commit,
  ) async {
    if (!isSearchQueryValid(query)) return const Result.success(null);
    final result = await _searchRepository.getResultsByQuery(query);
    if (_disposed) return result.map((_) {});
    return result.map((results) {
      commit(results);
      notifyListeners();
    });
  }
}
