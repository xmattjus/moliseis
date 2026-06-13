import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:latlong2/latlong.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/event.dart';
import 'package:moliseis/domain/use-cases/favourite_get_ids_use_case.dart';
import 'package:moliseis/ui/core/ui/content/content_event_card_grid_item.dart';
import 'package:moliseis/ui/core/ui/content/content_sliver_grid.dart';
import 'package:moliseis/ui/event/widgets/components/event_formatted_date_time.dart';
import 'package:moliseis/ui/favourite/view_models/favourite_view_model.dart';
import 'package:moliseis/ui/search/widgets/components/search_anchor_suggestion_list.dart';
import 'package:provider/provider.dart';

import '../../../../support/fake_repositories.dart';
import '../../../../support/fixtures.dart';

void main() {
  late FavouriteViewModel favouriteViewModel;

  setUpAll(() async {
    await initializeDateFormatting('en');

    favouriteViewModel = FavouriteViewModel(
      favouriteGetIdsUseCase: FavouriteGetIdsUseCase(
        eventRepository: FakeEventRepository(),
        placeRepository: FakePlaceRepository(),
      ),
    );
  });

  group('EventFormattedDateTime integrations', () {
    testWidgets('is used by compact ContentSliverGrid for EventContent', (
      tester,
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
                    ContentSliverGrid(<Event>[event], onPressed: (_) {}),
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
      tester,
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
      tester,
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
                suggestions: <Event>[event],
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

Event _buildEventContent({required DateTime startDate, DateTime? endDate}) {
  return makeEvent(
    startDate: startDate,
    endDate: endDate,
    description: 'Test event',
    category: ContentCategory.experience,
    coordinates: const LatLng(0, 0),
  );
}
