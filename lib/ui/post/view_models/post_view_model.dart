import 'dart:collection' show UnmodifiableListView;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/domain/use-cases/post_use_case.dart';
import 'package:moliseis/utils/command.dart';
import 'package:moliseis/utils/result.dart';

class PostViewModel extends ChangeNotifier {
  PostViewModel({required PostUseCase postUseCase})
    : _postUseCase = postUseCase {
    loadEvent = Command1(_loadEvent);
    loadNearContent = Command1(_loadNearContent);
    loadPlace = Command1(_loadPlace);
  }

  final PostUseCase _postUseCase;

  late Command1<void, int> loadEvent;
  late Command1<void, LatLng> loadNearContent;
  late Command1<void, int> loadPlace;

  late ContentBase _content;
  final _nearContent = <ContentBase>[];

  ContentBase get content => _content;
  UnmodifiableListView<ContentBase> get nearContent =>
      UnmodifiableListView(_nearContent);

  Future<Result<void>> _loadEvent(int id) async {
    return (await _postUseCase.getEventById(id)).map((content) {
      _content = content;
      notifyListeners();
    });
  }

  Future<Result<void>> _loadNearContent(LatLng coordinates) async {
    _nearContent.clear();

    final eventsResult = await _postUseCase.getNearEventsByCoords(
      coordinates.latitude,
      coordinates.longitude,
    );
    final events = eventsResult.getOrNull();
    if (events != null) _nearContent.addAll(events);

    final placesResult = await _postUseCase.getNearPlacesByCoords(
      coordinates.latitude,
      coordinates.longitude,
    );
    final places = placesResult.getOrNull();
    if (places != null) _nearContent.addAll(places);

    notifyListeners();

    // Return the first error encountered, or the places result.
    if (eventsResult.isError) return eventsResult;
    return placesResult;
  }

  Future<Result<void>> _loadPlace(int id) async {
    return (await _postUseCase.getPlaceById(id)).map((content) {
      _content = content;
      notifyListeners();
    });
  }
}
