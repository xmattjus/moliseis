import 'dart:async' show Completer, unawaited;

import 'package:cached_network_image_ce/cached_network_image.dart'
    show CacheManager;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/config/dependencies.dart';
import 'package:moliseis/data/services/api/weather/cached_weather_api_client.dart';
import 'package:moliseis/data/services/api/weather/model/combined_weather_forecast_response.dart';
import 'package:moliseis/data/services/api/weather/model/current_forecast/current_weather_forecast_data.dart';
import 'package:moliseis/data/services/api/weather/model/daily_forecast/daily_weather_forecast_data.dart';
import 'package:moliseis/data/services/api/weather/model/hourly_forecast/hourly_weather_forecast_data.dart';
import 'package:moliseis/data/services/api/weather/model/weather_forecast_data_cache_entry.dart';
import 'package:moliseis/data/services/url_launch_service.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/domain/models/content_type.dart';
import 'package:moliseis/domain/models/event.dart';
import 'package:moliseis/domain/models/media.dart';
import 'package:moliseis/domain/models/place.dart';
import 'package:moliseis/domain/repositories/event_repository.dart';
import 'package:moliseis/domain/repositories/place_repository.dart';
import 'package:moliseis/domain/repositories/search_repository.dart';
import 'package:moliseis/domain/repositories/settings_repository.dart';
import 'package:moliseis/domain/use-cases/favourite_get_ids_use_case.dart';
import 'package:moliseis/domain/use-cases/sync_use_case.dart';
import 'package:moliseis/routing/route_names.dart';
import 'package:moliseis/routing/route_paths.dart';
import 'package:moliseis/routing/router.dart';
import 'package:moliseis/ui/core/ui/app_navigation_rail.dart';
import 'package:moliseis/ui/core/ui/responsive_navigation_bar.dart';
import 'package:moliseis/ui/core/ui/route_error_screen.dart';
import 'package:moliseis/ui/core/ui/scaffold_shell.dart';
import 'package:moliseis/ui/favourite/view_models/favourite_view_model.dart';
import 'package:moliseis/ui/gallery/models/gallery_preview_route_data.dart';
import 'package:moliseis/ui/gallery/widgets/gallery_preview_screen.dart';
import 'package:moliseis/ui/geo_map/widgets/geo_map_bottom_sheet.dart';
import 'package:moliseis/ui/geo_map/widgets/geo_map_modal_post.dart';
import 'package:moliseis/ui/geo_map/widgets/geo_map_screen.dart';
import 'package:moliseis/ui/post/widgets/post_screen.dart';
import 'package:moliseis/ui/settings/view_models/settings_view_model.dart';
import 'package:moliseis/ui/settings/view_models/theme_view_model.dart';
import 'package:moliseis/ui/sync/view_models/sync_view_model.dart';
import 'package:moliseis/utils/logging/logging.dart';
import 'package:moliseis/utils/lru_cache.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/sentry_logging_flag.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../support/fake_cache_manager.dart';
import '../support/fake_repositories.dart';
import '../support/fixtures.dart';
import '../support/mock_gotrue_client.dart';
import '../support/mock_logger.dart';
import '../support/recording_tile_http_client.dart';

void main() {
  testWidgets(
    'NAV-01 [upstream #188018] inactive Post branch must not consume '
    'Map root Back',
    (tester) async {
      final event = makeEvent();
      final harness = _MapHarness();
      final router = _buildTestRouterApp(
        harness,
        eventRepository: FakeEventRepository(
          getByIdResults: <int, Result<Event>>{1: Result.success(event)},
        ),
      );
      addTearDown(router.router.dispose);

      await tester.pumpWidget(router.app);
      router.router.go('/home/posts/1?type=event');
      await tester.pumpAndSettle();
      final postFinder = find.byType(PostScreen, skipOffstage: false);
      final postState = tester.state(postFinder);
      final postNavigator = Navigator.of(tester.element(postFinder));
      expect(postNavigator.widget.pages.length, 2);

      router.router.go(RoutePaths.geoMap);
      await tester.pumpAndSettle();
      final mapContext = tester.element(find.byType(GeoMapScreen));
      expect(StatefulNavigationShell.of(mapContext).currentIndex, 3);
      expect(Navigator.of(mapContext).widget.pages.length, 1);
      expect(postState.mounted, isTrue);
      expect(tester.state(postFinder), same(postState));

      // A root branch has no previous page: the Back event must bubble out.
      expect(await tester.binding.handlePopRoute(), isFalse);
      await tester.pumpAndSettle();
      expect(
        router.router.routeInformationProvider.value.uri.path,
        RoutePaths.geoMap,
      );
      expect(postNavigator.widget.pages.length, 2);
      expect(tester.state(postFinder), same(postState));
    },
    // go_router 18.0.1 consumes Map-root Back with an inactive stacked branch.
    // https://github.com/flutter/flutter/issues/188018
    // https://github.com/flutter/packages/pull/11910
    // Both are open. Unskip after a released fix makes handlePopRoute false
    // while preserving the inactive Post State and stack.
    skip: true,
  );

  for (final size in <Size>[const Size(390, 844), const Size(1300, 900)]) {
    testWidgets('NAV-02 Map shell chrome stays stable under Gallery at $size', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final harness = _MapHarness();
      final router = _buildTestRouterApp(harness);
      addTearDown(router.router.dispose);

      await tester.pumpWidget(router.app);
      router.router.go(RoutePaths.geoMap);
      await tester.pumpAndSettle();
      final shellFinder = find.byType(ScaffoldShell, skipOffstage: false);
      final mapFinder = find.byType(GeoMapScreen, skipOffstage: false);
      final chromeFinder = find.byType(
        size.width == 390 ? ResponsiveNavigationBar : AppNavigationRail,
        skipOffstage: false,
      );
      final mapState = tester.state(mapFinder);
      final mapViewModel = tester.widget<GeoMapScreen>(mapFinder).viewModel;
      expect(tester.widget<ScaffoldShell>(shellFinder).showNavigation, isTrue);
      expect(chromeFinder, findsOneWidget);

      final media = Media(
        remoteId: 1,
        url: 'https://example.com/gallery.jpg',
        width: 800,
        height: 600,
        createdAt: DateTime.utc(2026),
        modifiedAt: DateTime.utc(2026),
        areaName: 'Molise',
        cityName: 'Campobasso',
      );
      unawaited(
        router.router.pushNamed<void>(
          RouteNames.gallery,
          extra: GalleryPreviewRouteData(
            media: <Media>[media],
            initialIndex: 0,
          ).toExtra(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(GalleryPreviewScreen), findsOneWidget);
      expect(tester.widget<ScaffoldShell>(shellFinder).showNavigation, isTrue);
      expect(chromeFinder, findsOneWidget);
      expect(tester.state(mapFinder), same(mapState));
      expect(
        tester.widget<GeoMapScreen>(mapFinder).viewModel,
        same(mapViewModel),
      );

      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(find.byType(GalleryPreviewScreen), findsNothing);
      expect(tester.widget<ScaffoldShell>(shellFinder).showNavigation, isTrue);
      expect(chromeFinder, findsOneWidget);
      expect(tester.state(mapFinder), same(mapState));
      expect(
        tester.widget<GeoMapScreen>(mapFinder).viewModel,
        same(mapViewModel),
      );
    });
  }

  testWidgets('NAV-02 Explore detail chrome stays hidden under Gallery', (
    tester,
  ) async {
    final harness = _MapHarness();
    final router = _buildTestRouterApp(
      harness,
      eventRepository: FakeEventRepository(
        getByIdResults: <int, Result<Event>>{1: Result.success(makeEvent())},
      ),
    );
    addTearDown(router.router.dispose);
    await tester.pumpWidget(router.app);

    final media = Media(
      remoteId: 1,
      url: 'https://example.com/gallery.jpg',
      width: 800,
      height: 600,
      createdAt: DateTime.utc(2026),
      modifiedAt: DateTime.utc(2026),
      areaName: 'Molise',
      cityName: 'Campobasso',
    );
    final shellFinder = find.byType(ScaffoldShell, skipOffstage: false);
    for (final location in <String>[
      '/home/search_results?q=molise',
      '/home/category/nature',
      '/home/posts/1?type=event',
    ]) {
      router.router.go(location);
      await tester.pumpAndSettle();
      expect(tester.widget<ScaffoldShell>(shellFinder).showNavigation, isFalse);

      unawaited(
        router.router.pushNamed<void>(
          RouteNames.gallery,
          extra: GalleryPreviewRouteData(
            media: <Media>[media],
            initialIndex: 0,
          ).toExtra(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(GalleryPreviewScreen), findsOneWidget);
      expect(tester.widget<ScaffoldShell>(shellFinder).showNavigation, isFalse);
      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(tester.widget<ScaffoldShell>(shellFinder).showNavigation, isFalse);
    }
  });

  group('buildAppRouter geoMap selection', () {
    testWidgets(
      'NAV-06 each selected content owns its pending weather request',
      (tester) async {
        const firstCoordinates = LatLng(41.56, 14.66);
        const secondCoordinates = LatLng(41.57, 14.67);
        final events = FakeEventRepository(
          getByIdResults: {
            1: Result.success(makeEvent()),
            2: Result.success(
              makeEvent(remoteId: 2, coordinates: secondCoordinates),
            ),
          },
        );
        final weather = FakeWeatherApiClient();
        final pending = Completer<Result<CombinedWeatherForecastResponse>>();
        weather.pendingCombinedForecast = pending;
        final router = _buildTestRouterApp(
          _MapHarness(),
          eventRepository: events,
          weatherApiClient: weather,
        );
        addTearDown(router.router.dispose);
        await tester.pumpWidget(router.app);
        await tester.pumpAndSettle();

        router.router.go('/map?contentId=1&type=event');
        await tester.pump();
        await tester.pump();
        final firstWeather = tester
            .widget<GeoMapScreen>(find.byType(GeoMapScreen))
            .weatherViewModel;
        expect(weather.combinedForecastCoordinates, [
          (firstCoordinates.latitude, firstCoordinates.longitude),
        ]);
        weather.pendingCombinedForecast = null;
        router.router.go('/map?contentId=2&type=event');
        await tester.pump();
        await tester.pump();
        final secondWeather = tester
            .widget<GeoMapScreen>(find.byType(GeoMapScreen))
            .weatherViewModel;
        expect(secondWeather, isNot(same(firstWeather)));
        expect(() => firstWeather.addListener(() {}), throwsFlutterError);
        expect(weather.getCombinedWeatherForecastCallCount, 2);
        expect(weather.combinedForecastCoordinates.last, (
          secondCoordinates.latitude,
          secondCoordinates.longitude,
        ));

        pending.complete(Result.error(TestException('weather unavailable')));
        await tester.pump();
        await tester.pump();
        expect(secondWeather.currentTemperatureCelsius, '--.-');
        expect(weather.getCombinedWeatherForecastCallCount, 2);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );

    for (final type in <String>['event', 'place']) {
      for (final firstFails in <bool>[false, true]) {
        testWidgets('NAV-06 rapid $type A to B resolves B when A '
            '${firstFails ? 'fails' : 'succeeds'}', (tester) async {
          final events = FakeEventRepository();
          final places = FakePlaceRepository();
          final firstEvent = Completer<Result<Event>>();
          final secondEvent = Completer<Result<Event>>();
          final firstPlace = Completer<Result<Place>>();
          final secondPlace = Completer<Result<Place>>();
          if (type == 'event') {
            events.pendingGetById[1] = firstEvent;
            events.pendingGetById[2] = secondEvent;
          } else {
            places.pendingGetById[1] = firstPlace;
            places.pendingGetById[2] = secondPlace;
          }
          final router = _buildTestRouterApp(
            _MapHarness(),
            eventRepository: events,
            placeRepository: places,
          );
          addTearDown(router.router.dispose);
          await tester.pumpWidget(router.app);
          await tester.pumpAndSettle();
          router.router.go('/map?contentId=1&type=$type');
          await tester.pump();
          final map = tester.widget<GeoMapScreen>(find.byType(GeoMapScreen));
          router.router.go('/map?contentId=2&type=$type');
          await tester.pump();
          expect(
            tester.widget<GeoMapScreen>(find.byType(GeoMapScreen)).viewModel,
            same(map.viewModel),
          );

          if (type == 'event') {
            firstEvent.complete(
              firstFails
                  ? Result.error(TestException('A unavailable'))
                  : Result.success(makeEvent()),
            );
          } else {
            firstPlace.complete(
              firstFails
                  ? Result.error(TestException('A unavailable'))
                  : Result.success(makePlace()),
            );
          }
          await tester.pump();
          await tester.pump();
          expect(find.byType(GeoMapModalPost), findsNothing);
          if (type == 'event') {
            secondEvent.complete(Result.success(makeEvent(remoteId: 2)));
          } else {
            secondPlace.complete(Result.success(makePlace(remoteId: 2)));
          }
          await tester.pump();
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<GeoMapModalPost>(find.byType(GeoMapModalPost))
                .content
                .remoteId,
            2,
          );
          expect(map.viewModel.selectedContent?.remoteId, 2);
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('NAV-06 a late event cannot replace a newer place selection', (
      tester,
    ) async {
      final events = FakeEventRepository();
      final places = FakePlaceRepository();
      final pendingEvent = Completer<Result<Event>>();
      final pendingPlace = Completer<Result<Place>>();
      events.pendingGetById[1] = pendingEvent;
      places.pendingGetById[2] = pendingPlace;
      final router = _buildTestRouterApp(
        _MapHarness(),
        eventRepository: events,
        placeRepository: places,
      );
      addTearDown(router.router.dispose);
      await tester.pumpWidget(router.app);
      await tester.pumpAndSettle();
      router.router.go('/map?contentId=1&type=event');
      await tester.pump();
      final map = tester.widget<GeoMapScreen>(find.byType(GeoMapScreen));
      expect(map.viewModel.showEvent.running, isTrue);

      router.router.go('/map?contentId=2&type=place');
      await tester.pump();
      expect(map.viewModel.showPlace.running, isTrue);
      pendingPlace.complete(Result.success(makePlace(remoteId: 2)));
      await tester.pump();
      await tester.pump();
      expect(
        tester
            .widget<GeoMapModalPost>(find.byType(GeoMapModalPost))
            .content
            .remoteId,
        2,
      );

      pendingEvent.complete(Result.success(makeEvent()));
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<GeoMapModalPost>(find.byType(GeoMapModalPost))
            .content
            .remoteId,
        2,
      );
      expect(map.viewModel.selectedContent?.remoteId, 2);
      expect(tester.takeException(), isNull);
    });

    testWidgets('NAV-06 map root invalidates an in-flight selection', (
      tester,
    ) async {
      final events = FakeEventRepository();
      final pendingEvent = Completer<Result<Event>>();
      events.pendingGetById[1] = pendingEvent;
      final router = _buildTestRouterApp(
        _MapHarness(),
        eventRepository: events,
      );
      addTearDown(router.router.dispose);
      await tester.pumpWidget(router.app);
      await tester.pumpAndSettle();
      router.router.go('/map?contentId=1&type=event');
      await tester.pump();
      final map = tester.widget<GeoMapScreen>(find.byType(GeoMapScreen));
      router.router.go(RoutePaths.geoMap);
      await tester.pump();
      pendingEvent.complete(Result.success(makeEvent()));
      await tester.pump();
      await tester.pump();
      expect(find.byType(GeoMapModalPost), findsNothing);
      expect(map.viewModel.selectedContent, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'NAV-06 route destruction disposes owned VMs with loads pending',
      (tester) async {
        final events = FakeEventRepository();
        final places = FakePlaceRepository();
        final searches = FakeSearchRepository();
        final router = _buildTestRouterApp(
          _MapHarness(),
          eventRepository: events,
          placeRepository: places,
          searchRepository: searches,
        );
        addTearDown(router.router.dispose);
        await tester.pumpWidget(router.app);
        await tester.pumpAndSettle();

        final pendingEvents = Completer<Result<List<Event>>>();
        final pendingPlaces = Completer<Result<List<Place>>>();
        final pendingSearches = Completer<Result<List<String>>>();
        events.pendingGetByCurrentYear = pendingEvents;
        places.pendingGetAll = pendingPlaces;
        searches.pendingGetPastSearches = pendingSearches;
        router.router.go(RoutePaths.geoMap);
        await tester.pump();

        final map = tester.widget<GeoMapScreen>(find.byType(GeoMapScreen));
        expect(map.viewModel.loadEvents.running, isTrue);
        expect(map.viewModel.loadPlaces.running, isTrue);
        expect(map.searchViewModel.loadPastSearches.running, isTrue);
        await tester.pumpWidget(const SizedBox.shrink());
        expect(() => map.viewModel.addListener(() {}), throwsFlutterError);
        expect(
          () => map.searchViewModel.addListener(() {}),
          throwsFlutterError,
        );
        expect(
          () => map.weatherViewModel.addListener(() {}),
          throwsFlutterError,
        );

        pendingEvents.complete(Result.success(<Event>[makeEvent()]));
        pendingPlaces.complete(Result.success(<Place>[makePlace()]));
        pendingSearches.complete(const Result.success(<String>['molise']));
        await tester.pump();
        await tester.pump();
        expect(map.viewModel.allEvents, isEmpty);
        expect(map.viewModel.allPlaces, isEmpty);
        expect(map.searchViewModel.pastSearches, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'NAV-06 Map retains GeoMap/Search VMs and replaces content Weather VM',
      (tester) async {
        final events = FakeEventRepository(
          getByIdResults: <int, Result<Event>>{
            1: Result.success(makeEvent()),
            2: Result.success(makeEvent(remoteId: 2)),
          },
        );
        final places = FakePlaceRepository(
          getByIdResults: <int, Result<Place>>{1: Result.success(makePlace())},
        );
        final searches = FakeSearchRepository();
        final weather = FakeWeatherApiClient();
        final router = _buildTestRouterApp(
          _MapHarness(),
          eventRepository: events,
          placeRepository: places,
          searchRepository: searches,
          weatherApiClient: weather,
        );
        addTearDown(router.router.dispose);
        await tester.pumpWidget(router.app);
        await tester.pumpAndSettle();
        final beforeMapLoads = (
          events.getByCurrentYearCallCount,
          places.getAllCallCount,
          searches.getPastSearchesCallCount,
        );
        router.router.go(RoutePaths.geoMap);
        await tester.pumpAndSettle();

        final finder = find.byType(GeoMapScreen, skipOffstage: false);
        final initialState = tester.state(finder);
        final initial = tester.widget<GeoMapScreen>(finder);
        final initialLoads = (
          events.getByCurrentYearCallCount,
          places.getAllCallCount,
          searches.getPastSearchesCallCount,
        );
        expect(initialLoads, (
          beforeMapLoads.$1 + 1,
          beforeMapLoads.$2 + 1,
          beforeMapLoads.$3 + 1,
        ));
        expect(weather.getCombinedWeatherForecastCallCount, 0);
        var priorWeatherViewModel = initial.weatherViewModel;

        for (final (location, selectedId, selectedType)
            in <(String, int?, Type?)>[
              ('/map?contentId=1&type=event', 1, Event),
              ('/map?contentId=2&type=event', 2, Event),
              ('/map?contentId=1&type=place', 1, Place),
              (RoutePaths.geoMap, null, null),
            ]) {
          router.router.go(location);
          await tester.pumpAndSettle();
          final current = tester.widget<GeoMapScreen>(finder);
          expect(tester.state(finder), same(initialState));
          expect(current.viewModel, same(initial.viewModel));
          expect(current.searchViewModel, same(initial.searchViewModel));
          expect(current.weatherViewModel, isNot(same(priorWeatherViewModel)));
          expect(
            () => priorWeatherViewModel.addListener(() {}),
            throwsFlutterError,
          );
          priorWeatherViewModel = current.weatherViewModel;
          expect((
            events.getByCurrentYearCallCount,
            places.getAllCallCount,
            searches.getPastSearchesCallCount,
          ), initialLoads);
          if (selectedId == null) {
            expect(find.byType(GeoMapModalPost), findsNothing);
            expect(current.viewModel.selectedContent, isNull);
            expect(
              tester
                  .widget<GeoMapBottomSheet>(find.byType(GeoMapBottomSheet))
                  .searchQuery,
              isEmpty,
            );
          } else {
            final content = tester
                .widget<GeoMapModalPost>(find.byType(GeoMapModalPost))
                .content;
            expect(content.remoteId, selectedId);
            expect(content.runtimeType, selectedType);
          }
        }

        final media = Media(
          remoteId: 1,
          url: 'https://example.com/gallery.jpg',
          width: 800,
          height: 600,
          createdAt: DateTime.utc(2026),
          modifiedAt: DateTime.utc(2026),
          areaName: 'Molise',
          cityName: 'Campobasso',
        );
        unawaited(
          router.router.pushNamed<void>(
            RouteNames.gallery,
            extra: GalleryPreviewRouteData(
              media: <Media>[media],
              initialIndex: 0,
            ).toExtra(),
          ),
        );
        await tester.pumpAndSettle();
        final underGallery = tester.widget<GeoMapScreen>(finder);
        expect(tester.state(finder), same(initialState));
        expect(underGallery.viewModel, same(initial.viewModel));
        expect(underGallery.searchViewModel, same(initial.searchViewModel));
        expect(underGallery.weatherViewModel, same(priorWeatherViewModel));
        expect(await tester.binding.handlePopRoute(), isTrue);
        await tester.pumpAndSettle();

        router.router.go(RoutePaths.home);
        await tester.pumpAndSettle();
        router.router.go(RoutePaths.geoMap);
        await tester.pumpAndSettle();
        final afterBranch = tester.widget<GeoMapScreen>(finder);
        expect(tester.takeException(), isNull);
        expect(tester.state(finder), same(initialState));
        expect(afterBranch.viewModel, same(initial.viewModel));
        expect(afterBranch.searchViewModel, same(initial.searchViewModel));
        expect(afterBranch.weatherViewModel, same(priorWeatherViewModel));
        // One weather request per selected content; Map/Gallery/branch changes
        // do not add another request when no content is selected.
        expect(weather.getCombinedWeatherForecastCallCount, 3);
        expect((
          events.getByCurrentYearCallCount,
          places.getAllCallCount,
          searches.getPastSearchesCallCount,
        ), initialLoads);
      },
    );

    testWidgets('direct /map renders the default map without selection', (
      tester,
    ) async {
      final harness = _MapHarness();
      final router = _buildTestRouterApp(harness);

      await tester.pumpWidget(router.app);
      await tester.pumpAndSettle();

      router.router.go(RoutePaths.geoMap);
      await tester.pumpAndSettle();

      expect(find.byType(GeoMapScreen), findsOneWidget);
      expect(find.byType(GeoMapModalPost), findsNothing);
      expect(
        router.router.routeInformationProvider.value.uri.path,
        RoutePaths.geoMap,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('legacy random key redirects to the canonical map URI', (
      tester,
    ) async {
      final harness = _MapHarness();
      final router = _buildTestRouterApp(harness);

      await tester.pumpWidget(router.app);
      await tester.pumpAndSettle();

      router.router.go('/map?key=legacy&source=restored');
      await tester.pumpAndSettle();

      final uri = router.router.routeInformationProvider.value.uri;
      expect(uri.path, RoutePaths.geoMap);
      expect(uri.queryParameters.containsKey('key'), isFalse);
      expect(uri.queryParameters['source'], 'restored');
    });

    testWidgets('/map?contentId=<event>&type=event selects the event', (
      tester,
    ) async {
      final event = makeEvent(name: 'Evento 1');
      final harness = _MapHarness();
      final router = _buildTestRouterApp(
        harness,
        eventRepository: FakeEventRepository(
          getByIdResults: <int, Result<Event>>{1: Result.success(event)},
        ),
      );

      await tester.pumpWidget(router.app);
      await tester.pumpAndSettle();

      router.router.goNamed(
        RouteNames.geoMap,
        queryParameters: <String, String>{'contentId': '1', 'type': 'event'},
      );
      await tester.pumpAndSettle();

      final mapContext = tester.element(find.byType(GeoMapScreen));
      expect(GoRouterState.of(mapContext).extra, isNull);
      expect(
        tester.widget<GeoMapScreen>(find.byType(GeoMapScreen)).initialContentId,
        1,
      );
      expect(
        tester
            .widget<GeoMapScreen>(find.byType(GeoMapScreen))
            .initialContentType,
        ContentType.event,
      );

      final modal = tester.widget<GeoMapModalPost>(
        find.byType(GeoMapModalPost),
      );
      expect(modal.content.remoteId, event.remoteId);
      final uri = router.router.routeInformationProvider.value.uri;
      expect(uri.path, RoutePaths.geoMap);
      expect(uri.queryParameters['contentId'], '1');
      expect(uri.queryParameters['type'], 'event');
      expect(tester.takeException(), isNull);
    });

    testWidgets('/map?contentId=<place>&type=place selects the place', (
      tester,
    ) async {
      final place = makePlace(remoteId: 3, name: 'Luogo 3');
      final harness = _MapHarness();
      final router = _buildTestRouterApp(
        harness,
        placeRepository: FakePlaceRepository(
          getByIdResults: <int, Result<Place>>{3: Result.success(place)},
        ),
      );

      await tester.pumpWidget(router.app);
      await tester.pumpAndSettle();

      router.router.goNamed(
        RouteNames.geoMap,
        queryParameters: <String, String>{'contentId': '3', 'type': 'place'},
      );
      await tester.pumpAndSettle();

      final modal = tester.widget<GeoMapModalPost>(
        find.byType(GeoMapModalPost),
      );
      expect(modal.content.remoteId, place.remoteId);
      expect(tester.takeException(), isNull);
    });

    for (final (label, queryParameters) in <(String, Map<String, String>)>[
      ('non-numeric id', <String, String>{'contentId': 'abc', 'type': 'event'}),
      ('zero id', <String, String>{'contentId': '0', 'type': 'event'}),
      ('negative id', <String, String>{'contentId': '-3', 'type': 'event'}),
      ('invalid type', <String, String>{'contentId': '1', 'type': 'bogus'}),
      ('missing id', <String, String>{'type': 'event'}),
    ]) {
      testWidgets(
        'malformed or missing parameters ($label) render the default map',
        (tester) async {
          final harness = _MapHarness();
          final router = _buildTestRouterApp(harness);

          await tester.pumpWidget(router.app);
          await tester.pumpAndSettle();

          router.router.goNamed(
            RouteNames.geoMap,
            queryParameters: queryParameters,
          );
          await tester.pumpAndSettle();

          expect(find.byType(GeoMapScreen), findsOneWidget);
          expect(find.byType(GeoMapModalPost), findsNothing);
          expect(find.byType(RouteErrorScreen), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'missing repository item keeps the default map and shows feedback',
      (tester) async {
        final harness = _MapHarness();
        final router = _buildTestRouterApp(harness);

        await tester.pumpWidget(router.app);
        await tester.pumpAndSettle();

        router.router.goNamed(
          RouteNames.geoMap,
          queryParameters: <String, String>{
            'contentId': '999',
            'type': 'event',
          },
        );
        await tester.pumpAndSettle();

        expect(find.byType(GeoMapModalPost), findsNothing);
        expect(find.text('Contenuto non trovato'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'repeated navigation to different content ids updates URI and screen',
      (tester) async {
        final first = makeEvent(name: 'Evento 1');
        final second = makeEvent(remoteId: 2, name: 'Evento 2');
        final harness = _MapHarness();
        final router = _buildTestRouterApp(
          harness,
          eventRepository: FakeEventRepository(
            getByIdResults: <int, Result<Event>>{
              1: Result.success(first),
              2: Result.success(second),
            },
          ),
        );

        await tester.pumpWidget(router.app);
        await tester.pumpAndSettle();

        router.router.goNamed(
          RouteNames.geoMap,
          queryParameters: <String, String>{'contentId': '1', 'type': 'event'},
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<GeoMapModalPost>(find.byType(GeoMapModalPost))
              .content
              .remoteId,
          1,
        );

        router.router.goNamed(
          RouteNames.geoMap,
          queryParameters: <String, String>{'contentId': '2', 'type': 'event'},
        );
        await tester.pumpAndSettle();

        expect(
          tester
              .widget<GeoMapModalPost>(find.byType(GeoMapModalPost))
              .content
              .remoteId,
          2,
        );
        final uri = router.router.routeInformationProvider.value.uri;
        expect(uri.path, RoutePaths.geoMap);
        expect(uri.queryParameters['contentId'], '2');
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'returning to /map clears selection and restores sheet extent',
      (tester) async {
        final event = makeEvent(name: 'Evento 1');
        final harness = _MapHarness();
        final router = _buildTestRouterApp(
          harness,
          eventRepository: FakeEventRepository(
            getByIdResults: <int, Result<Event>>{1: Result.success(event)},
          ),
        );

        await tester.pumpWidget(router.app);
        await tester.pumpAndSettle();

        router.router.go('/map?contentId=1&type=event');
        await tester.pumpAndSettle();
        final sheet = tester.widget<GeoMapBottomSheet>(
          find.byType(GeoMapBottomSheet),
        );
        final animation = sheet.controller.animateTo(
          0.5,
          duration: const Duration(milliseconds: 1),
          curve: Curves.linear,
        );
        await tester.pumpAndSettle();
        await animation;
        expect(sheet.controller.size, closeTo(0.5, 0.01));

        router.router.go(RoutePaths.geoMap);
        await tester.pumpAndSettle();

        expect(find.byType(GeoMapModalPost), findsNothing);
        expect(sheet.controller.size, closeTo(0.3, 0.01));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'reparsing the selected location retains the selected identity',
      (tester) async {
        final event = makeEvent(name: 'Evento 1');
        final harness = _MapHarness();
        final router = _buildTestRouterApp(
          harness,
          eventRepository: FakeEventRepository(
            getByIdResults: <int, Result<Event>>{1: Result.success(event)},
          ),
        );

        await tester.pumpWidget(router.app);
        await tester.pumpAndSettle();

        router.router.goNamed(
          RouteNames.geoMap,
          queryParameters: <String, String>{'contentId': '1', 'type': 'event'},
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<GeoMapModalPost>(find.byType(GeoMapModalPost))
              .content
              .remoteId,
          1,
        );

        router.router.go(RoutePaths.geoMap);
        await tester.pumpAndSettle();

        router.router.goNamed(
          RouteNames.geoMap,
          queryParameters: <String, String>{'contentId': '1', 'type': 'event'},
        );
        await tester.pumpAndSettle();

        expect(
          tester
              .widget<GeoMapModalPost>(find.byType(GeoMapModalPost))
              .content
              .remoteId,
          1,
        );
        final uri = router.router.routeInformationProvider.value.uri;
        expect(uri.queryParameters['contentId'], '1');
        expect(uri.queryParameters['type'], 'event');
        expect(tester.takeException(), isNull);
      },
    );
  });
}

/// A [SyncViewModel] that never has a due sync, so the redirect contract stays
/// out of the map tests.
final class _MapHarness {
  _MapHarness() {
    settings = FakeSettingsRepository(lastSyncedAt: DateTime.now());
    final useCase = SyncUseCase(
      cityRepository: FakeCityRepository(),
      eventRepository: FakeEventRepository(),
      mediaRepository: FakeMediaRepository(),
      placeRepository: FakePlaceRepository(),
      settingsRepository: settings,
      transactionCoordinator: FakeTransactionCoordinator(),
    );
    viewModel = SyncViewModel(syncUseCase: useCase);
  }

  late final FakeSettingsRepository settings;
  late final SyncViewModel viewModel;
}

/// Builds the production router with the full provider tree the real screens
/// require, plus the controlled [harness] sync view model.
({GoRouter router, Widget app}) _buildTestRouterApp(
  _MapHarness harness, {
  FakeEventRepository? eventRepository,
  FakePlaceRepository? placeRepository,
  SearchRepository? searchRepository,
  FakeWeatherApiClient? weatherApiClient,
}) {
  final auth = ControllableAdminAuth();
  addTearDown(auth.dispose);
  final router = buildAppRouter(
    syncViewModel: harness.viewModel,
    adminAuthViewModel: auth.viewModel,
  );

  final app = MultiProvider(
    providers: _buildProviders(
      harness,
      eventRepository: eventRepository,
      placeRepository: placeRepository,
      searchRepository: searchRepository,
      weatherApiClient: weatherApiClient,
    ),
    child: MaterialApp.router(
      scaffoldMessengerKey: $scaffoldMessengerKey,
      routerConfig: router,
    ),
  );

  return (router: router, app: app);
}

/// The providers the real screens resolved from the router tree require.
List<SingleChildWidget> _buildProviders(
  _MapHarness harness, {
  FakeEventRepository? eventRepository,
  FakePlaceRepository? placeRepository,
  SearchRepository? searchRepository,
  FakeWeatherApiClient? weatherApiClient,
}) {
  final eventRepo = eventRepository ?? FakeEventRepository();
  final placeRepo = placeRepository ?? FakePlaceRepository();
  final logger = MockLogger();
  final cachedWeatherApiClient = CachedWeatherApiClient(
    weatherApiClient: weatherApiClient ?? FakeWeatherApiClient(),
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
    logger: logger,
  );
  final settingsRepository = FakeSettingsRepository();

  return <SingleChildWidget>[
    Provider<http.Client>.value(value: RecordingTileHttpClient()),
    Provider<EventRepository>.value(value: eventRepo),
    Provider<PlaceRepository>.value(value: placeRepo),
    Provider<SearchRepository>.value(
      value: searchRepository ?? _FakeSearchRepository(),
    ),
    Provider<SettingsRepository>.value(value: settingsRepository),
    Provider<CachedWeatherApiClient>.value(value: cachedWeatherApiClient),
    Provider<CacheManager>.value(value: FakeCacheManager()),
    Provider<Logger>.value(value: logger),
    Provider<UrlLaunchService>(create: (_) => UrlLaunchService(logger: logger)),
    ChangeNotifierProvider<FavouriteViewModel>(
      create: (_) => FavouriteViewModel(
        favouriteGetIdsUseCase: FavouriteGetIdsUseCase(
          eventRepository: eventRepo,
          placeRepository: placeRepo,
        ),
      ),
    ),
    ChangeNotifierProvider<ThemeViewModel>(
      create: (_) => ThemeViewModel(settingsRepository: settingsRepository),
    ),
    ChangeNotifierProvider<SettingsViewModel>(
      create: (_) => SettingsViewModel(
        settingsRepository: settingsRepository,
        sentryLoggingFlag: SentryLoggingFlag(initialValue: false),
      ),
    ),
    ChangeNotifierProvider<SyncViewModel>.value(value: harness.viewModel),
  ];
}

/// A [SearchRepository] fake that never surfaces persisted data.
final class _FakeSearchRepository implements SearchRepository {
  @override
  Future<Result<void>> addToPastSearches(String text) async =>
      const Result.success(null);

  @override
  Future<Result<List<ContentBase>>> getResultsByQuery(String text) async =>
      const Result.success(<ContentBase>[]);

  @override
  Future<Result<List<String>>> getPastSearches() async =>
      const Result.success(<String>[]);

  @override
  Future<Result<void>> removeFromPastSearches(String text) async =>
      const Result.success(null);
}
