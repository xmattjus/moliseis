import 'dart:collection' show UnmodifiableListView;

import 'package:flutter/material.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/domain/models/event_content.dart';
import 'package:moliseis/domain/models/place_content.dart';
import 'package:moliseis/domain/use-cases/favourite_get_ids_use_case.dart';
import 'package:moliseis/utils/command.dart';
import 'package:moliseis/utils/result.dart';

/// Manages the user's favourited places and events.
///
/// Exposes commands for loading, adding, and removing favourites. Add and
/// remove operations are applied optimistically and rolled back on failure.
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

  /// Command for marking an event as a favourite by its ID.
  late Command1<void, int> addEvent;

  /// Command for marking a place as a favourite by its ID.
  late Command1<void, int> addPlace;

  /// Command for loading all favourited places and events from the repository.
  late Command0<void> load;

  /// Command for unmarking an event as a favourite by its ID.
  late Command1<void, int> removeEvent;

  /// Command for unmarking a place as a favourite by its ID.
  late Command1<void, int> removePlace;

  final _favouriteEvents = <ContentBase>[];
  final _favouritePlaces = <ContentBase>[];
  var _favouriteEventIds = <int>[];
  var _favouritePlaceIds = <int>[];

  /// The full content objects for all favourited events.
  UnmodifiableListView<ContentBase> get favouriteEvents =>
      UnmodifiableListView(_favouriteEvents);

  /// The full content objects for all favourited places.
  UnmodifiableListView<ContentBase> get favouritePlaces =>
      UnmodifiableListView(_favouritePlaces);

  /// The remote IDs of all favourited events.
  UnmodifiableListView<int> get favouriteEventIds =>
      UnmodifiableListView(_favouriteEventIds);

  /// The remote IDs of all favourited places.
  UnmodifiableListView<int> get favouritePlaceIds =>
      UnmodifiableListView(_favouritePlaceIds);

  Future<Result<void>> _addEvent(int id) {
    return _addFavourite(
      ids: _favouriteEventIds,
      persist: (favId) =>
          _favouriteGetIdsUseCase.setFavouriteEvent(favId, true),
      fetchContent: _getEventFromRepository,
      id: id,
    );
  }

  Future<Result<void>> _addPlace(int id) {
    return _addFavourite(
      ids: _favouritePlaceIds,
      persist: (favId) =>
          _favouriteGetIdsUseCase.setFavouritePlace(favId, true),
      fetchContent: _getPlaceFromRepository,
      id: id,
    );
  }

  /// Optimistically adds [id] to [ids], persists via [persist], then fetches
  /// the full content object via [fetchContent]. Rolls back [ids] on failure.
  Future<Result<void>> _addFavourite({
    required List<int> ids,
    required Future<Result<void>> Function(int) persist,
    required Future<void> Function(int) fetchContent,
    required int id,
  }) async {
    ids.add(id);
    notifyListeners();

    final result = await persist(id);

    if (result.isError) {
      // Roll back the optimistically added ID if the repository rejected it.
      ids.remove(id);
    } else {
      await fetchContent(id);
    }
    notifyListeners();

    return result;
  }

  Future<void> _getEventFromRepository(int id) async {
    final event = (await _favouriteGetIdsUseCase.getEventById(id)).getOrNull();
    if (event != null) _favouriteEvents.add(event);
  }

  Future<void> _getPlaceFromRepository(int id) async {
    final place = (await _favouriteGetIdsUseCase.getPlaceById(id)).getOrNull();
    if (place != null) _favouritePlaces.add(place);
  }

  /// Returns whether [content] is currently marked as a favourite.
  bool isFavourite(ContentBase content) {
    if (content is EventContent) {
      return _favouriteEventIds.contains(content.remoteId);
    } else if (content is PlaceContent) {
      return _favouritePlaceIds.contains(content.remoteId);
    }
    // Unknown ContentBase subtype — not tracked as a favourite.
    return false;
  }

  Future<Result<void>> _load() async {
    final placesResult = await _favouriteGetIdsUseCase.getFavouritePlaceIds();

    final placeIds = placesResult.getOrNull();
    if (placeIds != null) {
      _favouritePlaceIds = List<int>.of(placeIds);
      for (final int id in _favouritePlaceIds) {
        await _getPlaceFromRepository(id);
      }
      notifyListeners();
    }

    final eventsResult = await _favouriteGetIdsUseCase.getFavouriteEventIds();

    final eventIds = eventsResult.getOrNull();
    if (eventIds != null) {
      _favouriteEventIds = List<int>.of(eventIds);
      for (final int id in _favouriteEventIds) {
        await _getEventFromRepository(id);
      }
      notifyListeners();
    }

    if (placesResult.isError) return placesResult.map((_) {});
    if (eventsResult.isError) return eventsResult.map((_) {});
    return const Result.success(null);
  }

  Future<Result<void>> _removeEvent(int id) {
    return _removeFavourite(
      ids: _favouriteEventIds,
      contents: _favouriteEvents,
      persist: (favId) =>
          _favouriteGetIdsUseCase.setFavouriteEvent(favId, false),
      fetchContent: _getEventFromRepository,
      id: id,
    );
  }

  Future<Result<void>> _removePlace(int id) {
    return _removeFavourite(
      ids: _favouritePlaceIds,
      contents: _favouritePlaces,
      persist: (favId) =>
          _favouriteGetIdsUseCase.setFavouritePlace(favId, false),
      fetchContent: _getPlaceFromRepository,
      id: id,
    );
  }

  /// Optimistically removes [id] from [ids] and its content from [contents],
  /// persists via [persist]. Restores both on failure.
  Future<Result<void>> _removeFavourite({
    required List<int> ids,
    required List<ContentBase> contents,
    required Future<Result<void>> Function(int) persist,
    required Future<void> Function(int) fetchContent,
    required int id,
  }) async {
    ids.remove(id);
    contents.removeWhere((item) => item.remoteId == id);
    notifyListeners();

    final result = await persist(id);

    if (result.isError) {
      // Restore the optimistically removed item if the repository rejected it.
      ids.add(id);
      notifyListeners();
      await fetchContent(id);
      notifyListeners();
    }

    return result;
  }
}
