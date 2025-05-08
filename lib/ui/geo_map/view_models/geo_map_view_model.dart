import 'package:flutter/material.dart';
import 'package:moliseis/data/repositories/attraction/attraction_repository.dart';
import 'package:moliseis/domain/models/attraction/attraction.dart';
import 'package:moliseis/domain/models/attraction/attraction_sort.dart';
import 'package:moliseis/utils/result.dart';

class GeoMapViewModel extends ChangeNotifier {
  GeoMapViewModel({required AttractionRepository attractionRepository})
    : _attractionRepository = attractionRepository;

  final AttractionRepository _attractionRepository;

  Future<List<Attraction>> getAllAttractions() =>
      _attractionRepository.getAll(AttractionSort.byName);

  Future<Attraction> getAttractionById(int id) async {
    final result = await _attractionRepository.getById(id);

    switch (result) {
      case Success<Attraction>():
        return result.value;
      case Error<Attraction>():
        return Future.error(result.error);
    }
  }
}
