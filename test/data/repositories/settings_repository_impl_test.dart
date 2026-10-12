import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/data/data-sources/app_settings.dart';
import 'package:moliseis/data/repositories/settings_repository_impl.dart';
import 'package:moliseis/domain/models/content_sort.dart';
import 'package:moliseis/domain/models/theme_brightness.dart';
import 'package:moliseis/domain/models/theme_type.dart';
import 'package:moliseis/utils/result.dart';

import '../../support/fake_repositories.dart' show TestException;
import '../../support/settings_local_data_source.dart';

void main() {
  group('SettingsRepositoryImpl sync state', () {
    test('persists both dates once and retains unrelated settings', () async {
      final source = FakeSettingsLocalDataSource(
        loadResult: Result.success(
          AppSettings(
            type: ThemeType.app,
            brightness: ThemeBrightness.dark,
            contentSort: ContentSort.byDate,
            crashReporting: false,
          ),
        ),
      );
      final repository = SettingsRepositoryImpl(source);
      await repository.initialize();
      final completion = DateTime.utc(2026, 10, 12, 12);
      final cursor = DateTime.utc(2026, 10, 12, 11);
      final result = await repository.setSyncState(
        lastSyncedAt: completion,
        contentSyncCursorAt: cursor,
      );
      expect(result, isA<Success<void>>());
      expect(source.savedSettings, hasLength(1));
      final saved = source.savedSettings.single;
      expect(saved.lastSyncedAt, completion);
      expect(saved.contentSyncCursorAt, cursor);
      expect(saved.type, ThemeType.app);
      expect(saved.brightness, ThemeBrightness.dark);
      expect(saved.contentSort, ContentSort.byDate);
      expect(saved.crashReporting, isFalse);
      expect(repository.lastSyncedAt, completion);
      expect(repository.contentSyncCursorAt, cursor);
      await repository.setThemeType(ThemeType.system);
      expect(source.savedSettings.last.contentSyncCursorAt, cursor);
      expect(source.savedSettings.last.lastSyncedAt, completion);
    });

    test('failed sync save retains both authoritative cached dates', () async {
      final completion = DateTime.utc(2026, 10, 9, 12);
      final cursor = DateTime.utc(2026, 10, 9, 11);
      final source = FakeSettingsLocalDataSource(
        loadResult: Result.success(
          AppSettings(lastSyncedAt: completion, contentSyncCursorAt: cursor),
        ),
        saveResult: Result.error(TestException('save failed')),
      );
      final repository = SettingsRepositoryImpl(source);
      await repository.initialize();
      final result = await repository.setSyncState(
        lastSyncedAt: DateTime.utc(2026, 10, 12, 12),
        contentSyncCursorAt: DateTime.utc(2026, 10, 12, 11),
      );
      expect(result, isA<Error<void>>());
      expect(source.savedSettings, hasLength(1));
      expect(repository.lastSyncedAt, completion);
      expect(repository.contentSyncCursorAt, cursor);
    });
  });

  group('SettingsRepositoryImpl initialization contract', () {
    test('throws clear error when getter is used before initialize', () {
      final repository = SettingsRepositoryImpl(FakeSettingsLocalDataSource());

      expect(
        () => repository.themeType,
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('Call initialize() and await completion'),
          ),
        ),
      );
    });

    test('throws clear error when mutator is used before initialize', () async {
      final repository = SettingsRepositoryImpl(FakeSettingsLocalDataSource());

      await expectLater(
        () => repository.setThemeType(ThemeType.app),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('Call initialize() and await completion'),
          ),
        ),
      );
    });

    test('initialize success unlocks reads and writes', () async {
      final repository = SettingsRepositoryImpl(FakeSettingsLocalDataSource());

      final initializeResult = await repository.initialize();
      final saveResult = await repository.setThemeType(ThemeType.app);

      expect(initializeResult, isA<Success<void>>());
      expect(saveResult, isA<Success<void>>());
      expect(repository.themeType, ThemeType.app);
    });

    test(
      'initialize failure keeps fallback settings and returns error',
      () async {
        final repository = SettingsRepositoryImpl(
          FakeSettingsLocalDataSource(
            loadResult: Result.error(TestException('load failed')),
          ),
        );

        final initializeResult = await repository.initialize();

        expect(initializeResult, isA<Error<void>>());
        expect(repository.themeType, ThemeType.system);
        expect(repository.crashReporting, isTrue);
      },
    );

    test('save error does not mutate cached state', () async {
      final repository = SettingsRepositoryImpl(
        FakeSettingsLocalDataSource(
          saveResult: Result.error(TestException('save failed')),
        ),
      );

      await repository.initialize();

      final saveResult = await repository.setThemeType(ThemeType.app);

      expect(saveResult, isA<Error<void>>());
      expect(repository.themeType, ThemeType.system);
    });
  });
}
