import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import '../../support/sdk_boundary_source.dart';

void main() {
  test('production SDK use stays within approved boundaries', () {
    final violations = findSdkBoundaryViolations(
      readProductionDartSources(Directory('lib')),
    );
    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('source fixtures reject aliased Sentry and direct Talker bypasses', () {
    final violations = findSdkBoundaryViolations({
      'lib/data/repositories/repository.dart': '''
        import 'package:sentry_flutter/sentry_flutter.dart' as telemetry;
        void report(Object error) => telemetry.Sentry.captureException(error);
      ''',
      'lib/data/repositories/hub_adapter.dart': '''
        import 'package:sentry/sentry.dart';
        void report(Object error) => HubAdapter().captureException(error);
      ''',
      'lib/ui/example.dart': '''
        import 'package:sentry/sentry.dart' as monitoring;
        void addContext() => monitoring.Sentry.addBreadcrumb(Breadcrumb());
        void mutateScope() => monitoring.Sentry.configureScope((scope) {});
        void trace() => monitoring.Sentry.startSpan('operation', (span) async {});
        void log() => monitoring.Sentry.logger.error('message');
        void captureEvent() => monitoring.Sentry.captureEvent(SentryEvent());
        void mutateHub() => monitoring . Sentry . currentHub;
        void bindClient() => monitoring.Sentry.bindClient(client);
        void captureWithHub() => monitoring.HubAdapter().captureException(error);
        void captureWithHubDirectly() => monitoring.Hub().captureException(error);
      ''',
      'lib/domain/example.dart': '''
        import 'package:talker_flutter/talker_flutter.dart' as diagnostics;
        final diagnostics.Talker talker = diagnostics.Talker();
        void write() => talker.error('message');
      ''',
      'lib/ui/global_talker_bypass.dart': r'''
        import 'package:moliseis/config/dependencies.dart';
        void write() => $talker.warning('message');
      ''',
      'lib/ui/string_literal.dart': '''
        const example = 'Sentry.captureException(error)';
        // Sentry.configureScope((scope) {})
      ''',
      'lib/domain/commented_import.dart': '''
        // import 'package:sentry/sentry.dart';
        const example = "import 'package:sentry/sentry.dart';";
      ''',
    });

    expect(violations, hasLength(13));
    expect(
      violations.join('\n'),
      contains('repository.dart: business code must not import the Sentry SDK'),
    );
    expect(violations.join('\n'), contains('direct Sentry addBreadcrumb'));
    expect(violations.join('\n'), contains('direct Sentry configureScope'));
    expect(violations.join('\n'), contains('direct Sentry startSpan'));
    expect(violations.join('\n'), contains('direct Sentry logger'));
    expect(violations.join('\n'), contains('direct Sentry captureEvent'));
    expect(violations.join('\n'), contains('direct Sentry currentHub'));
    expect(violations.join('\n'), contains('direct Sentry bindClient'));
    expect(
      violations.join('\n'),
      contains('lib/ui/example.dart: direct Sentry Hub construction'),
    );
    expect(
      violations.join('\n'),
      contains(
        'lib/data/repositories/hub_adapter.dart: business code must not import',
      ),
    );
    expect(violations.join('\n'), contains('direct Talker use'));
    expect(violations.join('\n'), contains('direct global Talker use'));
  });

  test('approved exceptions are scoped to specific files and operations', () {
    final violations = findSdkBoundaryViolations({
      'lib/main.dart': '''
        import 'package:sentry_flutter/sentry_flutter.dart';
        void close() => Sentry.close();
      ''',
      'lib/utils/logging/app_logger.dart': '''
        import 'package:sentry_flutter/sentry_flutter.dart';
        void emit() {
          Sentry.addBreadcrumb(Breadcrumb());
          Sentry.captureEvent(SentryEvent());
        }
      ''',
      'lib/utils/logging/run_traced_result.dart': '''
        import 'package:sentry/sentry.dart';
        void trace() => Sentry.startSpan('operation', (span) async {});
      ''',
      'lib/utils/logging/unapproved.dart': '''
        import 'package:sentry/sentry.dart';
        void report() => Sentry.captureException(StateError('unexpected'));
      ''',
      'lib/ui/example.dart': '''
        import 'package:sentry/sentry.dart';
        void mutate() => Sentry.configureScope((scope) {});
      ''',
      'lib/domain/example.dart': '''
        import 'package:talker_flutter/talker_flutter.dart';
        final talker = Talker();
      ''',
    });

    expect(violations, hasLength(3));
    expect(
      violations.join('\n'),
      contains('lib/utils/logging/unapproved.dart'),
    );
    expect(violations.join('\n'), contains('lib/ui/example.dart'));
    expect(violations.join('\n'), contains('lib/domain/example.dart'));
  });

  test('production discovery excludes generated Dart sources', () {
    final root = Directory.systemTemp.createTempSync('sdk-boundary-');
    try {
      File('${root.path}/ordinary.dart').writeAsStringSync('class Ordinary {}');
      File(
        '${root.path}/objectbox.g.dart',
      ).writeAsStringSync('class Generated {}');
      File(
        '${root.path}/event.mapper.dart',
      ).writeAsStringSync('class Generated {}');
      File(
        '${root.path}/bootstrap.init.dart',
      ).writeAsStringSync('class Generated {}');

      final sources = readProductionDartSources(root);
      expect(sources.keys, hasLength(1));
      expect(sources.keys.single, endsWith('ordinary.dart'));
    } finally {
      root.deleteSync(recursive: true);
    }
  });
}
