import 'dart:async';
import 'dart:collection' show UnmodifiableListView;

import 'package:flutter/material.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/domain/models/event.dart';
import 'package:moliseis/domain/models/place.dart';
import 'package:moliseis/domain/use-cases/favourite_get_ids_use_case.dart';
import 'package:moliseis/utils/command.dart';
import 'package:moliseis/utils/result.dart';

/// Manages the user's favourited places and events.
///
/// Loading remains command-based for the screen's loading and error UI. A
/// single short local persistence mutation is accepted at a time so optimistic
/// updates and their rollbacks always have one clear predecessor state.
class FavouriteViewModel extends ChangeNotifier {
  FavouriteViewModel({required FavouriteGetIdsUseCase favouriteGetIdsUseCase})
    : _favouriteGetIdsUseCase = favouriteGetIdsUseCase {
    load = Command0(_load);
    load.addListener(_forwardLoadChanges);

    unawaited(load.execute());
  }

  final FavouriteGetIdsUseCase _favouriteGetIdsUseCase;

  /// Command for loading all favourited places and events from the repository.
  late final Command0<void> load;

  var _favouriteEvents = <ContentBase>[];
  var _favouritePlaces = <ContentBase>[];
  var _favouriteEventIds = <int>[];
  var _favouritePlaceIds = <int>[];
  var _mutationRunning = false;
  var _disposed = false;

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

  /// Whether favourite controls should temporarily reject a new mutation.
  bool get isUpdating => load.running || _mutationRunning;

  /// Optimistically sets [content]'s favourite state to [save] and persists it.
  ///
  /// Calls made during the initial load or another favourite write are
  /// rejected.
  /// Expected persistence failures restore the exact pre-call local state.
  Future<Result<void>> setFavourite(ContentBase content, bool save) async {
    if (isUpdating) return Result.error(_updateUnavailableException());
    if (content is! Event && content is! Place) {
      return Result.error(_unsupportedContentException(content));
    }

    _mutationRunning = true;
    try {
      return switch (content) {
        Event() => await _setEventFavourite(content, save),
        Place() => await _setPlaceFavourite(content, save),
        _ => Result.error(_unsupportedContentException(content)),
      };
    } finally {
      _mutationRunning = false;
      _notifyListeners();
    }
  }

  /// Returns whether [content] is currently marked as a favourite.
  bool isFavourite(ContentBase content) {
    return switch (content) {
      Event(:final remoteId) => _favouriteEventIds.contains(remoteId),
      Place(:final remoteId) => _favouritePlaceIds.contains(remoteId),
      _ => false,
    };
  }

  Future<Result<void>> _setEventFavourite(Event event, bool save) async {
    final id = event.remoteId;

    if (save) {
      final idAdded = !_favouriteEventIds.contains(id);
      final contentAdded = !_favouriteEvents.any(
        (content) => content.remoteId == id,
      );
      if (idAdded) _favouriteEventIds.add(id);
      if (contentAdded) _favouriteEvents.add(event);
      _notifyListeners();

      final result = await _persistFavourite(event, true);
      return result.mapError((error) {
        if (idAdded) _favouriteEventIds.remove(id);
        if (contentAdded) {
          _favouriteEvents.removeWhere((content) => content.remoteId == id);
        }
        _notifyListeners();
        return error;
      });
    }

    final idIndex = _favouriteEventIds.indexOf(id);
    final contentIndex = _favouriteEvents.indexWhere(
      (content) => content.remoteId == id,
    );
    final removedContent = contentIndex < 0
        ? null
        : _favouriteEvents.removeAt(contentIndex);
    if (idIndex >= 0) _favouriteEventIds.removeAt(idIndex);
    _notifyListeners();

    final result = await _persistFavourite(event, false);
    return result.mapError((error) {
      if (idIndex >= 0) _favouriteEventIds.insert(idIndex, id);
      if (removedContent != null) {
        _favouriteEvents.insert(contentIndex, removedContent);
      }
      _notifyListeners();
      return error;
    });
  }

  Future<Result<void>> _setPlaceFavourite(Place place, bool save) async {
    final id = place.remoteId;

    if (save) {
      final idAdded = !_favouritePlaceIds.contains(id);
      final contentAdded = !_favouritePlaces.any(
        (content) => content.remoteId == id,
      );
      if (idAdded) _favouritePlaceIds.add(id);
      if (contentAdded) _favouritePlaces.add(place);
      _notifyListeners();

      final result = await _persistFavourite(place, true);
      return result.mapError((error) {
        if (idAdded) _favouritePlaceIds.remove(id);
        if (contentAdded) {
          _favouritePlaces.removeWhere((content) => content.remoteId == id);
        }
        _notifyListeners();
        return error;
      });
    }

    final idIndex = _favouritePlaceIds.indexOf(id);
    final contentIndex = _favouritePlaces.indexWhere(
      (content) => content.remoteId == id,
    );
    final removedContent = contentIndex < 0
        ? null
        : _favouritePlaces.removeAt(contentIndex);
    if (idIndex >= 0) _favouritePlaceIds.removeAt(idIndex);
    _notifyListeners();

    final result = await _persistFavourite(place, false);
    return result.mapError((error) {
      if (idIndex >= 0) _favouritePlaceIds.insert(idIndex, id);
      if (removedContent != null) {
        _favouritePlaces.insert(contentIndex, removedContent);
      }
      _notifyListeners();
      return error;
    });
  }

  Future<Result<void>> _persistFavourite(
    ContentBase content,
    bool save,
  ) async {
    try {
      final result = switch (content) {
        Event(:final remoteId) => _favouriteGetIdsUseCase.setFavouriteEvent(
          remoteId,
          save,
        ),
        Place(:final remoteId) => _favouriteGetIdsUseCase.setFavouritePlace(
          remoteId,
          save,
        ),
        _ => Future.value(
          Result<void>.error(_unsupportedContentException(content)),
        ),
      };
      return await result;
    } on Exception catch (exception) {
      return Result.error(exception);
    }
  }

  Future<Result<void>> _load() async {
    if (_mutationRunning) return Result.error(_updateUnavailableException());

    final placesResult = await _favouriteGetIdsUseCase.getFavouritePlaceIds();
    final placeIds = placesResult.getOrNull();
    if (placeIds != null) {
      final freshPlaceIds = _deduplicateIds(placeIds);
      final freshPlaces = <ContentBase>[];
      for (final id in freshPlaceIds) {
        final place = await _getPlaceFromRepository(id);
        if (place != null) freshPlaces.add(place);
      }
      _favouritePlaceIds = freshPlaceIds;
      _favouritePlaces = freshPlaces;
      _notifyListeners();
    }

    final eventsResult = await _favouriteGetIdsUseCase.getFavouriteEventIds();
    final eventIds = eventsResult.getOrNull();
    if (eventIds != null) {
      final freshEventIds = _deduplicateIds(eventIds);
      final freshEvents = <ContentBase>[];
      for (final id in freshEventIds) {
        final event = await _getEventFromRepository(id);
        if (event != null) freshEvents.add(event);
      }
      _favouriteEventIds = freshEventIds;
      _favouriteEvents = freshEvents;
      _notifyListeners();
    }

    if (placesResult.isError) return placesResult.map((_) {});
    if (eventsResult.isError) return eventsResult.map((_) {});
    return const Result.success(null);
  }

  List<int> _deduplicateIds(List<int> ids) => ids.toSet().toList();

  Future<Event?> _getEventFromRepository(int id) async =>
      (await _favouriteGetIdsUseCase.getEventById(id)).getOrNull();

  Future<Place?> _getPlaceFromRepository(int id) async =>
      (await _favouriteGetIdsUseCase.getPlaceById(id)).getOrNull();

  Exception _unsupportedContentException(ContentBase content) => Exception(
    'Unsupported favourite content type: ${content.runtimeType}.',
  );

  Exception _updateUnavailableException() => Exception(
    'Cannot update favourites while another update is in progress.',
  );

  void _forwardLoadChanges() => _notifyListeners();

  void _notifyListeners() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    load.removeListener(_forwardLoadChanges);
    if (!load.running) load.dispose();
    super.dispose();
  }
}
