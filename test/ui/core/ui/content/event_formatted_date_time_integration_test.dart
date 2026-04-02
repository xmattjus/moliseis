// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:latlong2/latlong.dart';
import 'package:moliseis/data/sources/city.dart';
import 'package:moliseis/data/sources/event.dart';
import 'package:moliseis/data/sources/media.dart';
import 'package:moliseis/data/sources/place.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/content_sort.dart';
import 'package:moliseis/domain/models/event_content.dart';
import 'package:moliseis/domain/repositories/event_repository.dart';
import 'package:moliseis/domain/repositories/place_repository.dart';
import 'package:moliseis/domain/use-cases/favourite/favourite_get_ids_use_case.dart';
import 'package:moliseis/ui/core/ui/content/content_event_card_grid_item.dart';
import 'package:moliseis/ui/core/ui/content/content_sliver_grid.dart';
import 'package:moliseis/ui/event/widgets/components/event_formatted_date_time.dart';
import 'package:moliseis/ui/favourite/view_models/favourite_view_model.dart';
import 'package:moliseis/ui/search/widgets/components/search_anchor_suggestion_list.dart';
import 'package:moliseis/utils/result.dart';
import 'package:objectbox/objectbox.dart';
import 'package:provider/provider.dart';

void main() {
  late FavouriteViewModel favouriteViewModel;

  setUpAll(() async {
    await initializeDateFormatting('en');

    favouriteViewModel = FavouriteViewModel(
      favouriteGetIdsUseCase: FavouriteGetIdsUseCase(
        eventRepository: _FakeEventRepository(),
        placeRepository: _FakePlaceRepository(),
      ),
    );
  });

  group('EventFormattedDateTime integrations', () {
    testWidgets('is used by compact ContentSliverGrid for EventContent', (
      WidgetTester tester,
    ) async {
      final event = _buildEventContent(
        startDate: DateTime(2026, 4, 10, 10, 15),
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<FavouriteViewModel>.value(
          value: favouriteViewModel,
          child: MaterialApp(
            locale: const Locale('en'),
            home: MediaQuery(
              data: const MediaQueryData(size: Size(390, 844)),
              child: Scaffold(
                body: CustomScrollView(
                  slivers: <Widget>[
                    ContentSliverGrid(<EventContent>[event], onPressed: (_) {}),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(EventFormattedDateTime), findsOneWidget);
    });

    testWidgets('is used by ContentEventCardGridItem trailing content', (
      WidgetTester tester,
    ) async {
      final event = _buildEventContent(
        startDate: DateTime(2026, 4, 10, 10, 15),
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<FavouriteViewModel>.value(
          value: favouriteViewModel,
          child: MaterialApp(
            locale: const Locale('en'),
            home: Scaffold(
              body: ContentEventCardGridItem(event: event, onPressed: (_) {}),
            ),
          ),
        ),
      );

      expect(find.byType(EventFormattedDateTime), findsOneWidget);
    });

    testWidgets('is used by SearchAnchorSuggestionList for EventContent', (
      WidgetTester tester,
    ) async {
      final event = _buildEventContent(
        startDate: DateTime(2026, 4, 10, 10, 15),
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<FavouriteViewModel>.value(
          value: favouriteViewModel,
          child: MaterialApp(
            locale: const Locale('en'),
            home: Scaffold(
              body: SearchAnchorSuggestionList(
                suggestions: <EventContent>[event],
                onSuggestionPressed: (_) {},
              ),
            ),
          ),
        ),
      );

      expect(find.byType(EventFormattedDateTime), findsOneWidget);
    });
  });
}

class _FakeEventRepository extends EventRepository {
  @override
  Future<Result<List<Event>>> getByCategories(
    Set<ContentCategory> categories, {
    ContentSort sort = ContentSort.byName,
  }) async => const Result.success(<Event>[]);

  @override
  Future<Result<List<Event>>> getByCoordinates(
    List<double> coordinates,
  ) async => const Result.success(<Event>[]);

  @override
  Future<Result<List<Event>>> getByCurrentYear() async =>
      const Result.success(<Event>[]);

  @override
  Future<Result<List<Event>>> getByDate(DateTime date) async =>
      const Result.success(<Event>[]);

  @override
  Future<Result<List<Event>>> getByDateRange(
    DateTime start,
    DateTime end,
  ) async => const Result.success(<Event>[]);

  @override
  Future<Result<Event>> getById(int id) async =>
      Result.error(Exception('Not used in this test'));

  @override
  Future<Result<List<int>>> getFavouriteEventIds() async =>
      const Result.success(<int>[]);

  @override
  Future<Result<List<int>>> getNextEventIds() async =>
      const Result.success(<int>[]);

  @override
  Future<Result<void>> setFavouriteEvent(int id, bool save) async =>
      const Result.success(null);

  @override
  Future<Result<void>> synchronize() async => const Result.success(null);
}

class _FakePlaceRepository extends PlaceRepository {
  @override
  Future<Result<List<Place>>> getAll({
    ContentSort sort = ContentSort.byName,
  }) async => const Result.success(<Place>[]);

  @override
  Future<Result<List<Place>>> getByCategories(
    Set<ContentCategory> categories, {
    ContentSort sort = ContentSort.byName,
  }) async => const Result.success(<Place>[]);

  @override
  Future<Result<List<Place>>> getByCoordinates(
    List<double> coordinates,
  ) async => const Result.success(<Place>[]);

  @override
  Future<Result<Place>> getById(int id) async =>
      Result.error(Exception('Not used in this test'));

  @override
  Future<Result<List<int>>> getFavouritePlaceIds() async =>
      const Result.success(<int>[]);

  @override
  Future<Result<List<int>>> getIdsByCoordinates(
    List<double> coordinates,
  ) async => const Result.success(<int>[]);

  @override
  Future<Result<List<int>>> getLatestPlaceIds() async =>
      const Result.success(<int>[]);

  @override
  Future<Result<List<int>>> getSuggestedPlaceIds() async =>
      const Result.success(<int>[]);

  @override
  Future<Result<void>> setFavouritePlace(int id, bool save) async =>
      const Result.success(null);

  @override
  Future<Result<void>> synchronize() async => const Result.success(null);
}

EventContent _buildEventContent({
  required DateTime startDate,
  DateTime? endDate,
}) {
  return EventContent(
    category: ContentCategory.experience,
    city: ToOne<City>(),
    coordinates: const LatLng(0.0, 0.0),
    createdAt: DateTime(2026, 1, 1),
    description: 'Test event',
    media: ToMany<Media>(),
    modifiedAt: DateTime(2026, 1, 1),
    name: 'Event',
    remoteId: 1,
    isSaved: false,
    startDate: startDate,
    endDate: endDate,
  );
}
