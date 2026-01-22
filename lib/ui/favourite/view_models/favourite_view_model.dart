import 'dart:collection' show UnmodifiableListView;

import 'package:flutter/material.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/domain/models/event_content.dart';
import 'package:moliseis/domain/models/place_content.dart';
import 'package:moliseis/domain/use-cases/favourite/favourite_get_ids_use_case.dart';
import 'package:moliseis/utils/command.dart';
import 'package:moliseis/utils/result.dart';

class FavouriteViewModel extends ChangeNotifier {
  FavouriteViewModel({required FavouriteGetIdsUseCase favouriteGetIdsUseCase})
    : _favouriteGetIdsUseCase = favouriteGetIdsUseCase {
    load = Command0(_load)..execute();
    addEvent = Command1(_addEvent);
    addPlace = Command1(_addPlace);
    removeEvent = Command1(_removeEvent);
    removePlace = Command1(_removePlace);
  }

  final FavouriteGetIdsUseCase _favouriteGetIdsUseCase;

  late Command1<void, int> addEvent;
  late Command1<void, int> addPlace;
  late Command0<void> load;
  late Command1<void, int> removeEvent;
  late Command1<void, int> removePlace;

  final _favouriteEvents = <ContentBase>[];
  final _favouritePlaces = <ContentBase>[];
  var _favouriteEventIds = <int>[];
  var _favouritePlaceIds = <int>[];

  UnmodifiableListView<ContentBase> get favouriteEvents =>
      UnmodifiableListView(_favouriteEvents);
  UnmodifiableListView<ContentBase> get favouritePlaces =>
      UnmodifiableListView(_favouritePlaces);
  UnmodifiableListView<int> get favouriteEventIds =>
      UnmodifiableListView(_favouriteEventIds);
  UnmodifiableListView<int> get favouritePlaceIds =>
      UnmodifiableListView(_favouritePlaceIds);

  Future<Result<void>> _addEvent(int id) async {
    _favouriteEventIds.add(id);

    notifyListeners();

    final result = await _favouriteGetIdsUseCase.setFavouriteEvent(id, true);

    switch (result) {
      case Error<void>():
        // Removes the Id from the list of favourites Ids if it couldn't be
        // added to the repository.
        _favouriteEventIds.remove(id);

        notifyListeners();

      case Success<void>():
        await _getEventFromRepository(id);

        notifyListeners();
    }

    return result;
  }

  Future<Result<void>> _addPlace(int id) async {
    _favouritePlaceIds.add(id);

    notifyListeners();

    final result = await _favouriteGetIdsUseCase.setFavouritePlace(id, true);

    switch (result) {
      case Error<void>():
        // Removes the Id from the list of favourites Ids if it couldn't be
        // added to the repository.
        _favouritePlaceIds.remove(id);

        notifyListeners();

      case Success<void>():
        await _getPlaceFromRepository(id);

        notifyListeners();
    }

    return result;
  }

  Future<void> _getEventFromRepository(int id) async {
    // Fetches the event details and adds it to favourites.
    final result = await _favouriteGetIdsUseCase.getEventById(id);

    switch (result) {
      case Success<EventContent>():
        _favouriteEvents.add(result.value);
      case Error<EventContent>():
    }
  }

  Future<void> _getPlaceFromRepository(int id) async {
    // Fetches the place details and adds it to favourites.
    final result = await _favouriteGetIdsUseCase.getPlaceById(id);

    switch (result) {
      case Success<PlaceContent>():
        _favouritePlaces.add(result.value);
      case Error<PlaceContent>():
    }
  }

  bool isFavourite(ContentBase content) {
    if (content is EventContent) {
      return _favouriteEventIds.contains(content.remoteId);
    } else if (content is PlaceContent) {
      return _favouritePlaceIds.contains(content.remoteId);
    }
    return false;
  }

  Future<Result<void>> _load() async {
    final result = await _favouriteGetIdsUseCase.getFavouritePlaceIds();

    switch (result) {
      case Success<List<int>>():
        _favouritePlaceIds = result.value;

        notifyListeners();

        for (final int id in _favouritePlaceIds) {
          await _getPlaceFromRepository(id);
        }

        notifyListeners();
      case Error<List<int>>():
    }

    final result2 = await _favouriteGetIdsUseCase.getFavouriteEventIds();

    switch (result2) {
      case Success<List<int>>():
        _favouriteEventIds = result2.value;

        notifyListeners();

        for (final int id in _favouriteEventIds) {
          await _getEventFromRepository(id);
        }

        notifyListeners();
      case Error<List<int>>():
    }

    return result;
  }

  Future<Result<void>> _removeEvent(int id) async {
    _favouriteEventIds.remove(id);

    _favouriteEvents.removeWhere((event) => event.remoteId == id);

    notifyListeners();

    final result = await _favouriteGetIdsUseCase.setFavouriteEvent(id, false);

    switch (result) {
      case Error<void>():
        // Adds the Id back to the list of favourites Ids if it couldn't be
        // removed from the repository.
        _favouriteEventIds.add(id);

        notifyListeners();

        await _getEventFromRepository(id);

        notifyListeners();

      case Success<void>():
    }

    return result;
  }

  Future<Result<void>> _removePlace(int id) async {
    _favouritePlaceIds.remove(id);

    _favouritePlaces.removeWhere((place) => place.remoteId == id);

    notifyListeners();

    final result = await _favouriteGetIdsUseCase.setFavouritePlace(id, false);

    switch (result) {
      case Error<void>():
        // Adds the Id back to the list of favourites Ids if it couldn't be
        // removed from the repository.
        _favouritePlaceIds.add(id);

        notifyListeners();

        await _getPlaceFromRepository(id);

        notifyListeners();

      case Success<void>():
    }

    return result;
  }
}
