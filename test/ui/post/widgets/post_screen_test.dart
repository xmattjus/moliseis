import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/domain/models/event.dart';
import 'package:moliseis/domain/models/place.dart';
import 'package:moliseis/domain/use-cases/favourite_get_ids_use_case.dart';
import 'package:moliseis/domain/use-cases/post_use_case.dart';
import 'package:moliseis/ui/event/widgets/components/event_formatted_date_time.dart';
import 'package:moliseis/ui/favourite/view_models/favourite_view_model.dart';
import 'package:moliseis/ui/post/view_models/post_view_model.dart';
import 'package:moliseis/ui/post/widgets/post_screen.dart';
import 'package:moliseis/utils/result.dart';
import 'package:provider/provider.dart';

import '../../../support/fake_repositories.dart';
import '../../../support/fixtures.dart';
import '../../../support/mock_logger.dart';
import '../../../support/recording_tile_http_client.dart';
import '../../../support/weather_harness.dart';

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
      final weatherViewModel = buildWeatherViewModel(mockLogger);
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
      final weatherViewModel = buildWeatherViewModel(mockLogger);
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

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<FavouriteViewModel>.value(
        value: favouriteViewModel,
      ),
      Provider<http.Client>.value(value: RecordingTileHttpClient()),
    ],
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

Event _buildEvent() {
  final event = makeEvent(
    startDate: DateTime(2026, 4, 10, 10, 30),
    endDate: DateTime(2026, 4, 10, 12),
  );

  return Event(
    category: event.category,
    city: event.city,
    coordinates: event.coordinates,
    createdAt: event.createdAt,
    description: event.description,
    media: const [],
    modifiedAt: event.modifiedAt,
    name: event.name,
    remoteId: event.remoteId,
    isSaved: event.isSaved,
    startDate: event.startDate,
    endDate: event.endDate,
  );
}

Place _buildPlace() => makePlace(remoteId: 2);
