// Explicit package setup and SDK transport assertions.
// ignore_for_file: invalid_use_of_internal_member, cascade_invocations
import 'dart:io';

import 'package:flutter/material.dart' as legacy;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/utils/logging/logging.dart';
import 'package:moliseis/utils/sentry_logging_flag.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:talker_flutter/src/controller/talker_view_controller.dart';
import 'package:talker_flutter/talker_flutter.dart';

import '../../../support/recording_sentry_transport.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final reporting in [false, true]) {
    testWidgets('isolated Talker viewer copy control, consent=$reporting', (
      tester,
    ) async {
      final directory = Directory.systemTemp.createTempSync('talker_export_');
      final clipboard = <String>[];
      final exports = <String>[];
      final messenger = tester.binding.defaultBinaryMessenger;
      const platform = SystemChannels.platform;
      const paths = MethodChannel('plugins.flutter.io/path_provider');
      const share = MethodChannel('dev.fluttercommunity.plus/share');
      messenger.setMockMethodCallHandler(platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard.add((call.arguments as Map)['text'] as String);
        }
        return null;
      });
      messenger.setMockMethodCallHandler(paths, (call) async => directory.path);
      messenger.setMockMethodCallHandler(share, (call) async {
        expect(call.method, 'share');
        final files = ((call.arguments as Map)['paths'] as List).cast<String>();
        for (final path in files) {
          exports.add(File(path).readAsStringSync());
        }
        return 'dev.fluttercommunity.plus/share/dismissed';
      });
      addTearDown(() async {
        messenger.setMockMethodCallHandler(platform, null);
        messenger.setMockMethodCallHandler(paths, null);
        messenger.setMockMethodCallHandler(share, null);
        await Sentry.close();
        directory.deleteSync(recursive: true);
      });
      final transport = RecordingSentryTransport();
      if (reporting) {
        await tester.runAsync(
          () => Sentry.init((options) {
            options
              ..dsn = 'https://abc@example.test/1'
              ..automatedTestMode = true
              ..enablePrintBreadcrumbs = false
              ..beforeSend = AppLogger.beforeSend
              ..transport = transport
              ..addEventProcessor(transport);
          }),
        );
      }
      final talker = Talker(settings: TalkerSettings(useConsoleLogs: false));
      final error = StateError('PRIVATE_LOCAL_VIEWER_CANARY');
      final stack = StackTrace.fromString('PRIVATE_LOCAL_STACK_CANARY');
      AppLogger(
        talker,
        sentryFlag: SentryLoggingFlag(initialValue: reporting),
      ).log(
        const RouteErrorScreenShown(uri: '/private'),
        error: error,
        stackTrace: stack,
      );
      if (reporting) await tester.runAsync(transport.settleCaptures);
      expect(talker.history.last.exception, same(error));
      expect(talker.history.last.stackTrace, same(stack));
      await tester.pumpWidget(
        legacy.MaterialApp(
          home: TalkerScreen(
            talker: talker,
            // Avoid the pinned package’s decorated-ListTile debug warning;
            // production material_ui overlays remain an open acceptance gap.
            theme: const TalkerScreenTheme(backgroundColor: Colors.transparent),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('PRIVATE_LOCAL_VIEWER_CANARY'), findsWidgets);
      expect(exports, isEmpty);
      expect(clipboard, isEmpty);

      await tester.tap(find.byIcon(Icons.menu_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Copy all logs'));
      await tester.pumpAndSettle();
      expect(clipboard.single, contains('PRIVATE_LOCAL_VIEWER_CANARY'));
      expect(clipboard.single, contains('PRIVATE_LOCAL_STACK_CANARY'));
      expect(exports, isEmpty);

      expect(talker.history.last.exception, same(error));
      expect(talker.history.last.stackTrace, same(stack));
      expect(transport.envelopes, hasLength(reporting ? 1 : 0));
      if (reporting) {
        final envelope = await tester.runAsync(
          () => transport.serializedEnvelope(0),
        );
        expect(envelope, isNot(contains('PRIVATE_LOCAL_VIEWER_CANARY')));
        expect(envelope, isNot(contains('PRIVATE_LOCAL_STACK_CANARY')));
      }
    });
    test('installed Talker export pipeline, consent=$reporting', () async {
      final directory = Directory.systemTemp.createTempSync('talker_export_');
      final exports = <String>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const paths = MethodChannel('plugins.flutter.io/path_provider');
      const share = MethodChannel('dev.fluttercommunity.plus/share');
      messenger.setMockMethodCallHandler(paths, (_) async => directory.path);
      messenger.setMockMethodCallHandler(share, (call) async {
        expect(call.method, 'share');
        for (final path
            in ((call.arguments as Map)['paths'] as List).cast<String>()) {
          exports.add(File(path).readAsStringSync());
        }
        return 'dev.fluttercommunity.plus/share/dismissed';
      });
      addTearDown(() async {
        messenger.setMockMethodCallHandler(paths, null);
        messenger.setMockMethodCallHandler(share, null);
        await Sentry.close();
        directory.deleteSync(recursive: true);
      });
      final transport = RecordingSentryTransport();
      if (reporting) {
        await Sentry.init(
          (options) => options
            ..dsn = 'https://abc@example.test/1'
            ..automatedTestMode = true
            ..beforeSend = AppLogger.beforeSend
            ..transport = transport
            ..addEventProcessor(transport),
        );
      }
      final talker = Talker(settings: TalkerSettings(useConsoleLogs: false));
      final error = StateError('PRIVATE_LOCAL_EXPORT_CANARY');
      final stack = StackTrace.fromString('PRIVATE_LOCAL_EXPORT_STACK');
      AppLogger(
        talker,
        sentryFlag: SentryLoggingFlag(initialValue: reporting),
      ).log(
        const RouteErrorScreenShown(uri: '/private'),
        error: error,
        stackTrace: stack,
      );
      await transport.settleCaptures();
      expect(exports, isEmpty);
      final controller = TalkerViewController(talker: talker);
      addTearDown(controller.dispose);
      // The actual installed export method writes a real temporary file; only
      // platform sharing is mocked. This is not production overlay acceptance.
      await controller
          .downloadLogsFile(talker.history.text())
          .timeout(const Duration(seconds: 5));
      expect(exports.single, contains('PRIVATE_LOCAL_EXPORT_CANARY'));
      expect(exports.single, contains('PRIVATE_LOCAL_EXPORT_STACK'));
      expect(talker.history.last.exception, same(error));
      expect(talker.history.last.stackTrace, same(stack));
      expect(transport.envelopes, hasLength(reporting ? 1 : 0));
      if (reporting) {
        expect(
          await transport.serializedEnvelope(0),
          isNot(contains('PRIVATE_LOCAL_EXPORT')),
        );
      }
    });
  }
}
