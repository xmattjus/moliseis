import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/data/data-sources/app_settings.dart';
import 'package:moliseis/data/repositories/settings_repository_impl.dart';
import 'package:moliseis/domain/use_cases/set_crash_reporting_use_case.dart';
import 'package:moliseis/ui/settings/view_models/settings_view_model.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/result_command.dart';
import 'package:moliseis/utils/sentry_logging_flag.dart';

import '../../../support/command_test_support.dart';
import '../../../support/crash_reporting_support.dart';
import '../../../support/fake_repositories.dart';
import '../../../support/mock_logger.dart';
import '../../../support/ordinary_view_model_lifecycle_support.dart';
import '../../../support/settings_consent_support.dart';
import '../../../support/settings_local_data_source.dart';

void main() {
  group('post-dispose persisted consent', () {
    for (final initial in [true, false]) {
      testWidgets('F1.1/F1.2 persisted ${!initial} survives owner dispose', (
        tester,
      ) async {
        final gate = Completer<Result<void>>();
        var persisted = initial;
        final source =
            FakeSettingsLocalDataSource(
                loadResult: Result.success(
                  AppSettings(crashReporting: initial),
                ),
              )
              ..onSave = (settings) async {
                final result = await gate.future;
                if (result is Success<void>) {
                  persisted = settings.crashReporting;
                }
                return result;
              };
        final repository = SettingsRepositoryImpl(source);
        await repository.initialize();
        final flag = SentryLoggingFlag(initialValue: initial);
        final vm = SettingsViewModel(
          crashReporting: testCrashReporting(
            repository: repository,
            flag: flag,
          ),
        );
        var notifications = 0;
        vm.addListener(() => notifications++);
        final execution = vm.setCrashReporting.runAsync(!initial);
        await pumpCommandTurns(tester);
        expect(source.savedSettings, hasLength(1));
        expect(repository.crashReporting, initial);
        expect(flag.enabled, initial);
        final local = vm.crashReporting;
        final count = notifications;
        vm.dispose();
        await pumpPhysicalCommandDisposal(tester);
        const success = Result<void>.success(null);
        gate.complete(success);
        await pumpPhysicalCommandDisposal(tester);
        expect(await execution, isA<Success<CrashReportingUpdate>>());
        expect(repository.crashReporting, !initial);
        expect(persisted, !initial);
        expect(flag.enabled, initial && persisted);
        expect(vm.crashReporting, local);
        expect(notifications, count);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets(
      'F1.3 original domain failure cannot change persisted consent',
      (tester) async {
        final gate = Completer<Result<void>>();
        final source = FakeSettingsLocalDataSource(
          loadResult: Result.success(AppSettings()),
        )..onSave = (_) => gate.future;
        final repository = SettingsRepositoryImpl(source);
        await repository.initialize();
        final flag = SentryLoggingFlag(initialValue: true);
        final vm = SettingsViewModel(
          crashReporting: testCrashReporting(
            repository: repository,
            flag: flag,
          ),
        );
        var notifications = 0;
        vm.addListener(() => notifications++);
        final execution = vm.setCrashReporting.runAsync(false);
        await pumpCommandTurns(tester);
        vm.dispose();
        final failure = Result<void>.error(TestException('not persisted'));
        gate.complete(failure);
        await pumpPhysicalCommandDisposal(tester);
        expect(
          (await execution)!.fold((_) => null, (error) => error),
          same(failure.fold((_) => null, (error) => error)),
        );
        expect(repository.crashReporting, isTrue);
        expect(flag.enabled, isTrue);
        expect(vm.crashReporting, isFalse);
        expect(notifications, 1);
        expect(tester.takeException(), isNull);
      },
    );

    for (final aCommitsFirst in [true, false]) {
      testWidgets('F1.4 owner replacement: aCommitsFirst=$aCommitsFirst, '
          'delivery reversed', (tester) async {
        final aSave = Completer<Result<void>>();
        final bSave = Completer<Result<void>>();
        final firstDelivery = Completer<void>();
        final firstValue = !aCommitsFirst;
        var persisted = true;
        final commits = <bool>[];
        final deliveries = <bool>[];
        final source =
            FakeSettingsLocalDataSource(
                loadResult: Result.success(AppSettings()),
              )
              ..onSave = (settings) async {
                final result = await (settings.crashReporting
                    ? bSave.future
                    : aSave.future);
                if (result is Success<void>) {
                  persisted = settings.crashReporting;
                  commits.add(persisted);
                }
                return result;
              };
        final repository = DeferredSettingsRepository(source)
          ..beforeDelivery = ({required enable}) async {
            if (enable == firstValue) await firstDelivery.future;
            deliveries.add(enable);
          };
        await repository.initialize();
        final flag = SentryLoggingFlag(initialValue: true);
        final consent = testCrashReporting(repository: repository, flag: flag);
        final a = SettingsViewModel(crashReporting: consent);
        var aNotifications = 0;
        a.addListener(() => aNotifications++);
        final aResult = a.setCrashReporting.runAsync(false);
        await pumpCommandTurns(tester);
        a.dispose();
        final b = SettingsViewModel(crashReporting: consent);
        final bResult = b.setCrashReporting.runAsync(true);
        await pumpCommandTurns(tester);
        expect(source.savedSettings, hasLength(2));
        final first = aCommitsFirst ? aSave : bSave;
        final second = aCommitsFirst ? bSave : aSave;
        first.complete(const Result.success(null));
        await pumpCommandTurns(tester);
        expect(repository.crashReporting, firstValue);
        expect(deliveries, isEmpty);
        second.complete(const Result.success(null));
        await pumpCommandTurns(tester);
        expect(commits, [firstValue, !firstValue]);
        expect(repository.crashReporting, !firstValue);
        expect(flag.enabled, persisted);
        expect(deliveries, [!firstValue]);
        firstDelivery.complete();
        await pumpCommandTurns(tester);
        expect(await aResult, isA<Success<CrashReportingUpdate>>());
        expect(await bResult, isA<Success<CrashReportingUpdate>>());
        expect(deliveries, [!firstValue, firstValue]);
        expect(repository.crashReporting, persisted);
        expect(flag.enabled, persisted);
        expect(a.crashReporting, isFalse);
        expect(aNotifications, 1);
        b.dispose();
        await pumpPhysicalCommandDisposal(tester);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets(
      'F1.5 late runtime failure reports once without changing consent',
      (tester) async {
        final logger = MockLogger();
        addTearDown(installCommandTestReporting(logger));
        final gate = Completer<Result<void>>();
        final source = FakeSettingsLocalDataSource(
          loadResult: Result.success(AppSettings()),
        )..onSave = (_) => gate.future;
        final repository = SettingsRepositoryImpl(source);
        await repository.initialize();
        final flag = SentryLoggingFlag(initialValue: true);
        final vm = SettingsViewModel(
          crashReporting: testCrashReporting(
            repository: repository,
            flag: flag,
          ),
        );
        var notifications = 0;
        vm.addListener(() => notifications++);
        vm.setCrashReporting.run(false);
        await pumpCommandTurns(tester);
        vm.dispose();
        await pumpPhysicalCommandDisposal(tester);
        final original = StateError('late save failure');
        gate.completeError(original);
        await pumpPhysicalCommandDisposal(tester);
        expect(logger.calls, hasLength(1));
        expect(logger.calls.single.error, same(original));
        expect(repository.crashReporting, isTrue);
        expect(flag.enabled, isTrue);
        expect(vm.crashReporting, isFalse);
        expect(notifications, 1);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('SettingsViewModel crash reporting sync', () {
    test(
      'defers entry and preserves optimistic notify before repository write',
      () async {
        final repository = FakeSettingsRepository();
        final pending = Completer<Result<void>>();
        final events = <String>[];
        final vm = SettingsViewModel(
          crashReporting: testCrashReporting(
            repository: repository,
            flag: SentryLoggingFlag(initialValue: false),
          ),
        );
        addTearDown(vm.dispose);
        vm.addListener(() => events.add('notify:${vm.crashReporting}'));
        repository.onSetCrashReporting = (value) {
          events.add('write:$value');
          return pending.future;
        };
        final execution = vm.setCrashReporting.runAsync(true);
        expect(vm.crashReporting, isFalse);
        expect(events, isEmpty);
        await Future<void>.delayed(Duration.zero);
        expect(vm.crashReporting, isTrue);
        expect(events, ['notify:true', 'write:true']);
        pending.complete(const Result.success(null));
        await execution;
      },
    );
    test('single-flight rejects duplicates before entry '
        'and from optimistic notify', () async {
      final repository = FakeSettingsRepository();
      final pending = Completer<Result<void>>();
      var writes = 0;
      repository.onSetCrashReporting = (_) {
        writes++;
        return pending.future;
      };
      final flag = SentryLoggingFlag(initialValue: false);
      final vm = SettingsViewModel(
        crashReporting: testCrashReporting(repository: repository, flag: flag),
      );
      addTearDown(vm.dispose);
      vm.addListener(() => vm.setCrashReporting.run(false));
      final execution = vm.setCrashReporting.runAsync(true);
      vm.setCrashReporting.run(false);
      expect(vm.setCrashReporting.isRunningSync.value, isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(writes, 1);
      expect(vm.crashReporting, isTrue);
      expect(flag.enabled, isFalse);
      const result = Result<void>.success(null);
      pending.complete(result);
      expect(await execution, isA<Success<CrashReportingUpdate>>());
      expect(flag.enabled, isFalse);
    });

    test('saved opt-in leaves forwarding deferred until restart', () async {
      final repository = FakeSettingsRepository();
      final sentryLoggingFlag = SentryLoggingFlag(initialValue: false);
      final viewModel = SettingsViewModel(
        crashReporting: testCrashReporting(
          repository: repository,
          flag: sentryLoggingFlag,
        ),
      );

      addTearDown(viewModel.dispose);
      await viewModel.setCrashReporting.runAsync(true);

      expect(viewModel.crashReporting, isTrue);
      expect(sentryLoggingFlag.enabled, isFalse);
      expect(viewModel.setCrashReporting.results.value.completed, isTrue);
    });

    test('reverts value and flag when repository write fails', () async {
      final repository = FakeSettingsRepository(
        crashReporting: true,
        setCrashReportingResult: Result.error(TestException('write failed')),
      );
      final sentryLoggingFlag = SentryLoggingFlag(initialValue: true);
      final viewModel = SettingsViewModel(
        crashReporting: testCrashReporting(
          repository: repository,
          flag: sentryLoggingFlag,
        ),
      );

      addTearDown(viewModel.dispose);
      await viewModel.setCrashReporting.runAsync(false);

      expect(viewModel.crashReporting, isTrue);
      expect(sentryLoggingFlag.enabled, isTrue);
      expect(
        viewModel.setCrashReporting.results.value.domainError,
        isA<TestException>(),
      );
    });
  });
}
