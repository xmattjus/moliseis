import 'dart:async' show Completer;

import 'package:command_it/command_it.dart' as command_it;
import 'package:flutter_map/flutter_map.dart';
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
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/content_type.dart';
import 'package:moliseis/domain/models/event.dart';
import 'package:moliseis/domain/repositories/search_repository.dart';
import 'package:moliseis/domain/use-cases/favourite_get_ids_use_case.dart';
import 'package:moliseis/domain/use-cases/geo_map_use_case.dart';
import 'package:moliseis/ui/category/widgets/category_content_and_type_selection.dart';
import 'package:moliseis/ui/favourite/view_models/favourite_view_model.dart';
import 'package:moliseis/ui/geo_map/view_models/geo_map_mode.dart';
import 'package:moliseis/ui/geo_map/view_models/geo_map_selection_intent.dart';
import 'package:moliseis/ui/geo_map/view_models/geo_map_view_model.dart';
import 'package:moliseis/ui/geo_map/widgets/components/animated_geo_map_search_bar.dart';
import 'package:moliseis/ui/geo_map/widgets/geo_map.dart';
import 'package:moliseis/ui/geo_map/widgets/geo_map_bottom_sheet.dart';
import 'package:moliseis/ui/geo_map/widgets/geo_map_modal_post.dart';
import 'package:moliseis/ui/geo_map/widgets/geo_map_modal_search_results.dart';
import 'package:moliseis/ui/geo_map/widgets/geo_map_screen.dart';
import 'package:moliseis/ui/search/view_models/search_view_model.dart';
import 'package:moliseis/ui/search/widgets/search_result_sliver_list.dart';
import 'package:moliseis/ui/weather/view_models/weather_view_model.dart';
import 'package:moliseis/ui/weather/wmo_weather_description_mapper.dart';
import 'package:moliseis/ui/weather/wmo_weather_icon_mapper.dart';
import 'package:moliseis/utils/lru_cache.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/result_command.dart';
import 'package:provider/provider.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../support/command_test_support.dart';
import '../../../support/fake_repositories.dart';
import '../../../support/fixtures.dart';
import '../../../support/mock_logger.dart';
import '../../../support/recording_tile_http_client.dart';
import '../../../support/weather_harness.dart';

void main() {
  for (final category in [true, false]) {
    for (final emptyDraft in [false, true]) {
      testOwnerUI(
        'Map selector owner replacement category=$category empty=$emptyDraft',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(1280, 1600));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final oldPending = Completer<Result<Event>>();
          final newPending = Completer<Result<Event>>();
          final oldEvents = FakeEventRepository()
            ..pendingGetById[1] = oldPending;
          final newEvents = FakeEventRepository()
            ..pendingGetById[1] = newPending;
          final oldOwner = GeoMapViewModel(
            geoMapUseCase: GeoMapUseCase(
              eventRepository: oldEvents,
              placeRepository: FakePlaceRepository(),
            ),
          );
          final newOwner = GeoMapViewModel(
            geoMapUseCase: GeoMapUseCase(
              eventRepository: newEvents,
              placeRepository: FakePlaceRepository(),
            ),
          );
          final owner = ValueNotifier(oldOwner);
          final searches = _buildSearchViewModel();
          final weather = _buildWeatherViewModel();
          final favourites = _buildFavouriteViewModel();
          var oldPublications = 0;
          var newPublications = 0;
          void observeOld() => oldPublications++;
          void observeNew() => newPublications++;
          oldOwner
            ..setSelectedCategories.addListener(observeOld)
            ..setSelectedTypes.addListener(observeOld);
          newOwner
            ..setSelectedCategories.addListener(observeNew)
            ..setSelectedTypes.addListener(observeNew);
          try {
            await tester.pumpWidget(
              _buildApp(
                favouriteViewModel: favourites,
                child: ValueListenableBuilder<GeoMapViewModel>(
                  valueListenable: owner,
                  builder: (_, current, _) => GeoMapScreen(
                    routeSelection: (id: 1, type: ContentType.event),
                    viewModel: current,
                    searchViewModel: searches,
                    weatherViewModel: weather,
                  ),
                ),
              ),
            );
            await pumpCommandTurns(tester);
            final screen = tester.state(find.byType(GeoMapScreen));
            final selector = find.byType(
              CategoryContentAndTypeSelection,
              skipOffstage: false,
            );
            final oldState = tester.state(selector);
            final categories = Set.of(oldOwner.selectedCategories);
            final types = Set.of(oldOwner.selectedTypes);
            expect(newOwner.selectedCategories, categories);
            expect(newOwner.selectedTypes, types);
            expect(oldOwner.selectContent.isRunningSync.value, isTrue);
            await tester.tap(
              find.byTooltip(
                category ? 'Seleziona per categoria' : 'Seleziona per tipo',
              ),
            );
            await tester.pump();
            await tester.pump(Durations.long4);
            await pumpCommandTurns(tester);
            final options = <Key>[
              if (category)
                ...categories.map(ValueKey<ContentCategory>.new)
              else
                ...types.map(ValueKey<ContentType>.new),
            ];
            for (final option in emptyDraft ? options : options.take(1)) {
              final checkbox = find.byKey(option);
              await tester.ensureVisible(checkbox);
              await tester.tap(checkbox);
              await tester.pump();
            }
            expect(oldPublications, 0);
            expect(newPublications, 0);
            owner.value = newOwner;
            await pumpCommandTurns(tester);
            // The screen survives via its production didUpdateWidget path.
            expect(tester.state(find.byType(GeoMapScreen)), same(screen));
            expect(
              screen.widget,
              isA<GeoMapScreen>().having(
                (widget) => widget.viewModel,
                'owner',
                same(newOwner),
              ),
            );
            final oldStateStillMounted = oldState.mounted;
            final replacementState = tester.state(selector);
            expect(
              find.text(
                category ? 'Seleziona per categoria' : 'Seleziona per tipo',
              ),
              findsOneWidget,
            );
            // Old modal rows remain visible while the new owner is mounted.
            for (final option in emptyDraft ? options : options.take(1)) {
              expect(
                tester.widget<Checkbox>(find.byKey(option)).value,
                isFalse,
              );
            }
            await tester.tap(find.byTooltip('Salva'));
            await tester.pump();
            await tester.pump(Durations.long4);
            await pumpCommandTurns(tester);
            // Observe command admission, including a no-op empty-to-all call.
            expect(oldPublications, 0);
            expect(newPublications, 0);
            expect(oldStateStillMounted, isFalse);
            expect(oldState.mounted, isFalse);
            expect(replacementState, isNot(same(oldState)));
            expect(replacementState.mounted, isTrue);
            expect(oldOwner.selectedCategories, categories);
            expect(oldOwner.selectedTypes, types);
            expect(newOwner.selectedCategories, categories);
            expect(newOwner.selectedTypes, types);
            final current = tester.widget<CategoryContentAndTypeSelection>(
              selector,
            );
            expect(current.selectedCategories, categories);
            expect(current.selectedTypes, types);
            expect(find.text('Categoria'), findsOneWidget);
            expect(find.text('Tipo'), findsOneWidget);
            expect(oldEvents.getByIdCallCount, 1);
            expect(newEvents.getByIdCallCount, 1);
            // Dispose the detached owner with both lookups still pending.
            var lateNotifications = 0;
            oldOwner
              ..addListener(() => lateNotifications++)
              ..dispose();
            await tester.pump(const Duration(milliseconds: 100));
            oldPending.complete(Result.success(makeEvent(name: 'Obsolete')));
            newPending.complete(Result.success(makeEvent(name: 'Current')));
            await tester.pumpAndSettle();
            expect(lateNotifications, 0);
            expect(oldOwner.resolvedContent, isNull);
            expect(newOwner.resolvedContent?.name, 'Current');
            expect(oldPublications, 0);
            expect(newPublications, 0);
            expect(tester.takeException(), isNull);
          } finally {
            if (!oldPending.isCompleted) {
              oldPending.complete(Result.error(TestException('test cleanup')));
            }
            if (!newPending.isCompleted) {
              newPending.complete(Result.error(TestException('test cleanup')));
            }
            await tester.pumpWidget(const SizedBox.shrink());
            if (!oldOwner.isDisposed) oldOwner.dispose();
            if (!newOwner.isDisposed) newOwner.dispose();
            searches.dispose();
            favourites.dispose();
            owner.dispose();
            await tester.pump(const Duration(milliseconds: 100));
            await pumpCommandTurns(tester);
          }
        },
      );
    }
  }

  testOwnerUI(
    'Map shared selector preserves an empty category draft across owner notify',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final owner = _buildGeoMapViewModel();
      final searches = _buildSearchViewModel();
      final weather = _buildWeatherViewModel();
      await tester.pumpWidget(
        _buildApp(
          favouriteViewModel: _buildFavouriteViewModel(),
          child: GeoMapScreen(
            routeSelection: null,
            viewModel: owner,
            searchViewModel: searches,
            weatherViewModel: weather,
          ),
        ),
      );
      await pumpCommandTurns(tester);
      await owner.setSelectedCategories.execute({
        ContentCategory.nature,
        ContentCategory.history,
      });
      await tester.pumpAndSettle();
      final selectorState = tester.state(
        find.byType(CategoryContentAndTypeSelection),
      );
      var publications = 0;
      void observePublication() {
        if (owner.setSelectedCategories.completed) publications++;
      }

      owner.setSelectedCategories.addListener(observePublication);

      await tester.tap(find.byTooltip('Seleziona per categoria'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey(ContentCategory.history)));
      await tester.tap(find.byKey(const ValueKey(ContentCategory.nature)));
      owner.showContent(makePlace());
      await pumpCommandTurns(tester);
      expect(
        tester.state(find.byType(CategoryContentAndTypeSelection)),
        same(selectorState),
      );
      expect(
        find.text('Nessuna categoria', skipOffstage: false),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Checkbox>(
              find.byKey(const ValueKey(ContentCategory.nature)),
            )
            .value,
        isFalse,
      );
      expect(
        tester
            .widget<Checkbox>(
              find.byKey(const ValueKey(ContentCategory.history)),
            )
            .value,
        isFalse,
      );
      expect(owner.selectedCategories, {
        ContentCategory.nature,
        ContentCategory.history,
      });
      expect(publications, 0);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Salva'));
      await tester.pumpAndSettle();
      expect(publications, 1);
      expect(
        owner.selectedCategories,
        ContentCategory.values
            .where((value) => value != ContentCategory.unknown)
            .toSet(),
      );
      expect(owner.selectedTypes, ContentType.values.toSet());
      expect(find.text('Categoria'), findsOneWidget);
      owner.setSelectedCategories.removeListener(observePublication);
      await tester.pumpWidget(const SizedBox.shrink());
      owner.dispose();
      searches.dispose();
      weather.dispose();
      await tester.pump(const Duration(milliseconds: 100));
      await pumpCommandTurns(tester);
      expect(tester.takeException(), isNull);
    },
  );

  final response = CombinedWeatherForecastResponse(
    latitude: 41.56,
    longitude: 14.66,
    generationTimeMs: 1,
    utcOffsetSeconds: 7200,
    timezone: 'Europe/Rome',
    timezoneAbbreviation: 'CEST',
    elevation: 700,
    current: CurrentWeatherForecastData(
      time: DateTime.utc(2026, 4, 7, 10),
      interval: 900,
      temperature2m: 18.5,
      isDay: 1,
      weatherCode: 0,
      precipitation: 0,
    ),
    hourly: const HourlyWeatherForecastData(
      time: [],
      temperature2m: [],
      weatherCode: [],
      precipitationProbability: [],
      isDay: [],
    ),
    daily: const DailyWeatherForecastData(
      time: [],
      weatherCode: [],
      temperature2mMax: [],
      temperature2mMin: [],
      precipitationProbabilityMax: [],
    ),
  );
  for (final outcome in ['success', 'empty', 'expected', 'runtime']) {
    testWidgets('Map equal Search fences both publication windows: $outcome', (
      tester,
    ) async {
      final logger = MockLogger();
      final restore = installCommandTestReporting(logger);
      addTearDown(restore);
      final repository = FakeSearchRepository(
        resultsByQueryResult: Result.success([makeEvent(name: 'Previous A')]),
      );
      final searches = SearchViewModel(searchRepository: repository);
      final vm = _buildGeoMapViewModel();
      await tester.pumpWidget(
        _buildApp(
          favouriteViewModel: _buildFavouriteViewModel(),
          child: GeoMapScreen(
            routeSelection: null,
            viewModel: vm,
            searchViewModel: searches,
            weatherViewModel: _buildWeatherViewModel(),
          ),
        ),
      );
      await pumpCommandTurns(tester);
      tester
          .widget<AnimatedGeoMapSearchBar>(find.byType(AnimatedGeoMapSearchBar))
          .onSubmitted!('festival');
      await pumpCommandTurns(tester);
      final previous = tester.widget<GeoMapModalSearchResults>(
        find.byType(GeoMapModalSearchResults),
      );
      expect(
        admitsGeoMapSearchSnapshot(previous.admission, vm, searches),
        isTrue,
      );
      final oldSnapshot = searches.loadResults.results.value;
      // Leaving Search and submitting the same value before neutral publication
      // must exclude the still-public previous completed execution.
      vm.showContent(makePlace());
      final pending = Completer<Result<List<ContentBase>>>();
      repository.resultsByQueryHandler = (_) => pending.future;
      tester
          .widget<AnimatedGeoMapSearchBar>(find.byType(AnimatedGeoMapSearchBar))
          .onSubmitted!('festival');
      expect(searches.loadResults.results.value, same(oldSnapshot));
      expect(searches.loadResults.isRunningSync.value, isTrue);
      final newMode = vm.mode as GeoMapSearchResults;
      final immediateFence = (
        searchOwner: searches,
        mode: newMode,
        excludedSnapshot: oldSnapshot,
      );
      expect(admitsGeoMapSearchSnapshot(immediateFence, vm, searches), isFalse);
      await pumpCommandTurns(tester);
      final current = tester.widget<GeoMapModalSearchResults>(
        find.byType(GeoMapModalSearchResults),
      );
      expect(current.admission!.mode, same(newMode));
      expect(find.byType(SearchResultSliverList), findsNothing);
      expect(searches.results.single.name, 'Previous A');
      var settledBeforePublication = false;
      void observeSettlement() {
        if (!searches.loadResults.isRunningSync.value) {
          settledBeforePublication = true;
          expectSync(searches.loadResults.results.value.isRunning, isTrue);
          expectSync(
            admitsGeoMapSearchSnapshot(current.admission, vm, searches),
            isFalse,
          );
        }
      }

      searches.loadResults.isRunningSync.addListener(observeSettlement);
      switch (outcome) {
        case 'success':
          pending.complete(Result.success([makeEvent(name: 'Newest A')]));
        case 'empty':
          pending.complete(const Result.success([]));
        case 'expected':
          pending.complete(Result.error(TestException('latest expected')));
        case 'runtime':
          pending.completeError(StateError('latest runtime'));
      }
      await pumpCommandTurns(tester);
      searches.loadResults.isRunningSync.removeListener(observeSettlement);
      expect(settledBeforePublication, isTrue);
      expect(
        admitsGeoMapSearchSnapshot(current.admission, vm, searches),
        isTrue,
      );
      expect(find.byType(SearchResultSliverList), findsOneWidget);
      if (outcome == 'success') {
        expect(searches.results.single.name, 'Newest A');
      }
      if (outcome == 'empty') {
        expect(
          find.text('Non è stato trovato alcun risultato.'),
          findsOneWidget,
        );
      }
      if (outcome == 'expected' || outcome == 'runtime') {
        expect(
          find.text('Si è verificato un errore durante il caricamento.'),
          findsOneWidget,
        );
        final completed = searches.loadResults.results.value;
        current.onRetryPressed();
        expect(searches.loadResults.isRunningSync.value, isTrue);
        expect(searches.loadResults.results.value, same(completed));
        expect(
          admitsGeoMapSearchSnapshot(current.admission, vm, searches),
          isFalse,
        );
        await pumpCommandTurns(tester);
      }
      // A stale result callback cannot restore its old Search or Post surface.
      current.onBackPressed();
      current.onResultPressed(makeEvent(remoteId: 22));
      current.onRetryPressed();
      expect(vm.mode, isA<GeoMapExplore>());
      expect(vm.resolvedContent, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      vm.dispose();
      searches.dispose();
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
    });
  }

  for (final reentry in ['semantic', 'running', 'terminal']) {
    testWidgets('Map Search $reentry reentry cannot restore obsolete mode', (
      tester,
    ) async {
      final repository = FakeSearchRepository();
      final searches = SearchViewModel(searchRepository: repository);
      final vm = _buildGeoMapViewModel();
      await tester.pumpWidget(
        _buildApp(
          favouriteViewModel: _buildFavouriteViewModel(),
          child: GeoMapScreen(
            routeSelection: null,
            viewModel: vm,
            searchViewModel: searches,
            weatherViewModel: _buildWeatherViewModel(),
          ),
        ),
      );
      await pumpCommandTurns(tester);
      var switched = false;
      void supersede() {
        if (!switched &&
            vm.mode is GeoMapSearchResults &&
            (reentry != 'terminal' ||
                searches.loadResults.results.value.completed)) {
          switched = true;
          vm.showContent(makePlace(remoteId: 8));
        }
      }

      final source = (switch (reentry) {
        'semantic' => vm,
        'running' => searches.loadResults.isRunningSync,
        _ => searches.loadResults.results,
      })..addListener(supersede);
      final submit = tester
          .widget<AnimatedGeoMapSearchBar>(find.byType(AnimatedGeoMapSearchBar))
          .onSubmitted!;
      submit('festival');
      await pumpCommandTurns(tester);
      expect(switched, isTrue);
      expect(vm.resolvedContent?.remoteId, 8);
      expect(find.byType(GeoMapModalSearchResults), findsNothing);
      expect(
        repository.getResultsByQueryCallCount,
        reentry == 'terminal' ? 1 : 0,
      );
      submit('ab');
      expect(vm.resolvedContent?.remoteId, 8);
      source.removeListener(supersede);
      await tester.pumpWidget(const SizedBox.shrink());
      vm.dispose();
      searches.dispose();
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'Search repeat, retry, invalid input and owner replacement stay fenced',
    (tester) async {
      final repository = FakeSearchRepository();
      final first = Completer<Result<List<ContentBase>>>();
      final second = Completer<Result<List<ContentBase>>>();
      var calls = 0;
      repository.resultsByQueryHandler = (_) =>
          ++calls == 1 ? first.future : second.future;
      final searches = SearchViewModel(searchRepository: repository);
      final vm = _buildGeoMapViewModel();
      final weather = _buildWeatherViewModel();
      await tester.pumpWidget(
        _buildApp(
          favouriteViewModel: _buildFavouriteViewModel(),
          child: GeoMapScreen(
            routeSelection: null,
            viewModel: vm,
            searchViewModel: searches,
            weatherViewModel: weather,
          ),
        ),
      );
      await pumpCommandTurns(tester);
      final submit = tester
          .widget<AnimatedGeoMapSearchBar>(find.byType(AnimatedGeoMapSearchBar))
          .onSubmitted!;
      submit('festival');
      final firstMode = vm.mode;
      submit('festival'); // The first queued child must never perform I/O.
      expect(vm.mode, isNot(same(firstMode)));
      await pumpCommandTurns(tester);
      expect(calls, 1);
      final old = tester.widget<GeoMapModalSearchResults>(
        find.byType(GeoMapModalSearchResults),
      );
      final mode = vm.mode;
      submit('ab');
      expect(vm.mode, same(mode));
      expect(searches.loadResults.isRunningSync.value, isTrue);
      submit('museum'); // A different query after loading also revokes A.
      await pumpCommandTurns(tester);
      expect(calls, 2);
      first.complete(Result.success([makeEvent(name: 'Obsolete festival')]));
      await pumpCommandTurns(tester);
      expect(find.byType(SearchResultSliverList), findsNothing);
      old.onResultPressed(makePlace(remoteId: 44));
      old.onRetryPressed();
      expect((vm.mode as GeoMapSearchResults).query, 'museum');
      expect(calls, 2);
      second.complete(Result.success([makeEvent(name: 'Museum result')]));
      await pumpCommandTurns(tester);
      expect(searches.results.single.name, 'Museum result');
      final museumMode = vm.mode;
      // Retain the actual Element: the helper creates a new GoRouter.
      final element = tester.element(find.byType(GeoMapScreen));
      element.owner!.buildScope(element, () {
        element.update(
          GeoMapScreen(
            routeSelection: null,
            viewModel: vm,
            searchViewModel: searches,
            weatherViewModel: weather,
          ),
        );
      });
      await pumpCommandTurns(tester);
      expect(vm.mode, same(museumMode));
      expect(calls, 2);
      final replacementRepository = FakeSearchRepository(
        resultsByQueryResult: Result.success([makePlace(name: 'New owner')]),
      );
      final replacement = SearchViewModel(
        searchRepository: replacementRepository,
      );
      element.owner!.buildScope(element, () {
        element.update(
          GeoMapScreen(
            routeSelection: null,
            viewModel: vm,
            searchViewModel: replacement,
            weatherViewModel: weather,
          ),
        );
      });
      await pumpCommandTurns(tester);
      expect(replacementRepository.capturedQueries, ['museum']);
      expect(replacement.results.single.name, 'New owner');
      expect(find.byType(SearchResultSliverList), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      old.onRetryPressed();
      old.onResultPressed(makeEvent());
      expect(replacementRepository.getResultsByQueryCallCount, 1);
      vm.dispose();
      searches.dispose();
      replacement.dispose();
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
    },
  );

  for (final beforeScreen in [true, false]) {
    for (final replacement in ['lookup', 'materialized', 'explore']) {
      testWidgets('reentrant $replacement beforeScreen=$beforeScreen '
          'owns effects and feedback', (tester) async {
        final events = FakeEventRepository();
        final pending = Completer<Result<Event>>();
        events.pendingGetById[1] = pending;
        final vm = GeoMapViewModel(
          geoMapUseCase: GeoMapUseCase(
            eventRepository: events,
            placeRepository: FakePlaceRepository(),
          ),
        );
        final searches = _buildSearchViewModel();
        var replaced = false;
        void supersede() {
          if (!replaced &&
              vm.mode is GeoMapExplore &&
              vm.selectContent.results.value.hasFailure) {
            replaced = true;
            switch (replacement) {
              case 'lookup':
                vm.requestSelection(const EventSelection(1));
              case 'materialized':
                vm.showContent(makeEvent(name: 'Local current'));
              case 'explore':
                vm.showExplore(vm.exploreAnchor);
            }
          }
        }

        if (beforeScreen) vm.addListener(supersede);
        await tester.pumpWidget(
          _buildApp(
            favouriteViewModel: _buildFavouriteViewModel(),
            child: GeoMapScreen(
              routeSelection: (id: 1, type: ContentType.event),
              viewModel: vm,
              searchViewModel: searches,
              weatherViewModel: _buildWeatherViewModel(),
            ),
          ),
        );
        await pumpCommandTurns(tester);
        if (!beforeScreen) vm.addListener(supersede);
        final next = Completer<Result<Event>>();
        events.pendingGetById[1] = next;
        pending.complete(Result.error(TestException('superseded feedback')));
        await pumpCommandTurns(tester);
        expect(replaced, isTrue);
        expect(find.text('Contenuto non trovato'), findsNothing);
        if (replacement == 'lookup') {
          expect(events.getByIdCallCount, 2);
          next.complete(Result.success(makeEvent(name: 'Latest lookup')));
          await pumpCommandTurns(tester);
          expect(vm.resolvedContent?.name, 'Latest lookup');
        } else if (replacement == 'materialized') {
          expect(events.getByIdCallCount, 1);
          expect(vm.resolvedContent?.name, 'Local current');
        } else {
          expect(vm.mode, isA<GeoMapExplore>());
          expect(vm.resolvedContent, isNull);
        }
        vm.removeListener(supersede);
        await tester.pumpWidget(const SizedBox.shrink());
        vm.dispose();
        searches.dispose();
        await tester.pump(const Duration(milliseconds: 50));
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
    'camera settle cancels old movement and fallback aligns live center',
    (tester) async {
      final events = FakeEventRepository();
      final vm = GeoMapViewModel(
        geoMapUseCase: GeoMapUseCase(
          eventRepository: events,
          placeRepository: FakePlaceRepository(),
        ),
      );
      final searches = _buildSearchViewModel();
      await tester.pumpWidget(
        _buildApp(
          favouriteViewModel: _buildFavouriteViewModel(),
          child: GeoMapScreen(
            routeSelection: null,
            viewModel: vm,
            searchViewModel: searches,
            weatherViewModel: _buildWeatherViewModel(),
          ),
        ),
      );
      await pumpCommandTurns(tester);
      final map = tester.widget<GeoMap>(find.byType(GeoMap));
      final initial = vm.exploreAnchor;
      const a = LatLng(41.7, 14.7);
      const b = LatLng(41.9, 14.9);
      final onMapEvent = tester
          .widget<FlutterMap>(find.byType(FlutterMap))
          .options
          .onMapEvent!;
      map.mapController!.move(a, 13);
      onMapEvent(
        MapEventMoveEnd(
          source: MapEventSource.mapController,
          camera: map.mapController!.camera,
        ),
      );
      await tester.pump(const Duration(milliseconds: 1600));
      expect(vm.exploreAnchor, initial);
      onMapEvent(
        MapEventMoveEnd(
          source: MapEventSource.onDrag,
          camera: map.mapController!.camera,
        ),
      );
      await tester.pump(const Duration(milliseconds: 1000));
      expect(vm.exploreAnchor, initial);
      onMapEvent(
        MapEventMoveStart(
          source: MapEventSource.onDrag,
          camera: map.mapController!.camera,
        ),
      );
      map.mapController!.move(b, 13);
      await tester.pump(const Duration(milliseconds: 600));
      expect(vm.exploreAnchor, initial);
      onMapEvent(
        MapEventMoveEnd(
          source: MapEventSource.onDrag,
          camera: map.mapController!.camera,
        ),
      );
      await tester.pump(const Duration(milliseconds: 1500));
      expect(vm.exploreAnchor, b);
      final pending = Completer<Result<Event>>();
      events.pendingGetById[1] = pending;
      vm.requestSelection(const EventSelection(1));
      await pumpCommandTurns(tester);
      map.mapController!.move(a, 13);
      pending.complete(Result.error(TestException('current failure')));
      await pumpCommandTurns(tester);
      expect(vm.mode, isA<GeoMapExplore>());
      expect(vm.exploreAnchor, a);
      expect(vm.nearbyTarget?.latitude, a.latitude);
      expect(map.mapController!.camera.center, a);
      expect(find.text('Contenuto non trovato'), findsOneWidget);
      // A pending settle is revoked by synchronous Post presentation, whose
      // programmatic movement must never commit a remembered Explore anchor.
      map.onPositionChangeEnd!(a);
      vm.showContent(makePlace());
      await pumpCommandTurns(tester);
      await tester.pump(const Duration(milliseconds: 1700));
      expect(vm.exploreAnchor, a);
      expect(vm.mode, isA<GeoMapPostDetail>());
      await tester.pumpWidget(const SizedBox.shrink());
      vm.dispose();
      searches.dispose();
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('initial default keeps its initialized mode without admission', (
    tester,
  ) async {
    final vm = _buildGeoMapViewModel();
    final mode = vm.mode;
    final searches = _buildSearchViewModel();
    await tester.pumpWidget(
      _buildApp(
        favouriteViewModel: _buildFavouriteViewModel(),
        child: ChangeNotifierProvider<GeoMapViewModel>.value(
          value: vm,
          child: Builder(
            builder: (context) => GeoMapScreen(
              routeSelection: null,
              viewModel: context.read<GeoMapViewModel>(),
              searchViewModel: searches,
              weatherViewModel: _buildWeatherViewModel(),
            ),
          ),
        ),
      ),
    );
    await pumpCommandTurns(tester);
    expect(vm.mode, same(mode));
    expect(vm.selectContent.results.value.idle, isTrue);
    expect(find.byType(GeoMapModalPost), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    vm.dispose();
    searches.dispose();
    await tester.pump(const Duration(milliseconds: 50));
  });

  for (final ending in ['route', 'local', 'default', 'unmount']) {
    testWidgets('route preparation ABA $ending '
        'rejects work before next frame', (tester) async {
      final old = Completer<Result<Event>>();
      final next = Completer<Result<Event>>();
      final events = FakeEventRepository()
        ..pendingGetById[1] = old
        ..pendingGetById[2] = next;
      final vm = GeoMapViewModel(
        geoMapUseCase: GeoMapUseCase(
          eventRepository: events,
          placeRepository: FakePlaceRepository(),
        ),
      );
      final searches = _buildSearchViewModel();
      final weather = _buildWeatherViewModel();
      await tester.pumpWidget(
        _buildApp(
          favouriteViewModel: _buildFavouriteViewModel(),
          child: ChangeNotifierProvider<GeoMapViewModel>.value(
            value: vm,
            child: Builder(
              builder: (context) => GeoMapScreen(
                routeSelection: (id: 1, type: ContentType.event),
                viewModel: context.read<GeoMapViewModel>(),
                searchViewModel: searches,
                weatherViewModel: weather,
              ),
            ),
          ),
        ),
      );
      await pumpCommandTurns(tester);
      expect(events.getByIdCallCount, 1);
      final element = tester.element(find.byType(GeoMapScreen));
      var notifications = 0;
      void observe() {
        notifications++;
      }

      vm.addListener(observe);
      // Real retained Element updates exercise didUpdateWidget without allowing
      // either queued post-frame admission to execute between B and A.
      late GeoMapMode b;
      late GeoMapMode a;
      element.owner!.buildScope(element, () {
        element.update(
          GeoMapScreen(
            routeSelection: (id: 2, type: ContentType.event),
            viewModel: vm,
            searchViewModel: searches,
            weatherViewModel: weather,
          ),
        );
        b = vm.mode;
        element.update(
          GeoMapScreen(
            routeSelection: ending == 'default'
                ? null
                : (id: 1, type: ContentType.event),
            viewModel: vm,
            searchViewModel: searches,
            weatherViewModel: weather,
          ),
        );
        a = vm.mode;
      });
      expect(a, isNot(same(b)));
      expect(notifications, 0);
      expect(vm.resolvedContent, isNull);
      expect(vm.nearbyTerminal, isNull);
      expect(weather.currentTarget, isNull);
      expect(find.byType(GeoMapModalPost), findsNothing);
      expect(find.byType(GeoMapModalSearchResults), findsNothing);
      expect(events.getByIdCallCount, 1);
      old.complete(Result.error(TestException('superseded before frame')));
      await tester.idle();
      expect(vm.mode, same(a));
      expect(vm.resolvedContent, isNull);
      expect(notifications, 0);
      expect(find.text('Contenuto non trovato'), findsNothing);
      if (ending == 'route') {
        events.pendingGetById[1] = next;
      } else if (ending == 'local') {
        vm.showContent(makePlace(remoteId: 3));
      } else if (ending == 'unmount') {
        await tester.pumpWidget(const SizedBox.shrink());
      }
      await pumpCommandTurns(tester);
      expect(events.getByIdCallCount, ending == 'route' ? 2 : 1);
      if (ending == 'route') {
        next.complete(Result.success(makeEvent(name: 'Final A')));
        await pumpCommandTurns(tester);
        expect(vm.resolvedContent?.name, 'Final A');
      } else if (ending == 'local') {
        expect(vm.resolvedContent?.remoteId, 3);
      } else if (ending == 'default') {
        expect(vm.mode, isA<GeoMapExplore>());
      }
      expect(find.text('Contenuto non trovato'), findsNothing);
      expect(tester.takeException(), isNull);
      vm.removeListener(observe);
      await tester.pumpWidget(const SizedBox.shrink());
      vm.dispose();
      searches.dispose();
      await tester.pump(const Duration(milliseconds: 50));
      await pumpCommandTurns(tester);
      expect(tester.takeException(), isNull);
    });
  }

  for (final invalidPayload in <ContentBase?>[makePlace(), null]) {
    testWidgets('invalid ${invalidPayload == null ? 'null' : 'type'} payload '
        'never commits and produces one terminal feedback', (tester) async {
      final pending = Completer<Result<Event>>();
      final events = FakeEventRepository()..pendingGetById[1] = pending;
      final vm = GeoMapViewModel(
        geoMapUseCase: GeoMapUseCase(
          eventRepository: events,
          placeRepository: FakePlaceRepository(),
        ),
      );
      final searches = _buildSearchViewModel();
      await tester.pumpWidget(
        _buildApp(
          favouriteViewModel: _buildFavouriteViewModel(),
          child: GeoMapScreen(
            routeSelection: (id: 1, type: ContentType.event),
            viewModel: vm,
            searchViewModel: searches,
            weatherViewModel: _buildWeatherViewModel(),
          ),
        ),
      );
      await pumpCommandTurns(tester);
      await pumpCommandTurns(tester);
      await pumpCommandTurns(tester);
      expect(events.getByIdCallCount, 1);
      var notifications = 0;
      void observeCommit() {
        if (vm.selectedContent != null) notifications++;
      }

      vm.addListener(observeCommit);
      // Typed repositories cannot return these values. Establish a terminal
      // coordination state before injecting the malformed public snapshot.
      (vm.selectContent.isRunningSync as ValueNotifier<bool>).value = false;
      // This fault injection proves the shared VM/Screen validation pipeline.
      (vm.selectContent.results
              as ValueNotifier<
                command_it.CommandResult<
                  GeoMapSelectionIntent?,
                  Result<ContentBase?>?
                >
              >)
          .value = command_it.CommandResult.data(
        const EventSelection(1),
        Result.success(invalidPayload),
      );
      await pumpCommandTurns(tester);
      expect(vm.selectedContent, isNull);
      expect(notifications, 0);
      expect(find.text('Contenuto non trovato'), findsOneWidget);
      expect(find.byType(GeoMapModalPost), findsNothing);
      expect(events.getByIdCallCount, 1);
      pending.complete(Result.error(TestException('physical lookup settled')));
      await pumpCommandTurns(tester);
      expect(vm.selectedContent, isNull);
      expect(notifications, 0);
      expect(find.text('Contenuto non trovato'), findsOneWidget);
      expect(events.getByIdCallCount, 1);
      vm.removeListener(observeCommit);
      await tester.pumpWidget(const SizedBox.shrink());
      vm.dispose();
      searches.dispose();
      await tester.pump(const Duration(milliseconds: 50));
      await pumpCommandTurns(tester);
      expect(tester.takeException(), isNull);
    });
  }

  for (final state in ['pending', 'success', 'default_local']) {
    testWidgets(
      'same URI $state retains selection while Weather owner changes',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final pending = Completer<Result<Event>>();
        final events = FakeEventRepository(
          getByIdResults: {1: Result.success(makeEvent())},
        );
        if (state == 'pending') events.pendingGetById[1] = pending;
        final vm = GeoMapViewModel(
          geoMapUseCase: GeoMapUseCase(
            eventRepository: events,
            placeRepository: FakePlaceRepository(),
          ),
        );
        final searches = _buildSearchViewModel();
        final oldWeatherClient = FakeWeatherApiClient(
          result: Result.success(response),
        );
        final oldWeather = buildWeatherViewModel(
          MockLogger(),
          weatherApiClient: oldWeatherClient,
        );
        final weatherOwner = ValueNotifier(oldWeather);
        addTearDown(weatherOwner.dispose);
        await tester.pumpWidget(
          _buildApp(
            favouriteViewModel: _buildFavouriteViewModel(),
            child: ValueListenableBuilder<WeatherViewModel>(
              valueListenable: weatherOwner,
              builder: (_, weather, _) => GeoMapScreen(
                routeSelection: state == 'default_local'
                    ? null
                    : (id: 1, type: ContentType.event),
                viewModel: vm,
                searchViewModel: searches,
                weatherViewModel: weather,
              ),
            ),
          ),
        );
        await pumpCommandTurns(tester);
        if (state != 'pending') await tester.pumpAndSettle();
        if (state == 'default_local') {
          tester
              .widget<GeoMapBottomSheet>(find.byType(GeoMapBottomSheet))
              .onContentPressed(makePlace(remoteId: 2));
          await tester.pumpAndSettle();
        }
        final beforeState = tester.state(find.byType(GeoMapScreen));
        final beforeSnapshot = vm.selectContent.results.value;
        final sheet = tester.widget<GeoMapBottomSheet>(
          find.byType(GeoMapBottomSheet),
        );
        if (state != 'pending') {
          final animation = sheet.controller.animateTo(
            0.7,
            duration: const Duration(milliseconds: 1),
            curve: Curves.linear,
          );
          await tester.pumpAndSettle();
          await animation;
        }
        final newWeatherClient = FakeWeatherApiClient(
          result: Result.success(response),
        );
        final newWeather = buildWeatherViewModel(
          MockLogger(),
          weatherApiClient: newWeatherClient,
        );
        weatherOwner.value = newWeather;
        await pumpCommandTurns(tester);
        expect(tester.state(find.byType(GeoMapScreen)), same(beforeState));
        expect(vm.selectContent.results.value, same(beforeSnapshot));
        expect(events.getByIdCallCount, state == 'default_local' ? 0 : 1);
        expect(() => oldWeather.addListener(() {}), throwsFlutterError);
        if (state == 'pending') {
          expect(find.byType(SliverSkeletonizer), findsOneWidget);
          pending.complete(Result.success(makeEvent()));
        } else {
          expect(find.byType(GeoMapModalPost), findsOneWidget);
          expect(sheet.controller.size, closeTo(0.7, 0.01));
        }
        await tester.pumpAndSettle();
        await pumpCommandTurns(tester);
        expect(newWeather.loadCurrentForecast.results.value.completed, isTrue);
        expect(newWeatherClient.getCombinedWeatherForecastCallCount, 1);
        expect(
          oldWeatherClient.getCombinedWeatherForecastCallCount,
          state == 'pending' ? 0 : 1,
        );
        expect(events.getByIdCallCount, state == 'default_local' ? 0 : 1);
        await tester.pumpWidget(const SizedBox.shrink());
        vm.dispose();
        searches.dispose();
        await tester.pump(const Duration(milliseconds: 50));
        await pumpCommandTurns(tester);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final stale in [false, true]) {
    testWidgets('${stale ? 'stale' : 'latest'} runtime failure reports once '
        'with ${stale ? 'zero stale' : 'one terminal'} feedback', (
      tester,
    ) async {
      final logger = MockLogger();
      addTearDown(installCommandTestReporting(logger));
      final pending = Completer<Result<Event>>();
      final events = FakeEventRepository(
        getByIdResults: {2: Result.success(makeEvent(remoteId: 2))},
      );
      events.pendingGetById[1] = pending;
      final vm = GeoMapViewModel(
        geoMapUseCase: GeoMapUseCase(
          eventRepository: events,
          placeRepository: FakePlaceRepository(),
        ),
      );
      final id = ValueNotifier(1);
      addTearDown(id.dispose);
      final searches = _buildSearchViewModel();
      final weather = _buildWeatherViewModel();
      await tester.pumpWidget(
        _buildApp(
          favouriteViewModel: _buildFavouriteViewModel(),
          child: ValueListenableBuilder<int>(
            valueListenable: id,
            builder: (_, requested, _) => GeoMapScreen(
              routeSelection: (id: requested, type: ContentType.event),
              viewModel: vm,
              searchViewModel: searches,
              weatherViewModel: weather,
            ),
          ),
        ),
      );
      await pumpCommandTurns(tester);
      if (stale) {
        id.value = 2;
        await tester.pumpAndSettle();
      }
      final failure = StateError('repository runtime failure');
      pending.completeError(failure, StackTrace.current);
      await pumpCommandTurns(tester);
      expect(logger.calls, hasLength(1));
      expect(logger.calls.single.error, same(failure));
      expect(
        find.text('Contenuto non trovato'),
        stale ? findsNothing : findsOneWidget,
      );
      expect(vm.selectedContent?.remoteId, stale ? 2 : isNull);
      expect(events.getByIdCallCount, stale ? 2 : 1);
      await tester.pumpWidget(const SizedBox.shrink());
      vm.dispose();
      searches.dispose();
      await tester.pump(const Duration(milliseconds: 50));
      await pumpCommandTurns(tester);
      expect(tester.takeException(), isNull);
    });
  }

  for (final transition in ['search', 'close', 'local_content']) {
    testWidgets(
      'pending route lookup cannot replace local $transition transition',
      (tester) async {
        final pending = Completer<Result<Event>>();
        final events = FakeEventRepository();
        events.pendingGetById[1] = pending;
        final vm = GeoMapViewModel(
          geoMapUseCase: GeoMapUseCase(
            eventRepository: events,
            placeRepository: FakePlaceRepository(),
          ),
        );
        final searches = _buildSearchViewModel();
        await tester.pumpWidget(
          _buildApp(
            favouriteViewModel: _buildFavouriteViewModel(),
            child: GeoMapScreen(
              routeSelection: (id: 1, type: ContentType.event),
              viewModel: vm,
              searchViewModel: searches,
              weatherViewModel: _buildWeatherViewModel(),
            ),
          ),
        );
        await pumpCommandTurns(tester);
        expect(events.getByIdCallCount, 1);
        final sheet = tester.widget<GeoMapBottomSheet>(
          find.byType(GeoMapBottomSheet),
        );
        switch (transition) {
          case 'search':
            tester
                .widget<AnimatedGeoMapSearchBar>(
                  find.byType(AnimatedGeoMapSearchBar),
                )
                .onSubmitted!('molise');
          case 'close':
            sheet.onCloseButtonPressed();
          case 'local_content':
            sheet.onContentPressed(makePlace(remoteId: 2));
        }
        pending.complete(Result.success(makeEvent()));
        await tester.pumpAndSettle();
        if (transition == 'local_content') {
          expect(vm.resolvedContent?.remoteId, 2);
        } else {
          expect(vm.resolvedContent, isNull);
        }
        expect(find.text('Contenuto non trovato'), findsNothing);
        if (transition == 'local_content') {
          expect(
            tester
                .widget<GeoMapModalPost>(find.byType(GeoMapModalPost))
                .content
                .remoteId,
            2,
          );
        } else {
          expect(find.byType(GeoMapModalPost), findsNothing);
        }
        if (transition == 'search') {
          expect(find.byType(GeoMapModalSearchResults), findsOneWidget);
        }
        expect(events.getByIdCallCount, 1);
        await tester.pumpWidget(const SizedBox.shrink());
        vm.dispose();
        searches.dispose();
        await tester.pump(const Duration(milliseconds: 50));
        await pumpCommandTurns(tester);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('same route with replacement selection owner resolves anew', (
    tester,
  ) async {
    final oldEvents = FakeEventRepository();
    final newEvents = FakeEventRepository();
    final oldPending = Completer<Result<Event>>();
    final newPending = Completer<Result<Event>>();
    oldEvents.pendingGetById[1] = oldPending;
    newEvents.pendingGetById[1] = newPending;
    final oldVm = GeoMapViewModel(
      geoMapUseCase: GeoMapUseCase(
        eventRepository: oldEvents,
        placeRepository: FakePlaceRepository(),
      ),
    );
    final newVm = GeoMapViewModel(
      geoMapUseCase: GeoMapUseCase(
        eventRepository: newEvents,
        placeRepository: FakePlaceRepository(),
      ),
    );
    final owner = ValueNotifier(oldVm);
    addTearDown(owner.dispose);
    final searches = _buildSearchViewModel();
    final weather = _buildWeatherViewModel();
    await tester.pumpWidget(
      _buildApp(
        favouriteViewModel: _buildFavouriteViewModel(),
        child: ValueListenableBuilder<GeoMapViewModel>(
          valueListenable: owner,
          builder: (_, vm, _) => GeoMapScreen(
            routeSelection: (id: 1, type: ContentType.event),
            viewModel: vm,
            searchViewModel: searches,
            weatherViewModel: weather,
          ),
        ),
      ),
    );
    await pumpCommandTurns(tester);
    owner.value = newVm;
    await pumpCommandTurns(tester);
    expect(oldEvents.getByIdCallCount, 1);
    expect(newEvents.getByIdCallCount, 1);
    newPending.complete(Result.success(makeEvent(name: 'New owner content')));
    await tester.pumpAndSettle();
    oldPending.complete(Result.error(TestException('old owner')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<GeoMapModalPost>(find.byType(GeoMapModalPost)).content.name,
      'New owner content',
    );
    expect(find.text('Contenuto non trovato'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    oldVm.dispose();
    newVm.dispose();
    searches.dispose();
    await tester.pump(const Duration(milliseconds: 50));
    await pumpCommandTurns(tester);
    await pumpCommandTurns(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'content resolution is safe while the sheet controller attaches',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final event = makeEvent();
      final geoMapViewModel = GeoMapViewModel(
        geoMapUseCase: GeoMapUseCase(
          eventRepository: FakeEventRepository(
            getByIdResults: {event.remoteId: Result.success(event)},
          ),
          placeRepository: FakePlaceRepository(),
        ),
      );
      final searchViewModel = SearchViewModel(
        searchRepository: _FakeSearchRepository(),
      );
      final weatherViewModel = _buildWeatherViewModel();
      final favouriteViewModel = FavouriteViewModel(
        favouriteGetIdsUseCase: FavouriteGetIdsUseCase(
          eventRepository: FakeEventRepository(
            getByIdResults: {event.remoteId: Result.success(event)},
          ),
          placeRepository: FakePlaceRepository(),
        ),
      );
      final contentIdentity = ValueNotifier<({int id, ContentType type})?>(
        null,
      );
      final router = GoRouter(
        routes: <RouteBase>[
          GoRoute(
            path: '/',
            builder: (_, _) =>
                ValueListenableBuilder<({int id, ContentType type})?>(
                  valueListenable: contentIdentity,
                  builder: (_, identity, _) => GeoMapScreen(
                    routeSelection: identity,
                    viewModel: geoMapViewModel,
                    searchViewModel: searchViewModel,
                    weatherViewModel: weatherViewModel,
                  ),
                ),
          ),
        ],
      );
      addTearDown(contentIdentity.dispose);
      addTearDown(router.dispose);

      await tester.pumpWidget(
        Provider<http.Client>.value(
          value: RecordingTileHttpClient(),
          child: ChangeNotifierProvider<FavouriteViewModel>.value(
            value: favouriteViewModel,
            child: MaterialApp.router(routerConfig: router),
          ),
        ),
      );
      await pumpCommandTurns(tester);

      contentIdentity.value = (id: event.remoteId, type: ContentType.event);
      await pumpCommandTurns(tester);
      await pumpCommandTurns(tester);

      await pumpCommandTurns(tester);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpAndSettle();

      await tester.pump(const Duration(milliseconds: 50));
      await pumpCommandTurns(tester);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'selecting a suggestion while a post is selected shows search results',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final event = makeEvent();
      final geoMapViewModel = GeoMapViewModel(
        geoMapUseCase: GeoMapUseCase(
          eventRepository: FakeEventRepository(
            getByIdResults: {event.remoteId: Result.success(event)},
          ),
          placeRepository: FakePlaceRepository(),
        ),
      );
      final searchViewModel = SearchViewModel(
        searchRepository: _FakeSearchRepository(),
      );
      final weatherViewModel = _buildWeatherViewModel();
      final favouriteViewModel = FavouriteViewModel(
        favouriteGetIdsUseCase: FavouriteGetIdsUseCase(
          eventRepository: FakeEventRepository(
            getByIdResults: {event.remoteId: Result.success(event)},
          ),
          placeRepository: FakePlaceRepository(),
        ),
      );
      final router = GoRouter(
        routes: <RouteBase>[
          GoRoute(
            path: '/',
            builder: (_, _) => GeoMapScreen(
              routeSelection: (id: event.remoteId, type: ContentType.event),
              viewModel: geoMapViewModel,
              searchViewModel: searchViewModel,
              weatherViewModel: weatherViewModel,
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        Provider<http.Client>.value(
          value: RecordingTileHttpClient(),
          child: ChangeNotifierProvider<FavouriteViewModel>.value(
            value: favouriteViewModel,
            child: MaterialApp.router(routerConfig: router),
          ),
        ),
      );
      await pumpCommandTurns(tester);
      await tester.pump(const Duration(milliseconds: 1));

      expect(find.byType(GeoMapModalPost), findsOneWidget);

      final searchBar = tester.widget<AnimatedGeoMapSearchBar>(
        find.byType(AnimatedGeoMapSearchBar),
      );
      searchBar.onSuggestionPressed(event);
      await pumpCommandTurns(tester);
      await tester.pump(const Duration(milliseconds: 1));

      await tester.pump(const Duration(milliseconds: 50));
      await pumpCommandTurns(tester);
      expect(tester.takeException(), isNull);
      expect(find.byType(GeoMapModalSearchResults), findsOneWidget);
      expect(find.byType(GeoMapModalPost), findsNothing);
    },
  );

  for (final content in <ContentBase>[makeEvent(), makePlace(remoteId: 2)]) {
    final contentType = content is Event ? 'event' : 'place';
    testWidgets(
      'renders supplied $contentType content without resolving it again',
      (tester) async {
        final sheetController = DraggableScrollableController();
        addTearDown(sheetController.dispose);

        final geoMapViewModel = _buildGeoMapViewModel()..showContent(content);

        await tester.pumpWidget(
          _buildBottomSheetApp(
            favouriteViewModel: _buildFavouriteViewModel(),
            child: GeoMapBottomSheet(
              searchAdmission: null,
              onSearchResultPressed: (_) {},
              onSearchRetryPressed: () {},
              controller: sheetController,
              onCloseButtonPressed: () {},
              onContentPressed: (_) {},
              onVerticalDragUpdate: (_) {},
              viewModel: geoMapViewModel,
              searchViewModel: _buildSearchViewModel(),
              weatherViewModel: _buildWeatherViewModel(),
            ),
          ),
        );
        await pumpCommandTurns(tester);
        await tester.pump(const Duration(milliseconds: 1));

        if (content is Event) {
          expect(geoMapViewModel.selectContent.results.value.idle, isTrue);
        } else {
          expect(geoMapViewModel.selectContent.results.value.idle, isTrue);
        }
        await tester.pump(const Duration(milliseconds: 50));
        await pumpCommandTurns(tester);
        expect(tester.takeException(), isNull);
        expect(find.byType(GeoMapModalPost), findsOneWidget);
        expect(
          tester
              .widget<GeoMapModalPost>(find.byType(GeoMapModalPost))
              .content
              .remoteId,
          content.remoteId,
        );
      },
    );
  }

  testWidgets('resolving selection hides stale content', (tester) async {
    final staleContent = makeEvent();
    final sheetController = DraggableScrollableController();
    final geoMapViewModel = _buildGeoMapViewModel()
      ..showContent(staleContent)
      ..requestSelection(const EventSelection(99));
    addTearDown(sheetController.dispose);

    await tester.pumpWidget(
      _buildBottomSheetApp(
        favouriteViewModel: _buildFavouriteViewModel(),
        child: GeoMapBottomSheet(
          searchAdmission: null,
          onSearchResultPressed: (_) {},
          onSearchRetryPressed: () {},
          controller: sheetController,
          onCloseButtonPressed: () {},
          onContentPressed: (_) {},
          onVerticalDragUpdate: (_) {},
          viewModel: geoMapViewModel,
          searchViewModel: _buildSearchViewModel(),
          weatherViewModel: _buildWeatherViewModel(),
        ),
      ),
    );
    await pumpCommandTurns(tester);

    expect(geoMapViewModel.resolvedContent, isNull);
    expect(find.byType(SliverSkeletonizer), findsOneWidget);
    expect(find.byType(GeoMapModalPost), findsNothing);
    final sheet = tester.widget<GeoMapBottomSheet>(
      find.byType(GeoMapBottomSheet),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    geoMapViewModel.dispose();
    sheet.searchViewModel.dispose();
    sheet.weatherViewModel.dispose();
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('recreates the post when the selected identity changes', (
    tester,
  ) async {
    final first = makeEvent();
    final second = makeEvent(remoteId: 2, name: 'Evento 2');
    final selectedContent = ValueNotifier<ContentBase>(first);
    final sheetController = DraggableScrollableController();
    final geoMapViewModel = _buildGeoMapViewModel()..showContent(first);
    final searchViewModel = _buildSearchViewModel();
    final weatherViewModel = _buildWeatherViewModel();
    addTearDown(selectedContent.dispose);
    addTearDown(sheetController.dispose);

    await tester.pumpWidget(
      _buildBottomSheetApp(
        favouriteViewModel: _buildFavouriteViewModel(),
        child: ValueListenableBuilder<ContentBase>(
          valueListenable: selectedContent,
          builder: (_, content, _) => GeoMapBottomSheet(
            searchAdmission: null,
            onSearchResultPressed: (_) {},
            onSearchRetryPressed: () {},
            controller: sheetController,
            onCloseButtonPressed: () {},
            onContentPressed: (_) {},
            onVerticalDragUpdate: (_) {},
            viewModel: geoMapViewModel,
            searchViewModel: searchViewModel,
            weatherViewModel: weatherViewModel,
          ),
        ),
      ),
    );
    await pumpCommandTurns(tester);

    final firstPost = find.byKey(ValueKey((first.runtimeType, first.remoteId)));
    expect(firstPost, findsOneWidget);
    final firstElement = tester.element(firstPost);

    geoMapViewModel.showContent(second);
    selectedContent.value = second;
    await pumpCommandTurns(tester);

    final secondPost = find.byKey(
      ValueKey((second.runtimeType, second.remoteId)),
    );
    expect(firstPost, findsNothing);
    expect(secondPost, findsOneWidget);
    expect(tester.element(secondPost), isNot(same(firstElement)));
    await tester.pumpWidget(const SizedBox.shrink());
    geoMapViewModel.dispose();
    searchViewModel.dispose();
    weatherViewModel.dispose();
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('explicit close from selected content resets the sheet', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final event = makeEvent();
    final weatherViewModel = _buildWeatherViewModel();
    final favouriteViewModel = _buildFavouriteViewModel(event: event);

    await tester.pumpWidget(
      _buildApp(
        favouriteViewModel: favouriteViewModel,
        child: GeoMapScreen(
          routeSelection: (id: event.remoteId, type: ContentType.event),
          viewModel: _buildGeoMapViewModel(event: event),
          searchViewModel: _buildSearchViewModel(),
          weatherViewModel: weatherViewModel,
        ),
      ),
    );
    await pumpCommandTurns(tester);
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.byType(GeoMapModalPost), findsOneWidget);

    expect(find.byTooltip('Chiudi'), findsOneWidget);
    await tester.tap(find.byTooltip('Chiudi'));
    await tester.pumpAndSettle();

    expect(find.byType(GeoMapModalPost), findsNothing);
    await tester.pump(const Duration(milliseconds: 50));
    await pumpCommandTurns(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('explicit close from search results resets the sheet', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final weatherViewModel = _buildWeatherViewModel();
    final favouriteViewModel = _buildFavouriteViewModel();

    await tester.pumpWidget(
      _buildApp(
        favouriteViewModel: favouriteViewModel,
        child: GeoMapScreen(
          routeSelection: null,
          viewModel: _buildGeoMapViewModel(),
          searchViewModel: _buildSearchViewModel(),
          weatherViewModel: weatherViewModel,
        ),
      ),
    );
    await pumpCommandTurns(tester);
    await tester.pump(const Duration(milliseconds: 1));

    final searchBar = tester.widget<AnimatedGeoMapSearchBar>(
      find.byType(AnimatedGeoMapSearchBar),
    );
    searchBar.onSubmitted!('festival');
    await tester.pumpAndSettle();
    expect(find.byType(GeoMapModalSearchResults), findsOneWidget);

    await tester.tap(find.byTooltip('Indietro'));
    await tester.pumpAndSettle();

    expect(find.byType(GeoMapModalSearchResults), findsNothing);
    await tester.pump(const Duration(milliseconds: 50));
    await pumpCommandTurns(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('system back does not silently reset the sheet', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final event = makeEvent();
    final weatherViewModel = _buildWeatherViewModel();
    final favouriteViewModel = _buildFavouriteViewModel(event: event);

    await tester.pumpWidget(
      _buildApp(
        favouriteViewModel: favouriteViewModel,
        child: GeoMapScreen(
          routeSelection: (id: event.remoteId, type: ContentType.event),
          viewModel: _buildGeoMapViewModel(event: event),
          searchViewModel: _buildSearchViewModel(),
          weatherViewModel: weatherViewModel,
        ),
      ),
    );
    await pumpCommandTurns(tester);
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.byType(GeoMapModalPost), findsOneWidget);

    expect(await tester.binding.handlePopRoute(), isFalse);
    await tester.pumpAndSettle();

    expect(find.byType(GeoMapModalPost), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 50));
    await pumpCommandTurns(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'deep-linked content resolves once and never returns to a skeleton',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final event = makeEvent();
      final eventRepository = ControllableEventRepository();
      final geoMapViewModel = GeoMapViewModel(
        geoMapUseCase: GeoMapUseCase(
          eventRepository: eventRepository,
          placeRepository: FakePlaceRepository(),
        ),
      );

      await tester.pumpWidget(
        _buildApp(
          favouriteViewModel: _buildFavouriteViewModel(),
          child: GeoMapScreen(
            routeSelection: (id: event.remoteId, type: ContentType.event),
            viewModel: geoMapViewModel,
            searchViewModel: _buildSearchViewModel(),
            weatherViewModel: _buildWeatherViewModel(),
          ),
        ),
      );
      await pumpCommandTurns(tester);

      expect(eventRepository.getByIdCallCount, 1);
      expect(eventRepository.pendingGetById, contains(event.remoteId));
      expect(find.byType(SliverSkeletonizer), findsOneWidget);
      expect(find.byType(GeoMapModalPost), findsNothing);

      eventRepository.completeGetById(event.remoteId, Result.success(event));
      await pumpCommandTurns(tester);
      await pumpCommandTurns(tester);
      await tester.pumpAndSettle();

      // A second completion is a no-op because displaying content does not
      // start another show command.
      eventRepository.completeGetById(
        event.remoteId,
        Result.error(TestException('Unexpected second lookup')),
      );
      await pumpCommandTurns(tester);

      expect(eventRepository.getByIdCallCount, 1);
      expect(eventRepository.pendingGetById, isEmpty);
      expect(find.byType(SliverSkeletonizer), findsNothing);
      expect(find.byType(GeoMapModalPost), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 50));
      await pumpCommandTurns(tester);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed deep-link resolution replaces the skeleton with feedback',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final event = makeEvent();
      final eventRepository = ControllableEventRepository();
      final geoMapViewModel = GeoMapViewModel(
        geoMapUseCase: GeoMapUseCase(
          eventRepository: eventRepository,
          placeRepository: FakePlaceRepository(),
        ),
      );

      await tester.pumpWidget(
        _buildApp(
          favouriteViewModel: _buildFavouriteViewModel(),
          child: GeoMapScreen(
            routeSelection: (id: event.remoteId, type: ContentType.event),
            viewModel: geoMapViewModel,
            searchViewModel: _buildSearchViewModel(),
            weatherViewModel: _buildWeatherViewModel(),
          ),
        ),
      );
      await pumpCommandTurns(tester);

      expect(find.byType(SliverSkeletonizer), findsOneWidget);

      eventRepository.completeGetById(
        event.remoteId,
        Result.error(TestException('Event unavailable')),
      );
      await pumpCommandTurns(tester);
      await pumpCommandTurns(tester);

      expect(find.byType(SliverSkeletonizer), findsNothing);
      expect(find.byType(GeoMapModalPost), findsNothing);
      expect(find.text('Contenuto non trovato'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 50));
      await pumpCommandTurns(tester);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'mismatched repository response has zero invalid commit and zero retry',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // The repository returns a different content on success: the exact
      // "wrong id, no error" state that would previously retry forever.
      final event = makeEvent(remoteId: 2, name: 'Evento sbagliato');
      final eventRepository = ControllableEventRepository();
      final geoMapViewModel = GeoMapViewModel(
        geoMapUseCase: GeoMapUseCase(
          eventRepository: eventRepository,
          placeRepository: FakePlaceRepository(),
        ),
      );
      final weatherViewModel = _buildWeatherViewModel();
      final favouriteViewModel = _buildFavouriteViewModel();

      await tester.pumpWidget(
        _buildApp(
          favouriteViewModel: favouriteViewModel,
          child: GeoMapScreen(
            routeSelection: (id: 1, type: ContentType.event),
            viewModel: geoMapViewModel,
            searchViewModel: _buildSearchViewModel(),
            weatherViewModel: weatherViewModel,
          ),
        ),
      );
      await pumpCommandTurns(tester);

      eventRepository.completeGetById(1, Result.success(event));
      await pumpCommandTurns(tester);
      await tester.pump(const Duration(milliseconds: 50));
      await pumpCommandTurns(tester);
      expect(eventRepository.getByIdCallCount, 1);
      expect(geoMapViewModel.selectedContent, isNull);
      expect(find.byType(GeoMapModalPost), findsNothing);
      expect(find.text('Contenuto non trovato'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 50));
      await pumpCommandTurns(tester);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('rapid navigation resolves B before A physically settles', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final first = makeEvent(name: 'Evento 1');
    final second = makeEvent(remoteId: 2, name: 'Evento 2');
    final eventRepository = ControllableEventRepository();
    final geoMapViewModel = GeoMapViewModel(
      geoMapUseCase: GeoMapUseCase(
        eventRepository: eventRepository,
        placeRepository: FakePlaceRepository(),
      ),
    );
    final weatherViewModel = _buildWeatherViewModel();
    final favouriteViewModel = _buildFavouriteViewModel();
    final contentIdentity = ValueNotifier<({int id, ContentType type})?>((
      id: 1,
      type: ContentType.event,
    ));
    addTearDown(contentIdentity.dispose);

    await tester.pumpWidget(
      _buildApp(
        favouriteViewModel: favouriteViewModel,
        child: ValueListenableBuilder<({int id, ContentType type})?>(
          valueListenable: contentIdentity,
          builder: (_, identity, _) => GeoMapScreen(
            routeSelection: identity,
            viewModel: geoMapViewModel,
            searchViewModel: _buildSearchViewModel(),
            weatherViewModel: weatherViewModel,
          ),
        ),
      ),
    );
    await pumpCommandTurns(tester);

    contentIdentity.value = (id: 2, type: ContentType.event);
    await pumpCommandTurns(tester);
    expect(eventRepository.getByIdCallCount, 2);
    eventRepository.completeGetById(1, Result.success(first));
    await pumpCommandTurns(tester);
    expect(eventRepository.getByIdCallCount, 2);
    expect(find.byType(SliverSkeletonizer), findsOneWidget);

    // The new request resolves the requested content. The sheet renders
    // the resolved object directly and never re-executes the show command.
    eventRepository.completeGetById(2, Result.success(second));
    await pumpCommandTurns(tester);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();

    expect(eventRepository.getByIdCallCount, 2);
    expect(find.byType(SliverSkeletonizer), findsNothing);
    expect(
      tester
          .widget<GeoMapModalPost>(find.byType(GeoMapModalPost))
          .content
          .remoteId,
      2,
    );
    expect(find.text('Contenuto non trovato'), findsNothing);
    await tester.pump(const Duration(milliseconds: 50));
    await pumpCommandTurns(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'route removal and disposal produce no controller or setState errors',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final event = makeEvent();
      final weatherViewModel = _buildWeatherViewModel();
      final favouriteViewModel = _buildFavouriteViewModel(event: event);

      await tester.pumpWidget(
        _buildApp(
          favouriteViewModel: favouriteViewModel,
          child: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () async {
                    await Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => GeoMapScreen(
                          routeSelection: (
                            id: event.remoteId,
                            type: ContentType.event,
                          ),
                          viewModel: _buildGeoMapViewModel(event: event),
                          searchViewModel: _buildSearchViewModel(),
                          weatherViewModel: weatherViewModel,
                        ),
                      ),
                    );
                  },
                  child: const Text('Open map'),
                ),
              ),
            ),
          ),
        ),
      );
      await pumpCommandTurns(tester);

      await tester.tap(find.text('Open map'));
      await tester.pumpAndSettle();
      expect(find.byType(GeoMapModalPost), findsOneWidget);

      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();

      expect(find.byType(GeoMapModalPost), findsNothing);
      expect(find.text('Open map'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 50));
      await pumpCommandTurns(tester);
      expect(tester.takeException(), isNull);
    },
  );
}

Widget _buildApp({
  required FavouriteViewModel favouriteViewModel,
  required Widget child,
}) {
  final router = GoRouter(
    routes: <RouteBase>[GoRoute(path: '/', builder: (_, _) => child)],
  );
  addTearDown(router.dispose);
  return Provider<http.Client>.value(
    value: RecordingTileHttpClient(),
    child: ChangeNotifierProvider<FavouriteViewModel>.value(
      value: favouriteViewModel,
      child: MaterialApp.router(
        scaffoldMessengerKey: $scaffoldMessengerKey,
        routerConfig: router,
      ),
    ),
  );
}

Widget _buildBottomSheetApp({
  required FavouriteViewModel favouriteViewModel,
  required Widget child,
}) {
  return ChangeNotifierProvider<FavouriteViewModel>.value(
    value: favouriteViewModel,
    child: MaterialApp(
      home: Scaffold(body: SizedBox(height: 800, child: child)),
    ),
  );
}

GeoMapViewModel _buildGeoMapViewModel({Event? event}) {
  return GeoMapViewModel(
    geoMapUseCase: GeoMapUseCase(
      eventRepository: FakeEventRepository(
        getByIdResults: {
          if (event != null) event.remoteId: Result.success(event),
        },
      ),
      placeRepository: FakePlaceRepository(),
    ),
  );
}

SearchViewModel _buildSearchViewModel() {
  return SearchViewModel(searchRepository: _FakeSearchRepository());
}

FavouriteViewModel _buildFavouriteViewModel({Event? event}) {
  return FavouriteViewModel(
    favouriteGetIdsUseCase: FavouriteGetIdsUseCase(
      eventRepository: FakeEventRepository(
        getByIdResults: {
          if (event != null) event.remoteId: Result.success(event),
        },
      ),
      placeRepository: FakePlaceRepository(),
    ),
  );
}

WeatherViewModel _buildWeatherViewModel() {
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
    logger: MockLogger(),
  );

  return WeatherViewModel(
    weatherApiClient: weatherApiClient,
    weatherDescriptionMapper: const WmoWeatherDescriptionMapper(),
    weatherCodeIconMapper: const WmoWeatherIconMapper(),
  );
}

final class _FakeSearchRepository implements SearchRepository {
  @override
  Future<Result<void>> addToPastSearches(String text) async =>
      const Result.success(null);

  @override
  Future<Result<List<ContentBase>>> getResultsByQuery(String text) async =>
      const Result.success([]);

  @override
  Future<Result<List<String>>> getPastSearches() async =>
      const Result.success([]);

  @override
  Future<Result<void>> removeFromPastSearches(String text) async =>
      const Result.success(null);
}
