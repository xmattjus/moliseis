import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/config/bootstrap.dart';
import 'package:moliseis/data/data-sources/app_settings.dart';
import 'package:moliseis/data/repositories/settings_repository_impl.dart';
import 'package:moliseis/utils/result.dart';

import '../support/fake_repositories.dart';
import '../support/settings_local_data_source.dart';

void main() {
  for (final consent in [true, false, null]) {
    test(
      'bootstrap resolves consent=$consent before telemetry or normal work',
      () async {
        final source = FakeSettingsLocalDataSource(
          loadResult: consent == null
              ? null
              : Result.success(AppSettings(crashReporting: consent)),
        );
        final repository = SettingsRepositoryImpl(source);
        final order = <String>[];
        await bootstrapApplication(
          createSettings: () async {
            order.add('local-store');
            return repository;
          },
          onLocalFailure: (_, _) => fail('unexpected local failure'),
          onSettingsInitialized: (result) {
            expect(result.isSuccess, isTrue);
            order.add('settings');
          },
          initializeTelemetry: (runner) async {
            order.add('telemetry');
            await runner();
          },
          runApplication: (settings, {required reportingEnabled}) async {
            expect(settings, same(repository));
            expect(reportingEnabled, consent ?? true);
            order.add('application');
          },
        );
        expect(order, [
          'local-store',
          'settings',
          if (consent ?? true) 'telemetry',
          'application',
        ]);
      },
    );
  }

  test(
    'unreadable settings preserve defaults but fail closed for telemetry',
    () async {
      final error = TestException('unreadable');
      final repository = SettingsRepositoryImpl(
        FakeSettingsLocalDataSource(loadResult: Result.error(error)),
      );
      var runs = 0;
      await bootstrapApplication(
        createSettings: () async => repository,
        onLocalFailure: (_, _) => fail('unexpected local failure'),
        onSettingsInitialized: (result) => expect(
          result,
          isA<Error<void>>().having(
            (value) => value.error,
            'original failure',
            same(error),
          ),
        ),
        initializeTelemetry: (_) async => fail('must not initialize telemetry'),
        runApplication: (settings, {required reportingEnabled}) async {
          runs++;
          expect(settings.crashReporting, isTrue);
          expect(reportingEnabled, isFalse);
        },
      );
      expect(runs, 1);
    },
  );

  test(
    'ObjectBox creation failure takes only the existing local-error branch',
    () async {
      final error = StateError('store cannot open');
      final failures = <Object>[];
      await bootstrapApplication(
        createSettings: () async => throw error,
        onLocalFailure: (failure, stack) {
          failures.add(failure);
          expect(stack, isNotNull);
        },
        onSettingsInitialized: (_) => fail('no settings were created'),
        initializeTelemetry: (_) async => fail('must not initialize telemetry'),
        runApplication: (_, {required reportingEnabled}) async =>
            fail('must not run normal startup'),
      );
      expect(failures, [same(error)]);
    },
  );

  test('saved enable activates only when a new bootstrap reads it', () async {
    final source = FakeSettingsLocalDataSource(
      loadResult: Result.success(AppSettings(crashReporting: false)),
    );
    var telemetryStarts = 0;
    final reportingStates = <bool>[];
    late SettingsRepositoryImpl first;
    await bootstrapApplication(
      createSettings: () async => first = SettingsRepositoryImpl(source),
      onLocalFailure: (_, _) => fail('unexpected local failure'),
      onSettingsInitialized: (_) {},
      initializeTelemetry: (runner) async {
        telemetryStarts++;
        await runner();
      },
      runApplication: (_, {required reportingEnabled}) async =>
          reportingStates.add(reportingEnabled),
    );
    expect(telemetryStarts, 0);
    await first.setCrashReporting(enable: true);
    expect(telemetryStarts, 0);
    await bootstrapApplication(
      createSettings: () async => SettingsRepositoryImpl(source),
      onLocalFailure: (_, _) => fail('unexpected local failure'),
      onSettingsInitialized: (_) {},
      initializeTelemetry: (runner) async {
        telemetryStarts++;
        await runner();
      },
      runApplication: (_, {required reportingEnabled}) async =>
          reportingStates.add(reportingEnabled),
    );
    expect(telemetryStarts, 1);
    expect(reportingStates, [false, true]);
  });

  test(
    'normal startup failures do not become local-store failures or reruns',
    () async {
      final error = StateError('normal startup failed');
      var runs = 0;
      await expectLater(
        bootstrapApplication(
          createSettings: () async =>
              FakeSettingsRepository(crashReporting: true),
          onLocalFailure: (_, _) =>
              fail('normal failure must not be reclassified'),
          onSettingsInitialized: (_) {},
          initializeTelemetry: (runner) async => await runner(),
          runApplication: (_, {required reportingEnabled}) async {
            runs++;
            throw error;
          },
        ),
        throwsA(same(error)),
      );
      expect(runs, 1);
    },
  );
}
