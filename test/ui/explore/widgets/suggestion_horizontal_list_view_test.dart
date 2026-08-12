import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:moliseis/domain/models/place.dart';
import 'package:moliseis/domain/use-cases/favourite_get_ids_use_case.dart';
import 'package:moliseis/routing/route_names.dart';
import 'package:moliseis/routing/route_parameters.dart';
import 'package:moliseis/ui/core/ui/custom_ink_well.dart';
import 'package:moliseis/ui/core/ui/empty_view.dart';
import 'package:moliseis/ui/core/ui/text_section_divider.dart';
import 'package:moliseis/ui/explore/view_models/suggestion_view_model.dart';
import 'package:moliseis/ui/explore/widgets/suggestion_horizontal_list_view.dart';
import 'package:moliseis/ui/favourite/view_models/favourite_view_model.dart';
import 'package:moliseis/ui/favourite/widgets/favourite_button.dart';
import 'package:moliseis/utils/result.dart';
import 'package:provider/provider.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../support/fake_repositories.dart';
import '../../../support/fixtures.dart';

void main() {
  group('SuggestiondHorizontalListView', () {
    testWidgets('shows five placeholders while suggestions are loading', (
      tester,
    ) async {
      final response = Completer<Result<List<Place>>>();
      final repository = FakePlaceRepository(
        getSuggestionsHandler: () => response.future,
      );
      final viewModel = SuggestionViewModel(placeRepository: repository);
      final fixture = _buildFixture(viewModel);
      addTearDown(fixture.dispose);

      await tester.pumpWidget(fixture.app);

      expect(viewModel.load.running, isTrue);
      expect(find.text('Suggeriti'), findsOneWidget);
      final listView = tester.widget<ListView>(find.byType(ListView));
      final delegate = listView.childrenDelegate as SliverChildListDelegate;

      // A horizontal ListView lazily materializes only visible children. Its
      // delegate retains the complete placeholder set, independent of viewport
      // and cache extent.
      expect(delegate.children, hasLength(5));
      expect(find.byType(ClipRRect), findsWidgets);
      expect(find.byType(FavouriteButton), findsNothing);

      response.complete(const Result.success([]));
      await tester.pumpAndSettle();
    });

    testWidgets('renders successful suggestions and their favourite controls', (
      tester,
    ) async {
      final suggestions = <Place>[
        makePlace(
          name: 'Castello',
          city: testCity(name: 'Termoli'),
        ),
        makePlace(
          remoteId: 2,
          name: 'Teatro',
          city: testCity(name: 'Isernia'),
        ),
      ];
      final viewModel = SuggestionViewModel(
        placeRepository: FakePlaceRepository(
          getSuggestedPlacesResult: Result.success(suggestions),
        ),
      );
      final fixture = _buildFixture(viewModel);
      addTearDown(fixture.dispose);

      await tester.pumpWidget(fixture.app);
      await tester.pumpAndSettle();

      expect(viewModel.load.completed, isTrue);
      expect(find.byType(TextSectionDivider), findsOneWidget);
      expect(find.text('Suggeriti'), findsOneWidget);
      expect(find.text('Castello'), findsOneWidget);
      expect(find.text('Teatro'), findsOneWidget);
      expect(find.byType(FavouriteButton), findsNWidgets(2));
    });

    testWidgets('shows an intentional empty state after an empty success', (
      tester,
    ) async {
      final viewModel = SuggestionViewModel(
        placeRepository: FakePlaceRepository(),
      );
      final fixture = _buildFixture(viewModel);
      addTearDown(fixture.dispose);

      await tester.pumpWidget(fixture.app);
      await tester.pumpAndSettle();

      expect(viewModel.load.completed, isTrue);
      expect(find.text('Nessun luogo suggerito per ora'), findsOneWidget);
      expect(find.byType(EmptyView), findsOneWidget);
      expect(find.byType(FavouriteButton), findsNothing);
      expect(find.byType(Skeletonizer), findsNothing);
    });

    testWidgets('shows an error and retries the suggestions request', (
      tester,
    ) async {
      final repository = FakePlaceRepository(
        getSuggestedPlacesResult: Result.error(
          TestException('suggestions unavailable'),
        ),
      );
      final viewModel = SuggestionViewModel(placeRepository: repository);
      final fixture = _buildFixture(viewModel);
      addTearDown(fixture.dispose);

      await tester.pumpWidget(fixture.app);
      await tester.pumpAndSettle();

      expect(viewModel.load.error, isTrue);
      expect(
        find.text('Si è verificato un errore durante il caricamento'),
        findsOneWidget,
      );
      expect(find.text('Riprova'), findsOneWidget);
      expect(repository.getSuggestionsCallCount, 1);

      repository.getSuggestedPlacesResult = Result.success([
        makePlace(remoteId: 9, name: 'Abbazia'),
      ]);
      await tester.tap(find.text('Riprova'));
      await tester.pumpAndSettle();

      expect(repository.getSuggestionsCallCount, 2);
      expect(viewModel.load.completed, isTrue);
      expect(find.text('Abbazia'), findsOneWidget);
      expect(find.text('Riprova'), findsNothing);
    });

    testWidgets('navigates to the selected place with canonical parameters', (
      tester,
    ) async {
      final place = makePlace(remoteId: 42, name: 'Santuario');
      final viewModel = SuggestionViewModel(
        placeRepository: FakePlaceRepository(
          getSuggestedPlacesResult: Result.success([place]),
        ),
      );
      final fixture = _buildFixture(viewModel);
      addTearDown(fixture.dispose);

      await tester.pumpWidget(fixture.app);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(CustomInkWell));
      await tester.pumpAndSettle();

      final uri = fixture.router.routeInformationProvider.value.uri;
      expect(uri.path, '/posts/${place.remoteId}');
      expect(uri.queryParameters['type'], RouteParameters.placeType);
      expect(find.text('Post ${place.remoteId}'), findsOneWidget);
    });
  });
}

final class _SuggestionFixture {
  _SuggestionFixture({
    required this.app,
    required this.favouriteViewModel,
    required this.router,
    required this.suggestionViewModel,
  });

  final Widget app;
  final FavouriteViewModel favouriteViewModel;
  final GoRouter router;
  final SuggestionViewModel suggestionViewModel;

  void dispose() {
    router.dispose();
    favouriteViewModel.dispose();
    suggestionViewModel.dispose();
  }
}

_SuggestionFixture _buildFixture(SuggestionViewModel suggestionViewModel) {
  final favouriteViewModel = FavouriteViewModel(
    favouriteGetIdsUseCase: FavouriteGetIdsUseCase(
      eventRepository: FakeEventRepository(),
      placeRepository: FakePlaceRepository(),
    ),
  );
  final router = GoRouter(
    initialLocation: '/',
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(
          body: CustomScrollView(
            slivers: <Widget>[
              SuggestiondHorizontalListView(viewModel: suggestionViewModel),
            ],
          ),
        ),
      ),
      GoRoute(
        path: '/posts/:id',
        name: RouteNames.homePost,
        builder: (_, state) => Scaffold(
          body: Center(child: Text('Post ${state.pathParameters['id']}')),
        ),
      ),
    ],
  );

  return _SuggestionFixture(
    app: ChangeNotifierProvider<FavouriteViewModel>.value(
      value: favouriteViewModel,
      child: MaterialApp.router(routerConfig: router),
    ),
    favouriteViewModel: favouriteViewModel,
    router: router,
    suggestionViewModel: suggestionViewModel,
  );
}
