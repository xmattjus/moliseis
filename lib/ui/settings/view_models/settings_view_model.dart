import 'package:flutter/material.dart';
import 'package:moliseis/data/repositories/settings/settings_repository.dart';
import 'package:moliseis/domain/models/attraction/attraction_sort.dart';

class SettingsViewModel extends ChangeNotifier {
  final SettingsRepository _settingsRepository;
  AttractionSort? _sortBy;
  bool? _crashReporting;

  SettingsViewModel({required SettingsRepository settingsRepository})
    : _settingsRepository = settingsRepository;

  AttractionSort get attractionSortBy =>
      _sortBy ??= _settingsRepository.attractionSort;

  void saveAttractionSortBy(AttractionSort sortBy) {
    _sortBy = sortBy;
    notifyListeners();

    _settingsRepository.setAttractionSort(sortBy);
  }

  bool get crashReporting =>
      _crashReporting ??= _settingsRepository.crashReporting;

  void saveCrashReporting(bool enable) {
    _crashReporting = enable;
    notifyListeners();

    _settingsRepository.setCrashReporting(enable);
  }
}
