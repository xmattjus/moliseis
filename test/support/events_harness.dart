import 'dart:async' show unawaited;

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/config/dependencies.dart';
import 'package:moliseis/domain/repositories/event_repository.dart';
import 'package:moliseis/domain/repositories/place_repository.dart';
import 'package:moliseis/domain/repositories/search_repository.dart';
import 'package:moliseis/domain/use-cases/favourite_get_ids_use_case.dart';
import 'package:moliseis/domain/use-cases/sync_use_case.dart';
import 'package:moliseis/routing/router.dart';
import 'package:moliseis/ui/admin/auth/view_models/admin_auth_view_model.dart';
import 'package:moliseis/ui/event/view_models/event_view_model.dart';
import 'package:moliseis/ui/event/widgets/events_screen.dart';
import 'package:moliseis/ui/favourite/view_models/favourite_view_model.dart';
import 'package:moliseis/ui/sync/view_models/sync_view_model.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'fake_repositories.dart';
import 'mock_gotrue_client.dart';

/// Reproduces the production Provider ownership of [EventsScreen].
final class EventsProviderHarness {
  EventsProviderHarness({required this.repository, DateTime Function()? nowUtc})
    : _nowUtc = nowUtc;

  final FakeEventRepository repository;
  final DateTime Function()? _nowUtc;
  late EventViewModel _viewModel;

  /// The route-scoped ViewModel after the Provider has been mounted.
  EventViewModel get viewModel => _viewModel;

  /// Builds the exact production ownership chain around [EventsScreen].
  Widget get app => MaterialApp(
    locale: const Locale('en'),
    home: ChangeNotifierProvider<FavouriteViewModel>(
      create: (_) => FavouriteViewModel(
        favouriteGetIdsUseCase: FavouriteGetIdsUseCase(
          eventRepository: repository,
          placeRepository: FakePlaceRepository(),
        ),
      ),
      child: ChangeNotifierProvider<EventViewModel>(
        create: (_) {
          final viewModel = EventViewModel(
            repository: repository,
            nowUtc: _nowUtc,
          );
          unawaited(
            viewModel.loadByDate.execute(viewModel.currentCalendarDate),
          );
          _viewModel = viewModel;
          return viewModel;
        },
        child: Consumer<EventViewModel>(
          builder: (_, viewModel, _) => EventsScreen(viewModel: viewModel),
        ),
      ),
    ),
  );
}

/// Production-router fixture for Events branch navigation tests.
final class EventsRouteHarness {
  EventsRouteHarness({required this.eventRepository}) {
    final settingsRepository = FakeSettingsRepository(
      lastSyncedAt: DateTime.now(),
    );
    syncViewModel = SyncViewModel(
      syncUseCase: SyncUseCase(
        cityRepository: FakeCityRepository(),
        eventRepository: FakeEventRepository(),
        mediaRepository: FakeMediaRepository(),
        placeRepository: FakePlaceRepository(),
        settingsRepository: settingsRepository,
        transactionCoordinator: FakeTransactionCoordinator(),
      ),
    );
    auth = ControllableAdminAuth();
    router = buildAppRouter(
      syncViewModel: syncViewModel,
      adminAuthViewModel: auth.viewModel,
    );
  }

  final FakeEventRepository eventRepository;
  late final ControllableAdminAuth auth;
  late final SyncViewModel syncViewModel;
  late final GoRouter router;

  /// Builds the production router with the dependencies needed by the Explore
  /// and Events branches.
  Widget get app {
    final placeRepository = FakePlaceRepository();

    return MultiProvider(
      providers: <SingleChildWidget>[
        Provider<EventRepository>.value(value: eventRepository),
        Provider<PlaceRepository>.value(value: placeRepository),
        Provider<SearchRepository>.value(value: FakeSearchRepository()),
        ChangeNotifierProvider<FavouriteViewModel>(
          create: (_) => FavouriteViewModel(
            favouriteGetIdsUseCase: FavouriteGetIdsUseCase(
              eventRepository: eventRepository,
              placeRepository: placeRepository,
            ),
          ),
        ),
        ChangeNotifierProvider<SyncViewModel>.value(value: syncViewModel),
        ChangeNotifierProvider<AdminAuthViewModel>.value(value: auth.viewModel),
      ],
      child: MaterialApp.router(
        scaffoldMessengerKey: $scaffoldMessengerKey,
        locale: const Locale('en'),
        routerConfig: router,
      ),
    );
  }

  void dispose() {
    router.dispose();
    auth.dispose();
    syncViewModel.dispose();
  }
}
