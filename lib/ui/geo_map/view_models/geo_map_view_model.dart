import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/content_type.dart';
import 'package:moliseis/domain/models/event_content.dart';
import 'package:moliseis/domain/models/place_content.dart';
import 'package:moliseis/domain/use-cases/geo_map/geo_map_use_case.dart';
import 'package:moliseis/utils/command.dart';
import 'package:moliseis/utils/extensions/extensions.dart';
import 'package:moliseis/utils/result.dart';

class GeoMapViewModel extends ChangeNotifier {
  final GeoMapUseCase _geoMapUseCase;

  late Command0<void> loadEvents;
  late Command1<void, LatLng> loadNearContent;
  late Command0<void> loadPlaces;
  late Command1<void, Set<ContentCategory>> setSelectedCategories;
  late Command1<void, Set<ContentType>> setSelectedTypes;
  late Command1<void, int> showEvent;
  late Command1<void, int> showPlace;

  late DeepCollectionEquality equality;

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
  UnmodifiableSetView<ContentType> get selectedTypes =>
      UnmodifiableSetView(_selectedTypes);

  Future<Result<void>> _loadEvents() async {
    final result = await _geoMapUseCase.getAllEvents();

    switch (result) {
      case Success<List<EventContent>>():
        _allEvents = result.value
            .where((event) => _selectedCategories.contains(event.category))
            .toList();
        notifyListeners();
      case Error<List<EventContent>>():
    }

    return result;
  }

  Future<Result<void>> _loadPlaces() async {
    final result = await _geoMapUseCase.getAllPlaces();

    switch (result) {
      case Success<List<PlaceContent>>():
        _allPlaces = result.value
            .where((place) => _selectedCategories.contains(place.category))
            .toList();
        notifyListeners();
      case Error<List<PlaceContent>>():
    }

    return result;
  }

  Future<Result<void>> _loadNearContent(LatLng coordinates) async {
    _nearContent.clear();

    var result = await _geoMapUseCase.getNearPlacesByCoords(
      coordinates.latitude,
      coordinates.longitude,
    );

    switch (result) {
      case Success<List<ContentBase>>():
        _nearContent.addAll(result.value);
      case Error<List<ContentBase>>():
    }

    result = await _geoMapUseCase.getNearEventsByCoords(
      coordinates.latitude,
      coordinates.longitude,
    );

    switch (result) {
      case Success<List<ContentBase>>():
        _nearContent.addAll(result.value);
      case Error<List<ContentBase>>():
    }

    notifyListeners();

    return result;
  }

  Future<Result<void>> _setSelectedCategories(
    Set<ContentCategory> categories,
  ) async {
    if (equality.equals(_selectedCategories, categories)) {
      return const Result.success(null);
    }

    _selectedCategories = categories;

    await _load();

    notifyListeners();

    return const Result.success(null);
  }

  Future<Result<void>> _setSelectedTypes(Set<ContentType> types) async {
    if (equality.equals(_selectedTypes, types)) {
      return const Result.success(null);
    }

    _selectedTypes = types;

    await _load();

    notifyListeners();

    return const Result.success(null);
  }

  Future<Result<void>> _load() async {
    _allEvents.clear();
    _allPlaces.clear();

    if (_selectedTypes.containsAll({ContentType.place, ContentType.event})) {
      await loadEvents.execute();
      await loadPlaces.execute();
    } else if (_selectedTypes.contains(ContentType.event)) {
      await loadEvents.execute();
    } else if (_selectedTypes.contains(ContentType.place)) {
      await loadPlaces.execute();
    }

    return const Result.success(null);
  }

  Future<Result<void>> _showEvent(int id) async {
    final result = await _geoMapUseCase.getEventById(id);

    switch (result) {
      case Success<ContentBase>():
        _selectedContent = result.value;
        notifyListeners();
      case Error<ContentBase>():
    }

    return result;
  }

  Future<Result<void>> _showPlace(int id) async {
    final result = await _geoMapUseCase.getPlaceById(id);

    switch (result) {
      case Success<ContentBase>():
        _selectedContent = result.value;
        notifyListeners();
      case Error<ContentBase>():
    }

    return result;
  }
}
