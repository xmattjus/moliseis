/*
import 'dart:collection' show UnmodifiableListView;

import 'package:flutter/material.dart';
import 'package:moliseis/data/repositories/attraction/attraction_repository.dart';
import 'package:moliseis/domain/models/attraction/attraction_type.dart';
import 'package:moliseis/domain/use-cases/explore/explore_get_use_case.dart';
import 'package:moliseis/utils/command.dart';
import 'package:moliseis/utils/result.dart';

class ExploreViewModel extends ChangeNotifier {
  ExploreViewModel({
    required AttractionRepository attractionRepository,
    required ExploreGetUseCase exploreGetUseCase,
  }) : _exploreGetUseCase = exploreGetUseCase,
        _attractionRepository = attractionRepository {
    getLatest = Command0(_getLatest);
    getSuggested = Command0(_getSuggested);
    load = Command0(_load)..execute();
  }

  final AttractionRepository _attractionRepository;
  final ExploreGetUseCase _exploreGetUseCase;

  /// Returns a list of [AttractionType]s containing all but
  /// [AttractionType.unknown].
  final _attractionTypes = AttractionType.values.sublist(1);

  final List<AttractionUiState> _latestAttractions = [];
  List<int> _latestAttractionIds = [];
  final List<AttractionUiState> _suggestedAttractions = [];
  List<int> _suggestedAttractionIds = [];

  late Command0<void> load;
  late Command0<void> getSuggested;
  late Command0<void> getLatest;

  UnmodifiableListView<AttractionType> get attractionTypes =>
      UnmodifiableListView(_attractionTypes);
  UnmodifiableListView<AttractionUiState> get latestAttractions =>
      UnmodifiableListView(_latestAttractions);
  UnmodifiableListView<int> get latestAttractionIds =>
      UnmodifiableListView(_latestAttractionIds);
  UnmodifiableListView<AttractionUiState> get suggestedAttractions =>
      UnmodifiableListView(_suggestedAttractions);
  UnmodifiableListView<int> get suggestedAttractionIds =>
      UnmodifiableListView(_suggestedAttractionIds);

  /// Retrieves the list of latest attractions from the backend.
  Future<Result<void>> _getLatest() async {
    for (final attractionId in _latestAttractionIds) {
      final result = await _exploreGetUseCase.getById(attractionId);

      switch (result) {
        case Success<AttractionUiState>():
          _latestAttractions.add(result.value);
        case Error<AttractionUiState>():
        // TODO: Handle this case.
      }
    }

    notifyListeners();

    return const Result.success(null);
  }

  /// Retrieves the list of suggested attractions from the backend.
  Future<Result<void>> _getSuggested() async {
    for (final attractionId in _suggestedAttractionIds) {
      final result = await _exploreGetUseCase.getById(attractionId);

      switch (result) {
        case Success<AttractionUiState>():
          _suggestedAttractions.add(result.value);
        case Error<AttractionUiState>():
        // TODO: Handle this case.
      }
    }

    notifyListeners();

    return const Result.success(null);
  }

  Future<Result<void>> _load() async {
    final resultLatest = await _attractionRepository.latestAttractionsIds;

    switch (resultLatest) {
      case Success<List<int>>():
        // _latestAttractionIds = resultLatest.value;
      case Error<List<int>>():
      // TODO: Handle this case.
    }

    final resultSuggested = await _attractionRepository.suggestedAttractionsIds;

    switch (resultSuggested) {
      case Success<List<int>>():
        // _suggestedAttractionIds = resultSuggested.value;
      case Error<List<int>>():
      // TODO: Handle this case.
    }

    notifyListeners();

    getLatest.execute();

    getSuggested.execute();

    return const Result.success(null);
  }
}
 */
