import 'package:flutter/widgets.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/config/dependencies.dart';
import 'package:moliseis/config/service_locator.dart';
import 'package:moliseis/domain/models/content_sort.dart';
import 'package:moliseis/domain/models/theme_brightness.dart';
import 'package:moliseis/domain/models/theme_type.dart';
import 'package:moliseis/domain/repositories/settings_repository.dart';
import 'package:moliseis/ui/settings/view_models/theme_view_model.dart';
import 'package:moliseis/utils/result.dart';
import 'package:provider/provider.dart';

void main() {
  tearDown(() async {
    await sl.reset();
  });

  testWidgets(
    'providers use the pre-initialized SettingsRepository singleton',
    (tester) async {
      final settingsRepository = _FakeSettingsRepository();
      await settingsRepository.initialize();

      sl.registerSingleton<SettingsRepository>(settingsRepository);
      sl.registerSingleton<CacheManager>(CacheManager(Config('test-cache')));

      final app = Directionality(
        textDirection: TextDirection.ltr,
        child: MultiProvider(
          providers: providers,
          child: Builder(
            builder: (context) {
              final injectedRepository = context.read<SettingsRepository>();
              final themeViewModel = context.read<ThemeViewModel>();

              expect(identical(injectedRepository, settingsRepository), isTrue);
              expect(themeViewModel.themeType, ThemeType.system);

              return const SizedBox.shrink();
            },
          ),
        ),
      );

      await tester.pumpWidget(app);
    },
  );
}

final class _FakeSettingsRepository implements SettingsRepository {
  AppSettingsSnapshot? _snapshot;

  AppSettingsSnapshot get _initializedSnapshot {
    final snapshot = _snapshot;

    if (snapshot == null) {
      throw StateError(
        'SettingsRepositoryImpl has not been initialized. '
        'Call initialize() and await completion before accessing app settings.',
      );
    }

    return snapshot;
  }

  @override
  bool get crashReporting => _initializedSnapshot.crashReporting;

  @override
  ContentSort get contentSort => _initializedSnapshot.contentSort;

  @override
  DateTime? get modifiedAt => _initializedSnapshot.modifiedAt;

  @override
  ThemeBrightness get themeBrightness => _initializedSnapshot.themeBrightness;

  @override
  ThemeType get themeType => _initializedSnapshot.themeType;

  @override
  Future<Result<void>> initialize() async {
    _snapshot = const AppSettingsSnapshot();
    return const Result.success(null);
  }

  @override
  Future<Result<void>> setContentSort(ContentSort sort) async {
    _snapshot = _initializedSnapshot.copyWith(contentSort: sort);
    return const Result.success(null);
  }

  @override
  Future<Result<void>> setCrashReporting(bool enable) async {
    _snapshot = _initializedSnapshot.copyWith(crashReporting: enable);
    return const Result.success(null);
  }

  @override
  Future<Result<void>> setModifiedAt(DateTime dateTime) async {
    _snapshot = _initializedSnapshot.copyWith(modifiedAt: dateTime);
    return const Result.success(null);
  }

  @override
  Future<Result<void>> setThemeBrightness(ThemeBrightness brightness) async {
    _snapshot = _initializedSnapshot.copyWith(themeBrightness: brightness);
    return const Result.success(null);
  }

  @override
  Future<Result<void>> setThemeType(ThemeType type) async {
    _snapshot = _initializedSnapshot.copyWith(themeType: type);
    return const Result.success(null);
  }
}

final class AppSettingsSnapshot {
  const AppSettingsSnapshot({
    this.themeType = ThemeType.system,
    this.themeBrightness = ThemeBrightness.system,
    this.contentSort = ContentSort.byName,
    this.modifiedAt,
    this.crashReporting = true,
  });

  final ThemeType themeType;
  final ThemeBrightness themeBrightness;
  final ContentSort contentSort;
  final DateTime? modifiedAt;
  final bool crashReporting;

  AppSettingsSnapshot copyWith({
    ThemeType? themeType,
    ThemeBrightness? themeBrightness,
    ContentSort? contentSort,
    DateTime? modifiedAt,
    bool? crashReporting,
  }) {
    return AppSettingsSnapshot(
      themeType: themeType ?? this.themeType,
      themeBrightness: themeBrightness ?? this.themeBrightness,
      contentSort: contentSort ?? this.contentSort,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      crashReporting: crashReporting ?? this.crashReporting,
    );
  }
}
