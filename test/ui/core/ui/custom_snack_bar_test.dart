import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/ui/core/ui/custom_snack_bar.dart';
import 'package:moliseis/utils/logging/logging.dart';
import 'package:provider/provider.dart';

import '../../../support/mock_logger.dart';

void main() {
  testWidgets('showSnackBar does not throw when providers are present', (
    tester,
  ) async {
    late BuildContext context;

    await tester.pumpWidget(
      Provider<Logger>.value(
        value: MockLogger(),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (innerContext) {
              context = innerContext;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    expect(
      () => showSnackBar(context: context, textContent: 'Message'),
      returnsNormally,
    );
  });

  testWidgets('showSnackBar does not throw when providers are NOT present', (
    tester,
  ) async {
    late BuildContext context;

    await tester.pumpWidget(
      Provider<Logger?>.value(
        value: null,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (innerContext) {
              context = innerContext;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    expect(
      () => showSnackBar(context: context, textContent: 'Message'),
      returnsNormally,
    );
  });
}
