import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/ui/core/ui/custom_snack_bar.dart';

void main() {
  testWidgets('showSnackBar does not throw when providers are missing', (
    tester,
  ) async {
    late BuildContext context;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Builder(
          builder: (innerContext) {
            context = innerContext;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(
      () => showSnackBar(context: context, textContent: 'Message'),
      returnsNormally,
    );
  });
}
