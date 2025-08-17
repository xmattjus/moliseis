import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:moliseis/config/dependencies.dart';
import 'package:moliseis/config/env/env.dart';
import 'package:moliseis/data/services/objectbox.dart';
import 'package:moliseis/domain/models/settings/app_settings.dart';
import 'package:moliseis/routing/router.dart';
import 'package:moliseis/ui/core/themes/theme_data.dart';
import 'package:moliseis/ui/core/ui/window_size_provider.dart';
import 'package:moliseis/ui/settings/view_models/theme_view_model.dart';
import 'package:provider/provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_logging/sentry_logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The ObjectBox instance.
late final ObjectBox objectBox;

void main() async {
  // Ensures the disk can be accessed before continuing app start-up.
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: Env.supabaseProdUrl,
    anonKey: Env.supabaseProdApiKey,
  );

  objectBox = await ObjectBox.create();

  // Retrieves the app settings to check whether the user has given his consent
  // to report exceptions or not.
  final settings = objectBox.store.box<AppSettings>().get(settingsId);

  final reportExceptions = (settings?.crashReporting ?? false) && !kDebugMode;

  await _initializeSentry(enable: reportExceptions, app: const MoliseIsApp());
}

Future<void> _initializeSentry({
  required bool enable,
  required Widget app,
}) async {
  if (enable) {
    await SentryFlutter.init((options) {
      options.dsn = Env.sentryUrl;
      options.addIntegration(LoggingIntegration());
      // Set tracesSampleRate to 1.0 to capture 100% of transactions for
      // tracing.
      options.tracesSampleRate = 0.4;
      // The sampling rate for profiling is relative to tracesSampleRate
      // Setting to 1.0 will profile 100% of sampled transactions:
      options.profilesSampleRate = 1.0;
      // Session Replay setup.
      options.replay.sessionSampleRate = 0.4;
      options.replay.onErrorSampleRate = 1.0;
    }, appRunner: () => runApp(SentryWidget(child: app)));
  } else {
    runApp(app);
  }
}

class MoliseIsApp extends StatelessWidget {
  const MoliseIsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: providers,
      child: Consumer<ThemeViewModel>(
        builder: (_, viewModel, _) {
          return MaterialApp.router(
            routerConfig: appRouter,
            builder: (_, child) => AutoWindowSizeProvider(child: child!),
            title: 'Molise Is',
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale.fromSubtags(languageCode: 'en'),
              Locale.fromSubtags(languageCode: 'it'),
            ],
            theme: AppThemeData.light(),
            darkTheme: AppThemeData.dark(),
            themeMode: viewModel.themeMode,
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}
