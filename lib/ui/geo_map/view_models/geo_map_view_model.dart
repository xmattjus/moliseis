import 'dart:async' show scheduleMicrotask;

import 'package:collection/collection.dart';
import 'package:command_it/command_it.dart' as commands;
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/content_type.dart';
import 'package:moliseis/domain/models/event.dart';
import 'package:moliseis/domain/models/place.dart';
import 'package:moliseis/domain/use-cases/geo_map_use_case.dart';
import 'package:moliseis/ui/geo_map/view_models/geo_map_mode.dart';
import 'package:moliseis/ui/geo_map/view_models/geo_map_selection_intent.dart';
import 'package:moliseis/utils/extensions/extensions.dart';
import 'package:moliseis/utils/restartable_command.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/result_command.dart';

/// The semantic identity and coordinates owning a Nearby retrieval.
typedef GeoMapNearbyTarget = ({
  GeoMapContentIdentity? post,
  double latitude,
  double longitude,
});

/// A completed aggregate preserves partial discovery and its original error.
typedef GeoMapNearbyOutcome = ({
  List<ContentBase> items,
  Exception? firstError,
});

/// One terminal publication, synchronously cleared when its target changes.
typedef GeoMapNearbyTerminal =
    commands.CommandResult<GeoMapNearbyTarget?, Result<GeoMapNearbyOutcome>?>;

typedef GeoMapSelectionSnapshot =
    commands.CommandResult<GeoMapSelectionIntent?, Result<ContentBase?>?>;

/// An immutable filter selection with a unique admission identity.
class GeoMapMarkerRequest {
  /// Copies caller-owned sets; later selections receive independent identities.
  GeoMapMarkerRequest({
    required Set<ContentCategory> categories,
    required Set<ContentType> types,
  }) : categories = Set.unmodifiable(categories),
       types = Set.unmodifiable(types);

  /// Categories captured for this retrieval, excluding unknown values.
  final Set<ContentCategory> categories;

  /// Content sources admitted for this retrieval.
  final Set<ContentType> types;

  /// Empty programmatic selection settles without repository work.
  bool get isEmpty => categories.isEmpty || types.isEmpty;
}

/// One atomic marker result retaining partial sources and original failures.
class GeoMapMarkerOutcome {
  /// Copies source collections so later changes cannot alter committed markers.
  GeoMapMarkerOutcome({
    required List<ContentBase> events,
    required List<ContentBase> places,
    this.eventError,
    this.placeError,
  }) : events = List.unmodifiable(events),
       places = List.unmodifiable(places);

  /// Ordered events matching the captured categories.
  final List<ContentBase> events;

  /// Ordered places matching the captured categories.
  final List<ContentBase> places;

  /// Original expected failure from event discovery, if any.
  final Exception? eventError;

  /// Original expected failure from place discovery, if any.
  final Exception? placeError;

  /// Events have display precedence when both sources fail.
  Exception? get firstError => eventError ?? placeError;
}

/// Semantic marker state, independent of Map navigation and command dispatch.
enum GeoMapMarkerStatus { loading, successEmpty, successData, failure }

/// Authoritative terminal evidence belonging to one exact marker admission.
typedef GeoMapMarkerTerminal =
    commands.CommandResult<GeoMapMarkerRequest?, Result<GeoMapMarkerOutcome>?>;

class GeoMapViewModel extends ChangeNotifier {
  GeoMapViewModel({required GeoMapUseCase geoMapUseCase}) {
    loadMarkers = RestartableCommand(
      (request) => _fetchMarkers(geoMapUseCase, request),
      debugName: 'geo_map_markers',
    );
    loadMarkers.results.addListener(_commitMarkers);
    loadNearContent = RestartableCommand(
      (target) => _fetchNearby(geoMapUseCase, target),
      debugName: 'geo_map_nearby',
    );
    loadNearContent.results.addListener(_commitNearby);
    selectContent = RestartableCommand(
      (intent) => _fetchSelection(geoMapUseCase, intent),
      debugName: 'geo_map_selection',
    );
    selectContent.results.addListener(_commitSelection);

    equality = const DeepCollectionEquality();
    _admitMarkers();
  }

  bool _disposed = false;

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    loadMarkers.results.removeListener(_commitMarkers);
    loadMarkers.dispose();
    selectContent.results.removeListener(_commitSelection);
    selectContent.dispose();
    loadNearContent.results.removeListener(_commitNearby);
    loadNearContent.dispose();
    scheduleMicrotask(super.dispose);
  }

  /// Latest-filter retrieval; source data commits together at its terminal.
  late final RestartableCommand<GeoMapMarkerRequest, GeoMapMarkerOutcome>
  loadMarkers;
  late final RestartableCommand<GeoMapNearbyTarget, GeoMapNearbyOutcome>
  loadNearContent;

  /// Single latest-intent event/place/clear execution boundary.
  late final RestartableCommand<GeoMapSelectionIntent, ContentBase?>
  selectContent;

  late DeepCollectionEquality equality;

  var _allEvents = <ContentBase>[];
  var _allPlaces = <ContentBase>[];
  // A fresh instance represents a semantic admission, including equal intents.
  // ignore: prefer_const_constructors
  GeoMapMode _mode = GeoMapExplore();
  ContentBase? _resolvedContent;
  LatLng _exploreAnchor = const LatLng(41.5575078, 14.6485406);
  GeoMapNearbyTerminal? _nearbyTerminal;
  late GeoMapMarkerRequest _markerRequest;
  GeoMapMarkerTerminal? _markerTerminal;

  /// Current immutable admission, including its unique request identity.
  GeoMapMarkerRequest get markerRequest => _markerRequest;

  /// Terminal evidence is cleared synchronously whenever filters change.
  GeoMapMarkerTerminal? get markerTerminal => _markerTerminal;

  /// Partial source data, distinct from protocol-level command success.
  GeoMapMarkerOutcome? get markerOutcome => _markerTerminal?.data?.getOrNull();

  /// Current loading, empty, data or failure projection.
  GeoMapMarkerStatus get markerStatus {
    final terminal = _markerTerminal;
    if (terminal == null) return GeoMapMarkerStatus.loading;
    final outcome = terminal.data?.getOrNull();
    if (terminal.hasFailure || outcome?.firstError != null) {
      return GeoMapMarkerStatus.failure;
    }
    return (outcome?.events.isEmpty ?? true) &&
            (outcome?.places.isEmpty ?? true)
        ? GeoMapMarkerStatus.successEmpty
        : GeoMapMarkerStatus.successData;
  }

  GeoMapMode get mode => _mode;
  ContentBase? get resolvedContent => _resolvedContent;
  LatLng get exploreAnchor => _exploreAnchor;
  bool get isDisposed => _disposed;
  GeoMapNearbyTerminal? get nearbyTerminal => _nearbyTerminal;
  GeoMapNearbyOutcome? get nearbyOutcome => _nearbyTerminal?.data?.getOrNull();

  GeoMapNearbyTarget? get nearbyTarget => switch (_mode) {
    GeoMapExplore() => (
      post: null,
      latitude: _exploreAnchor.latitude,
      longitude: _exploreAnchor.longitude,
    ),
    GeoMapPostDetail(:final identity) when _resolvedContent != null => (
      post: identity,
      latitude: _resolvedContent!.coordinates.latitude,
      longitude: _resolvedContent!.coordinates.longitude,
    ),
    _ => null,
  };
  var _selectedCategories = Set<ContentCategory>.unmodifiable(
    ContentCategory.values.minusUnknown,
  );
  var _selectedTypes = Set<ContentType>.unmodifiable(ContentType.values);

  UnmodifiableListView<ContentBase> get allEvents =>
      UnmodifiableListView(_allEvents);
  UnmodifiableListView<ContentBase> get allPlaces =>
      UnmodifiableListView(_allPlaces);
  UnmodifiableListView<ContentBase> get nearContent =>
      UnmodifiableListView(nearbyOutcome?.items ?? const <ContentBase>[]);
  UnmodifiableSetView<ContentCategory> get selectedCategories =>
      UnmodifiableSetView(_selectedCategories);
  ContentBase? get selectedContent => _resolvedContent;

  /// Invalidates an older lookup when the Map URI requests a new selection
  /// or returns to the default map.
  void invalidateRequestedSelection() {
    requestSelection(const ClearSelection());
  }

  UnmodifiableSetView<ContentType> get selectedTypes =>
      UnmodifiableSetView(_selectedTypes);

  /// Captures a new category set and immediately revokes older marker data.
  void setSelectedCategories(Set<ContentCategory> categories) {
    if (_disposed) return;
    final normalized = Set<ContentCategory>.unmodifiable(
      categories.where((category) => category != ContentCategory.unknown),
    );
    if (equality.equals(_selectedCategories, normalized)) return;
    _selectedCategories = normalized;
    _admitMarkers();
  }

  /// Captures selected sources independently from the caller's mutable set.
  void setSelectedTypes(Set<ContentType> types) {
    if (_disposed) return;
    final snapshot = Set<ContentType>.unmodifiable(types);
    if (equality.equals(_selectedTypes, snapshot)) return;
    _selectedTypes = snapshot;
    _admitMarkers();
  }

  /// Retries current filters; busy and empty selections perform no extra work.
  void retryMarkers() {
    if (_disposed ||
        markerStatus == GeoMapMarkerStatus.loading ||
        _markerRequest.isEmpty) {
      return;
    }
    _admitMarkers();
  }

  void _admitMarkers() {
    final request = GeoMapMarkerRequest(
      categories: _selectedCategories,
      types: _selectedTypes,
    );
    _markerRequest = request;
    _allEvents = [];
    _allPlaces = [];
    _markerTerminal = null;
    if (request.isEmpty) {
      loadMarkers.invalidate();
      if (_disposed || !identical(_markerRequest, request)) return;
      final outcome = GeoMapMarkerOutcome(events: const [], places: const []);
      _markerTerminal = commands.CommandResult(
        request,
        Result.success(outcome),
        null,
        false,
      );
    } else {
      loadMarkers.run(request);
    }
    if (!_disposed && identical(_markerRequest, request)) notifyListeners();
  }

  Future<Result<GeoMapMarkerOutcome>> _fetchMarkers(
    GeoMapUseCase useCase,
    GeoMapMarkerRequest request,
  ) async {
    var events = <ContentBase>[];
    var places = <ContentBase>[];
    Exception? eventError;
    Exception? placeError;
    if (!_disposed && request.types.contains(ContentType.event)) {
      final result = await useCase.getAllEvents();
      result.fold(
        (items) => events = items
            .where((item) => request.categories.contains(item.category))
            .toList(),
        (error) => eventError = error,
      );
    }
    // Disposal prevents a new source phase; supersession only revokes commit.
    if (!_disposed && request.types.contains(ContentType.place)) {
      final result = await useCase.getAllPlaces();
      result.fold(
        (items) => places = items
            .where((item) => request.categories.contains(item.category))
            .toList(),
        (error) => placeError = error,
      );
    }
    return Result.success(
      GeoMapMarkerOutcome(
        events: events,
        places: places,
        eventError: eventError,
        placeError: placeError,
      ),
    );
  }

  void _commitMarkers() {
    if (_disposed || loadMarkers.isRunningSync.value) return;
    final snapshot = loadMarkers.results.value;
    if (!identical(snapshot.paramData, _markerRequest) ||
        !(snapshot.completed || snapshot.hasFailure)) {
      return;
    }
    final outcome = snapshot.data?.getOrNull();
    _allEvents = List.of(outcome?.events ?? const []);
    _allPlaces = List.of(outcome?.places ?? const []);
    _markerTerminal = snapshot;
    notifyListeners();
  }

  static Future<Result<GeoMapNearbyOutcome>> _fetchNearby(
    GeoMapUseCase useCase,
    GeoMapNearbyTarget target,
  ) async {
    final places = await useCase.getNearPlacesByCoords(
      target.latitude,
      target.longitude,
    );
    final events = await useCase.getNearEventsByCoords(
      target.latitude,
      target.longitude,
    );
    return Result.success((
      items: List<ContentBase>.unmodifiable([
        ...?places.getOrNull(),
        ...?events.getOrNull(),
      ]),
      firstError:
          places.fold((_) => null, (error) => error) ??
          events.fold((_) => null, (error) => error),
    ));
  }

  /// Admits only the current target; explicit retry clears its terminal.
  void requestNearby(GeoMapNearbyTarget target, {bool retry = false}) {
    if (_disposed ||
        target != nearbyTarget ||
        !LatLng(target.latitude, target.longitude).isValid) {
      return;
    }
    if (loadNearContent.isRunningSync.value) return;
    if (!retry && _nearbyTerminal != null) return;
    final mode = _mode;
    _nearbyTerminal = null;
    loadNearContent.run(target);
    if (!_disposed && identical(_mode, mode) && nearbyTarget == target) {
      notifyListeners();
    }
  }

  void _commitNearby() {
    if (_disposed || loadNearContent.isRunningSync.value) return;
    final snapshot = loadNearContent.results.value;
    if (snapshot.paramData != nearbyTarget ||
        !(snapshot.completed || snapshot.hasFailure)) {
      return;
    }
    _nearbyTerminal = snapshot;
    notifyListeners();
  }

  void _invalidateNearbyIfChanged(GeoMapNearbyTarget? oldTarget) {
    if (oldTarget == nearbyTarget) return;
    _nearbyTerminal = null;
    loadNearContent.invalidate();
  }

  /// Prepares route state during widget lifecycle without notifying Provider.
  ///
  /// Clearing materialization and terminal discovery immediately hides the old
  /// surface. Command invalidation revokes physical work before the next frame.
  /// The exact returned mode owns the deferred notification/lookup admission.
  GeoMapMode? prepareRouteAdmission(
    GeoMapContentIdentity? identity,
    LatLng anchor,
  ) {
    if (_disposed) return null;
    if (identity != null &&
        (identity.id <= 0 ||
            !{ContentType.event, ContentType.place}.contains(identity.type))) {
      return null;
    }
    final mode = identity == null
        // Route preparation is a fresh admission even for A -> B -> A.
        // ignore: prefer_const_constructors
        ? GeoMapExplore()
        : GeoMapPostDetail(identity);
    _mode = mode;
    _resolvedContent = null;
    _nearbyTerminal = null;
    if (identity == null) _exploreAnchor = anchor;
    loadNearContent.invalidate();
    if (_disposed || !identical(_mode, mode)) return mode;
    selectContent.invalidate();
    return mode;
  }

  /// Publishes only the route preparation still owned by the containing view.
  void admitPreparedRoute(GeoMapMode mode) {
    if (_disposed || !identical(_mode, mode)) return;
    if (mode case GeoMapPostDetail(:final identity)) {
      selectContent.run(
        identity.type == ContentType.event
            ? EventSelection(identity.id)
            : PlaceSelection(identity.id),
      );
    }
    if (!_disposed && identical(_mode, mode)) notifyListeners();
  }

  /// Accepts one cross-type Post intent with coherent semantic fields.
  void requestSelection(GeoMapSelectionIntent intent) {
    if (_disposed) return;
    if (intent is ClearSelection) {
      showExplore(_exploreAnchor);
      return;
    }
    final identity = switch (intent) {
      EventSelection(:final id) => (id: id, type: ContentType.event),
      PlaceSelection(:final id) => (id: id, type: ContentType.place),
      ClearSelection() => throw StateError('Already handled clear selection'),
    };
    if (identity.id <= 0) return;
    final oldTarget = nearbyTarget;
    final mode = GeoMapPostDetail(identity);
    _mode = mode;
    _resolvedContent = null;
    _invalidateNearbyIfChanged(oldTarget);
    if (_disposed || !identical(_mode, mode)) return;
    selectContent.run(intent);
    if (!_disposed && identical(_mode, mode)) notifyListeners();
  }

  /// Returns to discovery at the camera center supplied by the containing view.
  GeoMapExplore? showExplore(LatLng anchor) {
    if (_disposed) return null;
    // Every semantic admission requires a distinct identity for view effects.
    // ignore: prefer_const_constructors
    final mode = GeoMapExplore();
    final oldTarget = nearbyTarget;
    _mode = mode;
    _resolvedContent = null;
    _exploreAnchor = anchor;
    _invalidateNearbyIfChanged(oldTarget);
    if (_disposed || !identical(_mode, mode)) return mode;
    selectContent.invalidate();
    if (!_disposed && identical(_mode, mode)) notifyListeners();
    return mode;
  }

  /// Commits a valid query and returns the exact admission after reentrancy.
  GeoMapSearchResults? showSearchResults(String query) {
    // Match the existing Search validity contract; this VM has no Search owner.
    if (_disposed || query.length < 3) return null;
    final mode = GeoMapSearchResults(query);
    final oldTarget = nearbyTarget;
    _mode = mode;
    _resolvedContent = null;
    _invalidateNearbyIfChanged(oldTarget);
    if (_disposed || !identical(_mode, mode)) return mode;
    selectContent.invalidate();
    if (!_disposed && identical(_mode, mode)) notifyListeners();
    return mode;
  }

  /// Selects complete content synchronously, without another repository lookup.
  void showContent(ContentBase content) {
    if (_disposed || content.remoteId <= 0) return;
    final type = switch (content) {
      Event() => ContentType.event,
      Place() => ContentType.place,
      _ => null,
    };
    if (type == null) return;
    final oldTarget = nearbyTarget;
    final mode = GeoMapPostDetail((id: content.remoteId, type: type));
    _mode = mode;
    _resolvedContent = content;
    _invalidateNearbyIfChanged(oldTarget);
    if (_disposed || !identical(_mode, mode)) return;
    selectContent.invalidate();
    if (!_disposed && identical(_mode, mode)) notifyListeners();
  }

  /// Changes the settled anchor without a new mode admission.
  void commitExploreAnchor(LatLng anchor) {
    if (_disposed || _mode is! GeoMapExplore || anchor == _exploreAnchor) {
      return;
    }
    final mode = _mode;
    final oldTarget = nearbyTarget;
    _exploreAnchor = anchor;
    _invalidateNearbyIfChanged(oldTarget);
    if (!_disposed && identical(_mode, mode) && _exploreAnchor == anchor) {
      notifyListeners();
    }
  }

  /// Preserves the authoritative error snapshot while committing its fallback.
  GeoMapExplore? fallbackToExplore(
    LatLng anchor,
    GeoMapSelectionSnapshot snapshot,
  ) {
    if (_disposed ||
        selectContent.isRunningSync.value ||
        !identical(selectContent.results.value, snapshot) ||
        _resolvedContent != null ||
        !_matchesSelection(snapshot.paramData)) {
      return null;
    }
    if (!snapshot.hasFailure &&
        !(snapshot.completed &&
            snapshot.paramData?.matchesPayload(snapshot.data?.getOrNull()) !=
                true)) {
      return null;
    }
    // Every semantic admission requires a distinct identity for view effects.
    // ignore: prefer_const_constructors
    final mode = GeoMapExplore();
    final oldTarget = nearbyTarget;
    _mode = mode;
    _exploreAnchor = anchor;
    _invalidateNearbyIfChanged(oldTarget);
    if (!_disposed && identical(_mode, mode)) notifyListeners();
    return mode;
  }

  bool _matchesSelection(GeoMapSelectionIntent? intent) {
    final mode = _mode;
    if (mode is! GeoMapPostDetail) return false;
    return switch (intent) {
      EventSelection(:final id) =>
        mode.identity == (id: id, type: ContentType.event),
      PlaceSelection(:final id) =>
        mode.identity == (id: id, type: ContentType.place),
      _ => false,
    };
  }

  static Future<Result<ContentBase?>> _fetchSelection(
    GeoMapUseCase useCase,
    GeoMapSelectionIntent intent,
  ) async {
    final Result<ContentBase> result;
    switch (intent) {
      case EventSelection(:final id):
        result = await useCase.getEventById(id);
      case PlaceSelection(:final id):
        result = await useCase.getPlaceById(id);
      case ClearSelection():
        return const Result.success(null);
    }
    return result.flatMap<ContentBase?>(
      (content) => intent.matchesPayload(content)
          ? Result.success(content)
          : Result.error(GeoMapSelectionIdentityException(intent)),
    );
  }

  void _commitSelection() {
    if (_disposed || selectContent.isRunningSync.value) return;
    final snapshot = selectContent.results.value;
    if (!snapshot.completed || !_matchesSelection(snapshot.paramData)) return;
    final content = snapshot.data!.getOrNull();
    if (snapshot.paramData?.matchesPayload(content) != true) return;
    final mode = _mode;
    final oldTarget = nearbyTarget;
    _resolvedContent = content;
    _invalidateNearbyIfChanged(oldTarget);
    if (!_disposed &&
        identical(_mode, mode) &&
        identical(_resolvedContent, content)) {
      notifyListeners();
    }
  }
}
