import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:latlong2/latlong.dart';
import 'package:moliseis/data/services/api/weather/cached_weather_api_client.dart';
import 'package:moliseis/data/services/api/weather/model/combined_weather_forecast_response.dart';
import 'package:moliseis/data/services/api/weather/model/current_forecast/current_weather_forecast_data.dart';
import 'package:moliseis/data/services/api/weather/model/daily_forecast/daily_weather_forecast_data.dart';
import 'package:moliseis/data/services/api/weather/model/hourly_forecast/hourly_weather_forecast_data.dart';
import 'package:moliseis/data/services/api/weather/model/weather_forecast_data_cache_entry.dart';
import 'package:moliseis/ui/core/ui/empty_box.dart';
import 'package:moliseis/ui/weather/view_models/weather_view_model.dart';
import 'package:moliseis/ui/weather/widgets/components/weather_forecast_days_list.dart';
import 'package:moliseis/ui/weather/wmo_weather_description_mapper.dart';
import 'package:moliseis/ui/weather/wmo_weather_icon_mapper.dart';
import 'package:moliseis/utils/lru_cache.dart';
import 'package:moliseis/utils/result.dart';

import '../../../../support/fake_repositories.dart';
import '../../../../support/mock_logger.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('it');
  });

  const testCoordinates = LatLng(41.56, 14.66);

  late CombinedWeatherForecastResponse successResponse;

  setUp(() {
    final currentData = CurrentWeatherForecastData(
      time: DateTime.utc(2026, 4, 7, 10),
      interval: 900,
      temperature2m: 18.5,
      isDay: 1,
      weatherCode: 0,
    );

    final hourlyData = HourlyWeatherForecastData(
      time: List.generate(
        24,
        (i) => '2026-04-07T${i.toString().padLeft(2, '0')}:00',
      ),
      temperature2m: List.filled(24, 18.5),
      weatherCode: List.filled(24, 0),
      precipitationProbability: List.filled(24, 0),
      isDay: List.filled(24, 1),
    );

    const dailyData = DailyWeatherForecastData(
      time: ['2026-04-07', '2026-04-08', '2026-04-09'],
      weatherCode: [0, 1, 2],
      temperature2mMax: [20.0, 21.0, 19.0],
      temperature2mMin: [12.0, 13.0, 11.0],
      precipitationProbabilityMax: [0, 10, 20],
    );

    successResponse = CombinedWeatherForecastResponse(
      latitude: 41.56,
      longitude: 14.66,
      generationTimeMs: 1,
      utcOffsetSeconds: 7200,
      timezone: 'Europe/Rome',
      timezoneAbbreviation: 'CEST',
      elevation: 700,
      current: currentData,
      hourly: hourlyData,
      daily: dailyData,
    );
  });

  WeatherViewModel buildViewModel(
    MockLogger mockLogger,
    Result<CombinedWeatherForecastResponse> result,
  ) {
    return WeatherViewModel(
      weatherApiClient: CachedWeatherApiClient(
        weatherApiClient: FakeWeatherApiClient(result: result),
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
      ),
      weatherDescriptionMapper: const WmoWeatherDescriptionMapper(),
      weatherCodeIconMapper: const WmoWeatherIconMapper(),
    );
  }

  Widget buildTestWidget(WeatherViewModel viewModel) {
    return MaterialApp(
      home: Scaffold(
        body: WeatherForecastDaysList(
          borderColor: Colors.grey,
          backgroundColor: Colors.white,
          viewModel: viewModel,
        ),
      ),
    );
  }

  group('WeatherForecastDaysList', () {
    late MockLogger mockLogger;

    setUp(() {
      mockLogger = MockLogger();
    });

    testWidgets('shows EmptyBox before command runs', (tester) async {
      final viewModel = buildViewModel(
        mockLogger,
        Result.success(successResponse),
      );

      await tester.pumpWidget(buildTestWidget(viewModel));

      expect(find.byType(EmptyBox), findsOneWidget);
      expect(find.byType(ListView), findsNothing);
    });

    testWidgets('shows list after successful load', (tester) async {
      final viewModel = buildViewModel(
        mockLogger,
        Result.success(successResponse),
      );
      await viewModel.loadDailyForecast.execute(testCoordinates);

      await tester.pumpWidget(buildTestWidget(viewModel));
      await tester.pumpAndSettle();

      expect(find.byType(ListView), findsOneWidget);
      expect(find.byType(EmptyBox), findsNothing);
    });

    testWidgets('shows EmptyBox after failed load', (tester) async {
      final viewModel = buildViewModel(
        mockLogger,
        Result.error(Exception('network error')),
      );
      await viewModel.loadDailyForecast.execute(testCoordinates);

      await tester.pumpWidget(buildTestWidget(viewModel));

      expect(find.byType(EmptyBox), findsOneWidget);
      expect(find.byType(ListView), findsNothing);
    });
  });
}
