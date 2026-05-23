import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/utils/logging/app_log_level.dart';
import 'package:moliseis/utils/logging/app_log_level_mapper.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:talker_flutter/talker_flutter.dart';

void main() {
  group('mapToTalkerLevel', () {
    test('maps debug to TalkerLogLevel.debug', () {
      expect(mapToTalkerLevel(AppLogLevel.debug), LogLevel.debug);
    });

    test('maps info to TalkerLogLevel.info', () {
      expect(mapToTalkerLevel(AppLogLevel.info), LogLevel.info);
    });

    test('maps warning to TalkerLogLevel.warning', () {
      expect(mapToTalkerLevel(AppLogLevel.warning), LogLevel.warning);
    });

    test('maps error to TalkerLogLevel.error', () {
      expect(mapToTalkerLevel(AppLogLevel.error), LogLevel.error);
    });

    test('maps critical to TalkerLogLevel.critical', () {
      expect(mapToTalkerLevel(AppLogLevel.critical), LogLevel.critical);
    });
  });

  group('mapToSentryLevel', () {
    test('maps debug to SentryLevel.debug', () {
      expect(mapToSentryLevel(AppLogLevel.debug), SentryLevel.debug);
    });

    test('maps info to SentryLevel.info', () {
      expect(mapToSentryLevel(AppLogLevel.info), SentryLevel.info);
    });

    test('maps warning to SentryLevel.warning', () {
      expect(mapToSentryLevel(AppLogLevel.warning), SentryLevel.warning);
    });

    test('maps error to SentryLevel.error', () {
      expect(mapToSentryLevel(AppLogLevel.error), SentryLevel.error);
    });

    test('maps critical to SentryLevel.fatal', () {
      expect(mapToSentryLevel(AppLogLevel.critical), SentryLevel.fatal);
    });
  });
}
