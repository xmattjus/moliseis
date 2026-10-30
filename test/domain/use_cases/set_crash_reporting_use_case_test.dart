import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/data/data-sources/app_settings.dart';
import 'package:moliseis/domain/use_cases/set_crash_reporting_use_case.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/sentry_logging_flag.dart';

import '../../support/fake_repositories.dart';
import '../../support/settings_consent_support.dart';
import '../../support/settings_local_data_source.dart';

void main() {
  late FakeSettingsRepository repository;
  late SentryLoggingFlag flag;
  late SetCrashReportingUseCase operation;
  late Future<void> Function() close;
  late int closes;

  setUp(() {
    repository = FakeSettingsRepository(crashReporting: true);
    flag = SentryLoggingFlag(initialValue: false);
    closes = 0;
    close = () async {};
    operation = SetCrashReportingUseCase(
      settingsRepository: repository,
      sentryLoggingFlag: flag,
      initiallyEnabled: true,
      closeSentry: () {
        closes++;
        return close();
      },
    );
  });

  testWidgets('persistence precedes forwarding revocation and physical close', (
    tester,
  ) async {
    final save = Completer<Result<void>>();
    final shutdown = Completer<void>();
    repository.onSetCrashReporting = (_) => save.future;
    close = () => shutdown.future;
    final result = operation(enable: false);
    await tester.pump();
    expect(flag.enabled, isTrue);
    expect(operation.state, CrashReportingState.active);
    expect(closes, 0);
    save.complete(const Result.success(null));
    await tester.pump();
    expect(repository.crashReporting, isFalse);
    expect(flag.enabled, isFalse);
    expect(operation.state, CrashReportingState.closing);
    expect(closes, 1);
    shutdown.complete();
    await tester.pump();
    expect((await result).getOrNull()?.outcome, CrashReportingOutcome.disabled);
    expect(operation.state, CrashReportingState.inactive);
    expect(operation.isCurrent((await result).getOrNull()!), isTrue);
    expect(
      (await operation(enable: false)).getOrNull()?.outcome,
      CrashReportingOutcome.disabled,
    );
    expect(closes, 1);
  });

  test('opt-in does not stop an already active process', () async {
    expect(
      (await operation(enable: true)).getOrNull()?.outcome,
      CrashReportingOutcome.enabledForNextStart,
    );
    expect(operation.state, CrashReportingState.active);
    expect(flag.enabled, isTrue);
    expect(closes, 0);
  });

  test(
    'inactive opt-in is saved without activating forwarding or SDK',
    () async {
      final inactive = SetCrashReportingUseCase(
        settingsRepository: repository,
        sentryLoggingFlag: flag,
        initiallyEnabled: false,
        closeSentry: () async {
          closes++;
        },
      );
      expect(
        (await inactive(enable: true)).getOrNull()?.outcome,
        CrashReportingOutcome.enabledForNextStart,
      );
      expect(flag.enabled, isFalse);
      expect(inactive.state, CrashReportingState.inactive);
      expect(
        (await inactive(enable: false)).getOrNull()?.outcome,
        CrashReportingOutcome.disabled,
      );
      expect(closes, 0);
    },
  );

  test(
    'failed persistence preserves committed and effective consent',
    () async {
      final error = TestException('not saved');
      repository.setCrashReportingResult = Result.error(error);
      final result = await operation(enable: false);
      expect(
        result,
        isA<Error<CrashReportingUpdate>>().having(
          (value) => value.error,
          'original error',
          same(error),
        ),
      );
      expect(repository.crashReporting, isTrue);
      expect(flag.enabled, isTrue);
      expect(operation.state, CrashReportingState.active);
      expect(closes, 0);
    },
  );

  test('raw persistence error remains raw and cannot revoke consent', () async {
    final error = StateError('unexpected persistence failure');
    repository.onSetCrashReporting = (_) => Future.error(error);
    await expectLater(operation(enable: false), throwsA(same(error)));
    expect(flag.enabled, isTrue);
    expect(repository.crashReporting, isTrue);
    expect(closes, 0);
  });

  test(
    'expected close failure retains saved opt-out and original close',
    () async {
      close = () async => throw TestException('close failed');
      expect(
        (await operation(enable: false)).getOrNull()?.outcome,
        CrashReportingOutcome.shutdownUnconfirmed,
      );
      expect(operation.state, CrashReportingState.unconfirmed);
      expect(repository.crashReporting, isFalse);
      expect(flag.enabled, isFalse);
      expect(
        (await operation(enable: false)).getOrNull()?.outcome,
        CrashReportingOutcome.shutdownUnconfirmed,
      );
      expect(closes, 1);
    },
  );

  test(
    'raw close error remains raw after persistence without rollback',
    () async {
      final error = StateError('unexpected close failure');
      close = () => Future.error(error);
      await expectLater(operation(enable: false), throwsA(same(error)));
      expect(repository.crashReporting, isFalse);
      expect(flag.enabled, isFalse);
      expect(operation.state, CrashReportingState.unconfirmed);
      expect(closes, 1);
    },
  );

  testWidgets(
    'concurrent opt-outs share original pending close and feedback authority',
    (tester) async {
      final shutdown = Completer<void>();
      close = () => shutdown.future;
      final first = operation(enable: false);
      await tester.pump();
      final second = operation(enable: false);
      await tester.pump();
      expect(closes, 1);
      expect(operation.state, CrashReportingState.closing);
      shutdown.complete();
      await tester.pump();
      expect(
        (await first).getOrNull()?.outcome,
        CrashReportingOutcome.superseded,
      );
      final current = (await second).getOrNull()!;
      expect(current.outcome, CrashReportingOutcome.disabled);
      expect(operation.isCurrent(current), isTrue);
    },
  );

  testWidgets('opt-in during valid close never reactivates this process', (
    tester,
  ) async {
    final shutdown = Completer<void>();
    close = () => shutdown.future;
    final disable = operation(enable: false);
    await tester.pump();
    final enable = (await operation(enable: true)).getOrNull()!;
    expect(enable.outcome, CrashReportingOutcome.enabledForNextStart);
    expect(repository.crashReporting, isTrue);
    expect(flag.enabled, isFalse);
    expect(operation.state, CrashReportingState.closing);
    shutdown.complete();
    await tester.pump();
    expect(
      (await disable).getOrNull()?.outcome,
      CrashReportingOutcome.superseded,
    );
    expect(operation.state, CrashReportingState.inactive);
    expect(flag.enabled, isFalse);
    expect(operation.isCurrent(enable), isTrue);
    expect(closes, 1);
  });

  testWidgets(
    'ten-second deadline retains physical close and consumes late success',
    (tester) async {
      final shutdown = Completer<void>();
      close = () => shutdown.future;
      final result = operation(enable: false);
      await tester.pump();
      await tester.pump(const Duration(seconds: 9));
      expect(operation.state, CrashReportingState.closing);
      await tester.pump(const Duration(seconds: 1));
      final update = (await result).getOrNull()!;
      expect(update.outcome, CrashReportingOutcome.shutdownUnconfirmed);
      expect(repository.crashReporting, isFalse);
      expect(flag.enabled, isFalse);
      expect(operation.state, CrashReportingState.unconfirmed);
      expect(
        (await operation(enable: false)).getOrNull()?.outcome,
        CrashReportingOutcome.shutdownUnconfirmed,
      );
      expect(closes, 1);
      shutdown.complete();
      await tester.pump();
      expect(operation.state, CrashReportingState.inactive);
      expect(update.outcome, CrashReportingOutcome.shutdownUnconfirmed);
      expect(operation.isCurrent(update), isFalse);
      expect(flag.enabled, isFalse);
    },
  );

  testWidgets(
    'late expected close failure is observed without an unhandled error',
    (tester) async {
      final shutdown = Completer<void>();
      close = () => shutdown.future;
      final result = operation(enable: false);
      await tester.pump();
      await tester.pump(const Duration(seconds: 10));
      expect(
        (await result).getOrNull()?.outcome,
        CrashReportingOutcome.shutdownUnconfirmed,
      );
      shutdown.completeError(TestException('late close failure'));
      await tester.pump();
      expect(operation.state, CrashReportingState.unconfirmed);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'late raw physical failure reaches its original error zone once',
    (tester) async {
      late Completer<void> shutdown;
      final errors = <Object>[];
      close = () => shutdown.future;
      late Future<Result<CrashReportingUpdate>> result;
      runZonedGuarded(
        () {
          shutdown = Completer<void>();
          result = operation(enable: false);
        },
        (error, _) {
          errors.add(error);
        },
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 10));
      expect(
        (await result).getOrNull()?.outcome,
        CrashReportingOutcome.shutdownUnconfirmed,
      );
      final error = StateError('late raw physical failure');
      shutdown.completeError(error);
      await tester.pump();
      expect(errors, [same(error)]);
      expect(operation.state, CrashReportingState.unconfirmed);
    },
  );

  for (final disableCommitsFirst in [true, false]) {
    testWidgets('reversed result delivery retains commit order: '
        'disableFirst=$disableCommitsFirst', (tester) async {
      final disableSave = Completer<Result<void>>();
      final enableSave = Completer<Result<void>>();
      final firstDelivery = Completer<void>();
      final firstValue = !disableCommitsFirst;
      final source =
          FakeSettingsLocalDataSource(loadResult: Result.success(AppSettings()))
            ..onSave = (settings) => settings.crashReporting
                ? enableSave.future
                : disableSave.future;
      final deferred = DeferredSettingsRepository(source)
        ..beforeDelivery = ({required enable}) async {
          if (enable == firstValue) await firstDelivery.future;
        };
      await deferred.initialize();
      final coordinated = SetCrashReportingUseCase(
        settingsRepository: deferred,
        sentryLoggingFlag: flag,
        initiallyEnabled: true,
        closeSentry: () async {
          closes++;
        },
      );
      final disable = coordinated(enable: false);
      final enable = coordinated(enable: true);
      final first = disableCommitsFirst ? disableSave : enableSave;
      final second = disableCommitsFirst ? enableSave : disableSave;
      first.complete(const Result.success(null));
      await tester.pump();
      expect(deferred.crashReporting, firstValue);
      expect(closes, 0);
      second.complete(const Result.success(null));
      await tester.pump();
      expect(deferred.crashReporting, !firstValue);
      expect(closes, disableCommitsFirst ? 0 : 1);
      firstDelivery.complete();
      await tester.pump();
      final old = (await (disableCommitsFirst ? disable : enable)).getOrNull()!;
      expect(old.outcome, CrashReportingOutcome.superseded);
      expect(closes, disableCommitsFirst ? 0 : 1);
      expect(flag.enabled, disableCommitsFirst);
    });
  }
}
