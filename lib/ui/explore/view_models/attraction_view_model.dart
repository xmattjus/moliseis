import 'dart:async' show Future;
import 'dart:collection' show UnmodifiableListView;

import 'package:flutter/material.dart';
import 'package:moliseis/data/repositories/attraction/attraction_repository.dart';
import 'package:moliseis/domain/models/attraction/attraction.dart';
import 'package:moliseis/domain/models/attraction/attraction_type.dart';
import 'package:moliseis/utils/extensions.dart';
import 'package:moliseis/utils/result.dart';

class AttractionViewModel extends ChangeNotifier {
  AttractionViewModel({required AttractionRepository attractionRepository})
    : _attractionRepository = attractionRepository,
      _savedAttractionIds = attractionRepository.savedAttractionIds;

  final AttractionRepository _attractionRepository;
  Future<List<int>>? _suggestedAttractionIds;
  Future<List<int>>? _latestAttractionIds;
  final List<int> _savedAttractionIds;

  final List<AttractionType> _types = AttractionType.values.minusUnknown;

  UnmodifiableListView<AttractionType> get attractionTypes =>
      UnmodifiableListView(_types);

  Future<Result<void>> refreshData() async {
    final result = await _attractionRepository.synchronize();

    /// Clears the local Future copies.
    if (result == const Result.success(null)) {
      _suggestedAttractionIds = null;
      _latestAttractionIds = null;
    }

    return result;
  }

  Future<List<int>> get suggestedAttractionIds =>
      _suggestedAttractionIds ??= _attractionRepository.suggestedAttractionsIds;

  Future<List<int>> get latestAttractionIds =>
      _latestAttractionIds ??= _attractionRepository.latestAttractionsIds;

  List<int> get savedAttractionIds => _savedAttractionIds.toList();

  int getTypeIndexFromAttractionId(int id) {
    final typeIndex = _attractionRepository.getTypeIndexFromAttractionId(id);
    return typeIndex != 0 ? typeIndex : 1;
  }

  Future<Attraction> getAttractionById(String? id) async {
    final parsedId = int.tryParse(id!);

    if (parsedId == null) {
      return Future.error(const FormatException());
    }

    final result = await _attractionRepository.getById(parsedId);

    switch (result) {
      case Success<Attraction>():
        return result.value;
      case Error<Attraction>():
        return Future.error(result.error);
    }
  }

  Future<List<int>> getNearAttractionIds(List<double> coordinates) =>
      _attractionRepository.getNearAttractionIds(coordinates);

  bool isAttractionSaved(int id) {
    for (final element in _savedAttractionIds) {
      if (element == id) {
        return true;
      }
    }

    return false;
  }

  void setSavedAttractionId(int id, bool save) {
    if (!save) {
      _savedAttractionIds.removeWhere((element) => element == id);
    } else {
      _savedAttractionIds.add(id);
    }
    notifyListeners();

    _attractionRepository.setSavedAttraction(id, save);
  }
}
