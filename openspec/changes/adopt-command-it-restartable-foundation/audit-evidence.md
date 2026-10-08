# Baseline and reproducible audit evidence

Audit date: 2026-10-08. Read-only repository/upstream inspection preceded artifact drafting.

Initial `git status --short`:
```text
?? openspec/changes/harden-geo-map-semantic-state/
```
`git rev-parse HEAD`: `58544bca16f3e826ae01ff90fc3442a014325892`; identical to supplied remote baseline, no local descendants. Origin is https://github.com/xmattjus/moliseis.git.

Flutter cache metadata: Flutter 3.47.5 stable, framework 6a19cca56475dbfba1478ee68d7bd0c2ef891da1; bundled executable reports Dart 3.13.4 stable. pubspec declares sdk ^3.11.5 and exact Flutter 3.47.5. Lockfile requires Dart >=3.13.0 <4.0.0 and Flutter 3.47.5. Resolved package_config points stream_transform to 2.1.2 (transitive lock entry); command_it/listen_it are absent. Normal flutter/dart launcher version commands initially failed because they attempt to update Homebrew cache outside sandbox; metadata and direct bundled Dart binary were read successfully. No SDK changes performed.

OpenSpec CLI 1.12.0, nearest repo-local root, schema spec-driven from openspec/config.yaml. Root AGENTS applies; no nested AGENTS found. Read openspec-propose, dart-add-unit-test, flutter-add-widget-test, molise-is-test-support-reuse, molise-is-async-mounted-context-safety find-docs, molise-is-result-pattern and supabase SKILL.md. No tests edited; these define subsequent apply gates.

Upstream releases verified via pub.dev API and downloaded archives in /tmp; current command_it main source matches release lib/command_it.dart byte-for-byte. Context7 official documentation lookup supplemented direct source review; no README-only conclusions.

- command_it 9.5.2: archive SHA256 `1d4705cb830a09917da5cb0007d4dacda187bbac9f7153552e56b4357825d1e6`.
- stream_transform 2.1.2: archive SHA256 `a00e5f18bffc764f923e7dec1038527f7fe7a1791361a7117f0358193f13d53a`.
- command_it main audited commit `4c0ad0095472a7a8f38aab958402d87348a6eda7`.
- bloc master reference commit `b9be1e252ee24ffbe9f2fb629edc7624b2cfbf05`; restartable source and test/src/restartable_test.dart read.

Release/cache stream_transform lib/src/switch.dart and test/switch_test.dart were compared byte-for-byte and match the downloaded 2.1.2 archive.

## Inspected baseline file hashes

- `pubspec.yaml` SHA256 `7378a3367d2c5329f557827b25611fb66fda4d91a80f43fcbd7b60bd1897e856`.
- `pubspec.lock` SHA256 `3128e2dc8bd8699d7be9024d36b2cd0279c64a5fa7ebc74828b69d8462be5270`.
- `AGENTS.md` SHA256 `d07f138873888ffb7e7723b1deafbf79b9599b51d98577c6f66ffc22b29f400e`.
- `lib/utils/command.dart` SHA256 `250f18b9a8d1804c3299e5c5d9b24448525d9b20c26baec78823c380b905f5d4`.
- `lib/ui/search/view_models/search_view_model.dart` SHA256 `13f064332ffa6f9d7426d78c5532ae0e2ae1e09d3714a2da6dbe5d9369c9b398`.
- `lib/ui/geo_map/view_models/geo_map_view_model.dart` SHA256 `8ef26c9fed42734dd9da94a32235a6ddf48bafb55d65d9420260c3d2e6db8ce7`.
- `lib/ui/geo_map/widgets/geo_map_screen.dart` SHA256 `c3fabcb4d52d6fce10caaf3a86edbec0cb8b0e198bc03bf114ae321f154a8570`.
- `lib/ui/post/view_models/post_view_model.dart` SHA256 `559a343c360a6acc746ce5fcb08d3c29b9a29b4b8532f71e50e7afce0b2f560c`.
- `lib/routing/core_routes.dart` SHA256 `82cc4d3ecfad90a1657d218cb5ff2f73dc620c4315789eaad9e756780a31beb9`.

## Full Command/lifecycle call-site index

This index includes false positives for generic error/result properties; design.md classifies actual consumers. It is evidence, not a directive to migrate all matches.

```text
lib/domain/use-cases/explore_use_case.dart:24:  /// Repository failures are propagated as `Result.error`.
lib/domain/use-cases/explore_use_case.dart:30:  /// Repository failures are propagated as `Result.error`.
lib/domain/use-cases/explore_use_case.dart:37:  /// Repository failures are propagated as `Result.error`.
lib/domain/use-cases/post_use_case.dart:21:  /// Repository failures are propagated as `Result.error`.
lib/domain/use-cases/post_use_case.dart:27:  /// Repository failures are propagated as `Result.error`.
lib/domain/use-cases/post_use_case.dart:33:  /// Repository failures are propagated as `Result.error`.
lib/domain/use-cases/post_use_case.dart:41:  /// Repository failures are propagated as `Result.error`.
lib/domain/use-cases/sync_use_case.dart:52:  /// time. Returns [Result.error] if any phase fails.
lib/domain/use-cases/sync_use_case.dart:77:          return Result.error(error);
lib/domain/use-cases/sync_use_case.dart:86:          return Result.error(error);
lib/domain/use-cases/sync_use_case.dart:95:          return Result.error(error);
lib/domain/use-cases/sync_use_case.dart:104:          return Result.error(error);
lib/domain/use-cases/explore_get_by_id_use_case.dart:8:  /// Repository failures are propagated as [Result.error].
lib/domain/use-cases/geo_map_use_case.dart:24:  /// Repository failures are propagated as `Result.error`.
lib/domain/use-cases/geo_map_use_case.dart:30:  /// Repository failures are propagated as `Result.error`.
lib/domain/use-cases/geo_map_use_case.dart:37:  /// Repository failures are propagated as `Result.error`.
lib/domain/use-cases/geo_map_use_case.dart:43:  /// Repository failures are propagated as `Result.error`.
lib/domain/use-cases/geo_map_use_case.dart:49:  /// Repository failures are propagated as `Result.error`.
lib/domain/use-cases/geo_map_use_case.dart:57:  /// Repository failures are propagated as `Result.error`.
lib/utils/command.dart:18:/// Use [Command0] for actions without arguments.
lib/utils/command.dart:19:/// Use [Command1] for actions with one argument.
lib/utils/command.dart:25:abstract class Command<T> extends ChangeNotifier {
lib/utils/command.dart:26:  Command();
lib/utils/command.dart:73:      // [Result.error] only accepts [Exception]. Actions are expected to
lib/utils/command.dart:80:      _result = Result.error(exception);
lib/utils/command.dart:95:/// [Command] without arguments.
lib/utils/command.dart:97:class Command0<T> extends Command<T> {
lib/utils/command.dart:98:  Command0(this._action);
lib/utils/command.dart:108:/// [Command] with one argument.
lib/utils/command.dart:110:class Command1<T, A> extends Command<T> {
lib/utils/command.dart:111:  Command1(this._action);
lib/data/services/external_url_service.dart:17:      // The generic exception Result.error returns on canLaunchUrl == false or
lib/data/services/external_url_service.dart:25:          false => Result.error(exception),
lib/data/services/external_url_service.dart:30:        return Result.error(exception);
lib/data/services/external_url_service.dart:38:      return Result.error(exception);
lib/utils/result.dart:15:  const factory Result.error(Exception error) = Error._;
lib/utils/result.dart:37:    return fold((value) => Result.success(mapper(value)), Result.error);
lib/utils/result.dart:47:    return fold(mapper, Result.error);
lib/utils/result.dart:56:      Error<T>(:final error) => Result.error(mapper(error)),
lib/utils/result.dart:99:      Error<T>(:final error) => Result.error(error),
lib/utils/result.dart:111:      Error<T>(:final error) => Result.error(error),
lib/utils/result.dart:124:      Error<T>(:final error) => Result.error(await mapper(error)),
lib/utils/result.dart:162:  /// result. [onSuccess] may itself return a [Result.error].
lib/utils/result.dart:172:        return Result.error(error);
lib/utils/result.dart:180:        return Result.error(error);
lib/utils/result.dart:194:  /// its result. [onSuccess] may itself return a [Result.error].
lib/utils/result.dart:205:        return Result.error(error);
lib/utils/result.dart:213:        return Result.error(error);
lib/utils/result.dart:221:        return Result.error(error);
lib/utils/result.dart:235:  /// its result. [onSuccess] may itself return a [Result.error].
lib/utils/result.dart:247:        return Result.error(error);
lib/utils/result.dart:255:        return Result.error(error);
lib/utils/result.dart:263:        return Result.error(error);
lib/utils/result.dart:271:        return Result.error(error);
lib/utils/result.dart:292:  const Error._(this.error);
lib/utils/result.dart:298:  String toString() => 'Result<$T>.error($error)';
lib/main.dart:43:      error: result.error,
lib/ui/event/widgets/components/events_calendar.dart:61:        if (widget.viewModel.loadAll.completed) {
lib/ui/event/widgets/components/events_calendar.dart:86:            child: widget.viewModel.loadAll.running
lib/routing/core_routes.dart:66:              viewModel.setSelectedCategories.execute(
lib/routing/core_routes.dart:150:            unawaited(viewModel.loadEvent.execute(id));
lib/routing/core_routes.dart:152:            unawaited(viewModel.loadPlace.execute(id));
lib/routing/router.dart:95:        RouteErrorScreen(uri: state.uri, error: state.error),
lib/routing/router.dart:217:              unawaited(viewModel.load.execute());
lib/routing/router.dart:272:                  unawaited(viewModel.load.execute());
lib/routing/router.dart:356:                            unawaited(viewModel.loadResults.execute(query));
lib/routing/router.dart:434:                        viewModel.loadByDate.execute(
lib/routing/router.dart:480:                  // share a Command across different selected content.
lib/routing/router.dart:535:/// - fatal first-sync error on `/sync` -> remain for retry
lib/routing/router.dart:546:  if (sync.running) {
lib/routing/router.dart:550:  if (!onSync || (sync.error && syncViewModel.fatalError)) return null;
lib/ui/event/widgets/components/events_modal.dart:63:            if (command.completed) {
lib/utils/logging/events/repository_log_events.dart:47:  AppLogLevel get level => AppLogLevel.error;
lib/utils/logging/events/repository_log_events.dart:96:  AppLogLevel get level => AppLogLevel.error;
lib/utils/logging/events/repository_log_events.dart:153:  AppLogLevel get level => AppLogLevel.error;
lib/utils/logging/events/repository_log_events.dart:182:  AppLogLevel get level => AppLogLevel.error;
lib/utils/logging/events/repository_log_events.dart:200:  AppLogLevel get level => AppLogLevel.error;
lib/data/services/api/weather/weather_api_client.dart:78:      return Result.error(error);
lib/data/services/api/weather/weather_api_client.dart:85:      return Result.error(exception);
lib/data/repositories/admin_content_submission_repository_impl.dart:250:      return Result.error(transportError);
lib/data/repositories/admin_content_submission_repository_impl.dart:254:      return Result.error(normalized);
lib/data/repositories/admin_content_submission_repository_impl.dart:257:      return Result.error(error);
lib/domain/repositories/admin_content_submission_repository.dart:47:  /// an idempotent same-target retry reports the original promotion exactly
lib/utils/logging/events/core_events.dart:15:  AppLogLevel get level => AppLogLevel.error;
lib/utils/logging/events/core_events.dart:39:  AppLogLevel get level => AppLogLevel.error;
lib/data/services/api/weather/model/base_weather_forecast_response.dart:15:    required this.generationTimeMs,
lib/data/services/api/weather/model/base_weather_forecast_response.dart:24:  @MappableField(key: 'generationtime_ms')
lib/data/services/api/weather/model/base_weather_forecast_response.dart:25:  final double generationTimeMs;
lib/utils/logging/events/content_submission_events.dart:32:  AppLogLevel get level => AppLogLevel.error;
lib/utils/logging/events/content_submission_events.dart:46:  AppLogLevel get level => AppLogLevel.error;
lib/utils/logging/events/content_submission_events.dart:88:  AppLogLevel get level => AppLogLevel.error;
lib/utils/logging/events/content_submission_events.dart:144:  AppLogLevel get level => AppLogLevel.error;
lib/utils/logging/events/content_submission_events.dart:186:  AppLogLevel get level => AppLogLevel.error;
lib/utils/logging/events/content_submission_events.dart:230:  AppLogLevel get level => AppLogLevel.error;
lib/data/services/api/weather/cached_weather_api_client.dart:147:      return Result.error(Exception('Failed to fetch current weather data.'));
lib/data/services/api/weather/cached_weather_api_client.dart:189:      return Result.error(Exception('Failed to fetch hourly weather data.'));
lib/data/services/api/weather/cached_weather_api_client.dart:232:      return Result.error(Exception('Failed to fetch daily weather data.'));
lib/utils/logging/events/local_persistence_log_events.dart:25:  AppLogLevel get level => AppLogLevel.error;
lib/data/repositories/content_submission_draft_repository_impl.dart:37:      return Result.error(exception);
lib/data/repositories/content_submission_draft_repository_impl.dart:59:      return Result.error(exception);
lib/data/repositories/content_submission_draft_repository_impl.dart:78:      return Result.error(exception);
lib/ui/event/widgets/events_screen.dart:34:    _draggableScrollableController.addListener(_draggableScrollableListener);
lib/ui/event/widgets/events_screen.dart:60:      ..removeListener(_draggableScrollableListener)
lib/ui/event/widgets/events_screen.dart:84:        onDayPressed: (date) => widget.viewModel.loadByDate.execute(
lib/data/services/api/weather/model/hourly_forecast/hourly_weather_forecast_response.dart:19:    required super.generationTimeMs,
lib/utils/logging/events/admin_events.dart:11:  AppLogLevel get level => AppLogLevel.error;
lib/utils/logging/events/admin_events.dart:39:  AppLogLevel get level => AppLogLevel.error;
lib/utils/logging/events/admin_events.dart:53:  AppLogLevel get level => AppLogLevel.error;
lib/utils/logging/events/admin_events.dart:69:  AppLogLevel get level => AppLogLevel.error;
lib/data/repositories/media_repository_impl.dart:87:      return Result.error(exception);
lib/data/repositories/media_repository_impl.dart:117:      return Result.error(exception);
lib/ui/event/view_models/event_view_model.dart:19:    loadAll = Command0(_loadAll);
lib/ui/event/view_models/event_view_model.dart:20:    unawaited(loadAll.execute());
lib/ui/event/view_models/event_view_model.dart:21:    loadByDate = Command1(_loadByDate);
lib/ui/event/view_models/event_view_model.dart:22:    loadOngoing = Command1(_loadOngoing);
lib/ui/event/view_models/event_view_model.dart:23:    loadNext = Command1(_loadNext);
lib/ui/event/view_models/event_view_model.dart:30:  late Command0<void> loadAll;
lib/ui/event/view_models/event_view_model.dart:31:  late Command1<void, EventCalendarDate> loadByDate;
lib/ui/event/view_models/event_view_model.dart:34:  late Command1<void, DateTime> loadOngoing;
lib/ui/event/view_models/event_view_model.dart:37:  late Command1<void, DateTime> loadNext;
lib/ui/event/view_models/event_view_model.dart:46:  bool _disposed = false;
lib/ui/event/view_models/event_view_model.dart:96:    if (_disposed) return result.map((_) {});
lib/ui/event/view_models/event_view_model.dart:160:    if (_disposed) return const Result.success(null);
lib/ui/event/view_models/event_view_model.dart:162:    if (_disposed) return result.map((_) {});
lib/ui/event/view_models/event_view_model.dart:171:    if (_disposed) return const Result.success(null);
lib/ui/event/view_models/event_view_model.dart:173:    if (_disposed) return result.map((_) {});
lib/ui/event/view_models/event_view_model.dart:187:    if (_disposed) return Future.value();
lib/ui/event/view_models/event_view_model.dart:200:      while (!_disposed && _homeRefreshPending) {
lib/ui/event/view_models/event_view_model.dart:202:        while (!_disposed && (loadOngoing.running || loadNext.running)) {
lib/ui/event/view_models/event_view_model.dart:206:        if (_disposed) break;
lib/ui/event/view_models/event_view_model.dart:209:        await loadOngoing.execute(snapshotUtc);
lib/ui/event/view_models/event_view_model.dart:210:        if (_disposed) break;
lib/ui/event/view_models/event_view_model.dart:211:        await loadNext.execute(snapshotUtc);
lib/ui/event/view_models/event_view_model.dart:221:  Future<void> _waitForCommand(Command<void> command) {
lib/ui/event/view_models/event_view_model.dart:222:    if (_disposed || !command.running) return Future.value();
lib/ui/event/view_models/event_view_model.dart:226:      command.removeListener(listener);
lib/ui/event/view_models/event_view_model.dart:232:      if (!command.running) finish();
lib/ui/event/view_models/event_view_model.dart:235:    command.addListener(listener);
lib/ui/event/view_models/event_view_model.dart:241:    _disposed = true;
lib/utils/logging/events/service_log_events.dart:90:  AppLogLevel get level => AppLogLevel.error;
lib/utils/logging/events/service_log_events.dart:199:  AppLogLevel get level => AppLogLevel.error;
lib/utils/logging/events/service_log_events.dart:272:  AppLogLevel get level => AppLogLevel.error;
lib/utils/logging/events/service_log_events.dart:318:  AppLogLevel get level => AppLogLevel.error;
lib/utils/logging/events/service_log_events.dart:332:  AppLogLevel get level => AppLogLevel.error;
lib/utils/synchronizable.dart:18:  /// `Result.error` if the commit fails.
lib/data/repositories/content_submission_repository_impl.dart:76:      return Result.error(transportError);
lib/data/repositories/content_submission_repository_impl.dart:85:      return Result.error(normalized);
lib/data/repositories/content_submission_repository_impl.dart:93:      return Result.error(exception);
lib/data/services/api/weather/model/hourly_forecast/generated/hourly_weather_forecast_response.mapper.dart:39:  static double _$generationTimeMs(HourlyWeatherForecastResponse v) =>
lib/data/services/api/weather/model/hourly_forecast/generated/hourly_weather_forecast_response.mapper.dart:40:      v.generationTimeMs;
lib/data/services/api/weather/model/hourly_forecast/generated/hourly_weather_forecast_response.mapper.dart:42:  _f$generationTimeMs = Field(
lib/data/services/api/weather/model/hourly_forecast/generated/hourly_weather_forecast_response.mapper.dart:43:    'generationTimeMs',
lib/data/services/api/weather/model/hourly_forecast/generated/hourly_weather_forecast_response.mapper.dart:44:    _$generationTimeMs,
lib/data/services/api/weather/model/hourly_forecast/generated/hourly_weather_forecast_response.mapper.dart:45:    key: r'generationtime_ms',
lib/data/services/api/weather/model/hourly_forecast/generated/hourly_weather_forecast_response.mapper.dart:86:    #generationTimeMs: _f$generationTimeMs,
lib/data/services/api/weather/model/hourly_forecast/generated/hourly_weather_forecast_response.mapper.dart:99:      generationTimeMs: data.dec(_f$generationTimeMs),
lib/ui/sync/widgets/sync_screen.dart:29:    _syncViewModel.sync.addListener(_onSyncChanged);
lib/ui/sync/widgets/sync_screen.dart:34:    _syncViewModel.sync.removeListener(_onSyncChanged);
lib/ui/sync/widgets/sync_screen.dart:39:    if (_syncViewModel.sync.error && !_syncViewModel.fatalError) {
lib/ui/sync/widgets/sync_screen.dart:47:          type: SnackBarType.error,
lib/ui/sync/widgets/sync_screen.dart:69:                if (viewModel.sync.error && viewModel.fatalError) {
lib/ui/sync/widgets/sync_screen.dart:86:                          unawaited(viewModel.sync.execute(true));
lib/ui/sync/widgets/sync_screen.dart:94:                if (viewModel.sync.running) {
lib/utils/logging/app_logger.dart:62:    if (error != null && level.index >= AppLogLevel.error.index) {
lib/utils/logging/app_log_level_mapper.dart:10:  AppLogLevel.error => LogLevel.error,
lib/utils/logging/app_log_level_mapper.dart:19:  AppLogLevel.error => SentryLevel.error,
lib/ui/sync/view_models/sync_view_model.dart:13:    sync = Command1(_sync);
lib/ui/sync/view_models/sync_view_model.dart:16:      sync.execute(false);
lib/ui/sync/view_models/sync_view_model.dart:31:  /// Command for triggering synchronization.
lib/ui/sync/view_models/sync_view_model.dart:35:  late Command1<void, bool> sync;
lib/data/repositories/content_submission_staged_asset_repository_impl.dart:58:      return Result.error(Exception('Invalid staged asset ownership.'));
lib/data/repositories/content_submission_staged_asset_repository_impl.dart:65:        return Result.error(Exception('Staged source exceeds the size limit.'));
lib/data/repositories/content_submission_staged_asset_repository_impl.dart:98:        return Result.error(
lib/data/repositories/content_submission_staged_asset_repository_impl.dart:121:      return Result.error(exception);
lib/data/repositories/content_submission_staged_asset_repository_impl.dart:128:      return Result.error(Exception('Invalid staged asset ownership.'));
lib/data/repositories/content_submission_staged_asset_repository_impl.dart:136:      return Result.error(exception);
lib/data/repositories/content_submission_staged_asset_repository_impl.dart:147:      return Result.error(Exception('Invalid staged asset ownership.'));
lib/data/repositories/content_submission_staged_asset_repository_impl.dart:167:      return Result.error(exception);
lib/data/repositories/content_submission_staged_asset_repository_impl.dart:177:      return Result.error(Exception('Invalid staged asset ownership.'));
lib/data/repositories/content_submission_staged_asset_repository_impl.dart:269:      return Result.error(exception);
lib/data/repositories/content_submission_staged_asset_repository_impl.dart:282:        return Result.error(Exception('Staged asset is unavailable.'));
lib/data/repositories/content_submission_staged_asset_repository_impl.dart:291:      return Result.error(exception);
lib/data/data-sources/settings_local_data_source.dart:27:      return Result.error(
lib/data/data-sources/settings_local_data_source.dart:39:      return Result.error(
lib/data/services/api/weather/model/combined_weather_forecast_response.dart:26:    required super.generationTimeMs,
lib/data/repositories/event_repository_impl.dart:102:      return Result.error(exception);
lib/data/repositories/event_repository_impl.dart:145:      return Result.error(exception);
lib/data/repositories/event_repository_impl.dart:184:      return Result.error(exception);
lib/data/repositories/event_repository_impl.dart:252:      return Result.error(exception);
lib/data/repositories/event_repository_impl.dart:275:      return Result.error(exception);
lib/data/repositories/event_repository_impl.dart:297:        return Result.error(Exception('Event with id: $id not found'));
lib/data/repositories/event_repository_impl.dart:306:      return Result.error(exception);
lib/data/repositories/event_repository_impl.dart:342:      return Result.error(exception);
lib/data/repositories/event_repository_impl.dart:383:      return Result.error(exception);
lib/data/repositories/event_repository_impl.dart:408:      return Result.error(exception);
lib/data/repositories/event_repository_impl.dart:444:      return Result.error(exception);
lib/domain/core/sync_transaction_coordinator.dart:6:/// `Result` produced by [fn]. If [fn] returns `Result.error`, the transaction
lib/ui/geo_map/widgets/geo_map_screen.dart:114:  /// A single retry is enough to recover from an `execute()` silently dropped
lib/ui/geo_map/widgets/geo_map_screen.dart:115:  /// by `Command._execute` while a previous execution was still running
lib/ui/geo_map/widgets/geo_map_screen.dart:121:  /// Current retry count for the resolution of [_pendingSelection].
lib/ui/geo_map/widgets/geo_map_screen.dart:124:  /// a terminal state (match, error, or retry budget exhausted).
lib/ui/geo_map/widgets/geo_map_screen.dart:130:  bool _retryAfterPriorCommand = false;
lib/ui/geo_map/widgets/geo_map_screen.dart:136:    widget.viewModel.showEvent.addListener(_onSelectionResolutionChanged);
lib/ui/geo_map/widgets/geo_map_screen.dart:137:    widget.viewModel.showPlace.addListener(_onSelectionResolutionChanged);
lib/ui/geo_map/widgets/geo_map_screen.dart:153:      oldWidget.viewModel.showEvent.removeListener(
lib/ui/geo_map/widgets/geo_map_screen.dart:156:      oldWidget.viewModel.showPlace.removeListener(
lib/ui/geo_map/widgets/geo_map_screen.dart:159:      widget.viewModel.showEvent.addListener(_onSelectionResolutionChanged);
lib/ui/geo_map/widgets/geo_map_screen.dart:160:      widget.viewModel.showPlace.addListener(_onSelectionResolutionChanged);
lib/ui/geo_map/widgets/geo_map_screen.dart:175:      _retryAfterPriorCommand = false;
lib/ui/geo_map/widgets/geo_map_screen.dart:194:    widget.viewModel.showEvent.removeListener(_onSelectionResolutionChanged);
lib/ui/geo_map/widgets/geo_map_screen.dart:195:    widget.viewModel.showPlace.removeListener(_onSelectionResolutionChanged);
lib/ui/geo_map/widgets/geo_map_screen.dart:213:    _retryAfterPriorCommand = false;
lib/ui/geo_map/widgets/geo_map_screen.dart:226:      _retryAfterPriorCommand = command.running;
lib/ui/geo_map/widgets/geo_map_screen.dart:227:      unawaited(command.execute(request.id));
lib/ui/geo_map/widgets/geo_map_screen.dart:255:    if (command.running) return;
lib/ui/geo_map/widgets/geo_map_screen.dart:257:    final retryAfterPriorCommand = _retryAfterPriorCommand;
lib/ui/geo_map/widgets/geo_map_screen.dart:258:    _retryAfterPriorCommand = false;
lib/ui/geo_map/widgets/geo_map_screen.dart:259:    if (command.error && !retryAfterPriorCommand) {
lib/ui/geo_map/widgets/geo_map_screen.dart:265:    // is a superseded request that Command._execute silently dropped while a
lib/ui/geo_map/widgets/geo_map_screen.dart:280:          ? widget.viewModel.showEvent.execute(request.id)
lib/ui/geo_map/widgets/geo_map_screen.dart:281:          : widget.viewModel.showPlace.execute(request.id),
lib/ui/geo_map/widgets/geo_map_screen.dart:288:  /// Used both when the command completes with an error and when the retry
lib/ui/geo_map/widgets/geo_map_screen.dart:294:      _retryAfterPriorCommand = false;
lib/ui/geo_map/widgets/geo_map_screen.dart:302:      type: SnackBarType.error,
lib/ui/geo_map/widgets/geo_map_screen.dart:353:            if (widget.viewModel.loadEvents.completed &&
lib/ui/geo_map/widgets/geo_map_screen.dart:354:                widget.viewModel.loadPlaces.completed) {
lib/ui/geo_map/widgets/geo_map_screen.dart:515:    unawaited(widget.searchViewModel.loadResults.execute(text));
lib/ui/geo_map/widgets/geo_map_screen.dart:535:      widget.viewModel.setSelectedCategories.execute(selectedCategories);
lib/ui/geo_map/widgets/geo_map_screen.dart:538:      widget.viewModel.setSelectedTypes.execute(selectedTypes);
lib/data/repositories/search_repository_impl.dart:93:      return Result.error(exception);
lib/data/repositories/search_repository_impl.dart:138:      return Result.error(exception);
lib/data/repositories/search_repository_impl.dart:205:      return Result.error(exception);
lib/data/repositories/search_repository_impl.dart:227:      return Result.error(exception);
lib/data/repositories/search_repository_impl.dart:249:      return Result.error(exception);
lib/data/repositories/place_repository_impl.dart:95:      return Result.error(exception);
lib/data/repositories/place_repository_impl.dart:139:      return Result.error(exception);
lib/data/repositories/place_repository_impl.dart:183:      return Result.error(exception);
lib/data/repositories/place_repository_impl.dart:205:        return Result.error(Exception('Place with id: $id not found'));
lib/data/repositories/place_repository_impl.dart:214:      return Result.error(exception);
lib/data/repositories/place_repository_impl.dart:240:      return Result.error(exception);
lib/data/repositories/place_repository_impl.dart:265:      return Result.error(exception);
lib/data/repositories/place_repository_impl.dart:302:      return Result.error(exception);
lib/data/repositories/place_repository_impl.dart:330:      return Result.error(exception);
lib/data/services/api/weather/model/daily_forecast/daily_weather_forecast_response.dart:21:    required super.generationTimeMs,
lib/data/core/objectbox_sync_transaction_coordinator.dart:23:      return Result.error(exception);
lib/data/core/objectbox_sync_transaction_coordinator.dart:27:      return Result.error(Exception('$error, $stackTrace'));
lib/ui/geo_map/widgets/components/animated_map_attribution.dart:25:    _controller.addListener(_bottomSheetListener);
lib/ui/geo_map/widgets/components/animated_map_attribution.dart:30:    _controller.removeListener(_bottomSheetListener);
lib/data/services/api/weather/model/daily_forecast/generated/daily_weather_forecast_response.mapper.dart:40:  static double _$generationTimeMs(DailyWeatherForecastResponse v) =>
lib/data/services/api/weather/model/daily_forecast/generated/daily_weather_forecast_response.mapper.dart:41:      v.generationTimeMs;
lib/data/services/api/weather/model/daily_forecast/generated/daily_weather_forecast_response.mapper.dart:42:  static const Field<DailyWeatherForecastResponse, double> _f$generationTimeMs =
lib/data/services/api/weather/model/daily_forecast/generated/daily_weather_forecast_response.mapper.dart:43:      Field('generationTimeMs', _$generationTimeMs, key: r'generationtime_ms');
lib/data/services/api/weather/model/daily_forecast/generated/daily_weather_forecast_response.mapper.dart:75:    #generationTimeMs: _f$generationTimeMs,
lib/data/services/api/weather/model/daily_forecast/generated/daily_weather_forecast_response.mapper.dart:87:      generationTimeMs: data.dec(_f$generationTimeMs),
lib/data/services/api/cloudinary/cloudinary_upload_client_impl.dart:42:    @visibleForTesting Future<void> Function(Duration)? retryDelay,
lib/data/services/api/cloudinary/cloudinary_upload_client_impl.dart:48:       _retryDelay = retryDelay ?? Future<void>.delayed,
lib/data/services/api/cloudinary/cloudinary_upload_client_impl.dart:58:  static const _kUploadRetryBaseDelay = Duration(milliseconds: 500);
lib/data/services/api/cloudinary/cloudinary_upload_client_impl.dart:61:  static const _kUploadRetryMaxDelay = Duration(seconds: 10);
lib/data/services/api/cloudinary/cloudinary_upload_client_impl.dart:68:  final Future<void> Function(Duration) _retryDelay;
lib/data/services/api/cloudinary/cloudinary_upload_client_impl.dart:130:        Result.error(
lib/data/services/api/cloudinary/cloudinary_upload_client_impl.dart:141:        const Result.error(
lib/data/services/api/cloudinary/cloudinary_upload_client_impl.dart:161:        return _finalizeUploadResult(Result.error(error), token);
lib/data/services/api/cloudinary/cloudinary_upload_client_impl.dart:188:        return const Result.error(UploadCancelledException());
lib/data/services/api/cloudinary/cloudinary_upload_client_impl.dart:191:        Result.error(
lib/data/services/api/cloudinary/cloudinary_upload_client_impl.dart:218:    // it records the highest progress value emitted across all retry attempts
lib/data/services/api/cloudinary/cloudinary_upload_client_impl.dart:220:    // when a retry restarts from zero bytes uploaded (see the guard at the
lib/data/services/api/cloudinary/cloudinary_upload_client_impl.dart:226:        result = const Result.error(UploadCancelledException());
lib/data/services/api/cloudinary/cloudinary_upload_client_impl.dart:243:        // a `Result.error(TimeoutException)` inside [_executeUploadAttempt]
lib/data/services/api/cloudinary/cloudinary_upload_client_impl.dart:244:        // so the in-flight request can be aborted before the retry loop
lib/data/services/api/cloudinary/cloudinary_upload_client_impl.dart:246:        // streaming in the background and compete with the retry for the
lib/data/services/api/cloudinary/cloudinary_upload_client_impl.dart:249:          result = const Result.error(UploadCancelledException());
lib/data/services/api/cloudinary/cloudinary_upload_client_impl.dart:252:        // Thrown (non-timeout) exceptions are not retryable: bail out on the
lib/data/services/api/cloudinary/cloudinary_upload_client_impl.dart:257:        result = Result.error(exception);
lib/data/services/api/cloudinary/cloudinary_upload_client_impl.dart:266:        // Retry on HTTP 5xx (server errors) or TimeoutException (transient
lib/data/services/api/cloudinary/cloudinary_upload_client_impl.dart:268:        final isRetryable =
lib/data/services/api/cloudinary/cloudinary_upload_client_impl.dart:273:        if (!isRetryable || attempt == _kMaxUploadAttempts) {
lib/data/services/api/cloudinary/cloudinary_upload_client_impl.dart:287:        final delay = _kUploadRetryBaseDelay * multiplier;
lib/data/services/api/cloudinary/cloudinary_upload_client_impl.dart:289:          _retryDelay(
lib/data/services/api/cloudinary/cloudinary_upload_client_impl.dart:290:            delay > _kUploadRetryMaxDelay ? _kUploadRetryMaxDelay : delay,
lib/data/services/api/cloudinary/cloudinary_upload_client_impl.dart:295:          result = const Result.error(UploadCancelledException());
lib/data/services/api/cloudinary/cloudinary_upload_client_impl.dart:323:    // SocketException, which the retry loop classifies as non-retryable, so a
lib/data/services/api/cloudinary/cloudinary_upload_client_impl.dart:324:    // transient connect timeout never triggers a retry — only streaming
lib/data/services/api/cloudinary/cloudinary_upload_client_impl.dart:328:    // retrying. Worth keeping in mind if the connectionTimeout is ever tuned.
lib/data/services/api/cloudinary/cloudinary_upload_client_impl.dart:337:    // closed and the retry does not compete with a zombie upload for the
lib/data/services/api/cloudinary/cloudinary_upload_client_impl.dart:341:    // [CloudinaryUploadCancellationToken.cancel] so the retry loop can
lib/data/services/api/cloudinary/cloudinary_upload_client_impl.dart:375:        return Result.error(
lib/data/services/api/cloudinary/cloudinary_upload_client_impl.dart:388:        return const Result.error(EmptyUrlException());
lib/data/services/api/cloudinary/cloudinary_upload_client_impl.dart:392:        return const Result.error(InvalidAssetDimensions());
lib/data/services/api/cloudinary/cloudinary_upload_client_impl.dart:408:        return Result.error(exception);
lib/data/services/api/cloudinary/cloudinary_upload_client_impl.dart:414:        // `TimeoutException` so the retry classification treats this as
lib/data/services/api/cloudinary/cloudinary_upload_client_impl.dart:416:        return Result.error(
lib/data/services/api/cloudinary/cloudinary_upload_client_impl.dart:428:      // cancellation handler and retry classification can route them —
lib/data/services/api/cloudinary/cloudinary_upload_client_impl.dart:429:      // the inner `Result.error` return is reserved for HTTP/JSON
lib/data/services/api/cloudinary/cloudinary_upload_client_impl.dart:507:        Result.error(Exception('Cloudinary upload failed after retrying'));
lib/data/services/api/cloudinary/cloudinary_upload_client_impl.dart:537:          // above (e.g. a final [TimeoutException] after all retry attempts
lib/data/services/api/weather/model/current_forecast/current_weather_forecast_response.dart:16:    required super.generationTimeMs,
lib/ui/geo_map/widgets/geo_map_tile_layer.dart:3:import 'package:http/retry.dart';
lib/ui/geo_map/widgets/geo_map_tile_layer.dart:22:      httpClient: RetryClient(context.read<http.Client>()),
lib/ui/search/widgets/components/app_search_anchor.dart:171:            unawaited(widget.viewModel.addToPastSearches.execute(query));
lib/ui/search/widgets/components/app_search_anchor.dart:215:                  if (viewModel.loadSuggestions.completed) {
lib/ui/search/widgets/components/app_search_anchor.dart:229:                          viewModel.addToPastSearches.execute(content.name),
lib/ui/search/widgets/components/app_search_anchor.dart:237:                  if (viewModel.loadSuggestions.error) {
lib/ui/search/widgets/components/app_search_anchor.dart:270:            unawaited(viewModel.addToPastSearches.execute(e));
lib/ui/search/widgets/components/app_search_anchor.dart:275:                  unawaited(viewModel.removeFromPastSearches.execute(e));
lib/ui/search/widgets/components/app_search_anchor.dart:319:                widget.viewModel.addToPastSearches.execute(category.label),
lib/ui/search/widgets/components/app_search_anchor.dart:385:    await viewModel.loadSuggestions.execute(query);
lib/data/services/api/cloudinary/cloudinary_upload_cancellation_token.dart:46:          if (!_cancelled && !attachment.abortedForRetry) {
lib/data/services/api/cloudinary/cloudinary_upload_cancellation_token.dart:73:  /// so the retry loop can attach a fresh request. Unlike [cancel], this does
lib/data/services/api/cloudinary/cloudinary_upload_cancellation_token.dart:82:      ..abortedForRetry = true
lib/data/services/api/cloudinary/cloudinary_upload_cancellation_token.dart:91:  bool abortedForRetry = false;
lib/ui/search/widgets/search_result_sliver_list.dart:12:    this.onRetrySearchPressed,
lib/ui/search/widgets/search_result_sliver_list.dart:16:  final void Function()? onRetrySearchPressed;
lib/ui/search/widgets/search_result_sliver_list.dart:27:            if (viewModel.loadResults.completed) {
lib/ui/search/widgets/search_result_sliver_list.dart:45:            if (viewModel.loadResults.error) {
lib/ui/search/widgets/search_result_sliver_list.dart:52:                    onPressed: onRetrySearchPressed,
lib/data/core/base_sync_repository.dart:57:      return Result.error(e);
lib/data/core/base_sync_repository.dart:116:      return Result.error(e);
lib/ui/geo_map/widgets/geo_map_modal_search_results.dart:53:          onRetrySearchPressed: () {
lib/ui/geo_map/widgets/geo_map_modal_search_results.dart:54:            widget.viewModel.loadResults.execute(widget.query);
lib/data/services/api/weather/model/current_forecast/generated/current_weather_forecast_response.mapper.dart:36:  static double _$generationTimeMs(CurrentWeatherForecastResponse v) =>
lib/data/services/api/weather/model/current_forecast/generated/current_weather_forecast_response.mapper.dart:37:      v.generationTimeMs;
lib/data/services/api/weather/model/current_forecast/generated/current_weather_forecast_response.mapper.dart:39:  _f$generationTimeMs = Field(
lib/data/services/api/weather/model/current_forecast/generated/current_weather_forecast_response.mapper.dart:40:    'generationTimeMs',
lib/data/services/api/weather/model/current_forecast/generated/current_weather_forecast_response.mapper.dart:41:    _$generationTimeMs,
lib/data/services/api/weather/model/current_forecast/generated/current_weather_forecast_response.mapper.dart:42:    key: r'generationtime_ms',
lib/data/services/api/weather/model/current_forecast/generated/current_weather_forecast_response.mapper.dart:73:    #generationTimeMs: _f$generationTimeMs,
lib/data/services/api/weather/model/current_forecast/generated/current_weather_forecast_response.mapper.dart:85:      generationTimeMs: data.dec(_f$generationTimeMs),
lib/data/services/api/cloudinary/supabase_cloudinary_upload_preparation_client.dart:30:      return const Result.error(
lib/data/services/api/cloudinary/supabase_cloudinary_upload_preparation_client.dart:48:      return Result.error(recoverSupabaseFunctionsFetchError(error));
lib/data/services/api/cloudinary/supabase_cloudinary_upload_preparation_client.dart:50:      return Result.error(
lib/data/services/api/cloudinary/supabase_cloudinary_upload_preparation_client.dart:54:      return Result.error(error);
lib/data/services/api/weather/model/generated/base_weather_forecast_response.mapper.dart:38:  static double _$generationTimeMs(BaseWeatherForecastResponse v) =>
lib/data/services/api/weather/model/generated/base_weather_forecast_response.mapper.dart:39:      v.generationTimeMs;
lib/data/services/api/weather/model/generated/base_weather_forecast_response.mapper.dart:40:  static const Field<BaseWeatherForecastResponse, double> _f$generationTimeMs =
lib/data/services/api/weather/model/generated/base_weather_forecast_response.mapper.dart:41:      Field('generationTimeMs', _$generationTimeMs, key: r'generationtime_ms');
lib/data/services/api/weather/model/generated/base_weather_forecast_response.mapper.dart:69:    #generationTimeMs: _f$generationTimeMs,
lib/data/services/api/weather/model/generated/base_weather_forecast_response.mapper.dart:80:      generationTimeMs: data.dec(_f$generationTimeMs),
lib/ui/search/widgets/search_result_screen.dart:83:                  onRetrySearchPressed: () {
lib/ui/search/widgets/search_result_screen.dart:85:                      widget.viewModel.loadResults.execute(widget.query),
lib/ui/search/view_models/search_view_model.dart:14:/// All async actions are exposed as [Command]s so that
lib/ui/search/view_models/search_view_model.dart:20:    addToPastSearches = Command1(_addToPastSearches);
lib/ui/search/view_models/search_view_model.dart:21:    loadPastSearches = Command0(_loadPastSearches)..execute();
lib/ui/search/view_models/search_view_model.dart:22:    loadResults = Command1(_loadResults);
lib/ui/search/view_models/search_view_model.dart:23:    removeFromPastSearches = Command1(_removeFromPastSearches);
lib/ui/search/view_models/search_view_model.dart:24:    loadSuggestions = Command1(_loadSuggestions);
lib/ui/search/view_models/search_view_model.dart:28:  bool _disposed = false;
lib/ui/search/view_models/search_view_model.dart:32:    _disposed = true;
lib/ui/search/view_models/search_view_model.dart:40:  late Command1<void, String> addToPastSearches;
lib/ui/search/view_models/search_view_model.dart:45:  late Command0<void> loadPastSearches;
lib/ui/search/view_models/search_view_model.dart:50:  late Command1<void, String> loadResults;
lib/ui/search/view_models/search_view_model.dart:56:  late Command1<void, String> removeFromPastSearches;
lib/ui/search/view_models/search_view_model.dart:62:  late Command1<void, String> loadSuggestions;
lib/ui/search/view_models/search_view_model.dart:108:    if (_disposed) return result;
lib/ui/search/view_models/search_view_model.dart:120:    if (_disposed) return result.map((_) {});
lib/ui/search/view_models/search_view_model.dart:138:    if (_disposed) return result;
lib/ui/search/view_models/search_view_model.dart:159:    if (_disposed) return result.map((_) {});
lib/data/services/api/weather/model/generated/combined_weather_forecast_response.mapper.dart:38:  static double _$generationTimeMs(CombinedWeatherForecastResponse v) =>
lib/data/services/api/weather/model/generated/combined_weather_forecast_response.mapper.dart:39:      v.generationTimeMs;
lib/data/services/api/weather/model/generated/combined_weather_forecast_response.mapper.dart:41:  _f$generationTimeMs = Field(
lib/data/services/api/weather/model/generated/combined_weather_forecast_response.mapper.dart:42:    'generationTimeMs',
lib/data/services/api/weather/model/generated/combined_weather_forecast_response.mapper.dart:43:    _$generationTimeMs,
lib/data/services/api/weather/model/generated/combined_weather_forecast_response.mapper.dart:44:    key: r'generationtime_ms',
lib/data/services/api/weather/model/generated/combined_weather_forecast_response.mapper.dart:88:    #generationTimeMs: _f$generationTimeMs,
lib/data/services/api/weather/model/generated/combined_weather_forecast_response.mapper.dart:102:      generationTimeMs: data.dec(_f$generationTimeMs),
lib/ui/explore/widgets/suggestion_horizontal_list_view.dart:57:              final showPlaceholders = viewModel.load.running;
lib/ui/explore/widgets/suggestion_horizontal_list_view.dart:59:              if (viewModel.load.error) {
lib/ui/explore/widgets/suggestion_horizontal_list_view.dart:60:                return EmptyView.error(
lib/ui/explore/widgets/suggestion_horizontal_list_view.dart:65:                    onPressed: () => unawaited(viewModel.load.execute()),
lib/ui/explore/widgets/suggestion_horizontal_list_view.dart:84:              if (viewModel.load.completed && viewModel.suggestions.isEmpty) {
lib/ui/content_submission/widgets/content_submission_fields.dart:229:              style: TextStyle(color: context.colorScheme.error),
lib/ui/explore/widgets/explore_screen.dart:71:    _router?.routerDelegate.removeListener(_onRouteChanged);
lib/ui/explore/widgets/explore_screen.dart:75:    router.routerDelegate.addListener(_onRouteChanged);
lib/ui/explore/widgets/explore_screen.dart:113:    _router?.routerDelegate.removeListener(_onRouteChanged);
lib/ui/explore/widgets/explore_screen.dart:224:                  if (widget.eventViewModel.loadOngoing.completed) {
lib/ui/explore/widgets/explore_screen.dart:246:                  if (widget.eventViewModel.loadOngoing.error) {
lib/ui/explore/widgets/explore_screen.dart:250:                        child: EmptyView.error(
lib/ui/explore/widgets/explore_screen.dart:277:                  if (widget.eventViewModel.loadNext.completed) {
lib/ui/explore/widgets/explore_screen.dart:299:                  if (widget.eventViewModel.loadNext.error) {
lib/ui/explore/widgets/explore_screen.dart:303:                        child: EmptyView.error(
lib/ui/explore/widgets/explore_screen.dart:355:                  if (widget.exploreViewModel.loadLatest.completed) {
lib/ui/explore/widgets/explore_screen.dart:374:                  if (widget.exploreViewModel.loadLatest.error) {
lib/ui/explore/widgets/explore_screen.dart:378:                        child: EmptyView.error(
lib/ui/explore/widgets/explore_screen.dart:384:                              widget.exploreViewModel.loadLatest.execute(),
lib/ui/explore/widgets/explore_screen.dart:407:    unawaited(syncViewModel.sync.execute(true));
lib/ui/geo_map/widgets/geo_map_bottom_sheet.dart:72:    _controller.addListener(_onVerticalDragUpdate);
lib/ui/geo_map/widgets/geo_map_bottom_sheet.dart:97:    _controller.removeListener(_onVerticalDragUpdate);
lib/ui/geo_map/view_models/geo_map_view_model.dart:15:    loadEvents = Command0(_loadEvents)..execute();
lib/ui/geo_map/view_models/geo_map_view_model.dart:16:    loadNearContent = Command1(_loadNearContent);
lib/ui/geo_map/view_models/geo_map_view_model.dart:17:    loadPlaces = Command0(_loadPlaces)..execute();
lib/ui/geo_map/view_models/geo_map_view_model.dart:18:    setSelectedCategories = Command1(_setSelectedCategories);
lib/ui/geo_map/view_models/geo_map_view_model.dart:19:    setSelectedTypes = Command1(_setSelectedTypes);
lib/ui/geo_map/view_models/geo_map_view_model.dart:20:    showEvent = Command1(_showEvent);
lib/ui/geo_map/view_models/geo_map_view_model.dart:21:    showPlace = Command1(_showPlace);
lib/ui/geo_map/view_models/geo_map_view_model.dart:27:  bool _disposed = false;
lib/ui/geo_map/view_models/geo_map_view_model.dart:31:    _disposed = true;
lib/ui/geo_map/view_models/geo_map_view_model.dart:35:  late Command0<void> loadEvents;
lib/ui/geo_map/view_models/geo_map_view_model.dart:36:  late Command1<void, LatLng> loadNearContent;
lib/ui/geo_map/view_models/geo_map_view_model.dart:37:  late Command0<void> loadPlaces;
lib/ui/geo_map/view_models/geo_map_view_model.dart:38:  late Command1<void, Set<ContentCategory>> setSelectedCategories;
lib/ui/geo_map/view_models/geo_map_view_model.dart:39:  late Command1<void, Set<ContentType>> setSelectedTypes;
lib/ui/geo_map/view_models/geo_map_view_model.dart:40:  late Command1<void, int> showEvent;
lib/ui/geo_map/view_models/geo_map_view_model.dart:41:  late Command1<void, int> showPlace;
lib/ui/geo_map/view_models/geo_map_view_model.dart:52:  int _selectionGeneration = 0;
lib/ui/geo_map/view_models/geo_map_view_model.dart:68:    _selectionGeneration++;
lib/ui/geo_map/view_models/geo_map_view_model.dart:77:    if (_disposed) return result;
lib/ui/geo_map/view_models/geo_map_view_model.dart:92:    if (_disposed) return result;
lib/ui/geo_map/view_models/geo_map_view_model.dart:112:    if (_disposed) return placesResult;
lib/ui/geo_map/view_models/geo_map_view_model.dart:120:    if (_disposed) return placesResult.isError ? placesResult : eventsResult;
lib/ui/geo_map/view_models/geo_map_view_model.dart:141:    if (_disposed) return const Result.success(null);
lib/ui/geo_map/view_models/geo_map_view_model.dart:156:    if (_disposed) return const Result.success(null);
lib/ui/geo_map/view_models/geo_map_view_model.dart:168:      await loadEvents.execute();
lib/ui/geo_map/view_models/geo_map_view_model.dart:169:      if (_disposed) return const Result.success(null);
lib/ui/geo_map/view_models/geo_map_view_model.dart:170:      await loadPlaces.execute();
lib/ui/geo_map/view_models/geo_map_view_model.dart:172:      await loadEvents.execute();
lib/ui/geo_map/view_models/geo_map_view_model.dart:174:      await loadPlaces.execute();
lib/ui/geo_map/view_models/geo_map_view_model.dart:181:    final generation = ++_selectionGeneration;
lib/ui/geo_map/view_models/geo_map_view_model.dart:183:    if (_disposed || generation != _selectionGeneration) return result;
lib/ui/geo_map/view_models/geo_map_view_model.dart:193:    final generation = ++_selectionGeneration;
lib/ui/geo_map/view_models/geo_map_view_model.dart:195:    if (_disposed || generation != _selectionGeneration) return result;
lib/ui/explore/view_models/suggestion_view_model.dart:13:    load = Command0(_load);
lib/ui/explore/view_models/suggestion_view_model.dart:15:    unawaited(load.execute());
lib/ui/explore/view_models/suggestion_view_model.dart:20:  /// Command for loading the suggested places.
lib/ui/explore/view_models/suggestion_view_model.dart:21:  late Command0<void> load;
lib/ui/favourite/widgets/favourite_screen.dart:32:                if (viewModel.load.completed) {
lib/ui/favourite/widgets/favourite_screen.dart:68:                if (viewModel.load.error) {
lib/ui/favourite/widgets/favourite_screen.dart:76:                        onPressed: () => viewModel.load.execute(),
lib/ui/explore/view_models/explore_view_model.dart:15:    loadLatest = Command0(_loadLatest);
lib/ui/explore/view_models/explore_view_model.dart:16:    unawaited(loadLatest.execute());
lib/ui/explore/view_models/explore_view_model.dart:21:  late Command0<void> loadLatest;
lib/ui/content_submission/widgets/content_submission_screen.dart:55:    widget.viewModel.addListener(_handleSessionIdentityChanged);
lib/ui/content_submission/widgets/content_submission_screen.dart:58:      unawaited(widget.viewModel.retrieveLostAssets.execute());
lib/ui/content_submission/widgets/content_submission_screen.dart:64:    widget.viewModel.removeListener(_handleSessionIdentityChanged);
lib/ui/content_submission/widgets/content_submission_screen.dart:162:      unawaited(viewModel.submit.execute());
lib/ui/content_submission/widgets/content_submission_screen.dart:212:                  widget.viewModel.clear.running) {
lib/ui/post/widgets/post_screen.dart:75:            if (widget.viewModel.loadEvent.completed ||
lib/ui/post/widgets/post_screen.dart:76:                widget.viewModel.loadPlace.completed) {
lib/ui/core/themes/app_colors_theme_extension.dart:39:        actionForeground: colorScheme.error,
lib/ui/core/themes/app_colors_theme_extension.dart:67:        actionForeground: colorScheme.error,
lib/ui/admin/submissions/widgets/admin_dashboard_screen.dart:53:    await viewModel.load.execute();
lib/ui/admin/submissions/widgets/admin_dashboard_screen.dart:55:    if (viewModel.showIgnored) await viewModel.loadIgnored.execute();
lib/ui/admin/submissions/widgets/admin_dashboard_screen.dart:64:    unawaited(widget.authViewModel.logout.execute());
lib/ui/admin/submissions/widgets/admin_dashboard_screen.dart:76:            ? viewModel.loadIgnored.execute()
lib/ui/admin/submissions/widgets/admin_dashboard_screen.dart:77:            : viewModel.load.execute(),
lib/ui/admin/submissions/widgets/admin_dashboard_screen.dart:98:                              ? viewModel.loadIgnored.execute()
lib/ui/admin/submissions/widgets/admin_dashboard_screen.dart:99:                              : viewModel.load.execute(),
lib/ui/admin/submissions/widgets/admin_dashboard_screen.dart:141:                                unawaited(viewModel.loadIgnored.execute());
lib/ui/admin/submissions/widgets/admin_dashboard_screen.dart:194:                    if (viewModel.loadIgnored.running &&
lib/ui/admin/submissions/widgets/admin_dashboard_screen.dart:206:                        if (viewModel.loadIgnored.error)
lib/ui/admin/submissions/widgets/admin_dashboard_screen.dart:216:                        if (viewModel.unIgnore.error)
lib/ui/admin/submissions/widgets/admin_dashboard_screen.dart:223:                        if (viewModel.unIgnore.completed)
lib/ui/admin/submissions/widgets/admin_dashboard_screen.dart:234:                            !viewModel.loadIgnored.error)
lib/ui/admin/submissions/widgets/admin_dashboard_screen.dart:254:                                  viewModel.unIgnore.running ||
lib/ui/admin/submissions/widgets/admin_dashboard_screen.dart:255:                                      viewModel.loadIgnored.running ||
lib/ui/admin/submissions/widgets/admin_dashboard_screen.dart:256:                                      viewModel.load.running
lib/ui/admin/submissions/widgets/admin_dashboard_screen.dart:259:                                      viewModel.unIgnore.execute(source.id),
lib/ui/admin/submissions/widgets/admin_dashboard_screen.dart:275:                  if (viewModel.error && !viewModel.hasData) {
lib/ui/admin/submissions/widgets/admin_dashboard_screen.dart:278:                      child: EmptyView.error(
lib/ui/content_submission/view_models/content_submission_view_model.dart:99:    addAsset = Command0(_addAsset);
lib/ui/content_submission/view_models/content_submission_view_model.dart:100:    removeAssetAt = Command1(_removeAssetAt);
lib/ui/content_submission/view_models/content_submission_view_model.dart:101:    submit = Command0(_submit);
lib/ui/content_submission/view_models/content_submission_view_model.dart:102:    clear = Command0(_clear);
lib/ui/content_submission/view_models/content_submission_view_model.dart:103:    retrieveLostAssets = Command0(_retrieveLostAssets);
lib/ui/content_submission/view_models/content_submission_view_model.dart:109:  bool _disposed = false;
lib/ui/content_submission/view_models/content_submission_view_model.dart:113:    _disposed = true;
lib/ui/content_submission/view_models/content_submission_view_model.dart:146:  /// Whether executing the current immediate manual retry action is safe.
lib/ui/content_submission/view_models/content_submission_view_model.dart:148:  /// Retry is available only after confirmed remote success when local session
lib/ui/content_submission/view_models/content_submission_view_model.dart:151:  bool get canRetrySubmissionImmediately =>
lib/ui/content_submission/view_models/content_submission_view_model.dart:152:      !submit.running &&
lib/ui/content_submission/view_models/content_submission_view_model.dart:153:      submit.result is Error<void> &&
lib/ui/content_submission/view_models/content_submission_view_model.dart:189:  late Command0<AssetSelectionOutcome> addAsset;
lib/ui/content_submission/view_models/content_submission_view_model.dart:191:  late Command1<void, int> removeAssetAt;
lib/ui/content_submission/view_models/content_submission_view_model.dart:192:  late Command0<void> submit;
lib/ui/content_submission/view_models/content_submission_view_model.dart:195:  late Command0<void> clear;
lib/ui/content_submission/view_models/content_submission_view_model.dart:201:  late Command0<void> retrieveLostAssets;
lib/ui/content_submission/view_models/content_submission_view_model.dart:211:      if (_disposed) return;
lib/ui/content_submission/view_models/content_submission_view_model.dart:240:      if (_disposed) return;
lib/ui/content_submission/view_models/content_submission_view_model.dart:252:      if (!_disposed) {
lib/ui/content_submission/view_models/content_submission_view_model.dart:261:  /// a subsequent pre-picker retry cannot mutate uncertain state.
lib/ui/content_submission/view_models/content_submission_view_model.dart:268:    if (_disposed) return const Result.success(null);
lib/ui/content_submission/view_models/content_submission_view_model.dart:273:      return Result.error(error);
lib/ui/content_submission/view_models/content_submission_view_model.dart:283:      return Result.error(error);
lib/ui/content_submission/view_models/content_submission_view_model.dart:291:      if (_disposed) return const Result.success(null);
lib/ui/content_submission/view_models/content_submission_view_model.dart:296:        return Result.error(error);
lib/ui/content_submission/view_models/content_submission_view_model.dart:319:    if (_disposed) {
lib/ui/content_submission/view_models/content_submission_view_model.dart:342:    if (_disposed) {
lib/ui/content_submission/view_models/content_submission_view_model.dart:346:      return Result.error(error);
lib/ui/content_submission/view_models/content_submission_view_model.dart:356:    if (_disposed) {
lib/ui/content_submission/view_models/content_submission_view_model.dart:362:      return Result.error(error);
lib/ui/content_submission/view_models/content_submission_view_model.dart:374:    if (_disposed) return const Result.success(AssetSelectionOutcome());
lib/ui/content_submission/view_models/content_submission_view_model.dart:377:      if (_disposed) return const Result.success(AssetSelectionOutcome());
lib/ui/content_submission/view_models/content_submission_view_model.dart:379:        if (_disposed) return const Result.success(null);
lib/ui/content_submission/view_models/content_submission_view_model.dart:382:          return Result.error(
lib/ui/content_submission/view_models/content_submission_view_model.dart:396:            return Result.error(_stagedReconciliationError ?? error);
lib/ui/content_submission/view_models/content_submission_view_model.dart:401:          return Result.error(error);
lib/ui/content_submission/view_models/content_submission_view_model.dart:403:        if (_disposed) return const Result.success(null);
lib/ui/content_submission/view_models/content_submission_view_model.dart:407:        return Result.error(error);
lib/ui/content_submission/view_models/content_submission_view_model.dart:421:        if (_disposed ||
lib/ui/content_submission/view_models/content_submission_view_model.dart:435:              return Result.error(error);
lib/ui/content_submission/view_models/content_submission_view_model.dart:454:        if (!_disposed) {
lib/ui/content_submission/view_models/content_submission_view_model.dart:457:        return Result.error(error);
lib/ui/content_submission/view_models/content_submission_view_model.dart:469:      if (!_disposed) {
lib/ui/content_submission/view_models/content_submission_view_model.dart:481:      return Result.error(exception);
lib/ui/content_submission/view_models/content_submission_view_model.dart:486:    if (_disposed) return const Result.success(null);
lib/ui/content_submission/view_models/content_submission_view_model.dart:488:      // Preserve the meaning of the user's request at Command action entry.
lib/ui/content_submission/view_models/content_submission_view_model.dart:492:        return Result.error(Exception(RangeError.index(index, _assets)));
lib/ui/content_submission/view_models/content_submission_view_model.dart:499:      if (_disposed) return const Result.success(null);
lib/ui/content_submission/view_models/content_submission_view_model.dart:501:        if (_disposed ||
lib/ui/content_submission/view_models/content_submission_view_model.dart:510:        if (removed case Error<void>(:final error)) return Result.error(error);
lib/ui/content_submission/view_models/content_submission_view_model.dart:511:        if (_disposed) return const Result.success(null);
lib/ui/content_submission/view_models/content_submission_view_model.dart:515:      if (result case Error<void>(:final error)) return Result.error(error);
lib/ui/content_submission/view_models/content_submission_view_model.dart:517:      if (!_disposed) {
lib/ui/content_submission/view_models/content_submission_view_model.dart:529:      return Result.error(exception);
lib/ui/content_submission/view_models/content_submission_view_model.dart:534:    if (!_disposed) {
lib/ui/content_submission/view_models/content_submission_view_model.dart:540:    if (_disposed) return const Result.success(null);
lib/ui/content_submission/view_models/content_submission_view_model.dart:542:    if (_disposed) return const Result.success(null);
lib/ui/content_submission/view_models/content_submission_view_model.dart:551:    if (_disposed) return const Result.success(null);
lib/ui/content_submission/view_models/content_submission_view_model.dart:553:    if (_disposed) return const Result.success(null);
lib/ui/content_submission/view_models/content_submission_view_model.dart:556:        return Result.error(
lib/ui/content_submission/view_models/content_submission_view_model.dart:567:      if (!_disposed) notifyListeners();
lib/ui/content_submission/view_models/content_submission_view_model.dart:580:      return Result.error(
lib/ui/content_submission/view_models/content_submission_view_model.dart:593:    if (_disposed) return result;
lib/ui/content_submission/view_models/content_submission_view_model.dart:598:      if (!_disposed) {
lib/ui/content_submission/view_models/content_submission_view_model.dart:613:      return Result.error(exception);
lib/ui/content_submission/view_models/content_submission_view_model.dart:615:      return Result.error(Exception(error));
lib/ui/content_submission/view_models/content_submission_view_model.dart:709:      if (!_disposed) {
lib/ui/content_submission/view_models/content_submission_view_model.dart:737:  /// leak on a subsequent retry: `CloudinaryPublicIdGenerator` derives each
lib/ui/content_submission/view_models/content_submission_view_model.dart:745:    if (_disposed) return const Result.success(null);
lib/ui/content_submission/view_models/content_submission_view_model.dart:747:    if (_disposed) return const Result.success(null);
lib/ui/content_submission/view_models/content_submission_view_model.dart:751:      return Result.error(error);
lib/ui/content_submission/view_models/content_submission_view_model.dart:766:            .result;
lib/ui/content_submission/view_models/content_submission_view_model.dart:772:            return Result.error(result.error);
lib/ui/content_submission/view_models/content_submission_view_model.dart:810:        return Result.error(
lib/ui/content_submission/view_models/content_submission_view_model.dart:815:        return Result.error(Exception('Cannot submit: too many assets.'));
lib/ui/content_submission/view_models/content_submission_view_model.dart:825:          if (!_disposed) notifyListeners();
lib/ui/content_submission/view_models/content_submission_view_model.dart:827:        return Result.error(Exception('Cannot submit: invalid event time.'));
lib/ui/content_submission/view_models/content_submission_view_model.dart:837:        return Result.error(
lib/ui/content_submission/view_models/content_submission_view_model.dart:848:      if (checkpoint case Error<void>(:final error)) return Result.error(error);
lib/ui/content_submission/view_models/content_submission_view_model.dart:850:        return Result.error(Exception('Another submission session is active.'));
lib/ui/content_submission/view_models/content_submission_view_model.dart:877:        return Result.error(
lib/ui/content_submission/view_models/content_submission_view_model.dart:882:      if (retired case Error<void>(:final error)) return Result.error(error);
lib/ui/content_submission/view_models/content_submission_view_model.dart:888:    if (!_disposed) notifyListeners();
lib/ui/content_submission/view_models/content_submission_view_model.dart:893:    if (_disposed) return const Result.success(null);
lib/ui/content_submission/view_models/content_submission_view_model.dart:895:    if (_disposed) return const Result.success(null);
lib/ui/content_submission/view_models/content_submission_view_model.dart:898:        return Result.error(
lib/ui/content_submission/view_models/content_submission_view_model.dart:906:    if (!_disposed) {
lib/ui/content_submission/view_models/content_submission_view_model.dart:925:    if (_disposed) return const Result.success(null);
lib/ui/content_submission/view_models/content_submission_view_model.dart:948:    if (_disposed) return const Result.success(null);
lib/ui/content_submission/view_models/content_submission_view_model.dart:960:    if (_disposed) return const Result.success(null);
lib/ui/content_submission/view_models/content_submission_view_model.dart:1002:              return Result.error(error);
lib/ui/content_submission/view_models/content_submission_view_model.dart:1023:      if (!_disposed) {
lib/ui/settings/widgets/settings_screen.dart:98:                            await themeProvider.setThemeBrightness.execute(
lib/ui/settings/widgets/settings_screen.dart:127:                    await viewModel.setCrashReporting.execute(value);
lib/ui/favourite/view_models/favourite_view_model.dart:20:    load = Command0(_load);
lib/ui/favourite/view_models/favourite_view_model.dart:21:    load.addListener(_forwardLoadChanges);
lib/ui/favourite/view_models/favourite_view_model.dart:23:    unawaited(load.execute());
lib/ui/favourite/view_models/favourite_view_model.dart:28:  /// Command for loading all favourited places and events from the repository.
lib/ui/favourite/view_models/favourite_view_model.dart:29:  late final Command0<void> load;
lib/ui/favourite/view_models/favourite_view_model.dart:36:  var _disposed = false;
lib/ui/favourite/view_models/favourite_view_model.dart:55:  bool get isUpdating => load.running || _mutationRunning;
lib/ui/favourite/view_models/favourite_view_model.dart:63:    if (isUpdating) return Result.error(_updateUnavailableException());
lib/ui/favourite/view_models/favourite_view_model.dart:65:      return Result.error(_unsupportedContentException(content));
lib/ui/favourite/view_models/favourite_view_model.dart:73:        _ => Result.error(_unsupportedContentException(content)),
lib/ui/favourite/view_models/favourite_view_model.dart:190:          Result<void>.error(_unsupportedContentException(content)),
lib/ui/favourite/view_models/favourite_view_model.dart:195:      return Result.error(exception);
lib/ui/favourite/view_models/favourite_view_model.dart:200:    if (_mutationRunning) return Result.error(_updateUnavailableException());
lib/ui/favourite/view_models/favourite_view_model.dart:253:    if (!_disposed) notifyListeners();
lib/ui/favourite/view_models/favourite_view_model.dart:258:    _disposed = true;
lib/ui/favourite/view_models/favourite_view_model.dart:259:    load.removeListener(_forwardLoadChanges);
lib/ui/favourite/view_models/favourite_view_model.dart:260:    if (!load.running) load.dispose();
lib/ui/content_submission/widgets/content_submission_asset_list.dart:94:                    if (widget.viewModel.addAsset.running ||
lib/ui/content_submission/widgets/content_submission_asset_list.dart:95:                        widget.viewModel.retrieveLostAssets.running) {
lib/ui/content_submission/widgets/content_submission_asset_list.dart:117:                        await viewModel.addAsset.execute();
lib/ui/content_submission/widgets/content_submission_asset_list.dart:120:                        final result = viewModel.addAsset.result;
lib/ui/content_submission/widgets/content_submission_asset_list.dart:132:                        widget.viewModel.removeAssetAt.execute(index),
lib/ui/content_submission/widgets/content_submission_description_form_field.dart:75:    _focusNode.addListener(_handleFocusChange);
lib/ui/content_submission/widgets/content_submission_description_form_field.dart:130:      ..removeListener(_handleFocusChange)
lib/ui/settings/view_models/settings_view_model.dart:13:    setCrashReporting = Command1(_setCrashReporting);
lib/ui/settings/view_models/settings_view_model.dart:21:  late Command1<void, bool> setCrashReporting;
lib/ui/content_submission/widgets/checkbox_form_field.dart:56:                           color: Theme.of(context).colorScheme.error,
lib/ui/weather/widgets/weather_forecast_button.dart:35:        widget.viewModel.loadCurrentForecast.execute(widget.coordinates),
lib/ui/weather/widgets/weather_forecast_button.dart:52:        if (viewModel.loadCurrentForecast.completed) {
lib/ui/weather/widgets/weather_forecast_button.dart:58:                viewModel.loadHourlyForecast.execute(widget.coordinates),
lib/ui/weather/widgets/weather_forecast_button.dart:61:                viewModel.loadDailyForecast.execute(widget.coordinates),
lib/ui/content_submission/widgets/content_submission_progress_screen.dart:16:/// of the submission [Command] (running, idle, error, or completed). While an
lib/ui/content_submission/widgets/content_submission_progress_screen.dart:50:        final canRetryImmediately = _viewModel.canRetrySubmissionImmediately;
lib/ui/content_submission/widgets/content_submission_progress_screen.dart:52:        final canPop = !submit.running && !finalizationPending;
lib/ui/content_submission/widgets/content_submission_progress_screen.dart:84:                    action: submit.running
lib/ui/content_submission/widgets/content_submission_progress_screen.dart:86:                        : submit.idle
lib/ui/content_submission/widgets/content_submission_progress_screen.dart:92:                        : canRetryImmediately
lib/ui/content_submission/widgets/content_submission_progress_screen.dart:95:                            onPressed: () => unawaited(submit.execute()),
lib/ui/content_submission/widgets/content_submission_progress_screen.dart:107:                              if (submit.completed)
lib/ui/content_submission/widgets/content_submission_progress_screen.dart:131:  Color _buildColor(ColorScheme colorScheme, Command<void> command) =>
lib/ui/content_submission/widgets/content_submission_progress_screen.dart:132:      command.error
lib/ui/content_submission/widgets/content_submission_progress_screen.dart:133:      ? colorScheme.error
lib/ui/content_submission/widgets/content_submission_progress_screen.dart:134:      : command.completed
lib/ui/content_submission/widgets/content_submission_progress_screen.dart:139:    Command<void> command,
lib/ui/content_submission/widgets/content_submission_progress_screen.dart:141:  ) => command.running
lib/ui/content_submission/widgets/content_submission_progress_screen.dart:143:      : command.idle
lib/ui/content_submission/widgets/content_submission_progress_screen.dart:146:      : command.error && finalizationPending
lib/ui/content_submission/widgets/content_submission_progress_screen.dart:149:      : command.error
lib/ui/content_submission/widgets/content_submission_progress_screen.dart:154:  Widget _buildIcon(Command<void> command) => command.running
lib/ui/content_submission/widgets/content_submission_progress_screen.dart:156:      : command.idle
lib/ui/content_submission/widgets/content_submission_progress_screen.dart:158:      : command.error
lib/ui/settings/view_models/theme_view_model.dart:11:    setThemeBrightness = Command1(_setThemeBrightness);
lib/ui/settings/view_models/theme_view_model.dart:12:    setThemeType = Command1(_setThemeType);
lib/ui/settings/view_models/theme_view_model.dart:25:  late Command1<void, ThemeBrightness> setThemeBrightness;
lib/ui/settings/view_models/theme_view_model.dart:27:  late Command1<void, ThemeType> setThemeType;
lib/ui/admin/submissions/widgets/admin_submission_editor_screen.dart:53:    widget.viewModel.addListener(_syncEventTarget);
lib/ui/admin/submissions/widgets/admin_submission_editor_screen.dart:54:    widget.viewModel.save.addListener(_handleSaveCompleted);
lib/ui/admin/submissions/widgets/admin_submission_editor_screen.dart:55:    widget.viewModel.reject.addListener(_handleRejectCompleted);
lib/ui/admin/submissions/widgets/admin_submission_editor_screen.dart:56:    widget.viewModel.promote.addListener(_handlePromoteCompleted);
lib/ui/admin/submissions/widgets/admin_submission_editor_screen.dart:57:    widget.viewModel.link.addListener(_handleLinkCompleted);
lib/ui/admin/submissions/widgets/admin_submission_editor_screen.dart:58:    widget.viewModel.apply.addListener(_handleApplyCompleted);
lib/ui/admin/submissions/widgets/admin_submission_editor_screen.dart:59:    widget.viewModel.addAsset.addListener(_handleAddAssetCompleted);
lib/ui/admin/submissions/widgets/admin_submission_editor_screen.dart:60:    widget.viewModel.deleteAsset.addListener(_handleDeleteAssetCompleted);
lib/ui/admin/submissions/widgets/admin_submission_editor_screen.dart:65:    widget.viewModel.removeListener(_syncEventTarget);
lib/ui/admin/submissions/widgets/admin_submission_editor_screen.dart:67:    widget.viewModel.save.removeListener(_handleSaveCompleted);
lib/ui/admin/submissions/widgets/admin_submission_editor_screen.dart:68:    widget.viewModel.reject.removeListener(_handleRejectCompleted);
lib/ui/admin/submissions/widgets/admin_submission_editor_screen.dart:69:    widget.viewModel.promote.removeListener(_handlePromoteCompleted);
lib/ui/admin/submissions/widgets/admin_submission_editor_screen.dart:70:    widget.viewModel.link.removeListener(_handleLinkCompleted);
lib/ui/admin/submissions/widgets/admin_submission_editor_screen.dart:71:    widget.viewModel.apply.removeListener(_handleApplyCompleted);
lib/ui/admin/submissions/widgets/admin_submission_editor_screen.dart:72:    widget.viewModel.addAsset.removeListener(_handleAddAssetCompleted);
lib/ui/admin/submissions/widgets/admin_submission_editor_screen.dart:73:    widget.viewModel.deleteAsset.removeListener(_handleDeleteAssetCompleted);
lib/ui/admin/submissions/widgets/admin_submission_editor_screen.dart:99:  void _handleResolutionCompleted(Command<AdminEventResolution> command) {
lib/ui/admin/submissions/widgets/admin_submission_editor_screen.dart:100:    if (!mounted || command.running || command.idle) return;
lib/ui/admin/submissions/widgets/admin_submission_editor_screen.dart:101:    if (command.completed) {
lib/ui/admin/submissions/widgets/admin_submission_editor_screen.dart:103:    } else if (command.error) {
lib/ui/admin/submissions/widgets/admin_submission_editor_screen.dart:104:      _showModerationError(command.result);
lib/ui/admin/submissions/widgets/admin_submission_editor_screen.dart:121:        type: SnackBarType.error,
lib/ui/admin/submissions/widgets/admin_submission_editor_screen.dart:130:    if (save.completed) {
lib/ui/admin/submissions/widgets/admin_submission_editor_screen.dart:136:    } else if (save.error) {
lib/ui/admin/submissions/widgets/admin_submission_editor_screen.dart:137:      final result = save.result;
lib/ui/admin/submissions/widgets/admin_submission_editor_screen.dart:146:          type: SnackBarType.error,
lib/ui/admin/submissions/widgets/admin_submission_editor_screen.dart:149:        _showModerationError(save.result);
lib/ui/admin/submissions/widgets/admin_submission_editor_screen.dart:158:    if (reject.completed) {
lib/ui/admin/submissions/widgets/admin_submission_editor_screen.dart:161:    } else if (reject.error) {
lib/ui/admin/submissions/widgets/admin_submission_editor_screen.dart:162:      final result = reject.result;
lib/ui/admin/submissions/widgets/admin_submission_editor_screen.dart:170:          type: SnackBarType.error,
lib/ui/admin/submissions/widgets/admin_submission_editor_screen.dart:173:        _showModerationError(reject.result);
lib/ui/admin/submissions/widgets/admin_submission_editor_screen.dart:182:    if (promote.completed) {
lib/ui/admin/submissions/widgets/admin_submission_editor_screen.dart:185:    } else if (promote.error) {
lib/ui/admin/submissions/widgets/admin_submission_editor_screen.dart:186:      final result = promote.result;
lib/ui/admin/submissions/widgets/admin_submission_editor_screen.dart:199:          type: SnackBarType.error,
lib/ui/admin/submissions/widgets/admin_submission_editor_screen.dart:258:    if (widget.viewModel.addAsset.error) {
lib/ui/admin/submissions/widgets/admin_submission_editor_screen.dart:265:    if (widget.viewModel.deleteAsset.error) {
lib/ui/admin/submissions/widgets/admin_submission_editor_screen.dart:327:      unawaited(viewModel.promote.execute(target));
lib/ui/admin/submissions/widgets/admin_submission_editor_screen.dart:400:      unawaited(viewModel.reject.execute());
lib/ui/admin/submissions/widgets/admin_submission_editor_screen.dart:435:    unawaited(viewModel.deleteAsset.execute(assetId));
lib/ui/admin/submissions/widgets/admin_submission_editor_screen.dart:444:      unawaited(widget.viewModel.save.execute());
lib/ui/admin/submissions/widgets/admin_submission_editor_screen.dart:479:              viewModel.load.error &&
lib/ui/admin/submissions/widgets/admin_submission_editor_screen.dart:481:            return EmptyView.error(
lib/ui/admin/submissions/widgets/admin_submission_editor_screen.dart:632:                                            viewModel.addAsset.execute(),
lib/ui/admin/submissions/widgets/admin_submission_editor_screen.dart:742:                                onPressed: viewModel.findCandidates.running
lib/ui/admin/submissions/widgets/admin_submission_editor_screen.dart:745:                                        viewModel.findCandidates.execute(
lib/ui/admin/submissions/widgets/admin_submission_editor_screen.dart:751:                              if (viewModel.findCandidates.error)
lib/ui/admin/submissions/widgets/admin_submission_editor_screen.dart:805:                                        viewModel.link.execute(
lib/ui/admin/submissions/widgets/admin_submission_editor_screen.dart:820:                                if (viewModel.preview.error ||
lib/ui/admin/submissions/widgets/admin_submission_editor_screen.dart:821:                                    viewModel.keepCurrent.error)
lib/ui/admin/submissions/widgets/admin_submission_editor_screen.dart:822:                                  Text(switch (viewModel.keepCurrent.error
lib/ui/admin/submissions/widgets/admin_submission_editor_screen.dart:823:                                      ? viewModel.keepCurrent.result
lib/ui/admin/submissions/widgets/admin_submission_editor_screen.dart:824:                                      : viewModel.preview.result) {
lib/ui/admin/submissions/widgets/admin_submission_editor_screen.dart:868:                                                          .execute(group),
lib/ui/admin/auth/widgets/admin_login_screen.dart:35:    widget.viewModel.addListener(_replacePushedLoginWithDashboard);
lib/ui/admin/auth/widgets/admin_login_screen.dart:40:    widget.viewModel.removeListener(_replacePushedLoginWithDashboard);
lib/ui/admin/auth/widgets/admin_login_screen.dart:67:        widget.viewModel.login.execute((
lib/ui/admin/auth/widgets/admin_login_screen.dart:122:                            onPressed: login.running ? null : _login,
lib/ui/admin/auth/widgets/admin_login_screen.dart:123:                            child: login.running
lib/ui/admin/auth/widgets/admin_login_screen.dart:129:                          if (login.error)
lib/ui/core/ui/empty_view.dart:8:  const EmptyView.error({required this.text, this.action, super.key})
lib/ui/weather/widgets/components/weather_forecast_hourly_list.dart:96:                if (viewModel.loadHourlyForecast.completed) {
lib/ui/admin/auth/view_models/admin_auth_view_model.dart:23:    login = Command1<void, AdminLoginCredentials>(_login);
lib/ui/admin/auth/view_models/admin_auth_view_model.dart:24:    logout = Command0<void>(_logout);
lib/ui/admin/auth/view_models/admin_auth_view_model.dart:36:  bool _disposed = false;
lib/ui/admin/auth/view_models/admin_auth_view_model.dart:39:  late Command1<void, AdminLoginCredentials> login;
lib/ui/admin/auth/view_models/admin_auth_view_model.dart:42:  late Command0<void> logout;
lib/ui/admin/auth/view_models/admin_auth_view_model.dart:79:      return Result.error(error);
lib/ui/admin/auth/view_models/admin_auth_view_model.dart:104:      return Result.error(
lib/ui/admin/auth/view_models/admin_auth_view_model.dart:135:    return Result.error(
lib/ui/admin/auth/view_models/admin_auth_view_model.dart:154:    if (!_disposed) {
lib/ui/admin/auth/view_models/admin_auth_view_model.dart:161:    _disposed = true;
lib/ui/admin/submissions/widgets/admin_submission_location_editor.dart:249:              color: Theme.of(context).colorScheme.error,
lib/ui/weather/widgets/components/weather_forecast_days_list.dart:67:                if (viewModel.loadDailyForecast.completed) {
lib/ui/admin/submissions/view_models/admin_submissions_view_model.dart:17:    load = Command0<void>(() => _loadRequest = _load());
lib/ui/admin/submissions/view_models/admin_submissions_view_model.dart:18:    loadIgnored = Command0<void>(() => _ignoredLoadRequest = _loadIgnored());
lib/ui/admin/submissions/view_models/admin_submissions_view_model.dart:19:    unIgnore = Command1<AdminEventResolution, int>(_unIgnore);
lib/ui/admin/submissions/view_models/admin_submissions_view_model.dart:33:  late Command0<void> loadIgnored;
lib/ui/admin/submissions/view_models/admin_submissions_view_model.dart:36:  late Command1<AdminEventResolution, int> unIgnore;
lib/ui/admin/submissions/view_models/admin_submissions_view_model.dart:48:  var _disposed = false;
lib/ui/admin/submissions/view_models/admin_submissions_view_model.dart:51:  late Command0<void> load;
lib/ui/admin/submissions/view_models/admin_submissions_view_model.dart:69:  bool get loading => load.running;
lib/ui/admin/submissions/view_models/admin_submissions_view_model.dart:72:  bool get error => load.error;
lib/ui/admin/submissions/view_models/admin_submissions_view_model.dart:85:    if (unIgnore.running && !_refreshingAfterUnIgnore) {
lib/ui/admin/submissions/view_models/admin_submissions_view_model.dart:86:      return Result.error(Exception('Attendi la riattivazione della fonte.'));
lib/ui/admin/submissions/view_models/admin_submissions_view_model.dart:91:      if (_disposed) return;
lib/ui/admin/submissions/view_models/admin_submissions_view_model.dart:100:    if (unIgnore.running && !_refreshingAfterUnIgnore) {
lib/ui/admin/submissions/view_models/admin_submissions_view_model.dart:101:      return Result.error(Exception('Attendi la riattivazione della fonte.'));
lib/ui/admin/submissions/view_models/admin_submissions_view_model.dart:105:      if (_disposed) return;
lib/ui/admin/submissions/view_models/admin_submissions_view_model.dart:114:    if (loadIgnored.running || load.running) {
lib/ui/admin/submissions/view_models/admin_submissions_view_model.dart:115:      return Result.error(Exception('Attendi il caricamento delle fonti.'));
lib/ui/admin/submissions/view_models/admin_submissions_view_model.dart:121:      if (_disposed) return resolution;
lib/ui/admin/submissions/view_models/admin_submissions_view_model.dart:126:      if (_disposed) return resolution;
lib/ui/admin/submissions/view_models/admin_submissions_view_model.dart:129:        await loadIgnored.execute();
lib/ui/admin/submissions/view_models/admin_submissions_view_model.dart:130:        if (_disposed) return resolution;
lib/ui/admin/submissions/view_models/admin_submissions_view_model.dart:131:        await load.execute();
lib/ui/admin/submissions/view_models/admin_submissions_view_model.dart:141:    if (!_disposed) {
lib/ui/admin/submissions/view_models/admin_submissions_view_model.dart:148:    _disposed = true;
lib/ui/core/ui/route_error_screen.dart:23:  const RouteErrorScreen({required this.uri, required this.error, super.key});
lib/ui/core/ui/route_error_screen.dart:52:        oldWidget.error?.runtimeType != widget.error?.runtimeType ||
lib/ui/core/ui/route_error_screen.dart:53:        oldWidget.error?.toString() != widget.error?.toString()) {
lib/ui/core/ui/route_error_screen.dart:63:        reason: widget.error?.toString(),
lib/ui/core/ui/route_error_screen.dart:65:      error: widget.error,
lib/ui/core/ui/route_error_screen.dart:75:    body: EmptyView.error(
lib/ui/post/view_models/post_view_model.dart:13:    loadEvent = Command1(_loadEvent);
lib/ui/post/view_models/post_view_model.dart:14:    loadNearContent = Command1(_loadNearContent);
lib/ui/post/view_models/post_view_model.dart:15:    loadPlace = Command1(_loadPlace);
lib/ui/post/view_models/post_view_model.dart:19:  bool _disposed = false;
lib/ui/post/view_models/post_view_model.dart:21:  late Command1<void, int> loadEvent;
lib/ui/post/view_models/post_view_model.dart:22:  late Command1<void, LatLng> loadNearContent;
lib/ui/post/view_models/post_view_model.dart:23:  late Command1<void, int> loadPlace;
lib/ui/post/view_models/post_view_model.dart:33:    if (_disposed) return const Result.success(null);
lib/ui/post/view_models/post_view_model.dart:37:      if (_disposed) return;
lib/ui/post/view_models/post_view_model.dart:44:    if (_disposed) return const Result.success(null);
lib/ui/post/view_models/post_view_model.dart:52:    if (_disposed) return eventsResult.map((_) {});
lib/ui/post/view_models/post_view_model.dart:61:    if (!_disposed) {
lib/ui/post/view_models/post_view_model.dart:73:    if (_disposed) return const Result.success(null);
lib/ui/post/view_models/post_view_model.dart:77:      if (_disposed) return;
lib/ui/post/view_models/post_view_model.dart:85:    _disposed = true;
lib/ui/gallery/widgets/gallery_preview_modal_overlay.dart:57:        type: SnackBarType.error,
lib/ui/category/widgets/category_screen.dart:47:                              onPressed: () => widget.viewModel.setSort.execute(
lib/ui/category/widgets/category_screen.dart:58:                              onPressed: () => widget.viewModel.setSort.execute(
lib/ui/category/widgets/category_screen.dart:98:                        .execute(categories),
lib/ui/category/widgets/category_screen.dart:100:                        widget.viewModel.setSelectedTypes.execute(types),
lib/ui/category/widgets/category_screen.dart:116:                  if (widget.viewModel.load.completed ||
lib/ui/category/widgets/category_screen.dart:117:                      widget.viewModel.setSort.completed) {
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:43:    load = Command0<void>(_loadDetail);
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:44:    save = Command0<void>(_save);
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:45:    reject = Command0<void>(_reject);
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:46:    promote = Command1<AdminSubmissionPromotion, AdminPromotionTarget>(
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:49:    link = Command1<AdminEventResolution, int>(_link);
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:50:    preview = Command0<void>(_preview);
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:51:    findCandidates = Command1<void, String>(_findCandidates);
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:52:    apply = Command0<AdminEventResolution>(_apply);
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:53:    keepCurrent = Command1<void, AdminEventMergeGroup>(_keepCurrent);
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:54:    addAsset = Command0<void>(_addAsset);
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:55:    deleteAsset = Command1<void, int>(_deleteAsset);
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:85:  var _disposed = false;
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:88:  late Command0<void> load;
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:91:  late Command0<void> save;
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:94:  late Command0<void> reject;
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:97:  late Command1<AdminSubmissionPromotion, AdminPromotionTarget> promote;
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:100:  late Command0<void> addAsset;
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:103:  late Command1<void, int> deleteAsset;
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:108:  late Command1<void, String> findCandidates;
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:113:  late Command1<void, AdminEventMergeGroup> keepCurrent;
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:142:  int _previewGeneration = 0;
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:149:  late Command1<AdminEventResolution, int> link;
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:152:  late Command0<void> preview;
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:155:  late Command0<AdminEventResolution> apply;
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:165:    _previewGeneration++;
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:267:  bool get loading => load.running;
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:273:  bool get assetMutationRunning => addAsset.running || deleteAsset.running;
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:277:      save.running ||
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:278:      promote.running ||
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:279:      reject.running ||
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:280:      link.running ||
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:281:      apply.running ||
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:282:      keepCurrent.running ||
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:410:      if (_disposed) return;
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:447:      _previewGeneration++;
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:461:    if (promote.running ||
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:462:        reject.running ||
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:463:        link.running ||
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:464:        apply.running ||
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:465:        (keepCurrent.running && !fromKeepCurrent) ||
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:467:      return Result.error(
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:475:      return Result.error(
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:483:      return Result.error(Exception('Compila i campi obbligatori.'));
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:487:      return Result.error(Exception('Inserisci un intervallo di date valido.'));
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:492:      return Result.error(Exception('Inserisci coordinate valide.'));
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:514:      _previewGeneration++;
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:582:        (caller != 'promote' && promote.running) ||
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:583:        (caller != 'reject' && reject.running) ||
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:584:        (caller != 'link' && link.running) ||
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:585:        (caller != 'apply' && apply.running);
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:586:    if (save.running ||
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:588:        keepCurrent.running ||
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:603:    if (guard != null) return Result.error(guard);
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:614:      if (_disposed) return;
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:624:    if (guard != null) return Result.error(guard);
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:627:      return Result.error(
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:636:      return Result.error(
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:650:      if (_disposed) return promotion;
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:663:    if (guard != null) return Result.error(guard);
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:665:      return Result.error(
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:677:      if (_disposed) return resolution;
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:688:      return Result.error(
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:697:      if (_disposed) return;
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:710:      return Result.error(
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:716:    final generation = _previewGeneration;
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:719:      if (_disposed ||
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:722:          _previewGeneration != generation) {
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:749:        save.running ||
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:750:        promote.running ||
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:751:        reject.running ||
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:752:        link.running ||
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:753:        apply.running ||
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:754:        preview.running ||
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:757:      return Result.error(Exception('Attendi e carica una nuova anteprima.'));
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:790:    if (_disposed) return const Result.success(null);
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:796:    if (guard != null) return Result.error(guard);
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:799:      return Result.error(
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:811:      if (_disposed) return resolution;
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:821:    if (_disposed || _externalEvent == null) return;
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:831:    _previewGeneration++;
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:834:    if (_disposed) return;
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:841:      if (_disposed) return;
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:850:      return Result.error(
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:855:      return Result.error(
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:860:      return Result.error(
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:865:      return Result.error(Exception('Hai raggiunto il limite di foto.'));
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:867:    if (save.running ||
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:868:        promote.running ||
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:869:        reject.running ||
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:870:        link.running ||
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:871:        apply.running ||
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:872:        keepCurrent.running ||
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:873:        deleteAsset.running) {
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:874:      return Result.error(
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:882:    if (_disposed || selectedImage == null) return const Result.success(null);
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:890:      final uploadResult = await task.result;
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:891:      if (_disposed) return const Result.success(null);
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:898:        if (_disposed) return const Result.success(null);
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:915:      return Result.error(
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:920:      return Result.error(
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:925:      return Result.error(
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:929:    if (save.running ||
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:930:        promote.running ||
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:931:        reject.running ||
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:932:        link.running ||
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:933:        apply.running ||
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:934:        keepCurrent.running ||
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:935:        addAsset.running) {
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:936:      return Result.error(
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:941:      return Result.error(Exception('La foto non appartiene al contributo.'));
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:945:    if (_disposed) return const Result.success(null);
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:954:    _previewGeneration++;
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:961:    if (!_disposed) {
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:968:    _disposed = true;
lib/ui/post/widgets/components/post_section_nearby_content.dart:23:  final Command1<void, LatLng> loadNearContentCommand;
lib/ui/weather/view_models/weather_view_model.dart:21:    loadCurrentForecast = Command1(_loadCurrentWeatherForecast);
lib/ui/weather/view_models/weather_view_model.dart:22:    loadHourlyForecast = Command1(_loadHourlyWeatherForecast);
lib/ui/weather/view_models/weather_view_model.dart:23:    loadDailyForecast = Command1(_loadDailyWeatherForecast);
lib/ui/weather/view_models/weather_view_model.dart:29:  bool _disposed = false;
lib/ui/weather/view_models/weather_view_model.dart:33:    _disposed = true;
lib/ui/weather/view_models/weather_view_model.dart:37:  late Command1<CurrentWeatherForecastData, LatLng> loadCurrentForecast;
lib/ui/weather/view_models/weather_view_model.dart:38:  late Command1<HourlyWeatherForecastData, LatLng> loadHourlyForecast;
lib/ui/weather/view_models/weather_view_model.dart:39:  late Command1<DailyWeatherForecastData, LatLng> loadDailyForecast;
lib/ui/weather/view_models/weather_view_model.dart:71:    if (_disposed) return result;
lib/ui/weather/view_models/weather_view_model.dart:99:    if (_disposed) return result;
lib/ui/weather/view_models/weather_view_model.dart:117:    if (_disposed) return result;
lib/ui/core/ui/custom_snack_bar.dart:34:  type: SnackBarType.error,
lib/ui/core/ui/custom_snack_bar.dart:127:    SnackBarType.error => appColors.errorSnackBar.background,
lib/ui/core/ui/custom_snack_bar.dart:133:    SnackBarType.error => appColors.errorSnackBar.foreground,
lib/ui/core/ui/custom_snack_bar.dart:139:    SnackBarType.error => appColors.errorSnackBar.actionForeground,
lib/ui/core/ui/custom_snack_bar.dart:145:    SnackBarType.error => Symbols.error,
lib/ui/category/view_models/category_view_model.dart:22:    load = Command0(_load);
lib/ui/category/view_models/category_view_model.dart:23:    setSelectedCategories = Command1(_setSelectedCategories);
lib/ui/category/view_models/category_view_model.dart:24:    setSort = Command1(_setSort);
lib/ui/category/view_models/category_view_model.dart:25:    setSelectedTypes = Command1(_setSelectedTypes);
lib/ui/category/view_models/category_view_model.dart:35:  late Command0<void> load;
lib/ui/category/view_models/category_view_model.dart:36:  late Command1<void, Set<ContentCategory>> setSelectedCategories;
lib/ui/category/view_models/category_view_model.dart:37:  late Command1<void, ContentSort> setSort;
lib/ui/category/view_models/category_view_model.dart:38:  late Command1<void, Set<ContentType>> setSelectedTypes;
lib/ui/category/view_models/category_view_model.dart:110:    await load.execute();
lib/ui/category/view_models/category_view_model.dart:124:    await load.execute();
lib/ui/core/ui/content/nearby_content_horizontal_list.dart:23:/// - A [Command1] for loading nearby content by coordinates
lib/ui/core/ui/content/nearby_content_horizontal_list.dart:41:  final Command1<void, LatLng> loadNearContentCommand;
lib/ui/core/ui/content/nearby_content_horizontal_list.dart:84:      unawaited(command.execute(coordinates));
lib/ui/core/ui/content/nearby_content_horizontal_list.dart:108:              if (widget.loadNearContentCommand.completed) {
lib/ui/core/ui/content/nearby_content_horizontal_list.dart:157:              if (widget.loadNearContentCommand.error) {
lib/ui/core/ui/content/nearby_content_horizontal_list.dart:158:                return const EmptyView.error(
```
