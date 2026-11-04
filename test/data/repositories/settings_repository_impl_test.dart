import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/data/data-sources/app_settings.dart';
import 'package:moliseis/data/data-sources/settings_local_data_source.dart';
import 'package:moliseis/data/repositories/settings_repository_impl.dart';
import 'package:moliseis/domain/models/content_sort.dart';
import 'package:moliseis/domain/models/theme_brightness.dart';
import 'package:moliseis/domain/models/theme_type.dart';
import 'package:moliseis/utils/logging/logging.dart';
import 'package:moliseis/utils/result.dart';

import '../../support/fake_repositories.dart' show TestException;
import '../../support/mock_logger.dart';
import '../../support/objectbox_test_store.dart';
import '../../support/settings_local_data_source.dart';
import '../../support/sync_integration_test_support.dart';

void main() {
  group('SettingsRepositoryImpl overlapping independent settings', () {
    test('a delayed theme save cannot overwrite a confirmed opt-out', () async {
      final themeWrite = Completer<void>();
      final source = FakeSettingsLocalDataSource()
        ..onSave = (settings) async {
          if (settings.type == ThemeType.app) await themeWrite.future;
          return const Result.success(null);
        };
      final repository = SettingsRepositoryImpl(source);
      await repository.initialize();

      final theme = repository.setThemeType(ThemeType.app);
      final consent = await repository.setCrashReporting(enable: false);
      expect(consent, isA<Success<void>>());
      expect(repository.crashReporting, isFalse);
      themeWrite.complete();
      expect(await theme, isA<Success<void>>());

      expect(
        [
          repository.crashReporting,
          (await source.load()).getOrNull()!.crashReporting,
        ],
        [false, false],
      );
      expect(repository.themeType, ThemeType.app);
    });

    test('failed unrelated write preserves confirmed opt-out', () async {
      final themeWrite = Completer<Result<void>>();
      final source = FakeSettingsLocalDataSource()
        ..onSave = (settings) => settings.type == ThemeType.app
            ? themeWrite.future
            : Future.value(const Result.success(null));
      final repository = SettingsRepositoryImpl(source);
      await repository.initialize();
      final theme = repository.setThemeType(ThemeType.app);
      expect(
        await repository.setCrashReporting(enable: false),
        isA<Success<void>>(),
      );
      themeWrite.complete(Result.error(TestException('write failed')));
      expect(await theme, isA<Error<void>>());
      expect(repository.crashReporting, isFalse);
      expect(repository.themeType, ThemeType.system);
      expect((await source.load()).getOrNull()!.crashReporting, isFalse);
    });

    test('real ObjectBox same-turn writes preserve opt-out', () async {
      final environment = await TestObjectBoxEnvironment.create();
      addTearDown(environment.dispose);
      final source = SettingsLocalDataSource(environment.store);
      final repository = SettingsRepositoryImpl(source);
      await repository.initialize();

      final consent = repository.setCrashReporting(enable: false);
      final theme = repository.setThemeType(ThemeType.app);
      expect(await consent, isA<Success<void>>());
      expect(await theme, isA<Success<void>>());
      final reloaded = SettingsRepositoryImpl(source);
      await reloaded.initialize();

      expect(
        [repository.crashReporting, reloaded.crashReporting],
        [false, false],
      );
      expect(reloaded.themeType, ThemeType.app);
    });
  });

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

  for (final operation in ['sync', 'consent', 'sort', 'brightness', 'theme']) {
    test(
      'real update failure and retry retain $operation ownership and cache',
      () async {
        final env = await TestObjectBoxEnvironment.create();
        addTearDown(env.dispose);
        final logger = MockLogger();
        final source = SettingsLocalDataSource(env.store, logger: logger);
        final previous = DateTime.utc(2026, 10);
        final next = DateTime.utc(2026, 10, 2);
        final initial = AppSettings(
          lastSyncedAt: previous,
          contentSyncCursorAt: previous,
        );
        await source.save(initial);
        final failures = FailNextSettingsSave(source)..failNextSave = true;
        final repository = SettingsRepositoryImpl(failures);
        await repository.initialize();
        final write = switch (operation) {
          'sync' => () => repository.setSyncState(
            lastSyncedAt: next,
            contentSyncCursorAt: next,
          ),
          'consent' => () => repository.setCrashReporting(enable: false),
          'sort' => () => repository.setContentSort(ContentSort.byDate),
          'brightness' => () => repository.setThemeBrightness(
            ThemeBrightness.dark,
          ),
          _ => () => repository.setThemeType(ThemeType.app),
        };
        final result = await write();
        expect((result as Error<void>).error, same(failures.failure));
        final causes = logger.eventsOfType<SyncFailure>();
        expect(causes, hasLength(operation == 'sync' ? 1 : 0));
        if (operation == 'sync') {
          expect(causes.single.owner, SyncFailureOwner.settings);
          final call = logger.firstCallOfType<SyncFailure>()!;
          expect(call.error, same(failures.failure));
          expect(call.stackTrace, same(failures.failureStack));
        }
        final storedBeforeRetry = (await source.load()).getOrNull()!;
        expect(
          [
            repository.lastSyncedAt?.toUtc(),
            repository.contentSyncCursorAt?.toUtc(),
            repository.crashReporting,
            repository.contentSort,
            repository.themeBrightness,
            repository.themeType,
          ],
          [
            previous,
            previous,
            true,
            ContentSort.byName,
            ThemeBrightness.system,
            ThemeType.system,
          ],
        );
        expect(
          [
            storedBeforeRetry.lastSyncedAt?.toUtc(),
            storedBeforeRetry.contentSyncCursorAt?.toUtc(),
            storedBeforeRetry.crashReporting,
            storedBeforeRetry.contentSort,
            storedBeforeRetry.brightness,
            storedBeforeRetry.type,
          ],
          [
            previous,
            previous,
            true,
            ContentSort.byName,
            ThemeBrightness.system,
            ThemeType.system,
          ],
        );
        logger.reset();
        expect(await write(), isA<Success<void>>());
        expect(logger.eventsOfType<SyncFailure>(), isEmpty);
        final expected = switch (operation) {
          'sync' => initial.copyWith(
            lastSyncedAt: next,
            contentSyncCursorAt: next,
          ),
          'consent' => initial.copyWith(crashReporting: false),
          'sort' => initial.copyWith(contentSort: ContentSort.byDate),
          'brightness' => initial.copyWith(brightness: ThemeBrightness.dark),
          _ => initial.copyWith(type: ThemeType.app),
        };
        final expectedValues = <Object?>[
          expected.lastSyncedAt,
          expected.contentSyncCursorAt,
          expected.crashReporting,
          expected.contentSort,
          expected.brightness,
          expected.type,
        ];
        final stored = (await source.load()).getOrNull()!;
        expect([
          repository.lastSyncedAt?.toUtc(),
          repository.contentSyncCursorAt?.toUtc(),
          repository.crashReporting,
          repository.contentSort,
          repository.themeBrightness,
          repository.themeType,
        ], expectedValues);
        expect([
          stored.lastSyncedAt?.toUtc(),
          stored.contentSyncCursorAt?.toUtc(),
          stored.crashReporting,
          stored.contentSort,
          stored.brightness,
          stored.type,
        ], expectedValues);
      },
    );
  }

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
