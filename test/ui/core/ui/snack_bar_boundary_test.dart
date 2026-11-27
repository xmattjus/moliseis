import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../support/sdk_boundary_source.dart';

void main() {
  test('production Snackbar queue mutations stay in the app helper', () {
    const owner = 'lib/ui/core/ui/custom_snack_bar.dart';
    final nativeQueueAccess = RegExp(
      r'\.\s*(?:showSnackBar|clearSnackBars|hideCurrentSnackBar|removeCurrentSnackBar)\b'
      r'|\bScaffoldFeatureController\s*<\s*SnackBar\b'
      r'|\bSnackBar\s*\(',
    );
    final violations = [
      for (final source in readProductionDartSources(Directory('lib')).entries)
        if (source.key != owner &&
            nativeQueueAccess.hasMatch(maskDartCode(source.value)))
          source.key,
    ];
    expect(violations, isEmpty, reason: 'Use the queue owner at $owner.');
  });
}
