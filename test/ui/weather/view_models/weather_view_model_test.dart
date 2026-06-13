import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:moliseis/data/services/api/weather/cached_weather_api_client.dart';
import 'package:moliseis/data/services/api/weather/model/combined_weather_forecast_response.dart';
import 'package:moliseis/data/services/api/weather/model/current_forecast/current_weather_forecast_data.dart';
import 'package:moliseis/data/services/api/weather/model/daily_forecast/daily_weather_forecast_data.dart';
import 'package:moliseis/data/services/api/weather/model/hourly_forecast/hourly_weather_forecast_data.dart';
import 'package:moliseis/data/services/api/weather/model/weather_forecast_data_cache_entry.dart';
import 'package:moliseis/ui/weather/view_models/weather_view_model.dart';
import 'package:moliseis/ui/weather/wmo_weather_description_mapper.dart';
import 'package:moliseis/ui/weather/wmo_weather_icon_mapper.dart';
import 'package:moliseis/utils/lru_cache.dart';
import 'package:moliseis/utils/result.dart';

import '../../../support/fake_repositories.dart';
import '../../../support/mock_logger.dart';

void main() {
  late MockLogger mockLogger;

  const testCoordinates = LatLng(41.56, 14.66);

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
    );
  }

  group('WeatherViewModel', () {
    group('loadCurrentForecast', () {
      test('sets current conditions state on success', () async {
        final viewModel = buildViewModel(
          FakeWeatherApiClient(result: Result.success(testCombinedResponse)),
        );

        await viewModel.loadCurrentForecast.execute(testCoordinates);

        expect(viewModel.loadCurrentForecast.completed, isTrue);
        expect(
          viewModel.loadCurrentForecast.result,
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
        );

        await viewModel.loadCurrentForecast.execute(testCoordinates);

        expect(viewModel.loadCurrentForecast.completed, isFalse);
        expect(viewModel.loadCurrentForecast.error, isTrue);
        expect(
          viewModel.loadCurrentForecast.result,
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
        );

        await viewModel.loadHourlyForecast.execute(testCoordinates);

        expect(viewModel.loadHourlyForecast.completed, isTrue);
        expect(
          viewModel.loadHourlyForecast.result,
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
          );

          await viewModel.loadHourlyForecast.execute(testCoordinates);

          expect(viewModel.loadHourlyForecast.completed, isFalse);
          expect(viewModel.loadHourlyForecast.error, isTrue);
          expect(
            viewModel.loadHourlyForecast.result,
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
        );

        await viewModel.loadDailyForecast.execute(testCoordinates);

        expect(viewModel.loadDailyForecast.completed, isTrue);
        expect(
          viewModel.loadDailyForecast.result,
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
          );

          await viewModel.loadDailyForecast.execute(testCoordinates);

          expect(viewModel.loadDailyForecast.completed, isFalse);
          expect(viewModel.loadDailyForecast.error, isTrue);
          expect(
            viewModel.loadDailyForecast.result,
            isA<Error<DailyWeatherForecastData>>(),
          );
          expect(viewModel.getDailyForecastData, isNull);
        },
      );
    });
  });
}
