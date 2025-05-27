import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:moliseis/config/dependencies.dart';
import 'package:moliseis/config/env/env.dart';
import 'package:moliseis/data/services/objectbox.dart';
import 'package:moliseis/domain/models/settings/app_settings.dart';
import 'package:moliseis/routing/router.dart';
import 'package:moliseis/ui/core/themes/theme_data.dart';
import 'package:moliseis/ui/settings/view_models/theme_view_model.dart';
import 'package:provider/provider.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_logging/sentry_logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part '_main.dart';

late final Logger log;

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

  log = Logger('Molise Is');

  // Retrieves the app settings to check whether the user has given his consent
  // to report exceptions or not.
  final settings = objectBox.store.box<AppSettings>().get(settingsId);

  final reportExceptions = (settings?.crashReporting ?? false) && !kDebugMode;

  await _initializeSentry(reportExceptions, const MoliseIsApp());
}

class MoliseIsApp extends StatelessWidget {
  const MoliseIsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: providers,
      child: Consumer<ThemeViewModel>(
        builder: (_, controller, _) {
          _initializeSystemChrome(controller.brightness);

          return MaterialApp.router(
            routerConfig: appRouter,
            builder: (context, child) {
              return ResponsiveBreakpoints.builder(
                breakpoints: <Breakpoint>[
                  const Breakpoint(start: 0, end: 450, name: MOBILE),
                  const Breakpoint(start: 451, end: 800, name: TABLET),
                  const Breakpoint(
                    start: 801,
                    end: double.infinity,
                    name: DESKTOP,
                  ),
                ],
                useShortestSide: true,
                child: child!,
              );
            },
            title: 'Molise Is',
            theme: AppThemeData.light(),
            darkTheme: AppThemeData.dark(),
            themeMode: controller.themeMode,
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}
