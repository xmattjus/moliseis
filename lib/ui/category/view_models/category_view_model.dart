import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/content_sort.dart';
import 'package:moliseis/domain/models/content_type.dart';
import 'package:moliseis/domain/repositories/settings_repository.dart';
import 'package:moliseis/domain/use-cases/category_use_case.dart';
import 'package:moliseis/domain/use-cases/explore_use_case.dart';
import 'package:moliseis/utils/command.dart';
import 'package:moliseis/utils/extensions/extensions.dart';
import 'package:moliseis/utils/result.dart';

class CategoryViewModel extends ChangeNotifier {
  final CategoryUseCase _categoryUseCase;
  final ExploreUseCase _exploreGetByIdUseCase;
  final SettingsRepository _settingsRepository;

  late Command0<void> load;
  late Command1<void, Set<ContentCategory>> setSelectedCategories;
  late Command1<void, ContentSort> setSort;
  late Command1<void, Set<ContentType>> setSelectedTypes;

  late DeepCollectionEquality equality;

  CategoryViewModel({
    required CategoryUseCase categoryUseCase,
    required ExploreUseCase exploreGetByIdUseCase,
    required SettingsRepository settingsRepository,
  }) : _categoryUseCase = categoryUseCase,
       _exploreGetByIdUseCase = exploreGetByIdUseCase,
       _settingsRepository = settingsRepository {
    load = Command0(_load);
    setSelectedCategories = Command1(_setSelectedCategories);
    setSort = Command1(_setSort);
    setSelectedTypes = Command1(_setSelectedTypes);
    _sort = _settingsRepository.contentSort;

    equality = const DeepCollectionEquality();
  }

  final _content = <ContentBase>[];
  var _selectedCategories = <ContentCategory>{};
  var _selectedTypes = Set<ContentType>.from(ContentType.values);
  late ContentSort _sort;

  UnmodifiableListView<ContentBase> get content =>
      UnmodifiableListView(_content);
  UnmodifiableSetView<ContentCategory> get selectedCategories =>
      UnmodifiableSetView(_selectedCategories);
  UnmodifiableSetView<ContentType> get selectedTypes =>
      UnmodifiableSetView(_selectedTypes);
  ContentSort get sort => _sort;

  Future<Result<void>> _load() async {
    _content.clear();

    if (!_selectedCategories.containsAll(ContentCategory.values.minusUnknown)) {
      if (_selectedTypes.contains(ContentType.place)) {
        final result = await _categoryUseCase.getPlacesByCategories(
          _selectedCategories,
        );
        final places = result.getOrNull();
        if (places != null) _content.addAll(places);
        if (result.isError) return result;
      }

      if (_selectedTypes.contains(ContentType.event)) {
        final result = await _categoryUseCase.getEventsByCategories(
          _selectedCategories,
        );
        final events = result.getOrNull();
        if (events != null) _content.addAll(events);
        if (result.isError) return result;
      }
    } else {
      if (_selectedTypes.contains(ContentType.place)) {
        final result = await _exploreGetByIdUseCase.getAllPlaces();
        final places = result.getOrNull();
        if (places != null) _content.addAll(places);
        if (result.isError) return result;
      }

      if (_selectedTypes.contains(ContentType.event)) {
        final result = await _exploreGetByIdUseCase.getAllEvents();
        final events = result.getOrNull();
        if (events != null) _content.addAll(events);
        if (result.isError) return result;
      }
    }

    await _sortContent(sort);

    notifyListeners();

    return const Result.success(null);
  }

  Future<Result<void>> _setSelectedCategories(
    Set<ContentCategory> categories,
  ) async {
    if (equality.equals(categories, _selectedCategories)) {
      return const Result.success(null);
    }

    _selectedCategories = categories;

    _content.clear();

    await load.execute();

    return const Result.success(null);
  }

  Future<Result<void>> _setSelectedTypes(Set<ContentType> types) async {
    if (equality.equals(types, _selectedTypes)) {
      return const Result.success(null);
    }

    _selectedTypes = types;

    _content.clear();

    await load.execute();

    return const Result.success(null);
  }

  Future<Result<void>> _setSort(ContentSort sort) async {
    if (sort == _sort) {
      return const Result.success(null);
    }

    await _sortContent(sort);

    notifyListeners();

    await _settingsRepository.setContentSort(sort);

    return const Result.success(null);
  }

  Future<void> _sortContent(ContentSort sort) async {
    _sort = sort;

    if (_sort == ContentSort.byName) {
      _content.sort((a, b) => a.name.compareTo(b.name));
    } else if (_sort == ContentSort.byDate) {
      _content.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    }
  }
}
