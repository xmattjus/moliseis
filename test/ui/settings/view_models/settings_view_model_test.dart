import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/domain/models/content_sort.dart';
import 'package:moliseis/domain/models/theme_brightness.dart';
import 'package:moliseis/domain/models/theme_type.dart';
import 'package:moliseis/domain/repositories/settings_repository.dart';
import 'package:moliseis/ui/settings/view_models/settings_view_model.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/sentry_logging_flag.dart';

void main() {
  group('SettingsViewModel crash reporting sync', () {
    test('updates SentryLoggingFlag on successful toggle', () async {
      final repository = _FakeSettingsRepository(initialCrashReporting: false);
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
      final repository = _FakeSettingsRepository(
        initialCrashReporting: true,
        setCrashReportingResult: Result.error(_TestException('write failed')),
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

final class _FakeSettingsRepository implements SettingsRepository {
  _FakeSettingsRepository({
    required bool initialCrashReporting,
    Result<void>? setCrashReportingResult,
  }) : _crashReporting = initialCrashReporting,
       _setCrashReportingResult =
           setCrashReportingResult ?? const Result.success(null);

  bool _crashReporting;
  final Result<void> _setCrashReportingResult;

  @override
  bool get crashReporting => _crashReporting;

  @override
  ContentSort get contentSort => ContentSort.byName;

  @override
  DateTime? get modifiedAt => null;

  @override
  ThemeBrightness get themeBrightness => ThemeBrightness.system;

  @override
  ThemeType get themeType => ThemeType.system;

  @override
  Future<Result<void>> initialize() async => const Result.success(null);

  @override
  Future<Result<void>> setCrashReporting(bool enable) async {
    if (_setCrashReportingResult is Success<void>) {
      _crashReporting = enable;
    }

    return _setCrashReportingResult;
  }

  @override
  Future<Result<void>> setContentSort(ContentSort sort) async {
    return const Result.success(null);
  }

  @override
  Future<Result<void>> setModifiedAt(DateTime dateTime) async {
    return const Result.success(null);
  }

  @override
  Future<Result<void>> setThemeBrightness(ThemeBrightness brightness) async {
    return const Result.success(null);
  }

  @override
  Future<Result<void>> setThemeType(ThemeType type) async {
    return const Result.success(null);
  }
}

final class _TestException implements Exception {
  _TestException(this.message);

  final String message;

  @override
  String toString() => message;
}
