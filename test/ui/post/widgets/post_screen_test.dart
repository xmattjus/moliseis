// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:intl/date_symbol_data_local.dart';
import 'package:moliseis/data/services/api/weather/cached_weather_api_client.dart';
import 'package:moliseis/data/services/api/weather/model/combined_weather_forecast_response.dart';
import 'package:moliseis/data/services/api/weather/model/current_forecast/current_weather_forecast_data.dart';
import 'package:moliseis/data/services/api/weather/model/daily_forecast/daily_weather_forecast_data.dart';
import 'package:moliseis/data/services/api/weather/model/hourly_forecast/hourly_weather_forecast_data.dart';
import 'package:moliseis/data/services/api/weather/model/weather_forecast_data_cache_entry.dart';
import 'package:moliseis/data/services/api/weather/weather_api_client.dart';
import 'package:moliseis/data/sources/city.dart';
import 'package:moliseis/data/sources/event.dart';
import 'package:moliseis/data/sources/media.dart';
import 'package:moliseis/data/sources/place.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/content_sort.dart';
import 'package:moliseis/domain/repositories/event_repository.dart';
import 'package:moliseis/domain/repositories/place_repository.dart';
import 'package:moliseis/domain/use-cases/favourite/favourite_get_ids_use_case.dart';
import 'package:moliseis/domain/use-cases/post/post_use_case.dart';
import 'package:moliseis/ui/event/widgets/components/event_formatted_date_time.dart';
import 'package:moliseis/ui/favourite/view_models/favourite_view_model.dart';
import 'package:moliseis/ui/post/view_models/post_view_model.dart';
import 'package:moliseis/ui/post/widgets/post_screen.dart';
import 'package:moliseis/ui/weather/view_models/weather_view_model.dart';
import 'package:moliseis/ui/weather/wmo_weather_description_mapper.dart';
import 'package:moliseis/ui/weather/wmo_weather_icon_mapper.dart';
import 'package:moliseis/utils/lru_cache.dart';
import 'package:moliseis/utils/result.dart';
import 'package:objectbox/objectbox.dart';
import 'package:provider/provider.dart';
import 'package:talker_flutter/talker_flutter.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('it');
  });

  group('PostScreen', () {
    testWidgets('renders EventFormattedDateTime for event content', (
      WidgetTester tester,
    ) async {
      final event = _buildEvent();
      final place = _buildPlace();
      final viewModel = _buildPostViewModel(event: event, place: place);
      final weatherViewModel = _buildWeatherViewModel();
      final favouriteViewModel = _buildFavouriteViewModel(
        event: event,
        place: place,
      );

      await viewModel.loadEvent.execute(event.remoteId);

      await tester.pumpWidget(
        _buildTestApp(
          PostScreen(
            isEvent: true,
            viewModel: viewModel,
            weatherViewModel: weatherViewModel,
          ),
          favouriteViewModel,
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(PostScreen), findsOneWidget);
      expect(find.byType(EventFormattedDateTime), findsOneWidget);
    });

    testWidgets('does not render EventFormattedDateTime for place content', (
      WidgetTester tester,
    ) async {
      final event = _buildEvent();
      final place = _buildPlace();
      final viewModel = _buildPostViewModel(event: event, place: place);
      final weatherViewModel = _buildWeatherViewModel();
      final favouriteViewModel = _buildFavouriteViewModel(
        event: event,
        place: place,
      );

      await viewModel.loadPlace.execute(place.remoteId);

      await tester.pumpWidget(
        _buildTestApp(
          PostScreen(
            isEvent: false,
            viewModel: viewModel,
            weatherViewModel: weatherViewModel,
          ),
          favouriteViewModel,
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(PostScreen), findsOneWidget);
      expect(find.byType(EventFormattedDateTime), findsNothing);
    });
  });
}

Widget _buildTestApp(Widget child, FavouriteViewModel favouriteViewModel) {
  final router = GoRouter(
    initialLocation: '/',
    routes: <RouteBase>[GoRoute(path: '/', builder: (_, _) => child)],
  );

  return ChangeNotifierProvider<FavouriteViewModel>.value(
    value: favouriteViewModel,
    child: MaterialApp.router(routerConfig: router),
  );
}

FavouriteViewModel _buildFavouriteViewModel({
  required Event event,
  required Place place,
}) {
  return FavouriteViewModel(
    favouriteGetIdsUseCase: FavouriteGetIdsUseCase(
      eventRepository: _FakeEventRepository(event: event),
      placeRepository: _FakePlaceRepository(place: place),
    ),
  );
}

PostViewModel _buildPostViewModel({
  required Event event,
  required Place place,
}) {
  return PostViewModel(
    postUseCase: PostUseCase(
      eventRepository: _FakeEventRepository(event: event),
      placeRepository: _FakePlaceRepository(place: place),
    ),
  );
}

WeatherViewModel _buildWeatherViewModel() {
  final weatherApiClient = CachedWeatherApiClient(
    weatherApiClient: _FakeWeatherApiClient(),
    currentWeatherCache:
        LruCache<
          String,
          WeatherForecastDataCacheEntry<CurrentWeatherForecastData>
        >(maxSize: 8),
    hourlyWeatherCache:
        LruCache<
          String,
          WeatherForecastDataCacheEntry<HourlyWeatherForecastData>
        >(maxSize: 8),
    dailyWeatherCache:
        LruCache<
          String,
          WeatherForecastDataCacheEntry<DailyWeatherForecastData>
        >(maxSize: 8),
  );

  return WeatherViewModel(
    weatherApiClient: weatherApiClient,
    weatherDescriptionMapper: const WmoWeatherDescriptionMapper(),
    weatherCodeIconMapper: const WmoWeatherIconMapper(),
  );
}

final class _FakeWeatherApiClient extends WeatherApiClient {
  _FakeWeatherApiClient() : super(logger: Talker(), httpClient: http.Client());

  @override
  Future<Result<CombinedWeatherForecastResponse>> getCombinedWeatherForecast(
    double latitude,
    double longitude, {
    String timezone = 'Europe/Rome',
  }) async {
    return Result.error(Exception('Not needed in this test.'));
  }
}

final class _FakeEventRepository implements EventRepository {
  _FakeEventRepository({required this.event});

  final Event event;

  @override
  Future<Result<Event>> getById(int id) async => Result.success(event);

  @override
  Future<Result<List<Event>>> getByCoordinates(List<double> coordinates) async {
    return const Result.success(<Event>[]);
  }

  @override
  Future<Result<List<Event>>> getByCurrentYear() async {
    return const Result.success(<Event>[]);
  }

  @override
  Future<Result<List<Event>>> getByDate(DateTime date) async {
    return const Result.success(<Event>[]);
  }

  @override
  Future<Result<List<Event>>> getByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    return const Result.success(<Event>[]);
  }

  @override
  Future<Result<List<Event>>> getByCategories(
    Set<ContentCategory> categories, {
    ContentSort sort = ContentSort.byName,
  }) async {
    return const Result.success(<Event>[]);
  }

  @override
  Future<Result<List<int>>> getFavouriteEventIds() async {
    return const Result.success(<int>[]);
  }

  @override
  Future<Result<List<int>>> getNextEventIds() async {
    return const Result.success(<int>[]);
  }

  @override
  Future<Result<void>> setFavouriteEvent(int id, bool save) async {
    return const Result.success(null);
  }

  @override
  Future<Result<void>> synchronize() async {
    return const Result.success(null);
  }
}

final class _FakePlaceRepository implements PlaceRepository {
  _FakePlaceRepository({required this.place});

  final Place place;

  @override
  Future<Result<Place>> getById(int id) async => Result.success(place);

  @override
  Future<Result<List<Place>>> getAll({
    ContentSort sort = ContentSort.byName,
  }) async {
    return const Result.success(<Place>[]);
  }

  @override
  Future<Result<List<Place>>> getByCategories(
    Set<ContentCategory> categories, {
    ContentSort sort = ContentSort.byName,
  }) async {
    return const Result.success(<Place>[]);
  }

  @override
  Future<Result<List<Place>>> getByCoordinates(List<double> coordinates) async {
    return const Result.success(<Place>[]);
  }

  @override
  Future<Result<List<int>>> getFavouritePlaceIds() async {
    return const Result.success(<int>[]);
  }

  @override
  Future<Result<List<int>>> getIdsByCoordinates(
    List<double> coordinates,
  ) async {
    return const Result.success(<int>[]);
  }

  @override
  Future<Result<List<int>>> getLatestPlaceIds() async {
    return const Result.success(<int>[]);
  }

  @override
  Future<Result<List<int>>> getSuggestedPlaceIds() async {
    return const Result.success(<int>[]);
  }

  @override
  Future<Result<void>> setFavouritePlace(int id, bool save) async {
    return const Result.success(null);
  }

  @override
  Future<Result<void>> synchronize() async {
    return const Result.success(null);
  }
}

Event _buildEvent() {
  final city = ToOne<City>();
  city.target = _buildCity();

  final media = ToMany<Media>();
  media.add(_buildMedia());

  return Event(
    remoteId: 1,
    name: 'Evento demo',
    description: 'Descrizione evento',
    startDate: DateTime(2026, 4, 10, 10, 30),
    endDate: DateTime(2026, 4, 10, 12, 0),
    coordinates: const <double>[41.56, 14.66],
    category: ContentCategory.experience,
    createdAt: DateTime(2026, 1, 1),
    modifiedAt: DateTime(2026, 1, 1),
    city: city,
    media: media,
  );
}

Place _buildPlace() {
  final city = ToOne<City>();
  city.target = _buildCity();

  final media = ToMany<Media>();
  media.add(_buildMedia());

  return Place(
    remoteId: 2,
    name: 'Luogo demo',
    description: 'Descrizione luogo',
    coordinates: const <double>[41.57, 14.67],
    category: ContentCategory.nature,
    createdAt: DateTime(2026, 1, 1),
    modifiedAt: DateTime(2026, 1, 1),
    city: city,
    media: media,
  );
}

City _buildCity() {
  return City(
    remoteId: 10,
    name: 'Campobasso',
    createdAt: DateTime(2026, 1, 1),
    modifiedAt: DateTime(2026, 1, 1),
    places: ToMany<Place>(),
    events: ToMany<Event>(),
  );
}

Media _buildMedia() {
  return Media(
    remoteId: 20,
    title: 'Media demo',
    url: 'https://example.com/demo.jpg',
    width: 1080,
    height: 720,
    createdAt: DateTime(2026, 1, 1),
    modifiedAt: DateTime(2026, 1, 1),
    place: ToOne<Place>(),
    event: ToOne<Event>(),
  );
}
