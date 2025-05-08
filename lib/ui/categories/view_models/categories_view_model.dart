import 'dart:collection' show UnmodifiableListView;

import 'package:flutter/material.dart';
import 'package:moliseis/data/repositories/attraction/attraction_repository.dart';
import 'package:moliseis/domain/models/attraction/attraction_sort.dart';
import 'package:moliseis/domain/models/attraction/attraction_type.dart';

class CategoriesViewModel extends ChangeNotifier {
  CategoriesViewModel({required AttractionRepository attractionRepository})
    : _attractionRepository = attractionRepository;

  final AttractionRepository _attractionRepository;

  /// Returns a list of [AttractionType]s containing all but
  /// [AttractionType.unknown].
  final List<AttractionType> _types = AttractionType.values.sublist(1);

  UnmodifiableListView<AttractionType> get attractionTypes =>
      UnmodifiableListView(_types);

  int getTypeIndexFromAttractionId(int id) {
    final typeIndex = _attractionRepository.getTypeIndexFromAttractionId(id);
    return typeIndex != 0 ? typeIndex : 1;
  }

  Future<List<int>> getAttractionIdsByType(
    AttractionType type,
    AttractionSort orderBy,
  ) => _attractionRepository.getAttractionIdsByType(type, orderBy);
}
