import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/domain/models/place.dart';
import 'package:moliseis/domain/use-cases/favourite_get_ids_use_case.dart';
import 'package:moliseis/domain/use-cases/geo_map_use_case.dart';
import 'package:moliseis/ui/core/ui/content/content_base_card_grid_item.dart';
import 'package:moliseis/ui/core/ui/content/nearby_content_horizontal_list.dart';
import 'package:moliseis/ui/core/ui/skeletons/skeleton_content_grid_item.dart';
import 'package:moliseis/ui/favourite/view_models/favourite_view_model.dart';
import 'package:moliseis/ui/geo_map/view_models/geo_map_view_model.dart';
import 'package:moliseis/ui/geo_map/widgets/geo_map_modal_explore.dart';
import 'package:moliseis/ui/geo_map/widgets/geo_map_modal_post.dart';
import 'package:moliseis/ui/post/widgets/components/post_section_nearby_content.dart';
import 'package:moliseis/utils/result.dart';

import '../../../../support/command_test_support.dart';
import '../../../../support/fake_repositories.dart';
import '../../../../support/favourite_button_harness.dart';
import '../../../../support/fixtures.dart';
import '../../../../support/mock_logger.dart';
import '../../../../support/weather_harness.dart';

void main() {
  testWidgets(
    'neutral, empty success, runtime failure and retry stay distinct',
    (tester) async {
      final state = ValueNotifier<NearbyContentPresentation>((
        pending: true,
        items: const <ContentBase>[],
        error: null,
      ));
      final favourites = FavouriteViewModel(
        favouriteGetIdsUseCase: FavouriteGetIdsUseCase(
          eventRepository: FakeEventRepository(),
          placeRepository: FakePlaceRepository(),
        ),
      );
      addTearDown(state.dispose);
      addTearDown(favourites.dispose);
      var loads = 0;
      var retries = 0;
      await tester.pumpWidget(
        favouriteButtonHarness(
          viewModel: favourites,
          child: NearbyContentHorizontalList(
            loadListenable: state,
            loadKey: 'A',
            onLoad: () => loads++,
            readState: () => state.value,
            onRetry: () => retries++,
            onPressed: (_) {},
          ),
        ),
      );
      expect(loads, 1);
      expect(find.byType(SkeletonContentGridItem), findsWidgets);
      expect(find.text('Nessun luogo trovato nelle vicinanze.'), findsNothing);
      state.value = (pending: false, items: const <ContentBase>[], error: null);
      await tester.pump();
      expect(
        find.text('Nessun luogo trovato nelle vicinanze.'),
        findsOneWidget,
      );
      state.value = (
        pending: false,
        items: const <ContentBase>[],
        error: StateError('runtime'),
      );
      await tester.pump();
      expect(find.byType(SkeletonContentGridItem), findsNothing);
      expect(find.text('Nessun luogo trovato nelle vicinanze.'), findsNothing);
      expect(find.text('Riprova'), findsOneWidget);
      await tester.tap(find.text('Riprova'));
      expect(retries, 1);
      expect(loads, 1);
      await pumpCommandTurns(tester);
    },
  );

  testWidgets('deferred load uses only the latest '
      'owner and target', (tester) async {
    final first = ValueNotifier<NearbyContentPresentation>((
      pending: false,
      items: const <ContentBase>[],
      error: null,
    ));
    final second = ValueNotifier<NearbyContentPresentation>(first.value);
    final binding = ValueNotifier((owner: first, target: 'A'));
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    addTearDown(binding.dispose);
    final admitted = <String>[];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      binding.value = (owner: second, target: 'B');
      // Rebind while the original load callback is still in this frame's queue.
      tester.binding.buildOwner!.buildScope(tester.binding.rootElement!);
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder(
            valueListenable: binding,
            builder: (_, value, _) => NearbyContentHorizontalList(
              loadListenable: value.owner,
              loadKey: (value.owner, value.target),
              onLoad: () => admitted.add(value.target),
              readState: () => value.owner.value,
              onPressed: (_) {},
            ),
          ),
        ),
      ),
    );
    expect(admitted, ['B']);
    await tester.pump();
    expect(admitted, ['B']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unmount before deferred load admits no request', (tester) async {
    final state = ValueNotifier<NearbyContentPresentation>((
      pending: false,
      items: const <ContentBase>[],
      error: null,
    ));
    final visible = ValueNotifier(true);
    addTearDown(state.dispose);
    addTearDown(visible.dispose);
    var loads = 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      visible.value = false;
      tester.binding.buildOwner!.buildScope(tester.binding.rootElement!);
      tester.binding.buildOwner!.finalizeTree();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder(
            valueListenable: visible,
            builder: (_, show, _) => show
                ? NearbyContentHorizontalList(
                    loadListenable: state,
                    loadKey: 'A',
                    onLoad: () => loads++,
                    readState: () => state.value,
                    onPressed: (_) {},
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ),
    );
    expect(loads, 0);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Map Nearby projects partial first error and target-checked retry',
    (tester) async {
      final original = TestException('events');
      final firstError = TestException('places');
      final events = FakeEventRepository(
        getByCoordinatesResult: Result.error(original),
      );
      final places = FakePlaceRepository(
        getByCoordinatesResult: Result.success([makePlace()]),
      );
      final vm = GeoMapViewModel(
        geoMapUseCase: GeoMapUseCase(
          eventRepository: events,
          placeRepository: places,
        ),
      );
      final favourites = FavouriteViewModel(
        favouriteGetIdsUseCase: FavouriteGetIdsUseCase(
          eventRepository: events,
          placeRepository: places,
        ),
      );
      await tester.pumpWidget(
        favouriteButtonHarness(
          viewModel: favourites,
          child: CustomScrollView(
            slivers: [
              GeoMapModalExplore(viewModel: vm, onNearContentPressed: (_) {}),
            ],
          ),
        ),
      );
      expect(find.byType(SkeletonContentGridItem), findsWidgets);
      await pumpCommandTurns(tester);
      final nearby = tester.widget<NearbyContentHorizontalList>(
        find.byType(NearbyContentHorizontalList),
      );
      expect(nearby.readState().error, same(original));
      expect(nearby.readState().items, hasLength(1));
      expect(find.byType(ContentBaseCardGridItem), findsOneWidget);
      expect(find.text('Riprova'), findsOneWidget);
      places.getByCoordinatesResult = Result.error(firstError);
      await tester.tap(find.text('Riprova'));
      expect(nearby.readState().pending, isTrue);
      await pumpCommandTurns(tester);
      expect(nearby.readState().error, same(firstError));
      expect(nearby.readState().items, isEmpty);
      expect(find.byType(ContentBaseCardGridItem), findsNothing);
      expect(find.text('Riprova'), findsOneWidget);
      final calls = places.getByCoordinatesCallCount;
      vm.showContent(makePlace(remoteId: 2, coordinates: const LatLng(42, 15)));
      nearby.onRetry!();
      nearby.onLoad();
      await pumpCommandTurns(tester);
      expect(places.getByCoordinatesCallCount, calls);
      expect(nearby.readState().pending, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      vm.dispose();
      favourites.dispose();
      await pumpCommandTurns(tester);
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Map runtime terminal projects error and invalid target stays pending',
    (tester) async {
      final logger = MockLogger();
      addTearDown(installCommandTestReporting(logger));
      final pending = Completer<Result<List<Place>>>();
      final events = FakeEventRepository();
      final places = FakePlaceRepository()..pendingGetByCoordinates = pending;
      final vm = GeoMapViewModel(
        geoMapUseCase: GeoMapUseCase(
          eventRepository: events,
          placeRepository: places,
        ),
      );
      final favourites = FavouriteViewModel(
        favouriteGetIdsUseCase: FavouriteGetIdsUseCase(
          eventRepository: events,
          placeRepository: places,
        ),
      );
      final anchor = ValueNotifier(const LatLng(41, 14));
      vm.showExplore(anchor.value);
      await tester.pumpWidget(
        favouriteButtonHarness(
          viewModel: favourites,
          child: ValueListenableBuilder(
            valueListenable: anchor,
            builder: (_, _, _) => CustomScrollView(
              slivers: [
                GeoMapModalExplore(viewModel: vm, onNearContentPressed: (_) {}),
              ],
            ),
          ),
        ),
      );
      await pumpCommandTurns(tester);
      final error = StateError('runtime');
      pending.completeError(error);
      await pumpCommandTurns(tester);
      final nearby = tester.widget<NearbyContentHorizontalList>(
        find.byType(NearbyContentHorizontalList),
      );
      expect(nearby.readState().error, same(error));
      expect(nearby.readState().pending, isFalse);
      expect(find.byType(SkeletonContentGridItem), findsNothing);
      expect(find.text('Riprova'), findsOneWidget);
      final calls = places.getByCoordinatesCallCount;
      vm.showExplore(const LatLng(91, 0));
      anchor.value = const LatLng(91, 0);
      await tester.pump();
      await pumpCommandTurns(tester);
      expect(places.getByCoordinatesCallCount, calls);
      expect(events.getByCoordinatesCallCount, 0);
      final invalid = tester.widget<NearbyContentHorizontalList>(
        find.byType(NearbyContentHorizontalList),
      );
      expect(invalid.readState().pending, isTrue);
      expect(find.text('Nessun luogo trovato nelle vicinanze.'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      vm.dispose();
      favourites.dispose();
      anchor.dispose();
      await pumpCommandTurns(tester);
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Post Nearby old callbacks do not load a replacement Map owner', (
    tester,
  ) async {
    final content = makePlace();
    final firstPlaces = FakePlaceRepository();
    final secondPlaces = FakePlaceRepository();
    final first = GeoMapViewModel(
      geoMapUseCase: GeoMapUseCase(
        eventRepository: FakeEventRepository(),
        placeRepository: firstPlaces,
      ),
    )..showContent(content);
    final second = GeoMapViewModel(
      geoMapUseCase: GeoMapUseCase(
        eventRepository: FakeEventRepository(),
        placeRepository: secondPlaces,
      ),
    )..showContent(content);
    final weather = buildWeatherViewModel(MockLogger());
    final source = ValueNotifier(first);
    final scroll = ScrollController();
    final favourites = FavouriteViewModel(
      favouriteGetIdsUseCase: FavouriteGetIdsUseCase(
        eventRepository: FakeEventRepository(),
        placeRepository: firstPlaces,
      ),
    );
    await tester.pumpWidget(
      favouriteButtonHarness(
        viewModel: favourites,
        child: ValueListenableBuilder(
          valueListenable: source,
          builder: (_, vm, _) => GeoMapModalPost(
            content: content,
            viewModel: vm,
            weatherViewModel: weather,
            scrollController: scroll,
            onCloseButtonPressed: () {},
            onContentPressed: (_) {},
          ),
        ),
      ),
    );
    final old = tester
        .widget<CustomScrollView>(find.byType(CustomScrollView).first)
        .slivers
        .whereType<PostSectionNearbyContent>()
        .single;
    source.value = second;
    await tester.pumpAndSettle();
    final secondCalls = secondPlaces.getByCoordinatesCallCount;
    final firstCalls = firstPlaces.getByCoordinatesCallCount;
    old.onLoad();
    old.onRetry!();
    await tester.pumpAndSettle();
    expect(firstPlaces.getByCoordinatesCallCount, firstCalls);
    expect(secondPlaces.getByCoordinatesCallCount, secondCalls);
    expect(old.readState().pending, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    old.onLoad();
    old.onRetry!();
    expect(old.readState().pending, isTrue);
    first.dispose();
    second.dispose();
    weather.dispose();
    favourites.dispose();
    scroll.dispose();
    source.dispose();
    await pumpCommandTurns(tester);
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.takeException(), isNull);
  });

  testWidgets('partial collection and original error render together', (
    tester,
  ) async {
    final failure = TestException('first');
    final place = makePlace();
    final state = ValueNotifier<NearbyContentPresentation>((
      pending: false,
      items: <ContentBase>[place],
      error: failure,
    ));
    final favourites = FavouriteViewModel(
      favouriteGetIdsUseCase: FavouriteGetIdsUseCase(
        eventRepository: FakeEventRepository(),
        placeRepository: FakePlaceRepository(),
      ),
    );
    addTearDown(state.dispose);
    addTearDown(favourites.dispose);
    var reads = 0;
    await tester.pumpWidget(
      favouriteButtonHarness(
        viewModel: favourites,
        child: NearbyContentHorizontalList(
          loadListenable: state,
          loadKey: 'A',
          onLoad: () {},
          readState: () {
            reads++;
            return state.value;
          },
          onRetry: () {},
          onPressed: (_) {},
        ),
      ),
    );
    expect(find.byType(ContentBaseCardGridItem), findsOneWidget);
    expect(
      find.text('Si è verificato un errore durante il caricamento.'),
      findsOneWidget,
    );
    expect(find.text('Riprova'), findsOneWidget);
    expect(reads, 1);
    state.value = (pending: false, items: <ContentBase>[place], error: null);
    await tester.pump();
    expect(find.byType(ContentBaseCardGridItem), findsOneWidget);
    expect(find.text('Riprova'), findsNothing);
    expect(
      find.text('Si è verificato un errore durante il caricamento.'),
      findsNothing,
    );
    state.value = (pending: true, items: <ContentBase>[place], error: failure);
    await tester.pump();
    expect(find.byType(ContentBaseCardGridItem), findsNothing);
    expect(find.text('Riprova'), findsNothing);
    expect(find.byType(SkeletonContentGridItem), findsWidgets);
    await pumpCommandTurns(tester);
  });

  testWidgets('unchanged key does not reload and changed owner/target does', (
    tester,
  ) async {
    final state = ValueNotifier<NearbyContentPresentation>((
      pending: false,
      items: const <ContentBase>[],
      error: null,
    ));
    addTearDown(state.dispose);
    var loads = 0;
    final key = GlobalKey();
    for (final target in ['A', 'A', 'B', 'A']) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NearbyContentHorizontalList(
              key: key,
              loadListenable: state,
              loadKey: target,
              onLoad: () => loads++,
              readState: () => state.value,
              onPressed: (_) {},
            ),
          ),
        ),
      );
    }
    expect(loads, 3);
    await tester.pumpWidget(const SizedBox.shrink());
    state.value = (pending: true, items: const <ContentBase>[], error: null);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
