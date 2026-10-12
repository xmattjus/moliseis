import 'dart:async' show Completer;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:moliseis/data/services/api/weather/cached_weather_api_client.dart';
import 'package:moliseis/data/services/api/weather/model/combined_weather_forecast_response.dart';
import 'package:moliseis/data/services/api/weather/model/current_forecast/current_weather_forecast_data.dart';
import 'package:moliseis/data/services/api/weather/model/daily_forecast/daily_weather_forecast_data.dart';
import 'package:moliseis/data/services/api/weather/model/hourly_forecast/hourly_weather_forecast_data.dart';
import 'package:moliseis/data/services/api/weather/model/weather_forecast_data_cache_entry.dart';
import 'package:moliseis/domain/models/content_type.dart';
import 'package:moliseis/ui/weather/view_models/weather_view_model.dart';
import 'package:moliseis/ui/weather/wmo_weather_description_mapper.dart';
import 'package:moliseis/ui/weather/wmo_weather_icon_mapper.dart';
import 'package:moliseis/utils/lru_cache.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/result_command.dart';

import '../../../support/command_test_support.dart';
import '../../../support/fake_repositories.dart';
import '../../../support/mock_logger.dart';

void main() {
  late MockLogger mockLogger;

  const testTarget = (
    id: 1,
    type: ContentType.event,
    latitude: 41.56,
    longitude: 14.66,
  );

  final testCurrentData = CurrentWeatherForecastData(
    time: DateTime.utc(2026, 4, 7, 10),
    interval: 900,
    temperature2m: 18.5,
    isDay: 1,
    weatherCode: 0,
    precipitation: 0,
  );

  final testHourlyData = HourlyWeatherForecastData(
    time: List.generate(
      24,
      (i) => '2026-04-07T${i.toString().padLeft(2, '0')}:00',
    ),
    temperature2m: List.filled(24, 18.5),
    weatherCode: List.filled(24, 0),
    precipitationProbability: List.filled(24, 0),
    isDay: List.filled(24, 1),
  );

  const testDailyData = DailyWeatherForecastData(
    time: ['2026-04-07', '2026-04-08', '2026-04-09'],
    weatherCode: [0, 1, 2],
    temperature2mMax: [20.0, 21.0, 19.0],
    temperature2mMin: [12.0, 13.0, 11.0],
    precipitationProbabilityMax: [0, 10, 20],
  );

  late CombinedWeatherForecastResponse testCombinedResponse;

  setUp(() {
    mockLogger = MockLogger();

    testCombinedResponse = CombinedWeatherForecastResponse(
      latitude: 41.56,
      longitude: 14.66,
      generationTimeMs: 1,
      utcOffsetSeconds: 7200,
      timezone: 'Europe/Rome',
      timezoneAbbreviation: 'CEST',
      elevation: 700,
      current: testCurrentData,
      hourly: testHourlyData,
      daily: testDailyData,
    );
  });

  WeatherViewModel buildViewModel(FakeWeatherApiClient fakeClient) {
    final apiClient = CachedWeatherApiClient(
      weatherApiClient: fakeClient,
      currentWeatherCache:
          LruCache<
            String,
            WeatherForecastDataCacheEntry<CurrentWeatherForecastData>
          >(maxSize: 8),
      hourlyWeatherCache:
          LruCache<
            String,
            WeatherForecastDataCacheEntry<HourlyWeatherForecastData>
          >(maxSize: 8),
      dailyWeatherCache:
          LruCache<
            String,
            WeatherForecastDataCacheEntry<DailyWeatherForecastData>
          >(maxSize: 8),
      logger: mockLogger,
    );

    return WeatherViewModel(
      weatherApiClient: apiClient,
      weatherDescriptionMapper: const WmoWeatherDescriptionMapper(),
      weatherCodeIconMapper: const WmoWeatherIconMapper(),
    )..setTarget(testTarget);
  }

  group('WeatherViewModel', () {
    test(
      'in-flight forecasts do not update disposed ViewModel state',
      () async {
        final pending = Completer<Result<CombinedWeatherForecastResponse>>();
        final fakeClient = FakeWeatherApiClient()
          ..pendingCombinedForecast = pending;
        var notifications = 0;
        final viewModel = buildViewModel(fakeClient)
          ..addListener(() => notifications++)
          ..requestCurrent(testTarget)
          ..requestHourly(testTarget)
          ..requestDaily(testTarget);
        await settleForecasts();
        expect(fakeClient.getCombinedWeatherForecastCallCount, 3);

        viewModel.dispose();
        pending.complete(Result.success(testCombinedResponse));
        await settleForecasts();

        expect(viewModel.currentTemperatureCelsius, '--.-');
        expect(viewModel.getHourlyForecastData, isNull);
        expect(viewModel.getDailyForecastData, isNull);
        expect(viewModel.loadCurrentForecast.results.value.completed, isFalse);
        expect(viewModel.loadHourlyForecast.results.value.completed, isFalse);
        expect(viewModel.loadDailyForecast.results.value.completed, isFalse);
        expect(notifications, 0);
      },
    );

    test(
      'target replacement revokes all lanes and does not wait for A',
      () async {
        final a = Completer<Result<CombinedWeatherForecastResponse>>();
        final b = Completer<Result<CombinedWeatherForecastResponse>>();
        final fake = FakeWeatherApiClient()
          ..combinedForecastHandler = (lat, lon) =>
              lat == testTarget.latitude ? a.future : b.future;
        final vm = buildViewModel(fake)
          ..requestCurrent(testTarget)
          ..requestHourly(testTarget)
          ..requestDaily(testTarget);
        addTearDown(vm.dispose);
        await settleForecasts();
        expect(fake.getCombinedWeatherForecastCallCount, 3);
        const next = (
          id: 2,
          type: ContentType.place,
          latitude: 42.0,
          longitude: 15.0,
        );
        var notifications = 0;
        vm
          ..addListener(() => notifications++)
          ..setTarget(next);
        expect(vm.currentTemperatureCelsius, '--.-');
        expect(vm.getHourlyForecastData, isNull);
        expect(vm.getDailyForecastData, isNull);
        // Obsolete modal callbacks cannot restore A or admit lazy work.
        vm
          ..requestCurrent(next)
          ..requestHourly(testTarget)
          ..requestDaily(testTarget);
        await settleForecasts();
        expect(fake.getCombinedWeatherForecastCallCount, 4);
        expect(vm.loadHourlyForecast.results.value.idle, isTrue);
        expect(vm.loadDailyForecast.results.value.idle, isTrue);
        a.complete(Result.success(testCombinedResponse));
        await settleForecasts();
        expect(vm.currentTemperatureCelsius, '--.-');
        expect(vm.getHourlyForecastData, isNull);
        expect(vm.getDailyForecastData, isNull);
        b.complete(Result.success(testCombinedResponse));
        await settleForecasts();
        expect(vm.currentTemperatureCelsius, '18.5');
        expect(vm.loadCurrentForecast.results.value.paramData, next);
        expect(notifications, 0); // No teardown/build-time VM notification.
      },
    );

    test(
      'same target binding is idempotent and ABA resets all stored projections',
      () async {
        final fake = FakeWeatherApiClient(
          result: Result.success(testCombinedResponse),
        );
        final vm = buildViewModel(fake)..requestCurrent(testTarget);
        addTearDown(vm.dispose);
        await settleForecasts();
        vm
          ..requestHourly(testTarget)
          ..requestDaily(testTarget);
        await settleForecasts();
        final terminal = vm.loadCurrentForecast.results.value;
        vm
          ..setTarget(testTarget)
          ..requestCurrent(testTarget);
        await settleForecasts();
        expect(
          identical(vm.loadCurrentForecast.results.value, terminal),
          isTrue,
        );
        vm
          ..setTarget(null)
          ..setTarget(testTarget);
        expect(vm.currentTemperatureCelsius, '--.-');
        expect(vm.getHourlyForecastData, isNull);
        expect(vm.getDailyForecastData, isNull);
        await settleForecasts();
        vm.requestCurrent(testTarget);
        await settleForecasts();
        expect(
          identical(vm.loadCurrentForecast.results.value, terminal),
          isFalse,
        );
        expect(vm.currentTemperatureCelsius, '18.5');
        expect(vm.loadHourlyForecast.results.value.idle, isTrue);
        expect(vm.loadDailyForecast.results.value.idle, isTrue);
      },
    );

    test(
      'live unexpected runtime failure stays terminal and globally reported',
      () async {
        addTearDown(installCommandTestReporting(mockLogger));
        final failure = StateError('forecast runtime');
        final fake = FakeWeatherApiClient()
          ..combinedForecastHandler = (_, _) async => throw failure;
        final vm = buildViewModel(fake)..requestCurrent(testTarget);
        addTearDown(vm.dispose);
        await settleForecasts();
        expect(
          vm.loadCurrentForecast.results.value.unexpectedError,
          same(failure),
        );
        expect(vm.loadCurrentForecast.isRunningSync.value, isFalse);
        expect(vm.currentTemperatureCelsius, '--.-');
        expect(
          mockLogger.calls.where((call) => identical(call.error, failure)),
          hasLength(1),
        );
      },
    );

    test(
      'reentrant target writer does not invalidate newer lazy lanes',
      () async {
        final pending = Completer<Result<CombinedWeatherForecastResponse>>();
        final fake = FakeWeatherApiClient()..pendingCombinedForecast = pending;
        final vm = buildViewModel(fake)..requestCurrent(testTarget);
        addTearDown(vm.dispose);
        await settleForecasts();
        const next = (
          id: 2,
          type: ContentType.place,
          latitude: 42.0,
          longitude: 15.0,
        );
        vm.loadCurrentForecast.isRunningSync.addListener(() {
          if (!vm.loadCurrentForecast.isRunningSync.value &&
              vm.currentTarget == null) {
            vm
              ..setTarget(next)
              ..requestHourly(next)
              ..requestDaily(next);
          }
        });
        vm.setTarget(null);
        await settleForecasts();
        expect(vm.currentTarget, next);
        expect(vm.loadHourlyForecast.isRunningSync.value, isTrue);
        expect(vm.loadDailyForecast.isRunningSync.value, isTrue);
        pending.complete(Result.success(testCombinedResponse));
        await settleForecasts();
        expect(vm.loadHourlyForecast.results.value.paramData, next);
        expect(vm.loadDailyForecast.results.value.paramData, next);
        expect(vm.getHourlyForecastData, isNotNull);
        expect(vm.getDailyForecastData, isNotNull);
      },
    );

    for (final lane in ['current', 'hourly', 'daily']) {
      for (final completion in ['success', 'expected', 'runtime']) {
        test('$lane stale $completion is suppressed while B settles', () async {
          addTearDown(installCommandTestReporting(mockLogger));
          final a = Completer<Result<CombinedWeatherForecastResponse>>();
          final b = Completer<Result<CombinedWeatherForecastResponse>>();
          final fake = FakeWeatherApiClient()
            ..combinedForecastHandler = (lat, lon) =>
                lat == testTarget.latitude ? a.future : b.future;
          final vm = buildViewModel(fake);
          addTearDown(vm.dispose);
          void request(WeatherTarget target) {
            switch (lane) {
              case 'current':
                vm.requestCurrent(target);
              case 'hourly':
                vm.requestHourly(target);
              case 'daily':
                vm.requestDaily(target);
            }
          }

          request(testTarget);
          await settleForecasts();
          const next = (
            id: 2,
            type: ContentType.place,
            latitude: 42.0,
            longitude: 15.0,
          );
          vm.setTarget(next);
          request(next);
          await settleForecasts();
          expect(fake.getCombinedWeatherForecastCallCount, 2);
          final failure = StateError('obsolete $lane');
          switch (completion) {
            case 'success':
              a.complete(Result.success(testCombinedResponse));
            case 'expected':
              a.complete(Result.error(TestException('obsolete')));
            case 'runtime':
              a.completeError(failure, StackTrace.current);
          }
          await settleForecasts();
          expect(vm.currentTemperatureCelsius, '--.-');
          expect(vm.getHourlyForecastData, isNull);
          expect(vm.getDailyForecastData, isNull);
          expect(
            mockLogger.calls.where((call) => identical(call.error, failure)),
            hasLength(completion == 'runtime' ? 1 : 0),
          );
          b.complete(Result.success(testCombinedResponse));
          await settleForecasts();
          switch (lane) {
            case 'current':
              expect(vm.currentTemperatureCelsius, '18.5');
            case 'hourly':
              expect(vm.getHourlyForecastData, same(testHourlyData));
            case 'daily':
              expect(vm.getDailyForecastData, same(testDailyData));
          }
        });
      }
    }

    test(
      'different identity at equal coordinates clears all projections',
      () async {
        final vm =
            buildViewModel(
                FakeWeatherApiClient(
                  result: Result.success(testCombinedResponse),
                ),
              )
              ..requestCurrent(testTarget)
              ..requestHourly(testTarget)
              ..requestDaily(testTarget);
        addTearDown(vm.dispose);
        await settleForecasts();
        const next = (
          id: 1,
          type: ContentType.place,
          latitude: 41.56,
          longitude: 14.66,
        );
        var notifications = 0;
        vm
          ..addListener(() => notifications++)
          ..setTarget(next);
        expect(vm.currentTarget, next);
        expect(vm.currentTemperatureCelsius, '--.-');
        expect(vm.getHourlyForecastData, isNull);
        expect(vm.getDailyForecastData, isNull);
        expect(notifications, 0);
        await settleForecasts();
        expect(vm.loadCurrentForecast.results.value.idle, isTrue);
        expect(vm.loadHourlyForecast.results.value.idle, isTrue);
        expect(vm.loadDailyForecast.results.value.idle, isTrue);
        vm.dispose();
        await settleForecasts();
        expect(notifications, 0);
      },
    );

    group('loadCurrentForecast', () {
      test('sets current conditions state on success', () async {
        final viewModel = buildViewModel(
          FakeWeatherApiClient(result: Result.success(testCombinedResponse)),
        )..requestCurrent(testTarget);
        await settleForecasts();

        expect(viewModel.loadCurrentForecast.results.value.completed, isTrue);
        expect(
          viewModel.loadCurrentForecast.results.value.data,
          isA<Success<CurrentWeatherForecastData>>(),
        );
        expect(viewModel.currentTemperatureCelsius, '18.5');
        expect(viewModel.isDay, isTrue);
        // Clear sky day → sunny icon, not the default question mark.
        expect(
          viewModel.currentWeatherCodeIcon,
          isNot(equals(Symbols.question_mark)),
        );
        expect(viewModel.currentWeatherDescription, isNot('Meteo sconosciuto'));
      });

      test('leaves state at defaults and surfaces error on failure', () async {
        final viewModel = buildViewModel(
          FakeWeatherApiClient(
            result: Result.error(TestException('network error')),
          ),
        )..requestCurrent(testTarget);
        await settleForecasts();

        expect(viewModel.loadCurrentForecast.results.value.completed, isFalse);
        expect(viewModel.loadCurrentForecast.results.value.hasFailure, isTrue);
        expect(
          viewModel.loadCurrentForecast.results.value.data,
          isA<Error<CurrentWeatherForecastData>>(),
        );
        expect(viewModel.currentTemperatureCelsius, '--.-');
        expect(viewModel.isDay, isFalse);
        expect(viewModel.currentWeatherDescription, 'Meteo sconosciuto');
      });
    });

    group('loadHourlyForecast', () {
      test('populates getHourlyForecastData on success', () async {
        final viewModel = buildViewModel(
          FakeWeatherApiClient(result: Result.success(testCombinedResponse)),
        )..requestHourly(testTarget);
        await settleForecasts();

        expect(viewModel.loadHourlyForecast.results.value.completed, isTrue);
        expect(
          viewModel.loadHourlyForecast.results.value.data,
          isA<Success<HourlyWeatherForecastData>>(),
        );
        expect(viewModel.getHourlyForecastData, isNotNull);
        expect(viewModel.getHourlyForecastData!.time.length, 24);
      });

      test(
        'leaves getHourlyForecastData null and surfaces error on failure',
        () async {
          final viewModel = buildViewModel(
            FakeWeatherApiClient(
              result: Result.error(TestException('network error')),
            ),
          )..requestHourly(testTarget);
          await settleForecasts();

          expect(viewModel.loadHourlyForecast.results.value.completed, isFalse);
          expect(viewModel.loadHourlyForecast.results.value.hasFailure, isTrue);
          expect(
            viewModel.loadHourlyForecast.results.value.data,
            isA<Error<HourlyWeatherForecastData>>(),
          );
          expect(viewModel.getHourlyForecastData, isNull);
        },
      );
    });

    group('loadDailyForecast', () {
      test('populates getDailyForecastData on success', () async {
        final viewModel = buildViewModel(
          FakeWeatherApiClient(result: Result.success(testCombinedResponse)),
        )..requestDaily(testTarget);
        await settleForecasts();

        expect(viewModel.loadDailyForecast.results.value.completed, isTrue);
        expect(
          viewModel.loadDailyForecast.results.value.data,
          isA<Success<DailyWeatherForecastData>>(),
        );
        expect(viewModel.getDailyForecastData, isNotNull);
        expect(viewModel.getDailyForecastData!.time.length, 3);
      });

      test(
        'leaves getDailyForecastData null and surfaces error on failure',
        () async {
          final viewModel = buildViewModel(
            FakeWeatherApiClient(
              result: Result.error(TestException('network error')),
            ),
          )..requestDaily(testTarget);
          await settleForecasts();

          expect(viewModel.loadDailyForecast.results.value.completed, isFalse);
          expect(viewModel.loadDailyForecast.results.value.hasFailure, isTrue);
          expect(
            viewModel.loadDailyForecast.results.value.data,
            isA<Error<DailyWeatherForecastData>>(),
          );
          expect(viewModel.getDailyForecastData, isNull);
        },
      );
    });
  });
}

Future<void> settleForecasts() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}
