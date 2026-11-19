// The SDK test mode and scope expose the actual reporting boundaries.
// ignore_for_file: invalid_use_of_internal_member

import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/utils/logging/logging.dart';
import 'package:moliseis/utils/sentry_logging_flag.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:talker_flutter/talker_flutter.dart';

import 'recording_sentry_transport.dart';

/// Exercises application logging up to the serialized SDK envelope.
final class ApplicationReportingHarness {
  final transport = RecordingSentryTransport();
  final talker = Talker(settings: TalkerSettings(useConsoleLogs: false));
  final _flag = SentryLoggingFlag(initialValue: true);

  late final logger = AppLogger(talker, sentryFlag: _flag);

  Future<void> start() async {
    await Sentry.init(
      (options) => options
        ..dsn = 'https://abc@example.test/1'
        ..automatedTestMode = true
        ..beforeSend = AppLogger.beforeSend
        ..sendDefaultPii = false
        ..enablePrintBreadcrumbs = false
        ..transport = transport
        ..addEventProcessor(transport),
    );
    addTearDown(Sentry.close);
  }

  Future<void> expectTerminal(
    String name,
    Object error,
    Map<String, Object?> data, {
    required bool captures,
    bool hasStack = true,
  }) async {
    await transport.settleCaptures();
    final local = talker.history
        .where((entry) => entry.message?.contains(name) ?? false)
        .single;
    expect(local.exception, same(error));
    expect(local.stackTrace, hasStack ? isNotNull : isNull);
    final breadcrumb = Sentry.currentHub.scope.breadcrumbs
        .where((crumb) => crumb.message == name)
        .single;
    expect(breadcrumb.data, data);
    expect(transport.events, hasLength(captures ? 1 : 0));
    expect(transport.envelopes, hasLength(captures ? 1 : 0));
    if (captures) {
      final event = await transport.serializedEvent(0);
      expect(
        transport.exceptionValues(event).single['type'],
        'UploadDiagnosticFailure',
      );
      final contexts = event['contexts'] as Map<String, dynamic>;
      expect(contexts['upload_diagnostic'], data);
      final crumbs = event['breadcrumbs'] as List<dynamic>;
      final crumb = crumbs.single as Map<String, dynamic>;
      expect(crumb['message'], name);
      expect(crumb['data'], data);
    }
  }
}
