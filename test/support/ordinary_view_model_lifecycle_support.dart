import 'dart:async';

import 'package:command_it/command_it.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/content_sort.dart';
import 'package:moliseis/domain/models/content_submission_draft.dart';
import 'package:moliseis/domain/models/content_submission_staged_asset.dart';
import 'package:moliseis/domain/models/event.dart';
import 'package:moliseis/domain/models/place.dart';
import 'package:moliseis/domain/models/theme_brightness.dart';
import 'package:moliseis/domain/models/theme_type.dart';
import 'package:moliseis/domain/use-cases/category_use_case.dart';
import 'package:moliseis/domain/use-cases/explore_use_case.dart';
import 'package:moliseis/domain/use-cases/favourite_get_ids_use_case.dart';
import 'package:moliseis/domain/use-cases/post_use_case.dart';
import 'package:moliseis/ui/category/view_models/category_view_model.dart';
import 'package:moliseis/ui/content_submission/view_models/content_submission_view_model.dart';
import 'package:moliseis/ui/event/view_models/event_view_model.dart';
import 'package:moliseis/ui/explore/view_models/explore_view_model.dart';
import 'package:moliseis/ui/explore/view_models/suggestion_view_model.dart';
import 'package:moliseis/ui/favourite/view_models/favourite_view_model.dart';
import 'package:moliseis/ui/post/view_models/post_view_model.dart';
import 'package:moliseis/ui/settings/view_models/settings_view_model.dart';
import 'package:moliseis/ui/settings/view_models/theme_view_model.dart';
import 'package:moliseis/ui/sync/view_models/sync_view_model.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/sentry_logging_flag.dart';

import 'command_test_support.dart';
import 'crash_reporting_support.dart';
import 'fake_image_picker.dart';
import 'fake_repositories.dart';
import 'fixtures.dart';
import 'mock_logger.dart';
import 'sync_use_case_test_support.dart';

/// Ordinary command owners sharing the reviewed lifecycle contract.
enum OrdinaryOwnerLane {
  settings,
  brightness,
  themeType,
  explore,
  suggestion,
  favourite,
  categorySort,
  eventAnnual,
  eventOngoing,
  eventNext,
  postEvent,
  postPlace,
  postNearby,
  sync,
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
    void bindGate<T>(Completer<Result<T>> pending, T value) {
      unawaited(
        gate.future.then<void>(
          (_) => pending.complete(
            expectedError == null
                ? Result.success(value)
                : Result.error(expectedError!),
          ),
          onError: pending.completeError,
        ),
      );
    }

    switch (lane) {
      case OrdinaryOwnerLane.sync:
        final now = DateTime.utc(2026, 10, 23);
        preferences
          ..lastSyncedAt = now
          ..contentSyncCursorAt = now;
        final cursor = FakeSyncCursorSource();
        final pending = Completer<Result<DateTime>>();
        cursor.pendingCursor = pending;
        bindGate(pending, now);
        final deps = buildSyncUseCase(
          settings: preferences,
          cursorSource: cursor,
          now: () => now,
        );
        final vm = SyncViewModel(syncUseCase: deps.useCase);
        owner = vm;
        command = vm.sync;
        start = () => vm.sync.run(true);
        state = () => vm.fatalError;
        repositoryCalls = () => cursor.calls;

      case OrdinaryOwnerLane.postEvent:
      case OrdinaryOwnerLane.postPlace:
      case OrdinaryOwnerLane.postNearby:
        final events = FakeEventRepository();
        final postPlaces = FakePlaceRepository();
        if (lane == OrdinaryOwnerLane.postEvent) {
          final pending = Completer<Result<Event>>();
          events.pendingGetById[1] = pending;
          bindGate(pending, makeEvent());
        } else if (lane == OrdinaryOwnerLane.postPlace) {
          final pending = Completer<Result<Place>>();
          postPlaces.pendingGetById[1] = pending;
          bindGate(pending, makePlace());
        } else {
          final pending = Completer<Result<List<Event>>>();
          events.pendingGetByCoordinates = pending;
          bindGate(pending, [makeEvent()]);
        }
        final vm = PostViewModel(
          postUseCase: PostUseCase(
            eventRepository: events,
            placeRepository: postPlaces,
          ),
        );
        owner = vm;
        repositoryCalls = () =>
            events.getByIdCallCount +
            postPlaces.getByIdCallCount +
            events.getByCoordinatesCallCount +
            postPlaces.getByCoordinatesCallCount;
        if (lane == OrdinaryOwnerLane.postNearby) {
          command = vm.loadNearContent;
          start = () => vm.loadNearContent.run(const LatLng(41, 14));
          state = () => vm.nearContent.toList();
        } else {
          if (lane == OrdinaryOwnerLane.postEvent) {
            command = vm.loadEvent;
            start = () => vm.loadEvent.run(1);
          } else {
            command = vm.loadPlace;
            start = () => vm.loadPlace.run(1);
          }
          // Observe whether the public late slot initialized after revocation.
          // The sentinel catches its initial LateInitializationError.
          state = () {
            try {
              return vm.content;
            } on Object {
              return 'unresolved content';
            }
          };
        }

      case OrdinaryOwnerLane.eventAnnual:
      case OrdinaryOwnerLane.eventOngoing:
      case OrdinaryOwnerLane.eventNext:
        final events = FakeEventRepository();
        final pending = Completer<Result<List<Event>>>();
        bindGate(pending, [makeEvent()]);
        if (lane == OrdinaryOwnerLane.eventAnnual) {
          events.pendingGetByCurrentYear = pending;
        } else if (lane == OrdinaryOwnerLane.eventOngoing) {
          events.pendingGetOngoingEvents = pending;
        } else {
          events.pendingGetNextEvents = pending;
        }
        final vm = EventViewModel(repository: events);
        owner = vm;
        if (lane == OrdinaryOwnerLane.eventAnnual) {
          command = vm.loadAll;
          start = vm.loadAll.run;
          state = () => vm.all.toList();
          repositoryCalls = () => events.getByCurrentYearCallCount;
          autoStarted = true;
        } else if (lane == OrdinaryOwnerLane.eventOngoing) {
          command = vm.loadOngoing;
          start = () => vm.loadOngoing.run(DateTime.utc(2026));
          state = () => vm.ongoing.toList();
          repositoryCalls = () => events.getOngoingEventsCallCount;
        } else {
          command = vm.loadNext;
          start = () => vm.loadNext.run(DateTime.utc(2026));
          state = () => vm.next.toList();
          repositoryCalls = () => events.getNextEventsCallCount;
        }

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
          crashReporting: testCrashReporting(
            repository: preferences,
            flag: sentryFlag,
          ),
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
  late int Function() repositoryCalls;
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
  final creations = <ObjectCreated>[];
  void _record(ObjectEvent event) {
    if (event is ObjectCreated) creations.add(event);
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

/// The five private ordinary lanes exposed only through request/snapshot APIs.
enum SubmissionOwnerLane { add, remove, submit, clear, recovery }

/// Gates feature boundaries without exposing executable private commands.
///
/// Add/recovery pause at the plugin; remove at persistence; submit at its dirty
/// draft checkpoint; clear at draft retirement. Completing a gate after revoke
/// must never start the next phase, even when the result contains a candidate.
final class SubmissionOwnerHarness {
  SubmissionOwnerHarness(
    this.lane, {
    required DisposalEventProbe probe,
    XFile? pickedCandidate,
  }) {
    candidate =
        pickedCandidate ??
        XFile.fromData(Uint8List.fromList([3]), name: 'X.jpg');
    final creationStart = probe.creations.length;
    const identity = '2a1b0c3d-4e5f-4a6b-8c9d-0e1f2a3b4c5d';
    const digest = '1111111111111111111111111111111111111111';
    drafts = FakeContentSubmissionDraftRepository(
      loadDraftResult: Result.success(
        ContentSubmissionDraft(
          clientSubmissionId: identity,
          city: 'Rome',
          name: 'D0',
          userEmail: 'anna@example.test',
          userName: 'Anna',
        ),
      ),
    );
    staged = FakeContentSubmissionStagedAssetRepository(
      reconcileResult: Result.success([
        ContentSubmissionStagedAsset(
          clientSubmissionId: identity,
          digest: digest,
          relativePath: '$identity/$digest',
        ),
      ]),
    );
    repository = FakeContentSubmissionRepository();
    picker = FakeImagePicker(
      onPickMultipleMedia: () async {
        boundaryCalls++;
        final selectedGate = boundaryCalls == 1 ? gate : nextGate ?? gate;
        await selectedGate.future;
        if (expectedError != null) {
          throw PlatformException(code: 'expected-picker-failure');
        }
        return returnCandidate ? [candidate] : [];
      },
      onRetrieveLostData: () async {
        boundaryCalls++;
        final selectedGate = boundaryCalls == 1 ? gate : nextGate ?? gate;
        await selectedGate.future;
        if (expectedError != null) {
          throw PlatformException(code: 'expected-recovery-failure');
        }
        return returnCandidate
            ? LostDataResponse(file: candidate, type: RetrieveType.image)
            : LostDataResponse.empty();
      },
    );
    owner = ContentSubmissionViewModel(
      logger: MockLogger(),
      contentSubmissionRepository: repository,
      draftRepository: drafts,
      stagedAssetRepository: staged,
      imagePicker: picker,
    );
    owner.addListener(() => notifications++);
    // command_it 9.5.2 observes one direct listen_it results notifier per lane.
    // Public creation metadata excludes the derived WhereValueNotifier, whose
    // events use Flutter foundation's library. No private Command is exposed.
    resultNotifiers = probe.creations
        .skip(creationStart)
        .where(
          (event) =>
              event.library == 'package:functionlistener/functionlistener.dart',
        )
        .map((event) => event.object)
        .whereType<ValueListenable<dynamic>>()
        .where((notifier) => notifier.value is CommandResult<dynamic, dynamic>)
        .toList();
  }

  late final List<ValueListenable<dynamic>> resultNotifiers;

  final SubmissionOwnerLane lane;
  final gate = Completer<void>();
  Completer<void>? nextGate;
  late final XFile candidate;
  late final ContentSubmissionViewModel owner;
  late final FakeContentSubmissionDraftRepository drafts;
  late final FakeContentSubmissionStagedAssetRepository staged;
  late final FakeContentSubmissionRepository repository;
  late final FakeImagePicker picker;
  Exception? expectedError;
  bool returnCandidate = true;
  int boundaryCalls = 0;
  int notifications = 0;

  /// Resolves bootstrap, then installs exactly one gate for this request.
  Future<void> initialize() async {
    await owner.initialize();
    if (lane == SubmissionOwnerLane.submit) owner.setName('D1');
    _installRepositoryGate(gate);
  }

  /// Gates a second real request admitted by a synchronous idle observer.
  Completer<void> armNextExecution() {
    final next = Completer<void>();
    nextGate = next;
    _installRepositoryGate(next);
    return next;
  }

  void _installRepositoryGate(Completer<void> source) {
    final pending = Completer<Result<void>>();
    if (lane == SubmissionOwnerLane.remove) staged.pendingRemove = pending;
    if (lane == SubmissionOwnerLane.clear) drafts.pendingClearDraft = pending;
    if (lane == SubmissionOwnerLane.submit) drafts.pendingSaveDraft = pending;
    if ([
      SubmissionOwnerLane.remove,
      SubmissionOwnerLane.clear,
      SubmissionOwnerLane.submit,
    ].contains(lane)) {
      unawaited(
        source.future.then<void>(
          (_) {
            pending.complete(
              expectedError == null
                  ? const Result.success(null)
                  : Result.error(expectedError!),
            );
          },
          onError: (Object error, StackTrace stack) {
            pending.completeError(error, stack);
          },
        ),
      );
    }
  }

  bool request() => switch (lane) {
    SubmissionOwnerLane.add => owner.requestAddAsset(),
    SubmissionOwnerLane.remove => owner.requestRemoveAssetAt(0),
    SubmissionOwnerLane.submit => owner.requestSubmit(),
    SubmissionOwnerLane.clear => owner.requestClear(),
    SubmissionOwnerLane.recovery => owner.requestRetrieveLostAssets(),
  };

  bool get running => switch (lane) {
    SubmissionOwnerLane.add => owner.isAddingAsset,
    SubmissionOwnerLane.remove => owner.isRemovingAsset,
    SubmissionOwnerLane.submit => owner.isSubmitting,
    SubmissionOwnerLane.clear => owner.isClearing,
    SubmissionOwnerLane.recovery => owner.isRetrievingLostAssets,
  };

  CommandResult<void, Result<dynamic>?> get snapshot => switch (lane) {
    SubmissionOwnerLane.add => owner.addAssetSnapshot,
    SubmissionOwnerLane.remove => owner.removeAssetAtSnapshot,
    SubmissionOwnerLane.submit => owner.submitSnapshot,
    SubmissionOwnerLane.clear => owner.clearSnapshot,
    SubmissionOwnerLane.recovery => owner.retrieveLostAssetsSnapshot,
  };

  List<Object?> state() => [
    owner.state,
    owner.assets.toList(),
    owner.submissionFinalizationPending,
    owner.addAssetSnapshot,
    owner.removeAssetAtSnapshot,
    owner.submitSnapshot,
    owner.clearSnapshot,
    owner.retrieveLostAssetsSnapshot,
  ];

  int get calls =>
      drafts.loadDraftCallCount +
      drafts.saveDraftCallCount +
      drafts.clearDraftCallCount +
      staged.reconcileCallCount +
      staged.resolveCallCount +
      staged.acquired.length +
      staged.removed.length +
      staged.clearedSessions.length +
      repository.uploadedImages.length +
      repository.submitCallCount +
      boundaryCalls;

  int get entered => switch (lane) {
    SubmissionOwnerLane.add || SubmissionOwnerLane.recovery => boundaryCalls,
    SubmissionOwnerLane.remove => staged.removed.length,
    SubmissionOwnerLane.submit => drafts.saveDraftCallCount,
    SubmissionOwnerLane.clear => drafts.clearDraftCallCount,
  };
}

/// Restores the platform before Flutter verifies per-test debug invariants.
void testSubmissionOwnerLifecycle(
  String description,
  WidgetTesterCallback callback,
) {
  testWidgets(description, (tester) async {
    final previousPlatform = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await callback(tester);
    } finally {
      debugDefaultTargetPlatformOverride = previousPlatform;
    }
  });
}

/// Separately controls the two direct file await boundaries owned by the VM.
final class GatedSubmissionFile extends XFile {
  GatedSubmissionFile({required this.gateLength}) : super('/candidate.jpg');

  final bool gateLength;
  final lengthGate = Completer<int>();
  final readGate = Completer<List<int>>();
  int lengthCalls = 0;
  int openReadCalls = 0;

  @override
  Future<int> length() async {
    lengthCalls++;
    return gateLength ? await lengthGate.future : 1;
  }

  @override
  Stream<Uint8List> openRead([int? start, int? end]) async* {
    openReadCalls++;
    yield Uint8List.fromList(await readGate.future);
  }
}
