import 'dart:async';

import 'package:command_it/command_it.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/content_sort.dart';
import 'package:moliseis/domain/models/place.dart';
import 'package:moliseis/domain/models/theme_brightness.dart';
import 'package:moliseis/domain/models/theme_type.dart';
import 'package:moliseis/domain/use-cases/category_use_case.dart';
import 'package:moliseis/domain/use-cases/explore_use_case.dart';
import 'package:moliseis/domain/use-cases/favourite_get_ids_use_case.dart';
import 'package:moliseis/ui/category/view_models/category_view_model.dart';
import 'package:moliseis/ui/explore/view_models/explore_view_model.dart';
import 'package:moliseis/ui/explore/view_models/suggestion_view_model.dart';
import 'package:moliseis/ui/favourite/view_models/favourite_view_model.dart';
import 'package:moliseis/ui/settings/view_models/settings_view_model.dart';
import 'package:moliseis/ui/settings/view_models/theme_view_model.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/sentry_logging_flag.dart';

import 'command_test_support.dart';
import 'fake_repositories.dart';
import 'fixtures.dart';

/// Ordinary command owners sharing the reviewed lifecycle contract.
enum OrdinaryOwnerLane {
  settings,
  brightness,
  themeType,
  explore,
  suggestion,
  favourite,
  categorySort,
}

/// Repository gates retain real commands and expose observable owner state.
class OrdinaryOwnerHarness {
  OrdinaryOwnerHarness(OrdinaryOwnerLane lane) {
    Future<Result<void>> write() async {
      _repositoryCalls++;
      await gate.future;
      return expectedError == null
          ? const Result.success(null)
          : Result.error(expectedError!);
    }

    Future<Result<List<Place>>> read() async {
      _repositoryCalls++;
      await gate.future;
      return expectedError == null
          ? Result.success([makePlace()])
          : Result.error(expectedError!);
    }

    final preferences = FakeSettingsRepository()
      ..onSetCrashReporting = ((_) => write())
      ..onSetThemeBrightness = ((_) => write())
      ..onSetThemeType = ((_) => write())
      ..onSetContentSort = ((_) => write());
    final places = FakePlaceRepository(
      getByIdResults: {1: Result.success(makePlace())},
      getSuggestionsHandler: read,
      getFavouritePlaceIdsHandler: () async {
        _repositoryCalls++;
        await gate.future;
        return expectedError == null
            ? const Result.success(<int>[1])
            : Result.error(expectedError!);
      },
    );
    repositoryCalls = () =>
        _repositoryCalls + places.getLatestCallCount + places.getByIdCallCount;
    switch (lane) {
      case OrdinaryOwnerLane.categorySort:
        final events = FakeEventRepository();
        final vm = CategoryViewModel(
          initialCategories: {ContentCategory.history},
          categoryUseCase: CategoryUseCase(
            eventRepository: events,
            placeRepository: places,
          ),
          exploreGetByIdUseCase: ExploreUseCase(
            eventRepository: events,
            placeRepository: places,
          ),
          settingsRepository: preferences,
        );
        owner = vm;
        command = vm.setSort;
        start = () => vm.setSort.run(ContentSort.byDate);
        state = () => vm.sort;
      case OrdinaryOwnerLane.settings:
        final sentryFlag = SentryLoggingFlag(initialValue: false);
        final vm = SettingsViewModel(
          settingsRepository: preferences,
          sentryLoggingFlag: sentryFlag,
        );
        owner = vm;
        command = vm.setCrashReporting;
        start = () => vm.setCrashReporting(true);
        // Shared persisted consent has authority beyond the presentation owner;
        // settings_view_model_test independently verifies its reconciliation.
        state = () => vm.crashReporting;
      case OrdinaryOwnerLane.brightness:
      case OrdinaryOwnerLane.themeType:
        final vm = ThemeViewModel(settingsRepository: preferences);
        owner = vm;
        if (lane == OrdinaryOwnerLane.brightness) {
          command = vm.setThemeBrightness;
          otherCommand = vm.setThemeType;
          start = () => vm.setThemeBrightness(ThemeBrightness.dark);
        } else {
          command = vm.setThemeType;
          otherCommand = vm.setThemeBrightness;
          start = () => vm.setThemeType(ThemeType.app);
        }
        state = () => (vm.themeBrightness, vm.themeType);
      case OrdinaryOwnerLane.explore:
        final pending = Completer<Result<List<Place>>>();
        places.pendingGetLatest = pending;
        unawaited(
          gate.future.then<void>(
            (_) => pending.complete(
              expectedError == null
                  ? Result.success([makePlace()])
                  : Result.error(expectedError!),
            ),
            onError: pending.completeError,
          ),
        );
        final vm = ExploreViewModel(placeRepository: places);
        owner = vm;
        command = vm.loadLatest;
        start = vm.loadLatest.call;
        state = () => vm.latest.toList();
        autoStarted = true;
      case OrdinaryOwnerLane.suggestion:
        final vm = SuggestionViewModel(placeRepository: places);
        owner = vm;
        command = vm.load;
        start = vm.load.call;
        state = () => vm.suggestions.toList();
        autoStarted = true;
      case OrdinaryOwnerLane.favourite:
        final vm = FavouriteViewModel(
          favouriteGetIdsUseCase: FavouriteGetIdsUseCase(
            placeRepository: places,
            eventRepository: FakeEventRepository(),
          ),
        );
        owner = vm;
        command = vm.load;
        start = vm.load.call;
        state = () => [
          vm.favouritePlaces.toList(),
          vm.favouriteEvents.toList(),
          vm.favouritePlaceIds.toList(),
          vm.favouriteEventIds.toList(),
        ];
        autoStarted = true;
    }
    // Register creation before observing disposal, including never-run owners.
    command.addListener(() {});
    otherCommand?.addListener(() {});
    owner.addListener(() => notifications++);
  }

  final gate = Completer<void>();
  Exception? expectedError;
  late final ChangeNotifier owner;
  late final Command<dynamic, Result<void>?> command;
  Command<dynamic, Result<void>?>? otherCommand;
  late final VoidCallback start;
  late final Object Function() state;
  bool autoStarted = false;
  int _repositoryCalls = 0;
  late final int Function() repositoryCalls;
  int notifications = 0;

  void begin() {
    if (!autoStarted) start();
  }
}

/// Public SDK events prove physical release by identity, including the owner.
class DisposalEventProbe {
  DisposalEventProbe() {
    FlutterMemoryAllocations.instance.addListener(_record);
  }
  final events = <ObjectDisposed>[];
  void _record(ObjectEvent event) {
    if (event is ObjectDisposed) events.add(event);
  }

  int count(Object object) =>
      events.where((event) => identical(event.object, object)).length;
  void dispose() => FlutterMemoryAllocations.instance.removeListener(_record);
}

/// Flushes the documented upstream 50 ms physical notifier teardown.
Future<void> pumpPhysicalCommandDisposal(WidgetTester tester) async {
  await pumpCommandTurns(tester);
  await tester.pump(const Duration(milliseconds: 50));
  await pumpCommandTurns(tester);
}
