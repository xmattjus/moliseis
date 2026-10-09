import 'dart:async' show unawaited;

import 'package:collection/collection.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/content_type.dart';
import 'package:moliseis/domain/use-cases/geo_map_use_case.dart';
import 'package:moliseis/ui/geo_map/view_models/geo_map_selection_intent.dart';
import 'package:moliseis/utils/command.dart' as legacy;
import 'package:moliseis/utils/extensions/extensions.dart';
import 'package:moliseis/utils/restartable_command.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/result_command.dart';

class GeoMapViewModel extends ChangeNotifier {
  GeoMapViewModel({required GeoMapUseCase geoMapUseCase})
    : _geoMapUseCase = geoMapUseCase {
    loadEvents = legacy.Command0(_loadEvents);
    unawaited(loadEvents.execute());
    loadNearContent = legacy.Command1(_loadNearContent);
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
    super.dispose();
  }

  late legacy.Command0<void> loadEvents;
  late legacy.Command1<void, LatLng> loadNearContent;
  late legacy.Command0<void> loadPlaces;
  late legacy.Command1<void, Set<ContentCategory>> setSelectedCategories;
  late legacy.Command1<void, Set<ContentType>> setSelectedTypes;

  /// Single latest-intent event/place/clear execution boundary.
  late final RestartableCommand<GeoMapSelectionIntent, ContentBase?>
  selectContent;

  late DeepCollectionEquality equality;

  var _allEvents = <ContentBase>[];
  var _allPlaces = <ContentBase>[];
  final _nearContent = <ContentBase>[];
  var _selectedCategories = Set<ContentCategory>.from(
    ContentCategory.values.minusUnknown,
  );
  ContentBase? _selectedContent;
  var _selectedTypes = Set<ContentType>.from(ContentType.values);

  UnmodifiableListView<ContentBase> get allEvents =>
      UnmodifiableListView(_allEvents);
  UnmodifiableListView<ContentBase> get allPlaces =>
      UnmodifiableListView(_allPlaces);
  UnmodifiableListView<ContentBase> get nearContent =>
      UnmodifiableListView(_nearContent);
  UnmodifiableSetView<ContentCategory> get selectedCategories =>
      UnmodifiableSetView(_selectedCategories);
  ContentBase? get selectedContent => _selectedContent;

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

  Future<Result<void>> _loadNearContent(LatLng coordinates) async {
    _nearContent.clear();

    final placesResult = await _geoMapUseCase.getNearPlacesByCoords(
      coordinates.latitude,
      coordinates.longitude,
    );
    if (_disposed) return placesResult;
    final places = placesResult.getOrNull();
    if (places != null) _nearContent.addAll(places);

    final eventsResult = await _geoMapUseCase.getNearEventsByCoords(
      coordinates.latitude,
      coordinates.longitude,
    );
    if (_disposed) return placesResult.isError ? placesResult : eventsResult;
    final events = eventsResult.getOrNull();
    if (events != null) _nearContent.addAll(events);

    notifyListeners();

    // Return the first error encountered, or the events result.
    if (placesResult.isError) return placesResult;
    return eventsResult;
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

  /// Clears old selection and accepts a new authoritative intent immediately.
  void requestSelection(GeoMapSelectionIntent intent) {
    _selectedContent = null;
    selectContent.run(intent);
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
    return result.map<ContentBase?>((content) => content);
  }

  void _commitSelection() {
    final snapshot = selectContent.results.value;
    if (!snapshot.completed) return;
    snapshot.data!.map((content) {
      if (snapshot.paramData?.matchesPayload(content) != true) return;
      _selectedContent = content;
      notifyListeners();
    });
  }
}
