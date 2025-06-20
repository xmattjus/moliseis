import 'dart:collection' show UnmodifiableListView;

import 'package:flutter/material.dart';
import 'package:moliseis/data/repositories/attraction/attraction_repository.dart';
import 'package:moliseis/data/repositories/search/search_repository.dart';
import 'package:moliseis/domain/models/attraction/attraction.dart';
import 'package:moliseis/domain/models/attraction/attraction_type.dart';
import 'package:moliseis/utils/command.dart';
import 'package:moliseis/utils/extensions.dart';
import 'package:moliseis/utils/result.dart';

class SearchViewModel extends ChangeNotifier {
  SearchViewModel({
    required AttractionRepository attractionRepository,
    required SearchRepository searchRepository,
  }) : _searchRepository = searchRepository,
       _attractionRepository = attractionRepository {
    addToHistory = Command1(_addToHistory);
    addToHistoryByAttractionId = Command1(_addToHistoryByAttractionId);
    loadHistory = Command0(_loadHistory)..execute();
    loadResults = Command1(_loadResults);
    loadRelatedResults = Command1(_loadMoreResults);
    removeFromHistory = Command1(_removeFromHistory);
  }

  final AttractionRepository _attractionRepository;
  final SearchRepository _searchRepository;

  var _history = <String>[];
  var _resultIds = <int>[];
  var _relatedResultsIds = <int>[];
  final _types = AttractionType.values.minusUnknown;

  UnmodifiableListView<String> get history => UnmodifiableListView(_history);
  UnmodifiableListView<int> get resultIds => UnmodifiableListView(_resultIds);
  UnmodifiableListView<int> get relatedResultIds =>
      UnmodifiableListView(_relatedResultsIds);
  UnmodifiableListView<AttractionType> get types =>
      UnmodifiableListView(_types);

  late Command1<void, String> addToHistory;
  late Command1<void, int> addToHistoryByAttractionId;
  late Command0 loadHistory;
  late Command1<void, String> loadResults;
  late Command1<void, String> loadRelatedResults;
  late Command1<void, String> removeFromHistory;

  Future<Result> _addToHistory(String text) async {
    if (text.isEmpty) {
      return const Result.success(null);
    }

    final historyToLowerCase = _history.map((e) => e.toLowerCase());
    final lowerCaseText = text.toLowerCase();
    final typeSuggestions = _types.map((e) => e.label.toLowerCase());

    // Does not add the text to history since it's equal to one of the type
    // suggestions or is already present in history.
    if (typeSuggestions.contains(lowerCaseText) ||
        historyToLowerCase.contains(lowerCaseText)) {
      return const Result.success(null);
    }

    _history.add(text);

    final result = await _searchRepository.addToHistory(text);

    if (result is Error) {
      _history.remove(text);
    }

    return result;
  }

  Future<Result> _addToHistoryByAttractionId(int id) async {
    final result = await _attractionRepository.getById(id);

    if (result is Success<Attraction>) {
      if (!_history.contains(result.value.name)) {
        _history.add(result.value.name);

        // Does not wait for any result.
        _searchRepository.addToHistory(result.value.name);
      }
    }

    return result;
  }

  Future<Result> _loadHistory() async {
    final result = await _searchRepository.pastSearches;

    if (result is Success<List<String>>) {
      _history = result.value;
    }

    return result;
  }

  Future<Result> _loadResults(String query) async {
    if (query.isEmpty) {
      return const Result.success(<int>[]);
    }

    final result = await _searchRepository.getAttractionIdsByQuery(query);

    if (result is Success<List<int>>) {
      _resultIds = result.value;
    }

    return result;
  }

  Future<Result> _loadMoreResults(String query) async {
    if (query.isEmpty) {
      return const Result.success(<int>[]);
    }

    final result = await _searchRepository.getRelatedResults(query);

    if (result is Success<List<int>>) {
      _relatedResultsIds = result.value;
    }

    return result;
  }

  Future<Result> _removeFromHistory(String query) async {
    _history.remove(query);

    final result = await _searchRepository.removeFromHistory(query);

    if (result is Error) {
      _history.add(query);
    }

    return const Result.success(null);
  }
}
