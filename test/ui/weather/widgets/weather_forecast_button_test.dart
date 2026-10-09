import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/data/services/api/weather/model/combined_weather_forecast_response.dart';
import 'package:moliseis/data/services/api/weather/model/current_forecast/current_weather_forecast_data.dart';
import 'package:moliseis/data/services/api/weather/model/daily_forecast/daily_weather_forecast_data.dart';
import 'package:moliseis/data/services/api/weather/model/hourly_forecast/hourly_weather_forecast_data.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/ui/weather/view_models/weather_view_model.dart';
import 'package:moliseis/ui/weather/widgets/weather_forecast_button.dart';
import 'package:moliseis/utils/result.dart';

import '../../../support/fake_repositories.dart';
import '../../../support/fixtures.dart';
import '../../../support/mock_logger.dart';
import '../../../support/weather_harness.dart';

void main() {
  final response = CombinedWeatherForecastResponse(
    latitude: 41.56,
    longitude: 14.66,
    generationTimeMs: 1,
    utcOffsetSeconds: 7200,
    timezone: 'Europe/Rome',
    timezoneAbbreviation: 'CEST',
    elevation: 700,
    current: CurrentWeatherForecastData(
      time: DateTime.utc(2026, 4, 7, 10),
      interval: 900,
      temperature2m: 18.5,
      isDay: 1,
      weatherCode: 0,
      precipitation: 0,
    ),
    hourly: const HourlyWeatherForecastData(
      time: [],
      temperature2m: [],
      weatherCode: [],
      precipitationProbability: [],
      isDay: [],
    ),
    daily: const DailyWeatherForecastData(
      time: [],
      weatherCode: [],
      temperature2mMax: [],
      temperature2mMin: [],
      precipitationProbabilityMax: [],
    ),
  );
  late MockLogger logger;
  late FakeWeatherApiClient client;
  late WeatherViewModel owner;
  late ContentBase content;
  late LatLng coordinates;
  late int accepted;
  late bool initialOwnerDisposed;

  setUp(() {
    logger = MockLogger();
    client = FakeWeatherApiClient(result: Result.success(response));
    owner = buildWeatherViewModel(logger, weatherApiClient: client);
    content = makeEvent();
    coordinates = const LatLng(41.56, 14.66);
    accepted = 0;
    initialOwnerDisposed = false;
    final observedOwner = owner;
    owner.loadCurrentForecast.addListener(() {
      if (observedOwner.loadCurrentForecast.running) accepted++;
    });
    final initialOwner = owner;
    addTearDown(() {
      if (!initialOwnerDisposed) initialOwner.dispose();
    });
  });

  testWidgets(
    'initial owner once; equal semantic rebuild and identity cache hit',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WeatherForecastButton(
              content: content,
              coordinates: coordinates,
              viewModel: owner,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(accepted, 1);
      expect(client.combinedForecastCoordinates, [(41.56, 14.66)]);
      expect(find.text('18.5 °C'), findsOneWidget);
      content = makeEvent(name: 'Unrelated title');
      coordinates = const LatLng(41.56, 14.66);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WeatherForecastButton(
              content: content,
              coordinates: coordinates,
              viewModel: owner,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(accepted, 1);
      content = makeEvent(remoteId: 2);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WeatherForecastButton(
              content: content,
              coordinates: coordinates,
              viewModel: owner,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(accepted, 2);
      expect(client.getCombinedWeatherForecastCallCount, 1);
      coordinates = const LatLng(42, 15);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WeatherForecastButton(
              content: content,
              coordinates: coordinates,
              viewModel: owner,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(accepted, 3);
      expect(client.combinedForecastCoordinates.last, (42, 15));
    },
  );

  testWidgets(
    'new owner loads once and old disposed owner settles independently',
    (tester) async {
      final pending = Completer<Result<CombinedWeatherForecastResponse>>();
      client.pendingCombinedForecast = pending;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WeatherForecastButton(
              content: content,
              coordinates: coordinates,
              viewModel: owner,
            ),
          ),
        ),
      );
      final oldOwner = owner;
      final newClient = FakeWeatherApiClient(result: Result.success(response));
      owner = buildWeatherViewModel(logger, weatherApiClient: newClient);
      addTearDown(owner.dispose);
      oldOwner.dispose();
      initialOwnerDisposed = true;
      // Old owner already disposed by its real screen lifecycle.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WeatherForecastButton(
              content: content,
              coordinates: coordinates,
              viewModel: owner,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(newClient.getCombinedWeatherForecastCallCount, 1);
      expect(find.text('18.5 °C'), findsOneWidget);
      pending.complete(Result.success(response));
      await tester.pumpAndSettle();
      expect(oldOwner.currentTemperatureCelsius, '--.-');
      expect(owner.currentTemperatureCelsius, '18.5');
      expect(newClient.getCombinedWeatherForecastCallCount, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('busy same owner coalesces B then C and hides old target', (
    tester,
  ) async {
    final a = Completer<Result<CombinedWeatherForecastResponse>>();
    final c = Completer<Result<CombinedWeatherForecastResponse>>();
    client.combinedForecastHandler = (latitude, longitude) =>
        latitude == 41.56 ? a.future : c.future;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WeatherForecastButton(
            content: content,
            coordinates: coordinates,
            viewModel: owner,
          ),
        ),
      ),
    );
    coordinates = const LatLng(42, 15);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WeatherForecastButton(
            content: content,
            coordinates: coordinates,
            viewModel: owner,
          ),
        ),
      ),
    );
    coordinates = const LatLng(43, 16);
    content = makePlace(remoteId: 3);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WeatherForecastButton(
            content: content,
            coordinates: coordinates,
            viewModel: owner,
          ),
        ),
      ),
    );
    expect(accepted, 1);
    expect(find.text('--.- °C'), findsOneWidget);
    a.complete(Result.success(response));
    await tester.pump();
    await tester.pump();
    expect(accepted, 2);
    expect(client.combinedForecastCoordinates, [(41.56, 14.66), (43, 16)]);
    expect(find.text('--.- °C'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    c.complete(Result.success(response));
    await tester.pumpAndSettle();
    expect(find.text('18.5 °C'), findsOneWidget);
  });

  testWidgets(
    'same target domain failure does not retry; changed target does',
    (tester) async {
      client.result = Result.error(Exception('expected'));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WeatherForecastButton(
              content: content,
              coordinates: coordinates,
              viewModel: owner,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WeatherForecastButton(
              content: content,
              coordinates: coordinates,
              viewModel: owner,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(accepted, 1);
      expect(find.text('--.- °C'), findsOneWidget);
      client.result = Result.success(response);
      coordinates = const LatLng(42, 15);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WeatherForecastButton(
              content: content,
              coordinates: coordinates,
              viewModel: owner,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(accepted, 2);
      expect(find.text('18.5 °C'), findsOneWidget);
    },
  );

  testWidgets('init and update before first callback admit only latest owner', (
    tester,
  ) async {
    tester.binding.attachRootWidget(
      tester.binding.wrapWithDefaultView(
        MaterialApp(
          home: Scaffold(
            body: WeatherForecastButton(
              content: content,
              coordinates: coordinates,
              viewModel: owner,
            ),
          ),
        ),
      ),
    );
    tester.binding.buildOwner!.buildScope(tester.binding.rootElement!);
    expect(client.getCombinedWeatherForecastCallCount, 0);
    final newClient = FakeWeatherApiClient(result: Result.success(response));
    owner = buildWeatherViewModel(logger, weatherApiClient: newClient);
    addTearDown(owner.dispose);
    coordinates = const LatLng(43, 16);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WeatherForecastButton(
            content: content,
            coordinates: coordinates,
            viewModel: owner,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(client.getCombinedWeatherForecastCallCount, 0);
    expect(newClient.combinedForecastCoordinates, [(43, 16)]);
    expect(tester.takeException(), isNull);
  });

  for (final replaceOwner in [false, true]) {
    testWidgets('waiting listener detaches: '
        '${replaceOwner ? 'owner replacement' : 'unmount'}', (tester) async {
      final pending = Completer<Result<CombinedWeatherForecastResponse>>();
      client.pendingCombinedForecast = pending;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WeatherForecastButton(
              content: content,
              coordinates: coordinates,
              viewModel: owner,
            ),
          ),
        ),
      );
      final oldOwner = owner;
      coordinates = const LatLng(42, 15);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WeatherForecastButton(
              content: content,
              coordinates: coordinates,
              viewModel: owner,
            ),
          ),
        ),
      );
      if (replaceOwner) {
        final newClient = FakeWeatherApiClient(
          result: Result.success(response),
        );
        owner = buildWeatherViewModel(logger, weatherApiClient: newClient);
        addTearDown(owner.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: WeatherForecastButton(
                content: content,
                coordinates: coordinates,
                viewModel: owner,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(newClient.combinedForecastCoordinates, [(42, 15)]);
      } else {
        await tester.pumpWidget(const SizedBox());
      }
      pending.complete(Result.success(response));
      await tester.pumpAndSettle();
      expect(client.getCombinedWeatherForecastCallCount, 1);
      expect(oldOwner.loadCurrentForecast.running, isFalse);
      expect(tester.takeException(), isNull);
    });
  }
}
