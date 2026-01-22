import 'dart:collection' show UnmodifiableListView;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/domain/use-cases/detail/detail_use_case.dart';
import 'package:moliseis/utils/command.dart';
import 'package:moliseis/utils/result.dart';

class DetailViewModel extends ChangeNotifier {
  final DetailUseCase _detailUseCase;

  late Command1<void, int> loadEvent;
  late Command1<void, LatLng> loadNearContent;
  late Command1<void, int> loadPlace;

  DetailViewModel({required DetailUseCase detailUseCase})
    : _detailUseCase = detailUseCase {
    loadEvent = Command1(_loadEvent);
    loadNearContent = Command1(_loadNearContent);
    loadPlace = Command1(_loadPlace);
  }

  late ContentBase _content;
  final _nearContent = <ContentBase>[];

  ContentBase get content => _content;
  UnmodifiableListView<ContentBase> get nearContent =>
      UnmodifiableListView(_nearContent);

  Future<Result<void>> _loadEvent(int id) async {
    final result = await _detailUseCase.getEventById(id);

    switch (result) {
      case Success<ContentBase>():
        _content = result.value;
        notifyListeners();
      case Error<ContentBase>():
    }

    return result;
  }

  Future<Result<void>> _loadNearContent(LatLng coordinates) async {
    _nearContent.clear();

    var result = await _detailUseCase.getNearEventsByCoords(
      coordinates.latitude,
      coordinates.longitude,
    );

    switch (result) {
      case Success<List<ContentBase>>():
        _nearContent.addAll(result.value);
      case Error<List<ContentBase>>():
    }

    result = await _detailUseCase.getNearPlacesByCoords(
      coordinates.latitude,
      coordinates.longitude,
    );

    switch (result) {
      case Success<List<ContentBase>>():
        _nearContent.addAll(result.value);
      case Error<List<ContentBase>>():
    }

    notifyListeners();

    return result;
  }

  Future<Result<void>> _loadPlace(int id) async {
    final result = await _detailUseCase.getPlaceById(id);

    switch (result) {
      case Success<ContentBase>():
        _content = result.value;
        notifyListeners();
      case Error<ContentBase>():
    }

    return result;
  }
}
