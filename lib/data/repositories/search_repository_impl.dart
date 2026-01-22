import 'package:logging/logging.dart';
import 'package:moliseis/data/services/objectbox.dart';
import 'package:moliseis/data/sources/city.dart';
import 'package:moliseis/data/sources/event.dart';
import 'package:moliseis/data/sources/place.dart';
import 'package:moliseis/data/sources/search_query.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/repositories/search_repository.dart';
import 'package:moliseis/generated/objectbox.g.dart';
import 'package:moliseis/utils/extensions.dart';
import 'package:moliseis/utils/result.dart';

class SearchRepositoryImpl implements SearchRepository {
  late final Query<City> _cityQuery;
  late final Query<Event> _eventCategoryQuery;
  late final Query<Event> _eventQuery;
  final ObjectBox _objectBox;
  late final Query<Place> _placeCategoryQuery;
  late final Query<Place> _placeQuery;
  final Box<SearchQuery> _searchHistoryBox;

  SearchRepositoryImpl({required ObjectBox objectBoxI})
    : _objectBox = objectBoxI,
      _searchHistoryBox = objectBoxI.store.box<SearchQuery>() {
    _init();
  }

  final _log = Logger('SearchRepositoryImpl');

  /// The list of the Event IDs returned by the last search.
  // var _lastEventResultIds = <int>[];

  /// The list of the Place IDs returned by the last search.
  var _lastPlaceResultIds = <int>[];

  /// Whether the last search was made by category.
  var _categorySearched = false;

  /// Caches the ObjectBox queries.
  void _init() {
    _cityQuery = _objectBox.store
        .box<City>()
        .query(City_.name.contains('', caseSensitive: false))
        .build();

    _eventQuery = _objectBox.store
        .box<Event>()
        .query(Event_.name.contains('', caseSensitive: false))
        .build();

    _eventCategoryQuery = _objectBox.store
        .box<Event>()
        .query(Event_.dbType.oneOf(<int>[]))
        .build();

    _placeQuery = _objectBox.store
        .box<Place>()
        .query(Place_.name.contains('', caseSensitive: false))
        .build();

    _placeCategoryQuery = _objectBox.store
        .box<Place>()
        .query(Place_.dbType.oneOf(<int>[]))
        .build();
  }

  @override
  Future<Result> addToHistory(String text) async {
    if (text.isEmpty) {
      return const Result.success(null);
    }

    try {
      final history = _searchHistoryBox.getAll();

      for (final element in history) {
        if (element.name.toLowerCase() == text.toLowerCase()) {
          return const Result.success(null);
        }
      }

      _searchHistoryBox.putAsync(SearchQuery(text));
    } on Exception catch (error, stackTrace) {
      _log.severe(
        'An exception occurred while adding $text to search history.',
        error,
        stackTrace,
      );
      return Result.error(error);
    }

    return const Result.success(null);
  }

  @override
  Future<Result<List<int>>> getEventIdsByQuery(String text) async {
    try {
      _cityQuery.param(City_.name).value = text;

      _eventQuery.param(Event_.name).value = text;

      _eventCategoryQuery.param(Event_.dbType).values = _getCategoryIndexes(
        text,
      );

      final (categoryQuery, cityQuery, eventQuery) = (
        _eventCategoryQuery.findIds(),
        _cityQuery.findIds(),
        _eventQuery.findIds(),
      );

      final results = <int>[];

      results.addAll(eventQuery);

      final test = _objectBox.store.box<City>().getMany(cityQuery);

      for (var i = 0; i < test.length; i++) {
        final city = test[i];
        if (city != null) {
          for (final event in city.events) {
            results.add(event.remoteId);
          }
        }
      }

      results.addAll(categoryQuery);

      // _lastEventResultIds = results;

      // Purges the query results from any duplicate.
      final uniqueIds = <dynamic>{};
      results.retainWhere((id) => uniqueIds.add(id));

      return Result.success(results);
    } on Exception catch (error, stackTrace) {
      _log.warning(
        'An exception occurred while getting event ids by query: $text.',
        error,
        stackTrace,
      );
      return Result.error(error);
    }
  }

  @override
  Future<Result<List<int>>> getPlaceIdsByQuery(String text) async {
    try {
      _cityQuery.param(City_.name).value = text;

      _placeQuery.param(Place_.name).value = text;

      _placeCategoryQuery.param(Place_.dbType).values = _getCategoryIndexes(
        text,
      );

      // Generates a record.
      // Source: https://stackoverflow.com/a/77073846
      final (categoryQuery, cityQuery, placeQuery) = (
        _placeCategoryQuery.findIds(),
        _cityQuery.findIds(),
        _placeQuery.findIds(),
      );

      final results = <int>[];

      results.addAll(placeQuery);

      final test = _objectBox.store.box<City>().getMany(cityQuery);

      for (var i = 0; i < test.length; i++) {
        final city = test[i];
        if (city != null) {
          for (final place in city.places) {
            results.add(place.remoteId);
          }
        }
      }

      _categorySearched = categoryQuery.isNotEmpty;

      results.addAll(categoryQuery);

      // Purges the query results from any duplicate.
      final uniqueIds = <dynamic>{};
      results.retainWhere((id) => uniqueIds.add(id));

      _lastPlaceResultIds = results;

      return Result.success(results);
    } on Exception catch (error, stackTrace) {
      _log.warning(
        'An exception occurred while getting place ids by query: $text.',
        error,
        stackTrace,
      );
      return Result.error(error);
    }
  }

  @override
  Future<Result<List<int>>> getRelatedResults(String text) async {
    if (_categorySearched) {
      return const Result.success(<int>[]);
    }

    try {
      final placeBox = _objectBox.store.box<Place>();

      final places = placeBox.getMany(_lastPlaceResultIds);

      final places1 = <Place>[];

      for (final place in places) {
        if (place != null) {
          places1.add(place);
        }
      }

      final related = _getRelatedResults(places1);

      final results = related.map<int>((Place e) => e.remoteId).toList();

      final set1 = results.toSet();
      final set2 = _lastPlaceResultIds.toSet();
      final diff = set1.difference(set2).toList();

      return Result.success(diff);
    } on Exception catch (error, stackTrace) {
      _log.severe(
        'An exception occurred while getting related results.',
        error,
        stackTrace,
      );
      return Result.error(error);
    }
  }

  @override
  Future<Result<List<String>>> pastSearches() async {
    try {
      final history = await _searchHistoryBox.getAllAsync();

      return Result.success(
        history.map<String>((element) => element.name).toList(),
      );
    } on Exception catch (error, stackTrace) {
      _log.severe(
        'An exception occurred while getting past searches.',
        error,
        stackTrace,
      );
      return Result.error(error);
    }
  }

  @override
  Future<Result> removeFromHistory(String text) async {
    try {
      final condition = SearchQuery_.name.equals(text);
      final queryBuilder = _searchHistoryBox.query(condition);
      final query = queryBuilder.build();
      final result = await query.findUniqueAsync();
      query.close();
      if (result != null) {
        _searchHistoryBox.remove(result.id);
      }
      return const Result.success(null);
    } on Exception catch (error, stackTrace) {
      _log.severe(
        'An exception occurred while removing $text from search history.',
        error,
        stackTrace,
      );
      return Result.error(error);
    }
  }

  List<Place> _getRelatedResults(List<Place> searchResults) {
    try {
      // Creates a frequency map from direct search results where each key is
      // a ContentCategory and the corresponding value represents how many
      // times that type appears in the results.
      final freqMap = searchResults.fold<Map<ContentCategory, int>>({}, (
        Map<ContentCategory, int> map,
        Place element,
      ) {
        map[element.category] = (map[element.category] ?? 0) + 1;
        return map;
      });

      // Sorts the frequency map from the most to the least appeared type.
      final sorted = freqMap.keys.toList()
        ..sort(
          (k1, k2) => (freqMap[k2]! as num).compareTo(freqMap[k1]! as num),
        );

      // Finds all places having the most appeared type.
      _placeCategoryQuery.param(Place_.dbType).values = [sorted.first.index];

      return _placeCategoryQuery.find();
    } on Exception catch (error, stackTrace) {
      _log.severe(
        'An exception occurred while loading related results.',
        error,
        stackTrace,
      );

      return <Place>[];
    }
  }

  List<int> _getCategoryIndexes(String query) {
    final matchingTypes = ContentCategory.values.where(
      (type) => type.label.toLowerCase().contains(query.toLowerCase()),
    );

    final typeIndexes = matchingTypes.map((type) => type.index).toList();

    return typeIndexes;
  }
}
