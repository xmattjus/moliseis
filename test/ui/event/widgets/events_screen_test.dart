import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:moliseis/domain/core/event_time.dart';
import 'package:moliseis/domain/use-cases/favourite_get_ids_use_case.dart';
import 'package:moliseis/ui/event/view_models/event_view_model.dart';
import 'package:moliseis/ui/event/widgets/events_screen.dart';
import 'package:moliseis/ui/favourite/view_models/favourite_view_model.dart';
import 'package:moliseis/utils/result.dart';
import 'package:provider/provider.dart';

import '../../../support/fake_repositories.dart';
import '../../../support/fixtures.dart';

void main() {
  setUpAll(() => initializeDateFormatting('en'));

  testWidgets('loads the current Europe/Rome calendar day on initialization', (
    tester,
  ) async {
    final repository = FakeEventRepository(
      getByDateResult: Result.success([
        makeEvent(startDate: DateTime.utc(2026, 1, 10, 23, 30)),
      ]),
    );
    final viewModel = EventViewModel(
      repository: repository,
      nowUtc: () => DateTime.utc(2026, 1, 10, 23, 30),
    );
    final favouriteViewModel = FavouriteViewModel(
      favouriteGetIdsUseCase: FavouriteGetIdsUseCase(
        eventRepository: FakeEventRepository(),
        placeRepository: FakePlaceRepository(),
      ),
    );
    addTearDown(favouriteViewModel.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<FavouriteViewModel>.value(
        value: favouriteViewModel,
        child: MaterialApp(
          locale: const Locale('en'),
          home: EventsScreen(viewModel: viewModel),
        ),
      ),
    );
    await tester.pump();

    expect(viewModel.selectedDate, EventCalendarDate(2026, 1, 11));
    expect(repository.getByDateCallCount, 1);
    expect(viewModel.byMonth, hasLength(1));
  });
}
