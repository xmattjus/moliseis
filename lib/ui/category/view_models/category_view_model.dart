import 'dart:collection' show UnmodifiableListView;

import 'package:flutter/material.dart';
import 'package:moliseis/data/repositories/settings/settings_repository.dart';
import 'package:moliseis/domain/models/core/content_base.dart';
import 'package:moliseis/domain/models/core/content_category.dart';
import 'package:moliseis/domain/models/core/content_sort.dart';
import 'package:moliseis/domain/models/core/content_type.dart';
import 'package:moliseis/domain/models/event/event_content.dart';
import 'package:moliseis/domain/models/place/place_content.dart';
import 'package:moliseis/domain/use-cases/category/category_use_case.dart';
import 'package:moliseis/domain/use-cases/explore/explore_use_case.dart';
import 'package:moliseis/utils/command.dart';
import 'package:moliseis/utils/extensions.dart';
import 'package:moliseis/utils/result.dart';

class CategoryViewModel extends ChangeNotifier {
  final CategoryUseCase _categoryUseCase;
  final ExploreUseCase _exploreGetByIdUseCase;
  final SettingsRepository _settingsRepository;

  late Command0<void> load;
  late Command1<void, Set<ContentCategory>> setSelectedCategories;
  late Command1<void, ContentSort> setSort;
  late Command1<void, Set<ContentType>> setSelectedTypes;

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
  }

  final _content = <ContentBase>[];
  var _selectedCategories = Set<ContentCategory>.from(
    ContentCategory.values.minusUnknown,
  );
  var _selectedTypes = {ContentType.place, ContentType.event};
  ContentSort? _sort;

  UnmodifiableListView<ContentBase> get content =>
      UnmodifiableListView(_content);
  Set<ContentCategory> get selectedCategories =>
      Set<ContentCategory>.from(_selectedCategories);
  ContentSort get sort => _sort ??= _settingsRepository.contentSort;

  Future<Result<void>> _load() async {
    if (!_selectedCategories.containsAll(ContentCategory.values.minusUnknown)) {
      if (_selectedTypes.contains(ContentType.place)) {
        final job1 = await _categoryUseCase.getPlacesByCategories(
          _selectedCategories,
        );

        switch (job1) {
          case Success<List<PlaceContent>>():
            _content.addAll(job1.value);
          case Error<List<PlaceContent>>():
            return Result.error(job1.error);
        }
      }

      if (_selectedTypes.contains(ContentType.event)) {
        final job2 = await _categoryUseCase.getEventsByCategories(
          _selectedCategories,
        );

        switch (job2) {
          case Success<List<EventContent>>():
            _content.addAll(job2.value);
          case Error<List<EventContent>>():
            return Result.error(job2.error);
        }
      }

      notifyListeners();

      return const Result.success(null);
    } else {
      if (_selectedTypes.contains(ContentType.place)) {
        final job1 = await _exploreGetByIdUseCase.getAllPlaces();

        switch (job1) {
          case Success<List<PlaceContent>>():
            _content.addAll(job1.value);
          case Error<List<PlaceContent>>():
            return Result.error(job1.error);
        }
      }

      if (_selectedTypes.contains(ContentType.event)) {
        final job2 = await _exploreGetByIdUseCase.getAllEvents();

        switch (job2) {
          case Success<List<EventContent>>():
            _content.addAll(job2.value);
          case Error<List<EventContent>>():
            return Result.error(job2.error);
        }
      }

      notifyListeners();

      return const Result.success(null);
    }
  }

  Future<Result<void>> _setSelectedCategories(
    Set<ContentCategory> categories,
  ) async {
    _selectedCategories = categories;

    _content.clear();

    await load.execute();

    return const Result.success(null);
  }

  Future<Result<void>> _setSelectedTypes(Set<ContentType> types) async {
    _selectedTypes = types;

    _content.clear();

    await load.execute();

    return const Result.success(null);
  }

  Future<Result<void>> _setSort(ContentSort sort) async {
    _sort = sort;

    if (sort == ContentSort.byName) {
      _content.sort((a, b) => a.name.compareTo(b.name));
    } else if (sort == ContentSort.byDate) {
      _content.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    }

    notifyListeners();

    _settingsRepository.setContentSort(sort);

    return const Result.success(null);
  }
}
