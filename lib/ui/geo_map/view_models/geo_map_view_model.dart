import 'package:collection/collection.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/content_type.dart';
import 'package:moliseis/domain/use-cases/geo_map_use_case.dart';
import 'package:moliseis/utils/command.dart';
import 'package:moliseis/utils/extensions/extensions.dart';
import 'package:moliseis/utils/result.dart';

class GeoMapViewModel extends ChangeNotifier {
  GeoMapViewModel({required GeoMapUseCase geoMapUseCase})
    : _geoMapUseCase = geoMapUseCase {
    loadEvents = Command0(_loadEvents)..execute();
    loadNearContent = Command1(_loadNearContent);
    loadPlaces = Command0(_loadPlaces)..execute();
    setSelectedCategories = Command1(_setSelectedCategories);
    setSelectedTypes = Command1(_setSelectedTypes);
    showEvent = Command1(_showEvent);
    showPlace = Command1(_showPlace);

    equality = const DeepCollectionEquality();
  }

  final GeoMapUseCase _geoMapUseCase;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  late Command0<void> loadEvents;
  late Command1<void, LatLng> loadNearContent;
  late Command0<void> loadPlaces;
  late Command1<void, Set<ContentCategory>> setSelectedCategories;
  late Command1<void, Set<ContentType>> setSelectedTypes;
  late Command1<void, int> showEvent;
  late Command1<void, int> showPlace;

  late DeepCollectionEquality equality;

  var _allEvents = <ContentBase>[];
  var _allPlaces = <ContentBase>[];
  final _nearContent = <ContentBase>[];
  var _selectedCategories = Set<ContentCategory>.from(
    ContentCategory.values.minusUnknown,
  );
  ContentBase? _selectedContent;
  int _selectionGeneration = 0;
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
    _selectionGeneration++;
    _selectedContent = null;
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

  Future<Result<void>> _showEvent(int id) async {
    final generation = ++_selectionGeneration;
    final result = await _geoMapUseCase.getEventById(id);
    if (_disposed || generation != _selectionGeneration) return result;
    final content = result.getOrNull();
    if (content != null) {
      _selectedContent = content;
      notifyListeners();
    }
    return result;
  }

  Future<Result<void>> _showPlace(int id) async {
    final generation = ++_selectionGeneration;
    final result = await _geoMapUseCase.getPlaceById(id);
    if (_disposed || generation != _selectionGeneration) return result;
    final content = result.getOrNull();
    if (content != null) {
      _selectedContent = content;
      notifyListeners();
    }
    return result;
  }
}
