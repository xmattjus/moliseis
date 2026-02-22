import 'dart:collection' show UnmodifiableListView;

import 'package:flutter/material.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/place_content.dart';
import 'package:moliseis/domain/repositories/place_repository.dart';
import 'package:moliseis/domain/use-cases/explore/explore_use_case.dart';
import 'package:moliseis/utils/command.dart';
import 'package:moliseis/utils/extensions/extensions.dart';
import 'package:moliseis/utils/result.dart';

class ExploreViewModel extends ChangeNotifier {
  final ExploreUseCase _byIdUseCase;
  final PlaceRepository _placeRepository;

  late Command0<void> load;
  late Command0<void> loadLatest;
  late Command1<void, List<double>> loadNear;
  late Command0<void> loadSuggested;

  ExploreViewModel({
    required ExploreUseCase byIdUseCase,
    required PlaceRepository placeRepository,
  }) : _byIdUseCase = byIdUseCase,
       _placeRepository = placeRepository {
    load = Command0(_load)..execute();
    loadLatest = Command0(_loadLatest);
    loadNear = Command1(_loadNear);
    loadSuggested = Command0(_loadSuggested);
  }

  var _latest = <PlaceContent>[];
  final _near = <ContentBase>[];
  var _suggested = <PlaceContent>[];

  var _latestIds = <int>[];
  var _nearIds = <int>[];
  var _suggestedIds = <int>[];

  UnmodifiableListView<PlaceContent> get latest =>
      UnmodifiableListView(_latest);
  UnmodifiableListView<ContentBase> get near => UnmodifiableListView(_near);
  UnmodifiableListView<PlaceContent> get suggested =>
      UnmodifiableListView(_suggested);

  UnmodifiableListView<int> get latestIds => UnmodifiableListView(_latestIds);
  UnmodifiableListView<int> get suggestedIds =>
      UnmodifiableListView(_suggestedIds);

  UnmodifiableListView<ContentCategory> get types =>
      UnmodifiableListView(ContentCategory.values.minusUnknown);

  Future<Result<void>> _load() async {
    final result1 = await _placeRepository.getLatestPlaceIds();

    switch (result1) {
      case Success<List<int>>():
        _latestIds = result1.value;
      case Error<List<int>>():
    }

    final result2 = await _placeRepository.getSuggestedPlaceIds();

    switch (result2) {
      case Success<List<int>>():
        _suggestedIds = result2.value;
      case Error<List<int>>():
    }

    notifyListeners();

    loadLatest.execute();

    loadSuggested.execute();

    return const Result.success(null);
  }

  Future<Result<void>> _loadLatest() async {
    _latest = [];

    for (final int id in _latestIds) {
      final result = await _byIdUseCase.getById(id);

      switch (result) {
        case Success<PlaceContent>():
          _latest.add(result.value);
        case Error<PlaceContent>():
      }
    }

    notifyListeners();

    return const Result.success(null);
  }

  Future<Result<void>> _loadNear(List<double> coordinates) async {
    final result = await _placeRepository.getIdsByCoordinates(coordinates);

    switch (result) {
      case Success<List<int>>():
        _nearIds = result.value;
        notifyListeners();
      case Error<List<int>>():
        return Result.error(result.error);
    }

    _near.clear();

    for (final id in _nearIds) {
      final result2 = await _byIdUseCase.getById(id);

      switch (result2) {
        case Success<PlaceContent>():
          _near.add(result2.value);
        case Error<PlaceContent>():
      }
    }

    notifyListeners();

    return const Result.success(null);
  }

  Future<Result<void>> _loadSuggested() async {
    _suggested = [];

    for (final int id in _suggestedIds) {
      final result = await _byIdUseCase.getById(id);

      switch (result) {
        case Success<PlaceContent>():
          _suggested.add(result.value);
        case Error<PlaceContent>():
      }
    }

    notifyListeners();

    return const Result.success(null);
  }
}
