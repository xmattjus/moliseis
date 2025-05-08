/// Consolidates functions called during app startup.

part of 'main.dart';

Future<void> _initializeSentry(bool enable, Widget app) async {
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
      options.experimental.replay.sessionSampleRate = 0.4;
      options.experimental.replay.onErrorSampleRate = 1.0;
    }, appRunner: () => runApp(SentryWidget(child: app)));
  } else {
    runApp(app);
  }
}

Future<void> _initializeSystemChrome(Brightness brightness) async {
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Sets the navigation bar color
  var overlayStyle = const SystemUiOverlayStyle(
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
  );

  if (Platform.isAndroid) {
    // Android 8 does not support a transparent navigation bar.
    final info = await DeviceInfoPlugin().androidInfo;
    if (info.version.sdkInt <= 26) {
      overlayStyle =
          brightness == Brightness.light
              ? const SystemUiOverlayStyle(
                systemNavigationBarColor: Colors.white,
                systemNavigationBarDividerColor: Colors.white,
                systemNavigationBarIconBrightness: Brightness.dark,
              )
              : const SystemUiOverlayStyle(
                systemNavigationBarColor: Colors.black,
                systemNavigationBarDividerColor: Colors.black,
                systemNavigationBarIconBrightness: Brightness.light,
              );
    }
  }
  SystemChrome.setSystemUIOverlayStyle(overlayStyle);
}
