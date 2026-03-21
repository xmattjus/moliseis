import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/data/repositories/settings_repository_impl.dart';
import 'package:moliseis/data/sources/app_settings.dart';
import 'package:moliseis/data/sources/settings_local_data_source.dart';
import 'package:moliseis/domain/models/theme_type.dart';
import 'package:moliseis/utils/result.dart';

void main() {
  group('SettingsRepositoryImpl initialization contract', () {
    test('throws clear error when getter is used before initialize', () {
      final repository = SettingsRepositoryImpl(_FakeSettingsLocalDataSource());

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
      final repository = SettingsRepositoryImpl(_FakeSettingsLocalDataSource());

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
      final repository = SettingsRepositoryImpl(_FakeSettingsLocalDataSource());

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
          _FakeSettingsLocalDataSource(
            loadResult: Result.error(_TestException('load failed')),
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
        _FakeSettingsLocalDataSource(
          saveResult: Result.error(_TestException('save failed')),
        ),
      );

      await repository.initialize();

      final saveResult = await repository.setThemeType(ThemeType.app);

      expect(saveResult, isA<Error<void>>());
      expect(repository.themeType, ThemeType.system);
    });
  });
}

final class _FakeSettingsLocalDataSource implements ISettingsLocalDataSource {
  _FakeSettingsLocalDataSource({
    Result<AppSettings>? loadResult,
    Result<void>? saveResult,
  }) : _loadResult = loadResult ?? Result.success(AppSettings()),
       _saveResult = saveResult ?? const Result.success(null);

  final Result<AppSettings> _loadResult;
  final Result<void> _saveResult;

  @override
  Future<Result<AppSettings>> load() async => _loadResult;

  @override
  Future<Result<void>> save(AppSettings settings) async => _saveResult;
}

final class _TestException implements Exception {
  _TestException(this.message);

  final String message;

  @override
  String toString() => message;
}
