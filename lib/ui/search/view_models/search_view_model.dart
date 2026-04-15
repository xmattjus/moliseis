import 'dart:collection' show UnmodifiableListView;

import 'package:flutter/material.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/event_content.dart';
import 'package:moliseis/domain/repositories/event_repository.dart';
import 'package:moliseis/domain/repositories/search_repository.dart';
import 'package:moliseis/domain/use-cases/explore_get_by_id_use_case.dart';
import 'package:moliseis/utils/command.dart';
import 'package:moliseis/utils/extensions/extensions.dart';
import 'package:moliseis/utils/result.dart';

/// ViewModel for the search screen.
///
/// Manages past search history, live search results, and contextually
/// related content. All async actions are exposed as [Command]s so that
/// UI widgets can observe running, completed, and error states without
/// direct async/await wiring.
class SearchViewModel extends ChangeNotifier {
  final EventRepository _eventRepository;
  final ExploreGetByIdUseCase _exploreGetByIdUseCase;
  final SearchRepository _searchRepository;

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

  /// Fetches full content for each ID in [relatedResultIds] and populates
  /// [relatedResults].
  ///
  /// IDs whose lookup fails are silently skipped; [relatedResults] will
  /// contain only the successfully resolved items.
  late Command0<void> loadRelatedResults;

  /// Resolves place IDs related to a query and triggers [loadRelatedResults].
  ///
  /// No-op for queries shorter than 3 characters.
  late Command1<void, String> loadRelatedResultsIds;

  /// Removes a query string from the persistent search history.
  ///
  /// Uses an optimistic update: the entry is removed locally before the delete
  /// succeeds and restored on error.
  late Command1<void, String> removeFromPastSearches;

  /// Loads search suggestions for a query into [results].
  ///
  /// No-op for queries shorter than 3 characters. Shares the same
  /// underlying search logic as [loadResults].
  late Command1<void, String> loadSuggestions;

  SearchViewModel({
    required EventRepository eventRepository,
    required ExploreGetByIdUseCase exploreGetByIdUseCase,
    required SearchRepository searchRepository,
  }) : _eventRepository = eventRepository,
       _exploreGetByIdUseCase = exploreGetByIdUseCase,
       _searchRepository = searchRepository {
    addToPastSearches = Command1(_addToPastSearches);
    loadPastSearches = Command0(_loadPastSearches)..execute();
    loadResults = Command1(_loadResults);
    loadRelatedResults = Command0(_loadRelatedResults);
    loadRelatedResultsIds = Command1(_loadRelatedResultsIds);
    removeFromPastSearches = Command1(_removeFromPastSearches);
    loadSuggestions = Command1(_loadSuggestions);
  }

  var _pastSearches = <String>[];
  final _results = <ContentBase>[];
  final _suggestions = <ContentBase>[];
  var _relatedResults = <ContentBase>[];
  var _relatedResultsIds = <int>[];
  final _types = ContentCategory.values.minusUnknown;

  /// An unmodifiable view of the persisted past search queries.
  UnmodifiableListView<String> get pastSearches =>
      UnmodifiableListView(_pastSearches);

  /// An unmodifiable view of the current search results.
  UnmodifiableListView<ContentBase> get results =>
      UnmodifiableListView(_results);

  /// An unmodifiable view of the current search suggestions.
  UnmodifiableListView<ContentBase> get suggestions =>
      UnmodifiableListView(_suggestions);

  /// An unmodifiable view of the related content results.
  UnmodifiableListView<ContentBase> get relatedResults =>
      UnmodifiableListView(_relatedResults);

  /// An unmodifiable view of the related content IDs.
  UnmodifiableListView<int> get relatedResultIds =>
      UnmodifiableListView(_relatedResultsIds);

  /// Returns true when [query] is long enough to trigger a search.
  ///
  /// Queries shorter than 3 characters are treated as no-ops by [loadResults],
  /// [loadSuggestions], and [loadRelatedResultsIds].
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

    return result.mapError((error) {
      // Removes again the query from past searches on errors.
      _pastSearches.remove(query);
      notifyListeners();
      return error;
    });
  }

  Future<Result<void>> _loadPastSearches() async {
    final result = await _searchRepository.getPastSearches();

    return result.map((pastSearches) {
      _pastSearches = pastSearches;
      notifyListeners();
    });
  }

  Future<Result<void>> _loadResults(String query) => _search(query, _results);

  Future<Result<void>> _loadRelatedResults() async {
    final relatedResults = <ContentBase>[];

    for (final id in _relatedResultsIds) {
      final result = await _exploreGetByIdUseCase.getById(id);

      result.map((place) => relatedResults.add(place));
    }

    _relatedResults = relatedResults;
    notifyListeners();

    return const Result.success(null);
  }

  Future<Result<void>> _loadRelatedResultsIds(String query) async {
    if (!isSearchQueryValid(query)) {
      return const Result.success(null);
    }

    final result = await _searchRepository.getRelatedResults(query);

    return result.asyncMap((relatedResultsIds) async {
      _relatedResultsIds = relatedResultsIds;

      await loadRelatedResults.execute();
    });
  }

  Future<Result<void>> _removeFromPastSearches(String query) async {
    // Optimistically removes the query from past searches.
    _pastSearches.remove(query);
    notifyListeners();

    final result = await _searchRepository.removeFromPastSearches(query);

    return result.mapError((error) {
      // Adds again the query to past searches on error.
      _pastSearches.add(query);
      notifyListeners();
      return error;
    });
  }

  Future<Result<void>> _loadSuggestions(String query) =>
      _search(query, _suggestions);

  Future<Result<void>> _search(String query, List<ContentBase> list) async {
    if (!isSearchQueryValid(query)) return const Result.success(null);

    list.clear();

    return Result.zip2(
      () => _searchRepository.getPlaceIdsByQuery(query),
      () => _searchRepository.getEventIdsByQuery(query),
      (placeIds, eventIds) async {
        for (final id in placeIds) {
          final getPlace = await _exploreGetByIdUseCase.getById(id);
          getPlace.map((place) => list.add(place));
        }

        for (final id in eventIds) {
          final getEvent = await _eventRepository.getById(id);
          getEvent.map((event) => list.add(EventContent.fromEvent(event)));
        }

        return const Result.success(null);
      },
    );
  }
}
