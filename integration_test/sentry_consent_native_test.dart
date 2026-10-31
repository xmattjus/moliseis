import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image_ce/cached_network_image.dart'
    show FileInfo;
import 'package:cached_network_image_ce/src/cache/default_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/config/bootstrap.dart';
import 'package:moliseis/data/data-sources/app_settings.dart';
import 'package:moliseis/data/data-sources/settings_local_data_source.dart';
import 'package:moliseis/data/repositories/settings_repository_impl.dart';
import 'package:moliseis/data/services/api/weather/weather_api_client.dart';
import 'package:moliseis/domain/use_cases/set_crash_reporting_use_case.dart';
import 'package:moliseis/generated/objectbox.g.dart';
import 'package:moliseis/ui/admin/submissions/widgets/admin_submission_list_item.dart';
import 'package:moliseis/utils/http_client.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/sentry_logging_flag.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_supabase/sentry_supabase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../test/support/fake_repositories.dart';
import '../test/support/loopback_http_client.dart';
import '../test/support/mock_logger.dart';
import '../test/support/test_image_files.dart';
import '../test/support/weather_http_fixture.dart';

/// Runs isolated consent phases without importing production credentials.
///
/// Run prepare, active and disabled in separate processes on one installation.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const crashProbe = String.fromEnvironment('NATIVE_CRASH_PROBE');
  const phase = String.fromEnvironment(
    'CONSENT_PHASE',
    defaultValue: 'prepare',
  );

  testWidgets('native consent process $phase', (tester) async {
    expect(['prepare', 'active', 'disabled'], contains(phase));
    final documents = await getApplicationSupportDirectory();
    final directory = Directory('${documents.path}/consent-native-acceptance');
    if (phase == 'prepare' && directory.existsSync()) {
      await directory.delete(recursive: true);
    }
    if (phase != 'prepare') {
      expect(
        directory.existsSync(),
        isTrue,
        reason: 'run all phases with --no-uninstall',
      );
      final previous = File('${directory.path}/previous-process');
      expect(await previous.readAsString(), isNot('$pid'));
    }
    final store = await openStore(directory: directory.path);
    await File('${directory.path}/previous-process').writeAsString('$pid');
    addTearDown(() {
      if (!store.isClosed()) store.close();
    });
    if (phase == 'prepare') {
      store.box<AppSettings>().put(AppSettings(crashReporting: false));
    }
    final recordings = Directory('${directory.path}/recordings');
    if (phase == 'active' && recordings.existsSync()) {
      await recordings.delete(recursive: true);
    }
    final repository = SettingsRepositoryImpl(SettingsLocalDataSource(store));
    // Keep the DSN stable so native cached crashes survive process restarts.
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 48127);
    addTearDown(() => server.close(force: true));
    final base = Uri.parse('http://127.0.0.1:${server.port}');
    final images = TestImageFiles.create();
    addTearDown(images.dispose);
    final png = await images.createPng().readAsBytes();
    final envelopes = <String>[];
    final pendingArrived = Completer<void>();
    final releasePending = Completer<void>();
    addTearDown(() {
      if (!releasePending.isCompleted) releasePending.complete();
    });
    server.listen((request) async {
      if (request.uri.path.endsWith('/envelope/')) {
        var bytes = await request.fold<List<int>>([], (a, b) => a..addAll(b));
        if (bytes.length > 2 && bytes[0] == 31 && bytes[1] == 139) {
          bytes = gzip.decode(bytes);
        }
        envelopes.add(utf8.decode(bytes, allowMalformed: true));
        if (phase == 'active') {
          final artifacts = Directory('${directory.path}/recordings')
            ..createSync(recursive: true);
          await File(
            '${artifacts.path}/envelope-${envelopes.length}.bin',
          ).writeAsBytes(bytes);
        }
        request.response.write('{}');
      } else if (request.uri.path.endsWith('.png')) {
        request.response
          ..headers.contentType = ContentType('image', 'png')
          ..add(png);
      } else if (request.uri.path == '/v1/forecast') {
        request.response
          ..headers.contentType = ContentType.json
          ..write(jsonEncode(weatherHttpResponse));
      } else {
        if (request.uri.path == '/pending') {
          pendingArrived.complete();
          await releasePending.future;
        }
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
      }
      await request.response.close();
    });
    final appClient = httpClientFactory();
    addTearDown(appClient.close);
    final originalHandler = FlutterError.onError;
    try {
      // Exercise the installed handler without failing the test runner.
      FlutterError.onError = (details) {
        final error = details.exception;
        if (error is StateError &&
            const {
              'synthetic-pre-revocation',
              'synthetic-post-revocation',
            }.contains(error.message)) {
          return;
        }
        originalHandler?.call(details);
      };
      var starts = 0;
      late SetCrashReportingUseCase consent;
      var taps = 0;
      await bootstrapApplication(
        createSettings: () async => repository,
        onLocalFailure: (error, stack) => fail('local setup failed: $error'),
        onSettingsInitialized: (result) => expect(result.isSuccess, isTrue),
        initializeTelemetry: (runner) async {
          starts++;
          await SentryFlutter.init((options) {
            options
              ..dsn = 'http://synthetic@127.0.0.1:${server.port}/1'
              ..environment = 'isolated-native-acceptance'
              ..httpClient = httpClientFactory()
              ..replay.sessionSampleRate = 1
              ..replay.onErrorSampleRate = 1
              ..privacy.maskAllText = false
              ..privacy.maskAllImages = false
              ..sendDefaultPii = false;
          }, appRunner: runner);
        },
        runApplication: (settings, {required reportingEnabled}) async {
          expect(reportingEnabled, phase == 'active');
          consent = SetCrashReportingUseCase(
            settingsRepository: settings,
            sentryLoggingFlag: SentryLoggingFlag(initialValue: false),
            initiallyEnabled: reportingEnabled,
            closeSentry: () async {
              // Inspect disk, not only the committed repository cache.
              expect(store.box<AppSettings>().get(1)!.crashReporting, isFalse);
              await Sentry.close();
            },
          );
          final root = MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  const Text('Tourism title and date 31 October'),
                  AdminSubmissionListItem(
                    summary: sampleAdminSubmission(
                      name: 'Tourism editorial title',
                      userName: 'Synthetic contributor',
                      userEmail: 'synthetic@example.invalid',
                      createdAt: DateTime.utc(2026, 10, 31),
                    ),
                    onTap: () {},
                  ),
                  TextButton(onPressed: () => taps++, child: const Text('Tap')),
                ],
              ),
            ),
          );
          await tester.pumpWidget(
            reportingEnabled ? SentryWidget(child: root) : root,
          );
        },
      );
      expect(starts, phase == 'active' ? 1 : 0);
      expect(Sentry.isEnabled, phase == 'active');
      if (phase == 'prepare') {
        expect((await consent(enable: true)).isSuccess, isTrue);
        expect(Sentry.isEnabled, isFalse);
        expect(consent.state, CrashReportingState.inactive);
      } else if (phase == 'active') {
        await SentryFlutter.replay.start();
        for (var frame = 0; frame < 60; frame++) {
          await tester.pump();
          await Future<void>.delayed(const Duration(milliseconds: 200));
        }
        await SentryFlutter.replay.flush();
        FlutterError.onError!(
          FlutterErrorDetails(
            exception: StateError('synthetic-pre-revocation'),
            stack: StackTrace.current,
          ),
        );
        final deadline = DateTime.now().add(const Duration(seconds: 25));
        while (!envelopes.any((e) => e.contains('synthetic-pre-revocation')) &&
            DateTime.now().isBefore(deadline)) {
          await tester.pump(const Duration(milliseconds: 200));
          await Future<void>.delayed(const Duration(milliseconds: 200));
        }
        expect(
          envelopes.any((e) => e.contains('synthetic-pre-revocation')),
          isTrue,
          reason: 'native transport positive control must arrive on loopback',
        );
        if (crashProbe == 'before') {
          await Sentry.configureScope((scope) async {
            await scope.setTag('native_probe', 'before');
            await scope.setTag('native_probe_pid', '$pid');
          });
          debugPrint('NATIVE_ACCEPTANCE invoking native crash before close');
          await SentryFlutter.nativeCrash();
          fail('native crash probe unexpectedly returned');
        }
        if (crashProbe == 'after') {
          await Sentry.configureScope((scope) async {
            await scope.setTag('native_probe', 'after');
            await scope.setTag('native_probe_pid', '$pid');
          });
        }
        final supabase = SupabaseClient(
          base.toString(),
          'synthetic-key',
          httpClient: SentrySupabaseClient(client: appClient),
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        );
        addTearDown(supabase.dispose);
        final weather = WeatherApiClient(
          logger: MockLogger(),
          httpClient: LoopbackHttpClient(appClient, base),
        );
        final imageDirectory = await Directory(
          '${directory.path}/images',
        ).create();
        final cache = DefaultCacheManager(
          httpClientFactory: httpClientFactory,
          cacheDirectoryProvider: () async => imageDirectory,
          metadataDirectoryProvider: () async => imageDirectory,
        );
        addTearDown(cache.dispose);
        expect(
          (await weather.getCombinedWeatherForecast(41.5, 14.5)).isSuccess,
          isTrue,
        );
        final beforeImage =
            await cache
                    .getFileStream(base.resolve('/before.png').toString())
                    .firstWhere((event) => event is FileInfo)
                as FileInfo;
        expect(await beforeImage.file.readAsBytes(), png);
        final pending = appClient.get(base.resolve('/pending'));
        await pendingArrived.future.timeout(const Duration(seconds: 10));
        final result = await consent(enable: false);
        expect(result, isA<Success<CrashReportingUpdate>>());
        expect(
          (result as Success<CrashReportingUpdate>).value.outcome,
          CrashReportingOutcome.disabled,
        );
        releasePending.complete();
        expect((await pending).statusCode, 200);
        expect(await supabase.from('places').select(), isEmpty);
        expect(
          (await supabase.auth.getUser('synthetic-session')).user!.id,
          'synthetic-user',
        );
        expect((await appClient.get(base.resolve('/after'))).statusCode, 200);
        expect(
          (await weather.getCombinedWeatherForecast(41.5, 14.5)).isSuccess,
          isTrue,
        );
        final afterImage =
            await cache
                    .getFileStream(base.resolve('/after.png').toString())
                    .firstWhere((event) => event is FileInfo)
                as FileInfo;
        expect(await afterImage.file.readAsBytes(), png);
        FlutterError.onError!(
          FlutterErrorDetails(
            exception: StateError('synthetic-post-revocation'),
          ),
        );
        await Sentry.captureMessage('synthetic-post-revocation-explicit');
        await tester.tap(find.text('Tap'));
        await tester.pump();
        expect(taps, 1);
        await Sentry.close();
        await Future<void>.delayed(const Duration(seconds: 3));
        expect(
          envelopes.any((e) => e.contains('synthetic-post-revocation')),
          isFalse,
        );
        // A saved opt-in must still not initialize again in this OS process.
        expect((await consent(enable: true)).isSuccess, isTrue);
        expect(Sentry.isEnabled, isFalse);
        expect(starts, 1);
        if (crashProbe == 'after') {
          debugPrint('NATIVE_ACCEPTANCE invoking native crash after close');
          await SentryFlutter.nativeCrash();
          fail('native crash probe unexpectedly returned');
        }
        // Leave false for the final, independently launched disabled phase.
        expect((await consent(enable: false)).isSuccess, isTrue);
        debugPrint(
          'NATIVE_ACCEPTANCE replay envelopes: '
          '${envelopes.where((e) => e.contains('replay_video')).length}',
        );
      } else {
        expect(repository.crashReporting, isFalse);
        expect(
          (await appClient.get(base.resolve('/disabled'))).statusCode,
          200,
        );
      }
      debugPrint(
        'NATIVE_ACCEPTANCE phase=$phase pid=$pid '
        'platform=${Platform.operatingSystem} client=${appClient.runtimeType} '
        'starts=$starts envelopes=${envelopes.length}',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      if (phase == 'disabled') {
        store.close();
        await directory.delete(recursive: true);
      }
    } finally {
      await Sentry.close();
      FlutterError.onError = originalHandler;
    }
  }, timeout: const Timeout(Duration(minutes: 3)));
}
