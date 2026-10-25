import 'dart:async';
import 'dart:collection' show UnmodifiableListView;

import 'package:material_ui/material_ui.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/domain/models/event.dart';
import 'package:moliseis/domain/models/place.dart';
import 'package:moliseis/domain/use-cases/favourite_get_ids_use_case.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/result_command.dart';

/// Manages the user's favourited places and events.
///
/// Loading remains command-based for the screen's loading and error UI. A
/// single short local persistence mutation is accepted at a time so optimistic
/// updates and their rollbacks always have one clear predecessor state.
class FavouriteViewModel extends ChangeNotifier {
  FavouriteViewModel({required FavouriteGetIdsUseCase favouriteGetIdsUseCase})
    : _favouriteGetIdsUseCase = favouriteGetIdsUseCase {
    load = createResultCommandNoParam<void>(
      _load,
      debugName: 'favourite_view_model.load',
    );
    load.isRunningSync.addListener(_captureLoadAdmission);
    load.results.addListener(_forwardLoadChanges);
    load.run();
  }

  final FavouriteGetIdsUseCase _favouriteGetIdsUseCase;

  /// Command for loading all favourited places and events from the repository.
  late final ResultCommand<void, void> load;

  var _favouriteEvents = <ContentBase>[];
  var _favouritePlaces = <ContentBase>[];
  var _favouriteEventIds = <int>[];
  var _favouritePlaceIds = <int>[];
  var _mutationRunning = false;
  var _disposed = false;
  var _loadRejectedAtAdmission = false;

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
  bool get isUpdating => load.isRunningSync.value || _mutationRunning;

  /// Optimistically sets [content]'s favourite state to [save] and persists it.
  ///
  /// Calls made during the initial load or another favourite write are
  /// rejected.
  /// Expected persistence failures restore the exact pre-call local state.
  Future<Result<void>> setFavourite(
    ContentBase content, {
    required bool save,
  }) async {
    if (_disposed || isUpdating) {
      return Result.error(_updateUnavailableException());
    }
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
      if (!_disposed) {
        _mutationRunning = false;
        _notifyListeners();
      }
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

      if (_disposed) return Result.error(_updateUnavailableException());
      final result = await _persistFavourite(event, true);
      if (_disposed) return result;
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

    if (_disposed) return Result.error(_updateUnavailableException());
    final result = await _persistFavourite(event, false);
    if (_disposed) return result;
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

      if (_disposed) return Result.error(_updateUnavailableException());
      final result = await _persistFavourite(place, true);
      if (_disposed) return result;
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

    if (_disposed) return Result.error(_updateUnavailableException());
    final result = await _persistFavourite(place, false);
    if (_disposed) return result;
    return result.mapError((error) {
      if (idIndex >= 0) _favouritePlaceIds.insert(idIndex, id);
      if (removedContent != null) {
        _favouritePlaces.insert(contentIndex, removedContent);
      }
      _notifyListeners();
      return error;
    });
  }

  Future<Result<void>> _persistFavourite(ContentBase content, bool save) async {
    try {
      final result = switch (content) {
        Event(:final remoteId) => _favouriteGetIdsUseCase.setFavouriteEvent(
          remoteId,
          save: save,
        ),
        Place(:final remoteId) => _favouriteGetIdsUseCase.setFavouritePlace(
          remoteId,
          save: save,
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
    if (_disposed || _loadRejectedAtAdmission || _mutationRunning) {
      return Result.error(_updateUnavailableException());
    }

    final placesResult = await _favouriteGetIdsUseCase.getFavouritePlaceIds();
    if (_disposed) {
      return placesResult.isError
          ? placesResult.map((_) {})
          : Result.error(_updateUnavailableException());
    }
    final placeIds = placesResult.getOrNull();
    if (placeIds != null) {
      final freshPlaceIds = _deduplicateIds(placeIds);
      final freshPlaces = <ContentBase>[];
      for (final id in freshPlaceIds) {
        final place = await _getPlaceFromRepository(id);
        if (_disposed) return Result.error(_updateUnavailableException());
        if (place != null) freshPlaces.add(place);
      }
      _favouritePlaceIds = freshPlaceIds;
      _favouritePlaces = freshPlaces;
      _notifyListeners();
    }

    if (_disposed) return Result.error(_updateUnavailableException());
    final eventsResult = await _favouriteGetIdsUseCase.getFavouriteEventIds();
    if (_disposed) {
      if (placesResult.isError) return placesResult.map((_) {});
      return eventsResult.isError
          ? eventsResult.map((_) {})
          : Result.error(_updateUnavailableException());
    }
    final eventIds = eventsResult.getOrNull();
    if (eventIds != null) {
      final freshEventIds = _deduplicateIds(eventIds);
      final freshEvents = <ContentBase>[];
      for (final id in freshEventIds) {
        final event = await _getEventFromRepository(id);
        if (_disposed) {
          return placesResult.isError
              ? placesResult.map((_) {})
              : Result.error(_updateUnavailableException());
        }
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

  Exception _unsupportedContentException(ContentBase content) =>
      Exception('Unsupported favourite content type: ${content.runtimeType}.');

  Exception _updateUnavailableException() => Exception(
    'Cannot update favourites while another update is in progress.',
  );

  void _captureLoadAdmission() {
    if (load.isRunningSync.value) _loadRejectedAtAdmission = _mutationRunning;
  }

  void _forwardLoadChanges() => _notifyListeners();

  void _notifyListeners() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    load.results.removeListener(_forwardLoadChanges);
    load.isRunningSync.removeListener(_captureLoadAdmission);
    // Forwarding can cause dispose inside the owner's own notification.
    scheduleMicrotask(super.dispose);
    final command = load;
    var queued = false;
    var invalidated = false;
    var released = false;
    late VoidCallback onRunningChanged;
    void requestCleanup() {
      if (queued || released) return;
      queued = true;
      invalidated = false;
      // Leave dispatch and upstream's terminal event work before release.
      scheduleMicrotask(() {
        unawaited(
          Future<void>(() {
            queued = false;
            if (released || command.isRunningSync.value) return;
            if (invalidated) {
              requestCleanup();
              return;
            }
            command.isRunningSync.removeListener(onRunningChanged);
            released = true;
            command.dispose();
          }),
        );
      });
    }

    onRunningChanged = () {
      invalidated = true;
      if (!command.isRunningSync.value) requestCleanup();
    };
    command.isRunningSync.addListener(onRunningChanged);
    if (!command.isRunningSync.value) requestCleanup();
  }
}
