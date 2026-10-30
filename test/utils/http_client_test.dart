import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image_ce/cached_network_image.dart'
    show FileInfo;
import 'package:cached_network_image_ce/src/cache/default_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:moliseis/data/services/api/weather/weather_api_client.dart';
import 'package:moliseis/utils/constants.dart';
import 'package:moliseis/utils/http_client.dart';
import 'package:moliseis/utils/result.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_supabase/sentry_supabase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/loopback_http_client.dart';
import '../support/mock_logger.dart';
import '../support/recording_sentry_transport.dart';
import '../support/test_image_files.dart';

void main() {
  late HttpServer server;
  late Uri baseUri;
  late Future<void> Function(HttpRequest) respond;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    baseUri = Uri.parse('http://${server.address.host}:${server.port}');
    respond = (request) async {
      request.response
        ..headers.contentType = ContentType.json
        ..write('{}');
      await request.response.close();
    };
    server.listen((request) => unawaited(respond(request)));
  });

  tearDown(() async {
    await Sentry.close();
    await server.close(force: true);
  });

  for (final throws in [false, true]) {
    test(
      'fallback clients own separate sockets after platform throws=$throws',
      () async {
        http.Client? platform() {
          if (throws) throw StateError('platform unavailable');
          return null;
        }

        final first = httpClientFactory(platformClientFactory: platform);
        final second = httpClientFactory(platformClientFactory: platform);
        addTearDown(first.close);
        addTearDown(second.close);
        final agents = <String?>[];
        respond = (request) async {
          agents.add(request.headers.value(HttpHeaders.userAgentHeader));
          request.response.write('ok');
          await request.response.close();
        };
        expect((await first.get(baseUri)).body, 'ok');
        first.close();
        expect((await second.get(baseUri)).body, 'ok');
        expect(agents, everyElement(kUserAgent));
        await expectLater(
          first.get(baseUri),
          throwsA(isA<http.ClientException>()),
        );
      },
    );
  }

  test(
    'real Sentry close preserves pending and subsequent app requests',
    () async {
      final app = httpClientFactory(platformClientFactory: () => null);
      final telemetry = httpClientFactory(platformClientFactory: () => null);
      addTearDown(app.close);
      final received = Completer<void>();
      final release = Completer<void>();
      addTearDown(() {
        if (!release.isCompleted) release.complete();
      });
      respond = (request) async {
        if (request.uri.path == '/pending') {
          received.complete();
          await release.future;
        }
        request.response.write('ok');
        await request.response.close();
      };
      final transport = RecordingSentryTransport();
      await Sentry.init((options) {
        options
          ..dsn = 'https://synthetic@example.invalid/1'
          ..httpClient = telemetry
          ..transport = transport;
      });
      await Sentry.captureMessage('synthetic-before-close');
      expect(transport.envelopes, hasLength(1));
      final pending = app.get(baseUri.resolve('/pending'));
      await received.future;
      await Sentry.close();
      await Sentry.close();
      release.complete();
      expect((await pending).body, 'ok');
      expect((await app.get(baseUri)).body, 'ok');
      await expectLater(
        telemetry.get(baseUri),
        throwsA(isA<http.ClientException>()),
      );
      await Sentry.captureMessage('synthetic-after-close');
      expect(transport.envelopes, hasLength(1));
    },
  );

  test(
    'Supabase queries and authentication survive actual Sentry close',
    () async {
      final app = httpClientFactory(platformClientFactory: () => null);
      final telemetry = httpClientFactory(platformClientFactory: () => null);
      final transport = RecordingSentryTransport();
      await Sentry.init((options) {
        options
          ..dsn = 'https://synthetic@example.invalid/1'
          ..httpClient = telemetry
          ..transport = transport;
      });
      final supabase = SupabaseClient(
        baseUri.toString(),
        'synthetic-publishable-key',
        httpClient: SentrySupabaseClient(client: app),
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      addTearDown(supabase.dispose);
      addTearDown(app.close);
      final paths = <String>[];
      respond = (request) async {
        paths.add(request.uri.path);
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          request.uri.path.endsWith('/user')
              ? jsonEncode({
                  'id': 'synthetic-user',
                  'aud': 'authenticated',
                  'created_at': '2026-10-30T00:00:00Z',
                  'app_metadata': <String, dynamic>{},
                  'user_metadata': <String, dynamic>{},
                })
              : '[]',
        );
        await request.response.close();
      };
      expect(await supabase.from('places').select(), isEmpty);
      expect(
        (await supabase.auth.getUser('synthetic-session')).user?.id,
        'synthetic-user',
      );
      await Sentry.close();
      expect(await supabase.from('places').select(), isEmpty);
      expect(
        (await supabase.auth.getUser('synthetic-session')).user?.id,
        'synthetic-user',
      );
      expect(paths.where((path) => path.endsWith('/places')), hasLength(2));
      expect(paths.where((path) => path.endsWith('/user')), hasLength(2));
    },
  );

  test(
    'weather service and image-cache downloads survive actual Sentry close',
    () async {
      final app = httpClientFactory(platformClientFactory: () => null);
      final telemetry = httpClientFactory(platformClientFactory: () => null);
      addTearDown(app.close);
      final directory = await Directory.systemTemp.createTemp(
        'http-ownership-cache-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final images = TestImageFiles.create();
      addTearDown(images.dispose);
      final png = await images.createPng().readAsBytes();
      final cache = DefaultCacheManager(
        httpClientFactory: () =>
            httpClientFactory(platformClientFactory: () => null),
        cacheDirectoryProvider: () async => directory,
        metadataDirectoryProvider: () async => directory,
      );
      addTearDown(cache.dispose);
      final weather = WeatherApiClient(
        logger: MockLogger(),
        httpClient: LoopbackHttpClient(app, baseUri),
      );
      respond = (request) async {
        if (request.uri.path.endsWith('.png')) {
          request.response
            ..headers.contentType = ContentType('image', 'png')
            ..add(png);
        } else {
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode({
              'latitude': 41.5,
              'longitude': 14.5,
              'generationtime_ms': 0.1,
              'utc_offset_seconds': 0,
              'timezone': 'Europe/Rome',
              'timezone_abbreviation': 'CET',
              'elevation': 100,
              'current': {
                'time': '2026-10-30T12:00',
                'interval': 900,
                'temperature_2m': 18.0,
                'is_day': 1,
                'weather_code': 0,
              },
              'hourly': {
                'time': <String>[],
                'temperature_2m': <double>[],
                'precipitation_probability': <int>[],
                'weather_code': <int>[],
                'is_day': <int>[],
              },
              'daily': {
                'time': <String>[],
                'weather_code': <int>[],
                'temperature_2m_max': <double>[],
                'temperature_2m_min': <double>[],
                'precipitation_probability_max': <int>[],
              },
            }),
          );
        }
        await request.response.close();
      };
      await Sentry.init((options) {
        options
          ..dsn = 'https://synthetic@example.invalid/1'
          ..httpClient = telemetry
          ..transport = RecordingSentryTransport();
      });
      for (final name in ['before', 'after']) {
        if (name == 'after') await Sentry.close();
        expect(
          await weather.getCombinedWeatherForecast(41.5, 14.5),
          isA<Success<Object>>(),
        );
        final file =
            await cache
                    .getFileStream(baseUri.resolve('/$name.png').toString())
                    .firstWhere((event) => event is FileInfo)
                as FileInfo;
        expect(await file.file.readAsBytes(), png);
      }
    },
  );
}
