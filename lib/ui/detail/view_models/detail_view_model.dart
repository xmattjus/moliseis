import 'dart:collection' show UnmodifiableListView;

import 'package:flutter/material.dart';
import 'package:moliseis/domain/models/core/content_base.dart';
import 'package:moliseis/domain/use-cases/detail/detail_use_case.dart';
import 'package:moliseis/utils/command.dart';
import 'package:moliseis/utils/result.dart';

class DetailViewModel extends ChangeNotifier {
  final DetailUseCase _detailUseCase;

  late Command1<void, int> loadEvent;
  late Command1<void, List<double>> loadNearContent;
  late Command1<void, int> loadPlace;
  late Command1<void, List<double>> loadStreetAddress;

  DetailViewModel({required DetailUseCase detailUseCase})
    : _detailUseCase = detailUseCase {
    loadEvent = Command1(_loadEvent);
    loadNearContent = Command1(_loadNearContent);
    loadPlace = Command1(_loadPlace);
    loadStreetAddress = Command1(_loadStreetAddress);
  }

  late ContentBase _content;
  final _nearContent = <ContentBase>[];
  var _streetAddress = '';

  ContentBase get content => _content;
  UnmodifiableListView<ContentBase> get nearContent =>
      UnmodifiableListView(_nearContent);
  String get streetAddress => _streetAddress;

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

  Future<Result<void>> _loadNearContent(List<double> coordinates) async {
    _nearContent.clear();

    var result = await _detailUseCase.getNearEventsByCoords(
      coordinates[0],
      coordinates[1],
    );

    switch (result) {
      case Success<List<ContentBase>>():
        _nearContent.addAll(result.value);
      case Error<List<ContentBase>>():
    }

    result = await _detailUseCase.getNearPlacesByCoords(
      coordinates[0],
      coordinates[1],
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

  Future<Result<void>> _loadStreetAddress(List<double> coordinates) async {
    final result = await _detailUseCase.getStreetAddressByCoords(
      coordinates[0],
      coordinates[1],
    );

    switch (result) {
      case Success<String?>():
        _streetAddress = result.value ?? 'Indirizzo non trovato';
      case Error<String?>():
        _streetAddress = "Indirizzo non trovato";
    }

    return result;
  }
}
