import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/data/services/api/weather/model/combined_weather_forecast_response.dart';
import 'package:moliseis/data/services/api/weather/model/current_forecast/current_weather_forecast_data.dart';
import 'package:moliseis/data/services/api/weather/model/daily_forecast/daily_weather_forecast_data.dart';
import 'package:moliseis/data/services/api/weather/model/hourly_forecast/hourly_weather_forecast_data.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/domain/models/content_type.dart';
import 'package:moliseis/domain/models/event.dart';
import 'package:moliseis/ui/core/themes/app_theme_data.dart';
import 'package:moliseis/ui/weather/view_models/weather_view_model.dart';
import 'package:moliseis/ui/weather/widgets/components/weather_forecast_modal.dart';
import 'package:moliseis/ui/weather/widgets/weather_forecast_button.dart';
import 'package:moliseis/utils/result.dart';

import '../../../support/command_test_support.dart';
import '../../../support/fake_repositories.dart';
import '../../../support/fixtures.dart';
import '../../../support/mock_logger.dart';
import '../../../support/weather_harness.dart';

void main() {
  setUpAll(initializeDateFormatting);
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

  Widget boundButton() {
    owner.setTarget((
      id: content.remoteId,
      type: content is Event ? ContentType.event : ContentType.place,
      latitude: coordinates.latitude,
      longitude: coordinates.longitude,
    ));
    return WeatherForecastButton(
      content: content,
      coordinates: coordinates,
      viewModel: owner,
    );
  }

  setUp(() {
    logger = MockLogger();
    client = FakeWeatherApiClient(result: Result.success(response));
    owner = buildWeatherViewModel(logger, weatherApiClient: client);
    content = makeEvent();
    coordinates = const LatLng(41.56, 14.66);
    accepted = 0;
    initialOwnerDisposed = false;
    final observedOwner = owner;
    owner.loadCurrentForecast.isRunningSync.addListener(() {
      if (observedOwner.loadCurrentForecast.isRunningSync.value) accepted++;
    });
    final initialOwner = owner;
    addTearDown(() {
      if (!initialOwnerDisposed) initialOwner.dispose();
    });
  });

  Future<void> drain(WidgetTester tester) async {
    await tester.runAsync(() async {
      for (var turn = 0; turn < 8; turn++) {
        await Future<void>.delayed(Duration.zero);
      }
    });
    await pumpCommandTurns(tester);
  }

  testWidgets(
    'initial owner once; equal semantic rebuild and identity cache hit',
    (tester) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: boundButton())));
      await drain(tester);
      await drain(tester);
      await tester.pumpAndSettle();
      expect(accepted, 1);
      expect(client.combinedForecastCoordinates, [(41.56, 14.66)]);
      expect(find.text('18.5 °C'), findsOneWidget);
      content = makeEvent(name: 'Unrelated title');
      coordinates = const LatLng(41.56, 14.66);
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: boundButton())));
      await drain(tester);
      await drain(tester);
      await tester.pumpAndSettle();
      expect(accepted, 1);
      content = makeEvent(remoteId: 2);
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: boundButton())));
      await drain(tester);
      await drain(tester);
      await tester.pumpAndSettle();
      expect(accepted, 2);
      expect(client.getCombinedWeatherForecastCallCount, 1);
      coordinates = const LatLng(42, 15);
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: boundButton())));
      await drain(tester);
      await drain(tester);
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
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: boundButton())));
      await drain(tester);
      final oldOwner = owner;
      final newClient = FakeWeatherApiClient(result: Result.success(response));
      owner = buildWeatherViewModel(logger, weatherApiClient: newClient);
      addTearDown(owner.dispose);
      oldOwner.dispose();
      initialOwnerDisposed = true;
      // Old owner already disposed by its real screen lifecycle.
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: boundButton())));
      await drain(tester);
      await drain(tester);
      await tester.pumpAndSettle();
      expect(newClient.getCombinedWeatherForecastCallCount, 1);
      expect(find.text('18.5 °C'), findsOneWidget);
      pending.complete(Result.success(response));
      await drain(tester);
      await tester.pumpAndSettle();
      expect(oldOwner.currentTemperatureCelsius, '--.-');
      expect(owner.currentTemperatureCelsius, '18.5');
      expect(newClient.getCombinedWeatherForecastCallCount, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('same owner immediately admits B and C and hides old target', (
    tester,
  ) async {
    final a = Completer<Result<CombinedWeatherForecastResponse>>();
    final c = Completer<Result<CombinedWeatherForecastResponse>>();
    client.combinedForecastHandler = (latitude, longitude) =>
        latitude == 41.56 ? a.future : c.future;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: boundButton())));
    await drain(tester);
    coordinates = const LatLng(42, 15);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: boundButton())));
    await drain(tester);
    coordinates = const LatLng(43, 16);
    content = makePlace(remoteId: 3);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: boundButton())));
    await drain(tester);
    expect(accepted, 3);
    expect(find.text('--.- °C'), findsOneWidget);
    a.complete(Result.success(response));
    await tester.pump();
    await tester.pump();
    expect(accepted, 3);
    expect(client.combinedForecastCoordinates, [
      (41.56, 14.66),
      (42, 15),
      (43, 16),
    ]);
    expect(find.text('--.- °C'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    c.complete(Result.success(response));
    await drain(tester);
    await tester.pumpAndSettle();
    expect(find.text('18.5 °C'), findsOneWidget);
  });

  testWidgets(
    'same target domain failure does not retry; changed target does',
    (tester) async {
      client.result = Result.error(Exception('expected'));
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: boundButton())));
      await drain(tester);
      await drain(tester);
      await tester.pumpAndSettle();
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: boundButton())));
      await drain(tester);
      await drain(tester);
      await tester.pumpAndSettle();
      expect(accepted, 1);
      expect(find.text('--.- °C'), findsOneWidget);
      client.result = Result.success(response);
      coordinates = const LatLng(42, 15);
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: boundButton())));
      await drain(tester);
      await drain(tester);
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
        MaterialApp(home: Scaffold(body: boundButton())),
      ),
    );
    tester.binding.buildOwner!.buildScope(tester.binding.rootElement!);
    expect(client.getCombinedWeatherForecastCallCount, 0);
    final newClient = FakeWeatherApiClient(result: Result.success(response));
    owner = buildWeatherViewModel(logger, weatherApiClient: newClient);
    addTearDown(owner.dispose);
    coordinates = const LatLng(43, 16);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: boundButton())));
    await drain(tester);
    await drain(tester);
    await tester.pumpAndSettle();
    expect(client.getCombinedWeatherForecastCallCount, 0);
    expect(newClient.combinedForecastCoordinates, [(43, 16)]);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'stale opening and ABA deferred neutral cannot request or navigate',
    (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      final observer = _ModalObserver();
      Widget app() => Builder(
        builder: (context) => MaterialApp(
          theme: AppThemeData.light(context: context),
          navigatorKey: navigator,
          navigatorObservers: [observer],
          home: Scaffold(body: boundButton()),
        ),
      );
      await tester.pumpWidget(app());
      await drain(tester);
      await tester.pumpAndSettle();
      final oldOpen = tester
          .widget<FilledButton>(find.byType(FilledButton))
          .onPressed!;
      final original = owner.currentTarget;
      owner
        ..setTarget(null)
        ..setTarget(original);
      // Public terminal A still visible, synchronous projection cleared.
      oldOpen();
      expect(observer.modals, isEmpty);
      expect(owner.loadHourlyForecast.isRunningSync.value, isFalse);
      expect(owner.loadDailyForecast.isRunningSync.value, isFalse);
      await drain(tester);
      await drain(tester);
      await tester.pumpAndSettle();
      expect(find.text('18.5 °C'), findsOneWidget);
      content = makePlace(remoteId: 2);
      await tester.pumpWidget(app());
      await drain(tester);
      await tester.pumpAndSettle();
      oldOpen(); // Callback A must not read B and open its forecast instead.
      expect(observer.modals, isEmpty);
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed!();
      expect(observer.modals, hasLength(1));
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  for (final replacement in ['target', 'owner', 'unmount', 'ABA']) {
    testWidgets('modal revocation during opening: $replacement', (
      tester,
    ) async {
      final navigator = GlobalKey<NavigatorState>();
      final observer = _ModalObserver();
      Widget app() => Builder(
        builder: (context) => MaterialApp(
          theme: AppThemeData.light(context: context),
          navigatorKey: navigator,
          navigatorObservers: [observer],
          home: Scaffold(body: boundButton()),
        ),
      );
      await tester.pumpWidget(app());
      await drain(tester);
      await tester.pumpAndSettle();
      final open = tester
          .widget<FilledButton>(find.byType(FilledButton))
          .onPressed!;
      var hourly = 0;
      var daily = 0;
      final forecastOwner = owner;
      owner.loadHourlyForecast.isRunningSync.addListener(() {
        if (forecastOwner.loadHourlyForecast.isRunningSync.value) hourly++;
      });
      owner.loadDailyForecast.isRunningSync.addListener(() {
        if (forecastOwner.loadDailyForecast.isRunningSync.value) daily++;
      });
      open();
      open();
      expect(observer.modals, hasLength(1));
      expect(hourly, 1);
      expect(daily, 1);
      if (replacement == 'unmount') {
        await tester.pumpWidget(const SizedBox.shrink());
      } else if (replacement == 'owner') {
        final old = owner;
        owner = buildWeatherViewModel(
          logger,
          weatherApiClient: FakeWeatherApiClient(
            result: Result.success(response),
          ),
        );
        addTearDown(owner.dispose);
        await tester.pumpWidget(app());
        old.dispose();
        initialOwnerDisposed = true;
      } else if (replacement == 'ABA') {
        final original = owner.currentTarget;
        owner
          ..setTarget(null)
          ..setTarget(original);
        await drain(tester);
      } else {
        content = makePlace(remoteId: 2);
        await tester.pumpWidget(app());
      }
      await drain(tester);
      await tester.pumpAndSettle();
      expect(find.byType(WeatherForecastModal), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('pop before first modal builder retains admission', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    final observer = _ModalObserver();
    Widget app() => Builder(
      builder: (context) => MaterialApp(
        theme: AppThemeData.light(context: context),
        navigatorKey: navigator,
        navigatorObservers: [observer],
        home: Scaffold(body: boundButton()),
      ),
    );
    await tester.pumpWidget(app());
    await drain(tester);
    await tester.pumpAndSettle();
    final open = tester
        .widget<FilledButton>(find.byType(FilledButton))
        .onPressed!;
    open();
    expect(observer.modals, hasLength(1));
    expect(find.byType(WeatherForecastModal), findsNothing);
    final first = observer.modals.single;
    var completed = false;
    unawaited(first.completed.then((_) => completed = true));
    navigator.currentState!.pop();
    open();
    expect(observer.modals, hasLength(1));
    expect(completed, isFalse);
    await drain(tester);
    await tester.pumpAndSettle();
    expect(completed, isTrue);
    open();
    expect(observer.modals, hasLength(2));
    expect(observer.modals.last.isActive, isTrue);
    // Old completion cannot unlock the newly owned route's admission.
    open();
    expect(observer.modals, hasLength(2));
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('modal admission persists through exit and safely reopens', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    final observer = _ModalObserver();
    Widget app() => Builder(
      builder: (context) => MaterialApp(
        theme: AppThemeData.light(context: context),
        navigatorKey: navigator,
        navigatorObservers: [observer],
        home: Scaffold(body: boundButton()),
      ),
    );
    await tester.pumpWidget(app());
    await drain(tester);
    await tester.pumpAndSettle();
    final open = tester
        .widget<FilledButton>(find.byType(FilledButton))
        .onPressed!;
    open();
    open();
    expect(observer.modals, hasLength(1));
    await drain(tester);
    await tester.pumpAndSettle();
    expect(find.byType(WeatherForecastModal), findsOneWidget);
    navigator.currentState!.pop();
    await tester.pump();
    open();
    expect(observer.modals, hasLength(1));
    await tester.pumpAndSettle();
    open();
    expect(observer.modals, hasLength(2));
    expect(observer.modals.last.isActive, isTrue);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'target revocation removes captured modal beneath unrelated route',
    (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      final observer = _ModalObserver();
      Widget app() => Builder(
        builder: (context) => MaterialApp(
          theme: AppThemeData.light(context: context),
          navigatorKey: navigator,
          navigatorObservers: [observer],
          home: Scaffold(body: boundButton()),
        ),
      );
      await tester.pumpWidget(app());
      await drain(tester);
      await tester.pumpAndSettle();
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed!();
      await drain(tester);
      await tester.pumpAndSettle();
      final other = MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Unrelated route')),
      );
      navigator.currentState!.push(other);
      await tester.pumpAndSettle();
      owner.setTarget(null);
      await drain(tester);
      await tester.pumpAndSettle();
      expect(observer.modals.single.isActive, isFalse);
      expect(other.isCurrent, isTrue);
      expect(find.text('Unrelated route'), findsOneWidget);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('same owner target changes before initial deferred admission', (
    tester,
  ) async {
    tester.binding.attachRootWidget(
      tester.binding.wrapWithDefaultView(
        MaterialApp(home: Scaffold(body: boundButton())),
      ),
    );
    tester.binding.buildOwner!.buildScope(tester.binding.rootElement!);
    expect(client.getCombinedWeatherForecastCallCount, 0);
    content = makePlace(remoteId: 2);
    coordinates = const LatLng(43, 16);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: boundButton())));
    await drain(tester);
    await drain(tester);
    await tester.pumpAndSettle();
    expect(accepted, 1);
    expect(client.combinedForecastCoordinates, [(43, 16)]);
    expect(owner.currentTarget?.type, ContentType.place);
    expect(find.text('18.5 °C'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final replaceOwner in [false, true]) {
    testWidgets('current observer detaches: '
        '${replaceOwner ? 'owner replacement' : 'unmount'}', (tester) async {
      final pending = Completer<Result<CombinedWeatherForecastResponse>>();
      client.pendingCombinedForecast = pending;
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: boundButton())));
      await drain(tester);
      final oldOwner = owner;
      coordinates = const LatLng(42, 15);
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: boundButton())));
      await drain(tester);
      if (replaceOwner) {
        final newClient = FakeWeatherApiClient(
          result: Result.success(response),
        );
        owner = buildWeatherViewModel(logger, weatherApiClient: newClient);
        addTearDown(owner.dispose);
        await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: boundButton())),
        );
        await drain(tester);
        await tester.pumpAndSettle();
        expect(newClient.combinedForecastCoordinates, [(42, 15)]);
      } else {
        await tester.pumpWidget(const SizedBox());
      }
      pending.complete(Result.success(response));
      await drain(tester);
      await tester.pumpAndSettle();
      expect(client.getCombinedWeatherForecastCallCount, 2);
      expect(oldOwner.loadCurrentForecast.isRunningSync.value, isFalse);
      expect(tester.takeException(), isNull);
    });
  }
}

class _ModalObserver extends NavigatorObserver {
  final modals = <ModalBottomSheetRoute<dynamic>>[];
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is ModalBottomSheetRoute<dynamic>) modals.add(route);
  }
}
