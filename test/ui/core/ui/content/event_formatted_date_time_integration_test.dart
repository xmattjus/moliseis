import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
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

  for (final allDay in [false, true]) {
    group('EventFormattedDateTime integrations allDay=$allDay', () {
      testWidgets('is used by compact ContentSliverGrid for EventContent', (
        tester,
      ) async {
        final event = makeEvent(
          allDay: allDay,
          startDate: DateTime.utc(2026, 4, 9, 22),
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
        expect(find.textContaining('00:00'), findsNothing);
        expect(find.text('24 ore'), findsNothing);
        expect(find.text('Tutto il giorno'), findsNothing);
      });

      testWidgets('is used by ContentEventCardGridItem trailing content', (
        tester,
      ) async {
        final event = makeEvent(
          allDay: allDay,
          startDate: DateTime.utc(2026, 4, 9, 22),
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
        expect(find.textContaining('00:00'), findsNothing);
        expect(find.text('24 ore'), findsNothing);
        expect(find.text('Tutto il giorno'), findsNothing);
      });

      testWidgets('is used by SearchAnchorSuggestionList for EventContent', (
        tester,
      ) async {
        final event = makeEvent(
          allDay: allDay,
          startDate: DateTime.utc(2026, 4, 9, 22),
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
        expect(find.textContaining('00:00'), findsNothing);
        expect(find.text('24 ore'), findsNothing);
        expect(find.text('Tutto il giorno'), findsNothing);
      });
    });
  }
}
