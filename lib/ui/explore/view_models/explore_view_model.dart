import 'dart:async';
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
  ExploreViewModel({
    required ExploreUseCase byIdUseCase,
    required PlaceRepository placeRepository,
  }) : _byIdUseCase = byIdUseCase,
       _placeRepository = placeRepository {
    load = Command0(_load);
    unawaited(load.execute());
    loadLatest = Command0(_loadLatest);
    loadNear = Command1(_loadNear);
  }

  final ExploreUseCase _byIdUseCase;
  final PlaceRepository _placeRepository;

  late Command0<void> load;
  late Command0<void> loadLatest;
  late Command1<void, List<double>> loadNear;

  var _latest = <Place>[];
  final _near = <ContentBase>[];

  var _latestIds = <int>[];

  UnmodifiableListView<Place> get latest => UnmodifiableListView(_latest);
  UnmodifiableListView<ContentBase> get near => UnmodifiableListView(_near);

  UnmodifiableListView<int> get latestIds => UnmodifiableListView(_latestIds);

  UnmodifiableListView<ContentCategory> get types =>
      UnmodifiableListView(ContentCategory.values.minusUnknown);

  Future<Result<void>> _load() async {
    final latestResult = await _placeRepository.getLatestPlaceIds();
    _latestIds = latestResult.getOrNull() ?? [];

    notifyListeners();

    unawaited(loadLatest.execute());

    return latestResult;
  }

  Future<Result<void>> _loadLatest() async {
    _latest = [];

    for (final id in _latestIds) {
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
}
