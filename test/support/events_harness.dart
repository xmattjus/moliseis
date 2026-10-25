import 'dart:async';

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
          viewModel.selectDate(viewModel.currentCalendarDate);
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
  EventsRouteHarness({
    required this.eventRepository,
    FakePlaceRepository? placeRepository,
  }) : placeRepository = placeRepository ?? FakePlaceRepository() {
    final settingsRepository = FakeSettingsRepository(
      lastSyncedAt: DateTime.now(),
      contentSyncCursorAt: DateTime.utc(2026, 10, 12),
    );
    syncViewModel = SyncViewModel(
      syncUseCase: SyncUseCase(
        cityRepository: FakeCityRepository(),
        eventRepository: FakeEventRepository(),
        mediaRepository: FakeMediaRepository(),
        placeRepository: FakePlaceRepository(),
        settingsRepository: settingsRepository,
        cursorSource: FakeSyncCursorSource(),
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
  final FakePlaceRepository placeRepository;
  late final ControllableAdminAuth auth;
  late final SyncViewModel syncViewModel;
  late final GoRouter router;

  /// Builds the production router with the dependencies needed by the Explore
  /// and Events branches.
  Widget get app {
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

/// Waits for the current day intent, including deferred public terminal
/// delivery.
Future<void> settleEventDay(EventViewModel vm) {
  bool settled() =>
      !vm.loadByDate.isRunningSync.value &&
      vm.hasCurrentDaySnapshot &&
      !vm.loadByDate.results.value.isRunning;
  if (settled()) return Future.value();
  final completion = Completer<void>();
  late VoidCallback listener;
  listener = () {
    if (!settled()) return;
    vm.loadByDate.results.removeListener(listener);
    completion.complete();
  };
  vm.loadByDate.results.addListener(listener);
  return completion.future;
}

/// Owns commands while a fixed child observes the VM directly, without a parent
/// Consumer.
Widget eventCommandApp(
  EventViewModel vm,
  FakeEventRepository repository,
  Widget child,
) => MaterialApp(
  locale: const Locale('en'),
  home: ChangeNotifierProvider<FavouriteViewModel>(
    create: (_) => FavouriteViewModel(
      favouriteGetIdsUseCase: FavouriteGetIdsUseCase(
        eventRepository: repository,
        placeRepository: FakePlaceRepository(),
      ),
    ),
    child: ChangeNotifierProvider<EventViewModel>(
      create: (_) => vm,
      child: Scaffold(body: child),
    ),
  ),
);
