import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/ui/settings/view_models/settings_view_model.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/sentry_logging_flag.dart';

import '../../../support/fake_repositories.dart';

void main() {
  group('SettingsViewModel crash reporting sync', () {
    test('updates SentryLoggingFlag on successful toggle', () async {
      final repository = FakeSettingsRepository();
      final sentryLoggingFlag = SentryLoggingFlag(initialValue: false);
      final viewModel = SettingsViewModel(
        settingsRepository: repository,
        sentryLoggingFlag: sentryLoggingFlag,
      );

      await viewModel.setCrashReporting.execute(true);

      expect(viewModel.crashReporting, isTrue);
      expect(sentryLoggingFlag.enabled, isTrue);
      expect(viewModel.setCrashReporting.result, isA<Success<void>>());
    });

    test('reverts value and flag when repository write fails', () async {
      final repository = FakeSettingsRepository(
        crashReporting: true,
        setCrashReportingResult: Result.error(TestException('write failed')),
      );
      final sentryLoggingFlag = SentryLoggingFlag(initialValue: true);
      final viewModel = SettingsViewModel(
        settingsRepository: repository,
        sentryLoggingFlag: sentryLoggingFlag,
      );

      await viewModel.setCrashReporting.execute(false);

      expect(viewModel.crashReporting, isTrue);
      expect(sentryLoggingFlag.enabled, isTrue);
      expect(viewModel.setCrashReporting.result, isA<Error<void>>());
    });
  });
}
