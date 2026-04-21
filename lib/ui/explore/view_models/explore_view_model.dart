import 'dart:collection' show UnmodifiableListView;

import 'package:flutter/material.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/place.dart';
import 'package:moliseis/domain/repositories/place_repository.dart';
import 'package:moliseis/domain/use-cases/explore_use_case.dart';
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

  var _latest = <Place>[];
  final _near = <ContentBase>[];
  var _suggested = <Place>[];

  var _latestIds = <int>[];
  var _suggestedIds = <int>[];

  UnmodifiableListView<Place> get latest => UnmodifiableListView(_latest);
  UnmodifiableListView<ContentBase> get near => UnmodifiableListView(_near);
  UnmodifiableListView<Place> get suggested => UnmodifiableListView(_suggested);

  UnmodifiableListView<int> get latestIds => UnmodifiableListView(_latestIds);
  UnmodifiableListView<int> get suggestedIds =>
      UnmodifiableListView(_suggestedIds);

  UnmodifiableListView<ContentCategory> get types =>
      UnmodifiableListView(ContentCategory.values.minusUnknown);

  Future<Result<void>> _load() async {
    final latestResult = await _placeRepository.getLatestPlaceIds();
    final latestIds = latestResult.getOrNull();
    if (latestIds != null) _latestIds = latestIds;

    final suggestedResult = await _placeRepository.getSuggestedPlaceIds();
    final suggestedIds = suggestedResult.getOrNull();
    if (suggestedIds != null) _suggestedIds = suggestedIds;

    notifyListeners();

    loadLatest.execute();
    loadSuggested.execute();

    if (latestResult.isError) return latestResult;
    return suggestedResult;
  }

  Future<Result<void>> _loadLatest() async {
    _latest = [];

    for (final int id in _latestIds) {
      final place = (await _byIdUseCase.getById(id)).getOrNull();
      if (place != null) _latest.add(place);
    }

    notifyListeners();

    return const Result.success(null);
  }

  Future<Result<void>> _loadNear(List<double> coordinates) async {
    return (await _placeRepository.getIdsByCoordinates(
      coordinates,
    )).asyncFlatMap((ids) async {
      _near.clear();

      for (final id in ids) {
        final place = (await _byIdUseCase.getById(id)).getOrNull();
        if (place != null) _near.add(place);
      }

      notifyListeners();

      return const Result.success(null);
    });
  }

  Future<Result<void>> _loadSuggested() async {
    _suggested = [];

    for (final int id in _suggestedIds) {
      final place = (await _byIdUseCase.getById(id)).getOrNull();
      if (place != null) _suggested.add(place);
    }

    notifyListeners();

    return const Result.success(null);
  }
}
