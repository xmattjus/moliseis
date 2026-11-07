import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import '../../support/sdk_boundary_source.dart';

void main() {
  test(
    'Talker composition and all entry points use compile-time Debug guards',
    () {
      final dependencies = maskDartCode(
        File('lib/config/dependencies.dart').readAsStringSync(),
      );
      expect(
        dependencies,
        contains(
          r'final Talker? $talker = kDebugMode ? TalkerFlutter.init() : null;',
        ),
      );
      final router = maskDartCode(
        File('lib/routing/router.dart').readAsStringSync(),
      );
      expect(
        router,
        matches(
          RegExp(r'if \(kDebugMode\)\s+GoRoute\(\s+path: RoutePaths.logging,'),
        ),
      );
      expect(
        router,
        contains(r'observers: [if (kDebugMode) TalkerRouteObserver($talker!)]'),
      );
      final logger = maskDartCode(
        File('lib/utils/logging/app_logger.dart').readAsStringSync(),
      );
      expect(logger, contains('if (kDebugMode && _talker != null) {'));
      final explore = maskDartCode(
        File('lib/ui/explore/widgets/explore_screen.dart').readAsStringSync(),
      );
      expect(explore, matches(RegExp(r'if \(kDebugMode\)\s+MenuItem\(')));
      expect(explore, contains('context.pushNamed(RouteNames.logging)'));
      for (final source in [dependencies, router, logger, explore]) {
        expect(source, isNot(contains('kReleaseMode')));
      }
    },
  );

  test(
    'production Sentry privacy guard rejects missing or changed options',
    () {
      const source = '''
await SentryFlutter.init(
  (options) => options
    ..enablePrintBreadcrumbs = false
    ..beforeSend = AppLogger.beforeSend,
  appRunner: runner,
);
''';
      expect(productionSentryPrivacyConfigured(source), isTrue);
      expect(
        productionSentryPrivacyConfigured(
          source.replaceAll('..enablePrintBreadcrumbs = false', ''),
        ),
        isFalse,
      );
      expect(
        productionSentryPrivacyConfigured(
          source.replaceAll(
            '..enablePrintBreadcrumbs = false',
            '..enablePrintBreadcrumbs = true',
          ),
        ),
        isFalse,
      );
      expect(
        productionSentryPrivacyConfigured(
          source.replaceFirst(
            '..enablePrintBreadcrumbs = false',
            '..enablePrintBreadcrumbs = false\n'
                '    ..enablePrintBreadcrumbs = true',
          ),
        ),
        isFalse,
      );
      for (final replacement in ['null', 'customBeforeSend']) {
        expect(
          productionSentryPrivacyConfigured(
            source.replaceAll('AppLogger.beforeSend', replacement),
          ),
          isFalse,
        );
      }
      expect(
        productionSentryPrivacyConfigured(
          source.replaceAll('..beforeSend = AppLogger.beforeSend', ''),
        ),
        isFalse,
      );
      expect(
        productionSentryPrivacyConfigured(
          source.replaceFirst(
            '..beforeSend = AppLogger.beforeSend',
            '..beforeSend = AppLogger.beforeSend,\n'
                '    ..beforeSend = null',
          ),
        ),
        isFalse,
      );
      expect(
        productionSentryPrivacyConfigured('''
// ..enablePrintBreadcrumbs = false
// ..beforeSend = AppLogger.beforeSend
'''),
        isFalse,
      );
      expect(
        productionSentryPrivacyConfigured('''
await SentryFlutter.init(
  (options) => options..enablePrintBreadcrumbs = true,
  appRunner: runner,
);
await SentryFlutter.init(
  (options) => options
    ..enablePrintBreadcrumbs = false
    ..beforeSend = AppLogger.beforeSend,
  appRunner: runner,
);
'''),
        isFalse,
      );
      expect(
        productionSentryPrivacyConfigured(
          source.replaceAll(
            '..beforeSend = AppLogger.beforeSend',
            '// ..beforeSend = AppLogger.beforeSend',
          ),
        ),
        isFalse,
      );
    },
  );

  test('production SDK use stays within approved boundaries', () {
    final violations = findSdkBoundaryViolations(
      readProductionDartSources(Directory('lib')),
    );
    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('apostrophe in a comment cannot hide executable SDK calls', () {
    final violations = findSdkBoundaryViolations({
      'lib/ui/example.dart': """
// It doesn't matter here
Sentry.captureException(error);
final value = 'example';
""",
    });

    const expected =
        'lib/ui/example.dart: direct Sentry captureException '
        'requires an approved adapter';
    expect(violations, [expected]);
  });

  test('quotes and comment markers cannot hide following SDK calls', () {
    final fixtures = {
      'block_comment': """
/* It doesn't matter: ' or " */
Sentry.captureException(error);
final value = 'example';
""",
      'comment_markers': """
final line = '// not a comment';
final block = "/* not a comment */";
Sentry.captureException(error);
""",
      'raw_single': r"""
final value = r'// raw trailing backslash\';
Sentry.captureException(error);
final other = 'example';
""",
      'raw_double': r'''
final value = r"/* raw trailing backslash\";
Sentry.captureException(error);
final other = "example";
''',
      'escaped_quotes': r"""
final value = 'it\'s // still a string';
Sentry.captureException(error);
""",
    };
    for (final entry in fixtures.entries) {
      final path = 'lib/ui/${entry.key}.dart';
      expect(findSdkBoundaryViolations({path: entry.value}), [
        '$path: direct Sentry captureException requires an approved adapter',
      ], reason: entry.key);
    }
  });

  test('SDK-looking strings and comments are ignored', () {
    final violations = findSdkBoundaryViolations({
      'lib/domain/example.dart': r"""
// It doesn't call Sentry.captureException(error);
/* 'Sentry.captureEvent(event)' and "Sentry.configureScope(callback)" */
final single = 'Sentry.captureException(error)';
final double = "Sentry.startSpan('operation', callback)";
final raw = r'/* Sentry.captureException(error) */';
final escaped = 'it\'s Sentry.captureException(error)';
final importText = "import 'package:sentry/sentry.dart';";
""",
    });
    expect(violations, isEmpty);
  });

  for (final quote in ["'", '"']) {
    for (final raw in [false, true]) {
      test('triple $quote strings mask only their contents, raw=$raw', () {
        final delimiter = '$quote$quote$quote';
        final source = [
          'final value = ${raw ? 'r' : ''}$delimiter',
          'Sentry.captureException(fake);',
          "import 'package:sentry/sentry.dart';",
          "import 'package:talker/talker.dart';",
          '// comment markers inside a string',
          '/* also string contents */',
          if (!raw) '\\$delimiter',
          if (!raw) 'Sentry.configureScope(fake);',
          if (raw) r'\',
          '$delimiter;',
          'Sentry.captureEvent(event);',
        ].join('\n');
        const expected =
            'lib/domain/example.dart: direct Sentry captureEvent '
            'requires an approved adapter';
        expect(findSdkBoundaryViolations({'lib/domain/example.dart': source}), [
          expected,
        ]);
      });
    }
  }

  test('masking retains line boundaries for imports after comments', () {
    final violations = findSdkBoundaryViolations({
      'lib/ui/example.dart':
          """
// comment marker text: /*
library example; /* comment with a line break
ending on the import line */ import
  'package:sentry/sentry.dart' as telemetry;
void report() => telemetry.Sentry.captureException(error);
"""
              .replaceAll('\n', '\r\n'),
    });
    const expected =
        'lib/ui/example.dart: direct Sentry captureException '
        'requires an approved adapter';
    expect(violations, [expected]);
  });

  test('global Talker calls reject nullable operators and spacing', () {
    const expected =
        'lib/ui/example.dart: direct global Talker use bypasses Logger.log';
    for (final call in [
      r'$talker.warning(value);',
      r'$talker!.warning(value);',
      r'$talker?.warning(value);',
      r'$talker . warning (value);',
      r'$talker ! . warning (value);',
      r'$talker ?. warning (value);',
      r'''
$talker!
 . warning(value);
''',
    ]) {
      expect(
        findSdkBoundaryViolations({
          'lib/ui/example.dart': 'void write() => $call',
        }),
        [expected],
        reason: call,
      );
    }
  });

  test('approved Talker files reject direct instance construction', () {
    final violations = findSdkBoundaryViolations({
      'lib/main.dart': '''
import 'package:talker_flutter/talker_flutter.dart';
void bypass() => Talker().error('message');
''',
      'lib/ui/core/ui/logging_screen.dart': '''
import 'package:talker_flutter/talker_flutter.dart' as diagnostics;
final extra = diagnostics.Talker();
''',
      'lib/config/dependencies.dart': '''
import 'package:talker_flutter/talker_flutter.dart';
final extra = Talker();
''',
      'lib/routing/router.dart': '''
import 'package:talker_flutter/talker_flutter.dart';
void bypass() => TalkerFlutter.init().warning('message');
''',
    });

    expect(violations, [
      'lib/main.dart: direct Talker construction bypasses Debug composition',
      'lib/ui/core/ui/logging_screen.dart: direct Talker construction '
          'bypasses Debug composition',
      'lib/config/dependencies.dart: direct Talker construction '
          'bypasses Debug composition',
      'lib/routing/router.dart: Talker initialization requires Debug composition',
    ]);
  });

  test('approved Debug composition and Replay types remain permitted', () {
    final violations = findSdkBoundaryViolations({
      'lib/config/dependencies.dart': r'''
import 'package:talker_flutter/talker_flutter.dart';
final Talker? $talker = kDebugMode ? TalkerFlutter.init() : null;
''',
      'lib/main.dart': '''
import 'package:talker_flutter/talker_flutter.dart';
void masks(options) {
  options.privacy.mask<TalkerView>();
  options.privacy.mask<TalkerDataCard>();
}
''',
      'lib/routing/router.dart': r'''
final observer = TalkerRouteObserver($talker!);
''',
    });
    expect(violations, isEmpty);
  });

  test('Talker routing references and inert text stay permitted', () {
    expect(
      findSdkBoundaryViolations({
        'lib/routing/router.dart': r'''
final observer = TalkerRouteObserver($talker!);
final viewer = LoggingScreen(talker: $talker!);
''',
        'lib/ui/example.dart': r"""
const examples = ['$talker.warning(value)', '$talker!.warning(value)',
  '$talker?.warning(value)', '$talker ! . warning (value)'];
// $talker!.warning(value);
/* $talker?.warning(value); $talker.warning(value); */
""",
      }),
      isEmpty,
    );
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
