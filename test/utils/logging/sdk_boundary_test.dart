import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('business layers use Sentry logging adapters', () {
    final directSdkImport = RegExp('import .*package:sentry(?:_flutter)?/');
    final directSdkCall = RegExp(
      r'Sentry\.(?:startTransaction|startSpan(?:Sync|Manual)?|capture\w+|addBreadcrumb)\s*\(',
    );
    final violations = <String>[];
    for (final file in Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      final path = file.path.replaceAll(r'\', '/');
      final source = file.readAsStringSync();
      if ((path.startsWith('lib/domain/') ||
              path.startsWith('lib/data/repositories/')) &&
          directSdkImport.hasMatch(source)) {
        violations.add('$path: business code must import the logging adapter');
      }
      // Bootstrap owns platform telemetry; adapters own manual calls.
      if (path != 'lib/main.dart' &&
          !path.startsWith('lib/utils/logging/') &&
          directSdkCall.hasMatch(source)) {
        violations.add(
          '$path: direct Sentry calls require a reviewed ownership exception',
        );
      }
    }
    expect(violations, isEmpty, reason: violations.join('\n'));
  });
}
