import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/ui/content_submission/widgets/content_submission_asset_list_item.dart';

import '../../../support/typography_harness.dart';

void main() {
  testWidgets('public removal keeps its existing size and placement', (
    tester,
  ) async {
    await tester.pumpWidget(
      typographyHarness(
        child: const Scaffold(
          body: Center(
            child: ContentSubmissionAssetListItem(
              image: SizedBox.square(dimension: 86),
            ),
          ),
        ),
      ),
    );
    final item = tester.getRect(find.byType(ContentSubmissionAssetListItem));
    final button = tester.getRect(find.byType(InkWell));
    expect(button.size, const Size.square(24));
    expect(button.top, item.top - 4);
    expect(button.right, item.right + 4);
  });

  testWidgets(
    '48 pixel removal targets are labeled, fully tappable and spaced',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final removals = <int>[];
        await tester.pumpWidget(
          typographyHarness(
            child: Scaffold(
              body: Center(
                child: Wrap(
                  spacing: 8,
                  children: [
                    for (var index = 0; index < 2; index++)
                      ContentSubmissionAssetListItem(
                        removeButtonSize: 48,
                        image: const SizedBox.square(dimension: 86),
                        onRemove: () => removals.add(index),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
        final buttons = find.byType(InkWell);
        final first = tester.getRect(buttons.first);
        final second = tester.getRect(buttons.last);
        final firstItem = tester.getRect(
          find.byType(ContentSubmissionAssetListItem).first,
        );
        expect(first.size, const Size.square(48));
        expect(second.size, const Size.square(48));
        expect(firstItem.contains(first.topLeft), isTrue);
        expect(first.bottomRight, firstItem.topRight + const Offset(0, 48));
        expect(first.overlaps(second), isFalse);
        expect(second.left - first.right, greaterThanOrEqualTo(8));
        expect(find.bySemanticsLabel('Rimuovi foto'), findsNWidgets(2));
        await tester.tapAt(first.centerLeft + const Offset(1, 0));
        await tester.pump();
        await tester.tapAt(first.bottomCenter - const Offset(0, 1));
        await tester.pump();
        expect(removals, [0, 0]);
        await tester.tapAt(second.center);
        await tester.pump();
        expect(removals, [0, 0, 1]);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );
}
