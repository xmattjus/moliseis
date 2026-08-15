import 'dart:async' show Completer;
import 'dart:io' show File;

import 'package:http/http.dart' as http;
import 'package:moliseis/data/dtos/city_dto.dart';
import 'package:moliseis/data/dtos/event_dto.dart';
import 'package:moliseis/data/dtos/media_dto.dart';
import 'package:moliseis/data/dtos/place_dto.dart';
import 'package:moliseis/data/services/api/weather/model/combined_weather_forecast_response.dart';
import 'package:moliseis/data/services/api/weather/weather_api_client.dart';
import 'package:moliseis/domain/core/sync_transaction_coordinator.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/content_sort.dart';
import 'package:moliseis/domain/models/content_submission.dart';
import 'package:moliseis/domain/models/content_submission_draft.dart';
import 'package:moliseis/domain/models/event.dart';
import 'package:moliseis/domain/models/image_upload_task.dart';
import 'package:moliseis/domain/models/media.dart';
import 'package:moliseis/domain/models/place.dart';
import 'package:moliseis/domain/models/submission_asset.dart';
import 'package:moliseis/domain/models/theme_brightness.dart';
import 'package:moliseis/domain/models/theme_type.dart';
import 'package:moliseis/domain/repositories/city_repository.dart';
import 'package:moliseis/domain/repositories/content_submission_draft_repository.dart';
import 'package:moliseis/domain/repositories/content_submission_repository.dart';
import 'package:moliseis/domain/repositories/event_repository.dart';
import 'package:moliseis/domain/repositories/media_repository.dart';
import 'package:moliseis/domain/repositories/place_repository.dart';
import 'package:moliseis/domain/repositories/settings_repository.dart';
import 'package:moliseis/utils/command.dart' show Command;
import 'package:moliseis/utils/result.dart';

import 'mock_logger.dart';

// ---------------------------------------------------------------------------
// _NoopHttpClient
// ---------------------------------------------------------------------------

/// A minimal [http.BaseClient] that throws on any real request.
///
/// Avoids the socket-pool overhead of a real [http.Client] since all
/// [WeatherApiClient] methods are overridden by [FakeWeatherApiClient].
final class _NoopHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      throw UnsupportedError(
        'FakeWeatherApiClient should not make real HTTP requests',
      );
}

// ---------------------------------------------------------------------------
// TestException
// ---------------------------------------------------------------------------

/// Shared test exception used across the entire test suite.
///
/// Prefer this over defining a private `_TestException` per test file.
final class TestException implements Exception {
  TestException(this.message);

  final String message;

  @override
  String toString() => message;
}

// ---------------------------------------------------------------------------
// FakeTransactionCoordinator
// ---------------------------------------------------------------------------

/// A pass-through transaction coordinator that simply executes the function.
final class FakeTransactionCoordinator implements SyncTransactionCoordinator {
  @override
  Result<void> runInWriteTransaction(Result<void> Function() fn) => fn();
}

// ---------------------------------------------------------------------------
// FakeCityRepository
// ---------------------------------------------------------------------------

/// Create a fresh instance per test to avoid state bleed between tests.
final class FakeCityRepository extends CityRepository {
  FakeCityRepository({
    this.prepareResult = const Result.success([]),
  });

  Result<List<CityDto>> prepareResult;
  bool commitCalled = false;
  List<CityDto>? committedDtos;

  @override
  Future<Result<List<CityDto>>> prepareSync() async => prepareResult;

  @override
  Result<void> commitSync(List<CityDto> dtos) {
    commitCalled = true;
    committedDtos = dtos;
    return const Result.success(null);
  }
}

// ---------------------------------------------------------------------------
// FakeEventRepository
// ---------------------------------------------------------------------------

/// Create a fresh instance per test to avoid state bleed between tests.
final class FakeEventRepository extends EventRepository {
  FakeEventRepository({
    this.prepareResult = const Result.success([]),
    this.getByCurrentYearResult = const Result.success([]),
    this.getByDateResult = const Result.success([]),
    this.getByDateRangeResult = const Result.success([]),
    this.getByCategoriesResult = const Result.success([]),
    this.getByCoordinatesResult = const Result.success([]),
    this.getNextEventIdsResult = const Result.success([]),
    this.getFavouriteEventIdsResult = const Result.success([]),
    this.getFavouritesResult = const Result.success([]),
    this.setFavouriteEventResult = const Result.success(null),
    Map<int, Result<Event>>? getByIdResults,
  }) : getByIdResults = getByIdResults ?? {};

  // Configurable results (non-final for mid-test reconfiguration)
  Result<List<EventDto>> prepareResult;
  Result<List<Event>> getByCurrentYearResult;
  Result<List<Event>> getByDateResult;
  Result<List<Event>> getByDateRangeResult;
  Result<List<Event>> getByCategoriesResult;
  Result<List<Event>> getByCoordinatesResult;
  Result<List<int>> getNextEventIdsResult;
  Result<List<int>> getFavouriteEventIdsResult;
  Result<Iterable<Event>> getFavouritesResult;
  Result<void> setFavouriteEventResult;
  Map<int, Result<Event>> getByIdResults;

  // Sync tracking
  bool commitCalled = false;
  List<EventDto>? committedDtos;

  // Call counters (only where existing tests query them)
  int getByDateCallCount = 0;
  int getByCategoriesCallCount = 0;

  // Argument captures (only where existing tests inspect them)
  List<double>? lastCoordinates;

  @override
  Future<Result<List<EventDto>>> prepareSync() async => prepareResult;

  @override
  Result<void> commitSync(List<EventDto> dtos) {
    commitCalled = true;
    committedDtos = dtos;
    return const Result.success(null);
  }

  @override
  Future<Result<List<Event>>> getByCurrentYear() async =>
      getByCurrentYearResult;

  @override
  Future<Result<List<Event>>> getByDate(DateTime date) async {
    getByDateCallCount++;
    return getByDateResult;
  }

  @override
  Future<Result<List<Event>>> getByDateRange(
    DateTime start,
    DateTime end,
  ) async => getByDateRangeResult;

  @override
  Future<Result<List<Event>>> getByCategories(
    Set<ContentCategory> categories, {
    ContentSort sort = ContentSort.byName,
  }) async {
    getByCategoriesCallCount++;
    return getByCategoriesResult;
  }

  @override
  Future<Result<List<Event>>> getByCoordinates(
    List<double> coordinates,
  ) async {
    lastCoordinates = coordinates;
    return getByCoordinatesResult;
  }

  @override
  Future<Result<Event>> getById(int id) async =>
      getByIdResults[id] ??
      Result.error(TestException('Event $id not configured'));

  @override
  Future<Result<List<int>>> getNextEventIds() async => getNextEventIdsResult;

  @override
  Future<Result<List<int>>> getFavouriteEventIds() async =>
      getFavouriteEventIdsResult;

  @override
  Future<Result<void>> setFavouriteEvent(int id, bool save) async =>
      setFavouriteEventResult;
}

// ---------------------------------------------------------------------------
// ControllableEventRepository
// ---------------------------------------------------------------------------

/// An [EventRepository] fake whose [getById] result is gated by a fresh
/// [Completer] per call. Used by widget tests that need to hold the
/// resolution [Command] in the running state and complete the repository
/// calls in a controlled order (e.g. rapid-navigation races).
///
/// Every non-`getById` method mirrors the successful no-op defaults of
/// [FakeEventRepository].
final class ControllableEventRepository extends EventRepository {
  final Map<int, Completer<Result<Event>>> _pendingGetById = {};

  /// Number of times [getById] has been invoked.
  int getByIdCallCount = 0;

  /// Returns the completers still awaiting completion, keyed by id.
  ///
  /// Exposed for assertions that a specific request is in flight.
  Map<int, Completer<Result<Event>>> get pendingGetById => _pendingGetById;

  @override
  Future<Result<Event>> getById(int id) {
    getByIdCallCount++;
    final completer = Completer<Result<Event>>();
    _pendingGetById[id] = completer;
    return completer.future;
  }

  /// Resolves the in-flight [getById] call for [id] with [result]. Safe to
  /// call when no call for [id] is pending: it is a no-op in that case.
  void completeGetById(int id, Result<Event> result) {
    _pendingGetById.remove(id)?.complete(result);
  }

  @override
  Future<Result<List<EventDto>>> prepareSync() async =>
      const Result.success([]);

  @override
  Result<void> commitSync(List<EventDto> dtos) => const Result.success(null);

  @override
  Future<Result<List<Event>>> getByCurrentYear() async =>
      const Result.success([]);

  @override
  Future<Result<List<Event>>> getByDate(DateTime date) async =>
      const Result.success([]);

  @override
  Future<Result<List<Event>>> getByDateRange(
    DateTime start,
    DateTime end,
  ) async => const Result.success([]);

  @override
  Future<Result<List<Event>>> getByCategories(
    Set<ContentCategory> categories, {
    ContentSort sort = ContentSort.byName,
  }) async => const Result.success([]);

  @override
  Future<Result<List<Event>>> getByCoordinates(
    List<double> coordinates,
  ) async => const Result.success([]);

  @override
  Future<Result<List<int>>> getNextEventIds() async => const Result.success([]);

  @override
  Future<Result<List<int>>> getFavouriteEventIds() async =>
      const Result.success([]);

  @override
  Future<Result<void>> setFavouriteEvent(int id, bool save) async =>
      const Result.success(null);
}

// ---------------------------------------------------------------------------
// FakeMediaRepository
// ---------------------------------------------------------------------------

final class FakeMediaRepository extends MediaRepository {
  FakeMediaRepository({
    this.prepareResult = const Result.success([]),
    this.getByEventIdResult = const Result.success([]),
    this.getByPlaceIdResult = const Result.success([]),
  });

  Result<List<MediaDto>> prepareResult;
  Result<List<Media>> getByEventIdResult;
  Result<List<Media>> getByPlaceIdResult;

  bool commitCalled = false;
  List<MediaDto>? committedDtos;

  @override
  Future<Result<List<MediaDto>>> prepareSync() async => prepareResult;

  @override
  Result<void> commitSync(List<MediaDto> dtos) {
    commitCalled = true;
    committedDtos = dtos;
    return const Result.success(null);
  }

  @override
  Future<Result<List<Media>>> getByEventId(int id) async => getByEventIdResult;

  @override
  Future<Result<List<Media>>> getByPlaceId(int id) async => getByPlaceIdResult;
}

// ---------------------------------------------------------------------------
// FakePlaceRepository
// ---------------------------------------------------------------------------

/// Create a fresh instance per test to avoid state bleed between tests.
final class FakePlaceRepository extends PlaceRepository {
  FakePlaceRepository({
    this.prepareResult = const Result.success([]),
    this.getAllResult = const Result.success([]),
    this.getByCategoriesResult = const Result.success([]),
    this.getByCoordinatesResult = const Result.success([]),
    this.getFavouritePlaceIdsResult = const Result.success([]),
    this.getFavouritesResult = const Result.success([]),
    this.getIdsByCoordinatesResult = const Result.success([]),
    this.getLatestPlaceIdsResult = const Result.success([]),
    this.getSuggestedPlaceIdsResult = const Result.success([]),
    this.setFavouritePlaceResult = const Result.success(null),
    this.getSuggestedPlacesResult = const Result.success([]),
    this.getSuggestionsHandler,
    Map<int, Result<Place>>? getByIdResults,
  }) : getByIdResults = getByIdResults ?? {};

  Result<List<PlaceDto>> prepareResult;
  Result<List<Place>> getAllResult;
  Result<List<Place>> getByCategoriesResult;
  Result<List<Place>> getByCoordinatesResult;
  Result<List<int>> getFavouritePlaceIdsResult;
  Result<Iterable<Place>> getFavouritesResult;
  Result<List<int>> getIdsByCoordinatesResult;
  Result<List<int>> getLatestPlaceIdsResult;
  Result<List<int>> getSuggestedPlaceIdsResult;
  Result<List<Place>> getSuggestedPlacesResult;
  Future<Result<List<Place>>> Function()? getSuggestionsHandler;
  Result<void> setFavouritePlaceResult;
  Map<int, Result<Place>> getByIdResults;

  bool commitCalled = false;
  List<PlaceDto>? committedDtos;

  // Argument captures (only where existing tests inspect them)
  ContentSort? lastGetAllSort;
  List<double>? lastCoordinates;

  int getSuggestionsCallCount = 0;

  @override
  Future<Result<List<PlaceDto>>> prepareSync() async => prepareResult;

  @override
  Result<void> commitSync(List<PlaceDto> dtos) {
    commitCalled = true;
    committedDtos = dtos;
    return const Result.success(null);
  }

  @override
  Future<Result<List<Place>>> getAll({
    ContentSort sort = ContentSort.byName,
  }) async {
    lastGetAllSort = sort;
    return getAllResult;
  }

  @override
  Future<Result<List<Place>>> getByCategories(
    Set<ContentCategory> categories, {
    ContentSort sort = ContentSort.byName,
  }) async => getByCategoriesResult;

  @override
  Future<Result<List<Place>>> getByCoordinates(
    List<double> coordinates,
  ) async {
    lastCoordinates = coordinates;
    return getByCoordinatesResult;
  }

  @override
  Future<Result<Place>> getById(int id) async =>
      getByIdResults[id] ??
      Result.error(TestException('Place $id not configured'));

  @override
  Future<Result<List<int>>> getFavouritePlaceIds() async =>
      getFavouritePlaceIdsResult;

  @override
  Future<Result<List<int>>> getIdsByCoordinates(
    List<double> coordinates,
  ) async => getIdsByCoordinatesResult;

  @override
  Future<Result<List<int>>> getLatestPlaceIds() async =>
      getLatestPlaceIdsResult;

  @override
  Future<Result<List<Place>>> getSuggestions() {
    getSuggestionsCallCount++;
    return getSuggestionsHandler?.call() ??
        Future.value(getSuggestedPlacesResult);
  }

  @override
  Future<Result<void>> setFavouritePlace(int id, bool save) async =>
      setFavouritePlaceResult;
}

// ---------------------------------------------------------------------------
// FakeSettingsRepository
// ---------------------------------------------------------------------------

/// Create a fresh instance per test to avoid state bleed between tests.
final class FakeSettingsRepository implements SettingsRepository {
  FakeSettingsRepository({
    this.crashReporting = false,
    this.contentSort = ContentSort.byName,
    this.lastSyncedAt,
    this.themeBrightness = ThemeBrightness.system,
    this.themeType = ThemeType.system,
    this.initializeResult = const Result.success(null),
    this.setCrashReportingResult = const Result.success(null),
    this.setContentSortResult = const Result.success(null),
    this.setModifiedAtResult = const Result.success(null),
    this.setThemeBrightnessResult = const Result.success(null),
    this.setThemeTypeResult = const Result.success(null),
  });

  // Getters (non-final for mid-test mutation)
  @override
  bool crashReporting;
  @override
  ContentSort contentSort;
  @override
  DateTime? lastSyncedAt;
  @override
  ThemeBrightness themeBrightness;
  @override
  ThemeType themeType;

  // Write results
  Result<void> initializeResult;
  Result<void> setCrashReportingResult;
  Result<void> setContentSortResult;
  Result<void> setModifiedAtResult;
  Result<void> setThemeBrightnessResult;
  Result<void> setThemeTypeResult;

  // Call tracking
  bool setModifiedAtCalled = false;

  @override
  Future<Result<void>> initialize() async => initializeResult;

  @override
  Future<Result<void>> setCrashReporting(bool enable) async {
    if (setCrashReportingResult is Success<void>) crashReporting = enable;
    return setCrashReportingResult;
  }

  @override
  Future<Result<void>> setContentSort(ContentSort sort) async {
    if (setContentSortResult is Success<void>) contentSort = sort;
    return setContentSortResult;
  }

  @override
  Future<Result<void>> setModifiedAt(DateTime dateTime) async {
    setModifiedAtCalled = true;
    if (setModifiedAtResult is Success<void>) lastSyncedAt = dateTime;
    return setModifiedAtResult;
  }

  @override
  Future<Result<void>> setThemeBrightness(ThemeBrightness brightness) async {
    if (setThemeBrightnessResult is Success<void>) themeBrightness = brightness;
    return setThemeBrightnessResult;
  }

  @override
  Future<Result<void>> setThemeType(ThemeType type) async {
    if (setThemeTypeResult is Success<void>) themeType = type;
    return setThemeTypeResult;
  }
}

// ---------------------------------------------------------------------------
// FakeContentSubmissionRepository
// ---------------------------------------------------------------------------

final class FakeContentSubmissionRepository
    implements ContentSubmissionRepository {
  FakeContentSubmissionRepository({
    this.uploadResult = const Result.success(null),
    ImageUploadTask? uploadImageTaskResult,
  }) : uploadImageTaskResult =
           uploadImageTaskResult ??
           _FakeUploadTask.success(
             const Result.success(
               SubmissionAsset(
                 secureUrl: '',
                 width: 2048,
                 height: 2048,
               ),
             ),
           );

  Result<void> uploadResult;
  ImageUploadTask uploadImageTaskResult;

  bool uploadCalled = false;

  /// Content submission received by the latest [upload] call.
  ContentSubmission? lastUploadedSubmission;

  @override
  Future<Result<void>> upload(
    ContentSubmission contentSubmission,
    List<SubmissionAsset> submissionAssets,
  ) async {
    uploadCalled = true;
    lastUploadedSubmission = contentSubmission;
    return uploadResult;
  }

  @override
  ImageUploadTask uploadImageTask(File image) => uploadImageTaskResult;

  @override
  void dispose() {}
}

/// A stub [ImageUploadTask] for tests that do not exercise the upload pipeline.
final class _FakeUploadTask implements ImageUploadTask {
  _FakeUploadTask.success(Result<SubmissionAsset> result)
    : _result = Future.value(result);

  final Future<Result<SubmissionAsset>> _result;

  @override
  Future<Result<SubmissionAsset>> get result => _result;

  @override
  Stream<double> get progress => Stream<double>.value(1);

  @override
  void cancel() {}
}

// ---------------------------------------------------------------------------
// ControllableSubmissionRepository
// ---------------------------------------------------------------------------

/// A [ContentSubmissionRepository] fake whose [upload] result is gated by a
/// fresh [Completer] per call. Used by widget tests that need to hold the
/// submit [Command] in the running state until the test resolves it to
/// success or error.
///
/// [uploadImageTask] throws by default: the widget tests that consume this
/// fake run the submit pipeline with no assets, so any call to it indicates a
/// logic error. Pass a non-throwing [ImageUploadTask] via
/// [uploadImageTaskResult]
/// when a test actually needs the upload-image branch.
final class ControllableSubmissionRepository
    implements ContentSubmissionRepository {
  ControllableSubmissionRepository({
    this.uploadImageTaskResult,
    this.uploadImageTaskThrowMessage =
        'controllable repository tests run with no assets',
  });

  /// Optional task returned from [uploadImageTask]. When null, calling
  /// [uploadImageTask] throws with [uploadImageTaskThrowMessage].
  final ImageUploadTask? uploadImageTaskResult;

  /// Message used when [uploadImageTask] throws (i.e. when
  /// [uploadImageTaskResult] is null).
  final String uploadImageTaskThrowMessage;

  Completer<Result<void>>? _pending;
  int uploadCallCount = 0;

  @override
  Future<Result<void>> upload(
    ContentSubmission contentSubmission,
    List<SubmissionAsset> submissionAssets,
  ) async {
    uploadCallCount++;
    _pending = Completer<Result<void>>();
    return _pending!.future;
  }

  /// Resolves the in-flight [upload] call (if any) with [result]. Safe to
  /// call when no upload is pending: it is a no-op in that case.
  void completeUpload(Result<void> result) {
    final pending = _pending;
    _pending = null;
    pending?.complete(result);
  }

  @override
  ImageUploadTask uploadImageTask(File image) {
    final task = uploadImageTaskResult;
    if (task == null) {
      throw StateError(uploadImageTaskThrowMessage);
    }
    return task;
  }

  @override
  void dispose() {}
}

// ---------------------------------------------------------------------------
// FakeContentSubmissionDraftRepository
// ---------------------------------------------------------------------------

/// Create a fresh instance per test to avoid state bleed between tests.
final class FakeContentSubmissionDraftRepository
    implements ContentSubmissionDraftRepository {
  FakeContentSubmissionDraftRepository({
    this.loadDraftResult = const Result.success(null),
    this.saveDraftResult = const Result.success(null),
    this.clearDraftResult = const Result.success(null),
  });

  Result<ContentSubmissionDraft?> loadDraftResult;
  Result<void> saveDraftResult;
  Result<void> clearDraftResult;

  bool saveDraftCalled = false;
  int saveDraftCallCount = 0;
  bool clearDraftCalled = false;
  int clearDraftCallCount = 0;
  ContentSubmissionDraft? lastSavedState;

  @override
  Future<Result<ContentSubmissionDraft?>> loadDraft() async => loadDraftResult;

  @override
  Future<Result<void>> saveDraft(ContentSubmissionDraft state) async {
    saveDraftCalled = true;
    saveDraftCallCount++;
    lastSavedState = state;
    return saveDraftResult;
  }

  @override
  Future<Result<void>> clearDraft() async {
    clearDraftCalled = true;
    clearDraftCallCount++;
    return clearDraftResult;
  }
}

// ---------------------------------------------------------------------------
// FakeWeatherApiClient
// ---------------------------------------------------------------------------

final class FakeWeatherApiClient extends WeatherApiClient {
  FakeWeatherApiClient({this.result})
    : super(logger: MockLogger(), httpClient: _NoopHttpClient());

  /// The result to return from [getCombinedWeatherForecast].
  ///
  /// When `null`, returns an error indicating the weather API is not needed
  /// in the current test — matching the `post_screen_test` variant.
  Result<CombinedWeatherForecastResponse>? result;

  @override
  Future<Result<CombinedWeatherForecastResponse>> getCombinedWeatherForecast(
    double latitude,
    double longitude, {
    String timezone = 'Europe/Rome',
  }) async =>
      result ?? Result.error(Exception('Weather not configured for this test'));
}
