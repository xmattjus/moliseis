import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:moliseis/data/services/api/weather/cached_weather_api_client.dart';
import 'package:moliseis/data/services/api/weather/model/current_forecast/current_weather_forecast_data.dart';
import 'package:moliseis/data/services/api/weather/model/daily_forecast/daily_weather_forecast_data.dart';
import 'package:moliseis/data/services/api/weather/model/hourly_forecast/hourly_weather_forecast_data.dart';
import 'package:moliseis/data/services/api/weather/model/weather_forecast_data_cache_entry.dart';
import 'package:moliseis/domain/models/event.dart';
import 'package:moliseis/domain/models/place.dart';
import 'package:moliseis/domain/use-cases/favourite_get_ids_use_case.dart';
import 'package:moliseis/domain/use-cases/post_use_case.dart';
import 'package:moliseis/ui/event/widgets/components/event_formatted_date_time.dart';
import 'package:moliseis/ui/favourite/view_models/favourite_view_model.dart';
import 'package:moliseis/ui/post/view_models/post_view_model.dart';
import 'package:moliseis/ui/post/widgets/post_screen.dart';
import 'package:moliseis/ui/weather/view_models/weather_view_model.dart';
import 'package:moliseis/ui/weather/wmo_weather_description_mapper.dart';
import 'package:moliseis/ui/weather/wmo_weather_icon_mapper.dart';
import 'package:moliseis/utils/lru_cache.dart';
import 'package:moliseis/utils/result.dart';
import 'package:provider/provider.dart';

import '../../../support/fake_repositories.dart';
import '../../../support/fixtures.dart';
import '../../../support/mock_logger.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('it');
  });

  group('PostScreen', () {
    late MockLogger mockLogger;

    setUp(() {
      mockLogger = MockLogger();
    });

    testWidgets('renders EventFormattedDateTime for event content', (
      tester,
    ) async {
      final event = _buildEvent();
      final place = _buildPlace();
      final viewModel = _buildPostViewModel(event: event, place: place);
      final weatherViewModel = _buildWeatherViewModel(mockLogger);
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
      tester,
    ) async {
      final event = _buildEvent();
      final place = _buildPlace();
      final viewModel = _buildPostViewModel(event: event, place: place);
      final weatherViewModel = _buildWeatherViewModel(mockLogger);
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

    testWidgets('PopScope allows back navigation by default', (tester) async {
      final event = _buildEvent();
      final place = _buildPlace();
      final viewModel = _buildPostViewModel(event: event, place: place);
      final weatherViewModel = _buildWeatherViewModel(mockLogger);
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

      expect(
        find.descendant(
          of: find.byType(PostScreen),
          matching: find.byKey(const ValueKey('galleryPopScopeVlb')),
        ),
        findsOneWidget,
      );

      final popScope = find.byKey(const ValueKey('galleryPopScope'));
      expect(popScope, findsOneWidget);
      expect(tester.widget<PopScope>(popScope).canPop, isTrue);
    });

    testWidgets('canPop changes when gallery open/close state changes', (
      tester,
    ) async {
      final event = _buildEvent();
      final place = _buildPlace();
      final viewModel = _buildPostViewModel(event: event, place: place);
      final weatherViewModel = _buildWeatherViewModel(mockLogger);
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

      // Access the notifier through the public ValueListenableBuilder API.
      // The isGalleryOpenNotifier field controls PopScope reactivity.
      final vlb = tester.widget<ValueListenableBuilder<bool>>(
        find.byKey(const ValueKey('galleryPopScopeVlb')),
      );
      final notifier = vlb.valueListenable as ValueNotifier<bool>;

      expect(notifier.value, isFalse);

      final popScope = find.byKey(const ValueKey('galleryPopScope'));
      expect(tester.widget<PopScope>(popScope).canPop, isTrue);

      notifier.value = true;
      await tester.pump();
      expect(tester.widget<PopScope>(popScope).canPop, isFalse);

      notifier.value = false;
      await tester.pump();
      expect(tester.widget<PopScope>(popScope).canPop, isTrue);
    });

    testWidgets('deactivate handles open gallery without crashing', (
      tester,
    ) async {
      final event = _buildEvent();
      final place = _buildPlace();
      final viewModel = _buildPostViewModel(event: event, place: place);
      final weatherViewModel = _buildWeatherViewModel(mockLogger);
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

      final vlb = tester.widget<ValueListenableBuilder<bool>>(
        find.byKey(const ValueKey('galleryPopScopeVlb')),
      );
      final notifier = vlb.valueListenable as ValueNotifier<bool>;

      // Test readability benefits from separate statements over cascades.
      // ignore: cascade_invocations
      notifier.value = true;
      // pumpAndSettle() ensures the canPop:false rebuild completes fully
      // before the widget tree is replaced. Without this, deactivate() fires
      // while the rebuild pipeline is still active, causing a "setState called
      // during rebuild" error in the test environment.
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        _buildTestApp(const SizedBox.shrink(), favouriteViewModel),
      );
      // pumpAndSettle() lets the maybePop() call from deactivate() complete.
      await tester.pumpAndSettle();
      // The notifier belongs to the now-deactivated State; its value (true)
      // is irrelevant — deactivate() correctly called maybePop() and did not
      // crash. Test passes if no exception is thrown.
    });

    testWidgets('PopScope blocks back navigation when gallery is open', (
      tester,
    ) async {
      final event = _buildEvent();
      final place = _buildPlace();
      final viewModel = _buildPostViewModel(event: event, place: place);
      final weatherViewModel = _buildWeatherViewModel(mockLogger);
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

      final vlb = tester.widget<ValueListenableBuilder<bool>>(
        find.byKey(const ValueKey('galleryPopScopeVlb')),
      );
      final notifier = vlb.valueListenable as ValueNotifier<bool>;

      // Verify default state: canPop is true, onPopInvokedWithResult is wired.
      final popScope = find.byKey(const ValueKey('galleryPopScope'));
      expect(tester.widget<PopScope>(popScope).canPop, isTrue);
      expect(
        tester.widget<PopScope>(popScope).onPopInvokedWithResult,
        isNotNull,
      );

      // Simulate gallery opening: canPop should become false.
      notifier.value = true;
      await tester.pump();

      expect(tester.widget<PopScope>(popScope).canPop, isFalse);

      // PopScope and PostScreen are still in tree — back navigation is
      // suppressed when the gallery is open.
      expect(find.byKey(const ValueKey('galleryPopScope')), findsOneWidget);
      expect(find.byType(PostScreen), findsOneWidget);
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
      eventRepository: FakeEventRepository(
        getByIdResults: {event.remoteId: Result.success(event)},
      ),
      placeRepository: FakePlaceRepository(
        getByIdResults: {place.remoteId: Result.success(place)},
      ),
    ),
  );
}

PostViewModel _buildPostViewModel({
  required Event event,
  required Place place,
}) {
  return PostViewModel(
    postUseCase: PostUseCase(
      eventRepository: FakeEventRepository(
        getByIdResults: {event.remoteId: Result.success(event)},
      ),
      placeRepository: FakePlaceRepository(
        getByIdResults: {place.remoteId: Result.success(place)},
      ),
    ),
  );
}

WeatherViewModel _buildWeatherViewModel(MockLogger mockLogger) {
  final weatherApiClient = CachedWeatherApiClient(
    weatherApiClient: FakeWeatherApiClient(),
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
    logger: mockLogger,
  );

  return WeatherViewModel(
    weatherApiClient: weatherApiClient,
    weatherDescriptionMapper: const WmoWeatherDescriptionMapper(),
    weatherCodeIconMapper: const WmoWeatherIconMapper(),
  );
}

Event _buildEvent() => makeEvent(
  startDate: DateTime(2026, 4, 10, 10, 30),
  endDate: DateTime(2026, 4, 10, 12),
);

Place _buildPlace() => makePlace(remoteId: 2);
