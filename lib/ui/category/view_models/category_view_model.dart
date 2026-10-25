import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/content_sort.dart';
import 'package:moliseis/domain/models/content_type.dart';
import 'package:moliseis/domain/repositories/settings_repository.dart';
import 'package:moliseis/domain/use-cases/category_use_case.dart';
import 'package:moliseis/domain/use-cases/explore_use_case.dart';
import 'package:moliseis/utils/extensions/extensions.dart';
import 'package:moliseis/utils/restartable_command.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/result_command.dart';

/// Independent immutable filter snapshots for one content retrieval.
typedef CategoryLoadRequest = ({
  Set<ContentCategory> categories,
  Set<ContentType> types,
});

class CategoryViewModel extends ChangeNotifier {
  CategoryViewModel({
    required Set<ContentCategory> initialCategories,
    required CategoryUseCase categoryUseCase,
    required ExploreUseCase exploreGetByIdUseCase,
    required SettingsRepository settingsRepository,
  }) : _categoryUseCase = categoryUseCase,
       _exploreGetByIdUseCase = exploreGetByIdUseCase,
       _settingsRepository = settingsRepository,
       _selectedCategories = _normalizeCategories(initialCategories),
       _sort = settingsRepository.contentSort {
    load = RestartableCommand<CategoryLoadRequest, List<ContentBase>>(
      _load,
      debugName: 'category_view_model.load',
    );
    setSort = createResultCommand<ContentSort, void>(
      _setSort,
      debugName: 'category_view_model.setSort',
    );
    load.results.addListener(_commitLoad);
    _startLoad();
  }

  final CategoryUseCase _categoryUseCase;
  final ExploreUseCase _exploreGetByIdUseCase;
  final SettingsRepository _settingsRepository;

  late final RestartableCommand<CategoryLoadRequest, List<ContentBase>> load;
  late final ResultCommand<ContentSort, void> setSort;
  var _content = <ContentBase>[];
  Set<ContentCategory> _selectedCategories;
  var _selectedTypes = Set<ContentType>.unmodifiable(ContentType.values);
  ContentSort _sort;
  bool _disposed = false;

  UnmodifiableListView<ContentBase> get content =>
      UnmodifiableListView(_content);
  UnmodifiableSetView<ContentCategory> get selectedCategories =>
      UnmodifiableSetView(_selectedCategories);
  UnmodifiableSetView<ContentType> get selectedTypes =>
      UnmodifiableSetView(_selectedTypes);
  ContentSort get sort => _sort;

  static Set<ContentCategory> _normalizeCategories(Set<ContentCategory> input) {
    final known = input
        .where((value) => value != ContentCategory.unknown)
        .toSet();
    return Set.unmodifiable(
      known.isEmpty ? ContentCategory.values.minusUnknown : known,
    );
  }

  /// Reloads the current selection, superseding any pending retrieval.
  void refresh() {
    if (_disposed) return;
    _startLoad();
    if (!_disposed) notifyListeners();
  }

  void _startLoad() {
    load.run((
      categories: Set.unmodifiable(_selectedCategories),
      types: Set.unmodifiable(_selectedTypes),
    ));
  }

  /// Changes confirmed categories without waiting for obsolete work.
  void setSelectedCategories(Set<ContentCategory> categories) {
    if (_disposed) return;
    final selected = _normalizeCategories(categories);
    if (setEquals(selected, _selectedCategories)) return;
    _selectedCategories = selected;
    _content = [];
    refresh();
  }

  /// Changes confirmed types and preserves previously exposed snapshots.
  void setSelectedTypes(Set<ContentType> types) {
    if (_disposed) return;
    final selected = Set<ContentType>.unmodifiable(
      types.isEmpty ? ContentType.values : types,
    );
    if (setEquals(selected, _selectedTypes)) return;
    _selectedTypes = selected;
    _content = [];
    refresh();
  }

  Future<Result<List<ContentBase>>> _load(CategoryLoadRequest request) async {
    if (_disposed) return _unavailable();
    final candidate = <ContentBase>[];
    final all = request.categories.containsAll(
      ContentCategory.values.minusUnknown,
    );
    if (request.types.contains(ContentType.place)) {
      final result = await (all
          ? _exploreGetByIdUseCase.getAllPlaces()
          : _categoryUseCase.getPlacesByCategories(request.categories));
      switch (result) {
        case Error(:final error):
          return Result.error(error);
        case Success(:final value):
          if (_disposed) return _unavailable();
          candidate.addAll(value);
      }
    }
    if (_disposed) return _unavailable();
    if (request.types.contains(ContentType.event)) {
      final result = await (all
          ? _exploreGetByIdUseCase.getAllEvents()
          : _categoryUseCase.getEventsByCategories(request.categories));
      switch (result) {
        case Error(:final error):
          return Result.error(error);
        case Success(:final value):
          if (_disposed) return _unavailable();
          candidate.addAll(value);
      }
    }
    return Result.success(candidate);
  }

  Result<List<ContentBase>> _unavailable() =>
      Result.error(Exception('Category owner unavailable'));

  void _commitLoad() {
    if (_disposed) return;
    final snapshot = load.results.value;
    if (!snapshot.completed) return;
    // RestartableCommand only delivers authoritative results. Do not commit
    // inside the physical action, which may outlive its publication authority.
    final candidate = List<ContentBase>.of(snapshot.data!.getOrNull()!);
    _sortContent(candidate);
    _content = candidate;
    notifyListeners();
  }

  Future<Result<void>> _setSort(ContentSort sort) async {
    if (_disposed) return Result.error(Exception('Category owner unavailable'));
    if (sort == _sort) return const Result.success(null);
    _sort = sort;
    _sortContent(_content);
    notifyListeners();
    if (_disposed) return Result.error(Exception('Category owner unavailable'));
    // Session ordering intentionally remains optimistic if persistence fails.
    return await _settingsRepository.setContentSort(sort);
  }

  void _sortContent(List<ContentBase> content) {
    content.sort(
      (a, b) => switch (_sort) {
        ContentSort.byName => a.name.compareTo(b.name),
        ContentSort.byDate => b.modifiedAt.compareTo(a.modifiedAt),
      },
    );
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    load.results.removeListener(_commitLoad);
    load.dispose();
    scheduleMicrotask(super.dispose);
    final command = setSort;
    var queued = false;
    var invalidated = false;
    var released = false;
    late VoidCallback onRunningChanged;
    void requestCleanup() {
      if (queued || released) return;
      queued = true;
      invalidated = false;
      // Preserve upstream terminal reporting and leave notifier dispatch.
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
