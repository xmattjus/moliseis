import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/ui/core/ui/empty_view.dart';
import 'package:moliseis/ui/core/ui/media/image_error_placeholder.dart';

import '../../../../support/empty_view_geometry.dart';
import '../../../../support/typography_measurement_harness.dart';

void main() {
  testWidgets('gallery feedback contrasts with its black background', (
    tester,
  ) async {
    await tester.pumpWidget(
      emptyViewGeometryHarness(
        width: 500,
        height: 500,
        photoViewer: true,
        child: const ImageErrorPlaceholder(),
      ),
    );
    final icon = tester.widget<Icon>(find.byIcon(Symbols.broken_image));
    final text = tester.renderObject<RenderParagraph>(
      find.descendant(
        of: find.text('Immagine non disponibile'),
        matching: find.byType(RichText),
      ),
    );
    expect((icon.color!.computeLuminance() + 0.05) / 0.05, greaterThan(3));
    expect(
      (text.text.style!.color!.computeLuminance() + 0.05) / 0.05,
      greaterThan(4.5),
    );
  });

  for (final scale in [1.0, 2.0]) {
    for (final side in [32.0, 48.0, 72.0, 86.0]) {
      testWidgets(
        'compact $side square at scale $scale stays bounded and labelled',
        (tester) async {
          final semantics = tester.ensureSemantics();
          await tester.pumpWidget(
            emptyViewGeometryHarness(
              width: side,
              height: side,
              scale: scale,
              child: const ImageErrorPlaceholder(),
            ),
          );
          final slot = tester.getRect(find.byType(ImageErrorPlaceholder));
          final icon = tester.getRect(find.byIcon(Symbols.broken_image));
          expect(icon.width, greaterThan(0));
          expect(icon.height, greaterThan(0));
          expect(icon.width, lessThanOrEqualTo(40));
          expect(icon.center, slot.center);
          expect(slot.intersect(icon), icon);
          expect(find.byType(EmptyView), findsNothing);
          expect(find.byType(Scrollable), findsNothing);
          expect(
            find.bySemanticsLabel('Immagine non disponibile'),
            findsOneWidget,
          );
          final node = tester.getSemantics(find.byType(ImageErrorPlaceholder));
          expect(node.getSemanticsData().label, 'Immagine non disponibile');
          expect(node.childrenCount, 0);
          expect(tester.takeException(), isNull);
          semantics.dispose();
        },
      );
    }
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'full composition boundary follows measured label at scale $scale',
      (tester) async {
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(
          emptyViewGeometryHarness(
            width: 200,
            height: 500,
            scale: scale,
            child: const ImageErrorPlaceholder(),
          ),
        );
        final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(
            of: find.text('Immagine non disponibile'),
            matching: find.byType(RichText),
          ),
        );
        final measured = measureRenderedText(paragraph, maxWidth: 168);
        final requiredHeight = 96 + measured.height;
        measured.dispose();
        for (final extra in [-0.01, 0.01]) {
          await tester.pumpWidget(
            emptyViewGeometryHarness(
              width: 200,
              height: requiredHeight + extra,
              scale: scale,
              child: const ImageErrorPlaceholder(),
            ),
          );
          expect(
            find.byType(EmptyView),
            extra < 0 ? findsNothing : findsOneWidget,
          );
          if (extra > 0) {
            final slot = tester.getRect(find.byType(ImageErrorPlaceholder));
            final label = tester.getRect(find.text('Immagine non disponibile'));
            final icon = tester.getRect(find.byIcon(Symbols.broken_image));
            expect(slot.intersect(label), label);
            expect(slot.intersect(icon), icon);
            expect(
              tester
                  .state<ScrollableState>(find.byType(Scrollable))
                  .position
                  .maxScrollExtent,
              0,
            );
          }
          expect(
            find.bySemanticsLabel('Immagine non disponibile'),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        }
        semantics.dispose();
      },
    );
  }

  testWidgets(
    'minimum decorated width and accessibility typography are measured',
    (tester) async {
      for (final width in [103.99, 104.0]) {
        await tester.pumpWidget(
          emptyViewGeometryHarness(
            width: width,
            height: 1000,
            child: const ImageErrorPlaceholder(),
          ),
        );
        expect(
          find.byType(EmptyView),
          width < 104 ? findsNothing : findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      }

      const data = MediaQueryData(
        textScaler: TextScaler.linear(2),
        boldText: true,
        lineHeightScaleFactorOverride: 2,
        letterSpacingOverride: 3,
        wordSpacingOverride: 4,
      );
      await tester.pumpWidget(
        emptyViewGeometryHarness(
          width: 250,
          height: 1000,
          mediaQuery: data,
          direction: TextDirection.rtl,
          typography: const TextTheme(
            bodyLarge: TextStyle(fontSize: 21, height: 1.4),
          ),
          child: const ImageErrorPlaceholder(),
        ),
      );
      final label = find.text('Immagine non disponibile');
      final requiredHeight = 96 + tester.getSize(label).height;
      for (final extra in [-0.01, 0.01]) {
        await tester.pumpWidget(
          emptyViewGeometryHarness(
            width: 250,
            height: requiredHeight + extra,
            mediaQuery: data,
            direction: TextDirection.rtl,
            typography: const TextTheme(
              bodyLarge: TextStyle(fontSize: 21, height: 1.4),
            ),
            child: const ImageErrorPlaceholder(),
          ),
        );
        expect(
          find.byType(EmptyView),
          extra < 0 ? findsNothing : findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      }
    },
  );
}
