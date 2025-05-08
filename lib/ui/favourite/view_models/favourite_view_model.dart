import 'dart:collection' show UnmodifiableListView;

import 'package:flutter/material.dart';
import 'package:moliseis/data/repositories/attraction/attraction_repository.dart';
import 'package:moliseis/utils/command.dart';
import 'package:moliseis/utils/result.dart';

class FavouriteViewModel extends ChangeNotifier {
  FavouriteViewModel({required AttractionRepository attractionRepository})
    : _attractionRepository = attractionRepository {
    load = Command0(_load)..execute();
    addFavourite = Command1(_addFavourite);
    deleteFavourite = Command1(_deleteFavourite);
  }

  final AttractionRepository _attractionRepository;

  late Command0<void> load;
  late Command1<void, int> addFavourite;
  late Command1<void, int> deleteFavourite;

  List<int> _favourites = [];

  UnmodifiableListView<int> get favourites => UnmodifiableListView(_favourites);

  Future<Result<void>> _load() async {
    _favourites = _attractionRepository.savedAttractionIds;

    notifyListeners();

    return const Result.success(null);
  }

  Future<Result<void>> _addFavourite(int id) async {
    _attractionRepository.setSavedAttraction(id, true);

    _favourites.add(id);

    notifyListeners();

    return const Result.success(null);
  }

  Future<Result<void>> _deleteFavourite(int id) async {
    _attractionRepository.setSavedAttraction(id, false);

    _favourites.remove(id);

    notifyListeners();

    return const Result.success(null);
  }
}
