import 'dart:collection' show UnmodifiableListView;

import 'package:flutter/material.dart';
import 'package:moliseis/data/sources/event.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/event_content.dart';
import 'package:moliseis/domain/models/place_content.dart';
import 'package:moliseis/domain/repositories/event_repository.dart';
import 'package:moliseis/domain/repositories/search_repository.dart';
import 'package:moliseis/domain/use-cases/explore/explore_use_case.dart';
import 'package:moliseis/utils/command.dart';
import 'package:moliseis/utils/extensions/extensions.dart';
import 'package:moliseis/utils/result.dart';

class SearchViewModel extends ChangeNotifier {
  final EventRepository _eventRepository;
  final ExploreUseCase _exploreGetByIdUseCase;
  final SearchRepository _searchRepository;

  late Command1<void, String> addToHistory;
  late Command0 loadHistory;
  late Command1<void, String> loadResults;
  late Command0 loadRelatedResults;
  late Command1<void, String> loadRelatedResultsIds;
  late Command1<void, String> removeFromHistory;
  late Command1<void, String> loadSuggestions;

  SearchViewModel({
    required EventRepository eventRepository,
    required ExploreUseCase exploreGetByIdUseCase,
    required SearchRepository searchRepository,
  }) : _eventRepository = eventRepository,
       _exploreGetByIdUseCase = exploreGetByIdUseCase,
       _searchRepository = searchRepository {
    addToHistory = Command1(_addToHistory);
    loadHistory = Command0(_loadHistory)..execute();
    loadResults = Command1(_loadResults);
    loadRelatedResults = Command0(_loadRelatedResults);
    loadRelatedResultsIds = Command1(_loadRelatedResultsIds);
    removeFromHistory = Command1(_removeFromHistory);
    loadSuggestions = Command1(_loadSuggestions);
  }

  var _history = <String>[];
  final _results = <ContentBase>[];
  var _relatedResults = <ContentBase>[];
  var _relatedResultsIds = <int>[];
  final _types = ContentCategory.values.minusUnknown;

  UnmodifiableListView<String> get history => UnmodifiableListView(_history);
  UnmodifiableListView<ContentBase> get results =>
      UnmodifiableListView(_results);
  UnmodifiableListView<ContentBase> get relatedResults =>
      UnmodifiableListView(_relatedResults);
  UnmodifiableListView<int> get relatedResultIds =>
      UnmodifiableListView(_relatedResultsIds);

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

  Future<Result> _loadHistory() async {
    final result = await _searchRepository.pastSearches();

    if (result is Success<List<String>>) {
      _history = result.value;
    }

    return result;
  }

  Future<Result<void>> _loadResults(String query) async {
    if (query.length < 3) {
      return const Result.success(null);
    }

    _results.clear();

    final job1 = await _searchRepository.getPlaceIdsByQuery(query);

    if (job1 is Success<List<int>>) {
      for (final id in job1.value) {
        final result = await _exploreGetByIdUseCase.getById(id);

        if (result is Success<PlaceContent>) {
          _results.add(result.value);
        }
      }
    }

    final job2 = await _searchRepository.getEventIdsByQuery(query);

    if (job2 is Success<List<int>>) {
      for (final id in job2.value) {
        final result = await _eventRepository.getById(id);

        if (result is Success<Event>) {
          _results.add(EventContent.fromEvent(result.value));
        }
      }
    }

    return const Result.success(null);
  }

  Future<Result> _loadRelatedResults() async {
    final temp = <ContentBase>[];

    for (final id in _relatedResultsIds) {
      final result = await _exploreGetByIdUseCase.getById(id);

      if (result is Success<PlaceContent>) {
        temp.add(result.value);
      }
    }

    _relatedResults = temp;
    notifyListeners();

    return const Result.success(null);
  }

  Future<Result> _loadRelatedResultsIds(String query) async {
    if (query.isEmpty) {
      return const Result.success(<int>[]);
    }

    final result = await _searchRepository.getRelatedResults(query);

    if (result is Success<List<int>>) {
      _relatedResultsIds = result.value;

      loadRelatedResults.execute();
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

  Future<Result> _loadSuggestions(String query) async {
    if (query.length < 3) {
      return const Result.success(null);
    }

    _results.clear();

    final job1 = await _searchRepository.getPlaceIdsByQuery(query);

    if (job1 is Success<List<int>>) {
      for (final id in job1.value) {
        final result = await _exploreGetByIdUseCase.getById(id);

        if (result is Success<PlaceContent>) {
          _results.add(result.value);
        }
      }
    }

    final job2 = await _searchRepository.getEventIdsByQuery(query);

    if (job2 is Success<List<int>>) {
      for (final id in job2.value) {
        final result = await _eventRepository.getById(id);

        if (result is Success<Event>) {
          _results.add(EventContent.fromEvent(result.value));
        }
      }
    }

    return const Result.success(null);
  }
}
