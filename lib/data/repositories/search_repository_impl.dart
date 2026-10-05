import 'package:meta/meta.dart';
import 'package:moliseis/data/core/object_box_conditions.dart';
import 'package:moliseis/data/data-sources/city_entity.dart';
import 'package:moliseis/data/data-sources/event_entity.dart';
import 'package:moliseis/data/data-sources/place_entity.dart';
import 'package:moliseis/data/data-sources/search_query.dart';
import 'package:moliseis/data/mappers/event_entity_mapper.dart';
import 'package:moliseis/data/mappers/place_entity_mapper.dart';
import 'package:moliseis/data/services/objectbox.dart';
import 'package:moliseis/domain/core/event_time.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/event.dart';
import 'package:moliseis/domain/models/place.dart';
import 'package:moliseis/domain/repositories/search_repository.dart';
import 'package:moliseis/generated/objectbox.g.dart';
import 'package:moliseis/utils/extensions/extensions.dart';
import 'package:moliseis/utils/logging/logging.dart';
import 'package:moliseis/utils/result.dart';

class SearchRepositoryImpl implements SearchRepository {
  SearchRepositoryImpl({
    required Logger logger,
    required ObjectBox objectBoxI,
    DateTime Function()? nowUtc,
  }) : _logger = logger,
       _objectBox = objectBoxI,
       _nowUtc = nowUtc ?? DateTime.now,
       _searchHistoryBox = objectBoxI.store.box<SearchQuery>() {
    _init();
  }

  final Logger _logger;
  final DateTime Function() _nowUtc;
  final EventTimePolicy _eventTimePolicy = EventTimePolicy();

  late final Query<CityEntity> _cityQuery;
  final ObjectBox _objectBox;
  late final Query<PlaceEntity> _placeCategoryQuery;
  late final Query<PlaceEntity> _placeQuery;
  final Box<SearchQuery> _searchHistoryBox;

  DateTime get _currentUtc => _nowUtc().toUtc();

  /// Caches the ObjectBox queries.
  void _init() {
    _cityQuery = _objectBox.store
        .box<CityEntity>()
        .query(CityEntity_.name.contains('', caseSensitive: false))
        .build();

    _placeQuery = _objectBox.store
        .box<PlaceEntity>()
        .query(
          PlaceEntity_.name
              .contains('', caseSensitive: false)
              .and(PlaceEntity_.isDeleted.equals(false)),
        )
        .build();

    _placeCategoryQuery = _objectBox.store
        .box<PlaceEntity>()
        .query(
          PlaceEntity_.contentCategoryIndex
              .oneOf(<int>[])
              .and(PlaceEntity_.isDeleted.equals(false)),
        )
        .build();
  }

  @override
  Future<Result<void>> addToPastSearches(String text) async {
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

      await _searchHistoryBox.putAsync(SearchQuery(text));
    } on Exception catch (exception, stackTrace) {
      _logger.log(
        const EntityInsertFailed('search', 0),
        error: exception,
        stackTrace: stackTrace,
      );
      return Result.error(exception);
    }

    return const Result.success(null);
  }

  @override
  Future<Result<List<ContentBase>>> getResultsByQuery(String text) =>
      Result.zip2(
        () => searchPlaces(text),
        () => searchEvents(text),
        (places, events) => Result.success(<ContentBase>[...places, ...events]),
      );

  /// Discovers and materializes places before event discovery can begin.
  ///
  /// Kept overridable for focused phase-order and failure regressions.
  @protected
  Future<Result<List<Place>>> searchPlaces(String text) async {
    try {
      _cityQuery.param(CityEntity_.name).value = text;
      _placeQuery.param(PlaceEntity_.name).value = text;
      _placeCategoryQuery.param(PlaceEntity_.contentCategoryIndex).values =
          _getCategoryIndexes(text);

      final categories = _placeCategoryQuery.find();
      final cities = _cityQuery.find();
      final matches = _placeQuery.find();
      for (final city in cities) {
        matches.addAll(city.places.where((place) => !place.isDeleted));
      }
      matches.addAll(categories);
      final seen = <int>{};
      return Result.success(
        matches
            .where((place) => seen.add(place.remoteId))
            .map((place) => place.toModel())
            .toList(),
      );
    } on Exception catch (exception, stackTrace) {
      _logger.log(
        const EntityLoadFailed('search', method: 'getResultsByQuery'),
        error: exception,
        stackTrace: stackTrace,
      );
      return Result.error(exception);
    }
  }

  /// Discovers and materializes events after successful place discovery.
  ///
  /// Uses one clock capture for name, city and category annual visibility.
  @protected
  Future<Result<List<Event>>> searchEvents(String text) async {
    Query<EventEntity>? eventQuery;
    Query<EventEntity>? eventCategoryQuery;
    try {
      final nowUtc = _currentUtc;
      final currentYearCondition =
          ObjectBoxConditions.visibleEventInCurrentYear(nowUtc);
      eventQuery = _objectBox.store
          .box<EventEntity>()
          .query(
            EventEntity_.name
                .contains(text, caseSensitive: false)
                .and(currentYearCondition),
          )
          .build();
      eventCategoryQuery = _objectBox.store
          .box<EventEntity>()
          .query(
            EventEntity_.contentCategoryIndex
                .oneOf(_getCategoryIndexes(text))
                .and(currentYearCondition),
          )
          .build();
      _cityQuery.param(CityEntity_.name).value = text;
      final categories = eventCategoryQuery.find();
      final cities = _cityQuery.find();
      final matches = eventQuery.find();
      final currentYear = _eventTimePolicy.currentCalendarDate(nowUtc).year;
      final currentYearStart = _eventTimePolicy
          .utcRangeForCalendarDate(EventCalendarDate(currentYear, 1, 1))
          .startUtc;
      final currentYearEnd = _eventTimePolicy
          .utcRangeForCalendarDate(EventCalendarDate(currentYear, 12, 31))
          .endUtc;
      for (final city in cities) {
        matches.addAll(
          city.events.where(
            (event) => _isVisibleEventInCurrentYear(
              event,
              currentYearStart,
              currentYearEnd,
            ),
          ),
        );
      }
      matches.addAll(categories);
      final seen = <int>{};
      return Result.success(
        matches
            .where((event) => seen.add(event.remoteId))
            .map((event) => event.toModel())
            .toList(),
      );
    } on Exception catch (exception, stackTrace) {
      _logger.log(
        const EntityLoadFailed('search', method: 'getResultsByQuery'),
        error: exception,
        stackTrace: stackTrace,
      );
      return Result.error(exception);
    } finally {
      eventQuery?.close();
      eventCategoryQuery?.close();
    }
  }

  @override
  Future<Result<List<String>>> getPastSearches() async {
    try {
      final history = await _searchHistoryBox.getAllAsync();

      return Result.success(
        history.map<String>((element) => element.name).toList(),
      );
    } on Exception catch (exception, stackTrace) {
      _logger.log(
        const EntityLoadFailed('search', method: 'getPastSearches'),
        error: exception,
        stackTrace: stackTrace,
      );

      return Result.error(exception);
    }
  }

  @override
  Future<Result<void>> removeFromPastSearches(String text) async {
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
    } on Exception catch (exception, stackTrace) {
      _logger.log(
        const EntityRemoveFailed('search'),
        error: exception,
        stackTrace: stackTrace,
      );
      return Result.error(exception);
    }
  }

  List<int> _getCategoryIndexes(String query) {
    final matchingTypes = ContentCategory.values.where(
      (type) => type.label.toLowerCase().contains(query.toLowerCase()),
    );

    final typeIndexes = matchingTypes.map((type) => type.index).toList();

    return typeIndexes;
  }

  /// Whether [event] is visible ([EventEntity.isDeleted] is `false`) and
  /// overlaps the inclusive year range bounded by [startOfYear] and
  /// [endOfYear].
  ///
  /// Multi-day events (non-null [EventEntity.endDate]) overlap when they start
  /// on or before [endOfYear] and end on or after [startOfYear]. Single-day
  /// events (null [EventEntity.endDate]) are matched when their
  /// [EventEntity.startDate] falls within the same range.
  bool _isVisibleEventInCurrentYear(
    EventEntity event,
    DateTime startOfYear,
    DateTime endOfYear,
  ) {
    if (event.isDeleted) return false;

    final startDate = event.startDate;
    final endDate = event.endDate;

    if (endDate == null) {
      return startDate != null &&
          !startDate.isBefore(startOfYear) &&
          !startDate.isAfter(endOfYear);
    }

    return startDate != null &&
        !startDate.isAfter(endOfYear) &&
        !endDate.isBefore(startOfYear);
  }
}
