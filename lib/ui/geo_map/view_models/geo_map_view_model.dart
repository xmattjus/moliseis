import 'dart:async' show unawaited;

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
import 'package:moliseis/utils/command.dart' as legacy;
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

class GeoMapViewModel extends ChangeNotifier {
  GeoMapViewModel({required GeoMapUseCase geoMapUseCase})
    : _geoMapUseCase = geoMapUseCase {
    loadEvents = legacy.Command0(_loadEvents);
    unawaited(loadEvents.execute());
    loadNearContent = RestartableCommand(
      (target) => _fetchNearby(geoMapUseCase, target),
      debugName: 'geo_map_nearby',
    );
    loadNearContent.results.addListener(_commitNearby);
    loadPlaces = legacy.Command0(_loadPlaces);
    unawaited(loadPlaces.execute());
    setSelectedCategories = legacy.Command1(_setSelectedCategories);
    setSelectedTypes = legacy.Command1(_setSelectedTypes);
    selectContent = RestartableCommand(
      (intent) => _fetchSelection(geoMapUseCase, intent),
      debugName: 'geo_map_selection',
    );
    selectContent.results.addListener(_commitSelection);

    equality = const DeepCollectionEquality();
  }

  final GeoMapUseCase _geoMapUseCase;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    selectContent.results.removeListener(_commitSelection);
    selectContent.dispose();
    loadNearContent.results.removeListener(_commitNearby);
    loadNearContent.dispose();
    super.dispose();
  }

  late legacy.Command0<void> loadEvents;
  late final RestartableCommand<GeoMapNearbyTarget, GeoMapNearbyOutcome>
  loadNearContent;
  late legacy.Command0<void> loadPlaces;
  late legacy.Command1<void, Set<ContentCategory>> setSelectedCategories;
  late legacy.Command1<void, Set<ContentType>> setSelectedTypes;

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
  var _selectedCategories = Set<ContentCategory>.from(
    ContentCategory.values.minusUnknown,
  );
  var _selectedTypes = Set<ContentType>.from(ContentType.values);

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

  Future<Result<void>> _loadEvents() async {
    final result = await _geoMapUseCase.getAllEvents();
    if (_disposed) return result;

    final events = result.getOrNull();
    if (events != null) {
      _allEvents = events
          .where((event) => _selectedCategories.contains(event.category))
          .toList();
      notifyListeners();
    }

    return result;
  }

  Future<Result<void>> _loadPlaces() async {
    final result = await _geoMapUseCase.getAllPlaces();
    if (_disposed) return result;

    final places = result.getOrNull();
    if (places != null) {
      _allPlaces = places
          .where((place) => _selectedCategories.contains(place.category))
          .toList();
      notifyListeners();
    }

    return result;
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

  Future<Result<void>> _setSelectedCategories(
    Set<ContentCategory> categories,
  ) async {
    if (equality.equals(_selectedCategories, categories)) {
      return const Result.success(null);
    }

    _selectedCategories = categories;

    await _load();
    if (_disposed) return const Result.success(null);

    notifyListeners();

    return const Result.success(null);
  }

  Future<Result<void>> _setSelectedTypes(Set<ContentType> types) async {
    if (equality.equals(_selectedTypes, types)) {
      return const Result.success(null);
    }

    _selectedTypes = types;

    await _load();
    if (_disposed) return const Result.success(null);

    notifyListeners();

    return const Result.success(null);
  }

  Future<Result<void>> _load() async {
    _allEvents.clear();
    _allPlaces.clear();

    if (_selectedTypes.containsAll({ContentType.place, ContentType.event})) {
      await loadEvents.execute();
      if (_disposed) return const Result.success(null);
      await loadPlaces.execute();
    } else if (_selectedTypes.contains(ContentType.event)) {
      await loadEvents.execute();
    } else if (_selectedTypes.contains(ContentType.place)) {
      await loadPlaces.execute();
    }

    return const Result.success(null);
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
