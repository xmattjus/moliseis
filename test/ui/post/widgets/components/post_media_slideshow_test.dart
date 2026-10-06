import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/domain/models/media.dart';
import 'package:moliseis/ui/core/themes/app_theme_data.dart';
import 'package:moliseis/ui/core/ui/media/app_network_image.dart';
import 'package:moliseis/ui/post/widgets/components/post_media_slideshow.dart';
import 'package:moliseis/utils/extensions/extensions.dart';
import 'package:provider/provider.dart';

import '../../../../support/fake_cache_manager.dart';
import '../../../../support/typography_measurement_harness.dart';

void main() {
  testWidgets('queued image loading callback is safe after disposal', (
    tester,
  ) async {
    final cacheManager = FakeCacheManager();
    final visibilityNotifier = ValueNotifier(true);
    addTearDown(cacheManager.dispose);
    addTearDown(visibilityNotifier.dispose);

    await tester.pumpWidget(
      Provider<CacheManager>.value(
        value: cacheManager,
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 400,
              child: PostMediaSlideshow(
                height: 400,
                media: [_buildMedia()],
                visibilityNotifier: visibilityNotifier,
              ),
            ),
          ),
        ),
      ),
    );

    final image = tester.widget<AppNetworkImage>(find.byType(AppNetworkImage));
    image.onImageLoading!(false);

    await tester.pumpWidget(const SizedBox.shrink());

    expect(tester.takeException(), isNull);
  });

  group('pause label measurement', () {
    setUpAll(loadTypographyMeasurementFont);

    for (final direction in TextDirection.values) {
      testWidgets('expanded width follows rendered typography in $direction', (
        tester,
      ) async {
        final cacheManager = FakeCacheManager();
        final visibility = ValueNotifier(true);
        final inputs = ValueNotifier(
          const MediaQueryData(size: Size(800, 600)),
        );
        addTearDown(cacheManager.dispose);
        addTearDown(visibility.dispose);
        addTearDown(inputs.dispose);
        await tester.pumpWidget(
          Provider<CacheManager>.value(
            value: cacheManager,
            child: Builder(
              builder: (context) => TypographyMeasurementApp(
                mediaQuery: inputs,
                direction: direction,
                theme: AppThemeData.light(context: context).copyWith(
                  filledButtonTheme: const FilledButtonThemeData(
                    style: ButtonStyle(
                      textStyle: WidgetStatePropertyAll(
                        TextStyle(fontSize: 30),
                      ),
                    ),
                  ),
                ),
                home: Scaffold(
                  body: SizedBox(
                    height: 400,
                    child: PostMediaSlideshow(
                      height: 400,
                      media: [_buildMedia(), _buildMedia()],
                      visibilityNotifier: visibility,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        final image = tester.widget<AppNetworkImage>(
          find.byType(AppNetworkImage).first,
        );
        image.onImageLoading!(false);
        await tester.pump();
        await tester.pump();
        await tester.tap(find.byType(FilledButton));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        const label = 'Attiva scorrimento automatico';
        expect(find.text(label), findsOneWidget);
        final measuredWidths = <double>[];
        for (final data in [
          const MediaQueryData(size: Size(800, 600)),
          const MediaQueryData(
            size: Size(800, 600),
            textScaler: TextScaler.linear(2),
          ),
          const MediaQueryData(size: Size(800, 600), boldText: true),
          const MediaQueryData(
            size: Size(800, 600),
            lineHeightScaleFactorOverride: 2,
            letterSpacingOverride: 2,
            wordSpacingOverride: 4,
          ),
        ]) {
          inputs.value = data;
          await tester.pump();
          final paragraph = tester.renderObject<RenderParagraph>(
            find.descendant(
              of: find.text(label),
              matching: find.byType(RichText),
            ),
          );
          final reference = measureRenderedText(paragraph);
          final paragraphWidth = reference.width;
          reference.dispose();
          final buttonFinder = find.byType(FilledButton);
          final buttonContext = tester.element(buttonFinder);
          final button = tester.widget<FilledButton>(buttonFinder);
          expect(
            button.style!.textStyle!.resolve({}),
            buttonContext.textTheme.labelLarge,
          );
          final width = tester.getSize(buttonFinder).width;
          final iconSize = IconTheme.of(buttonContext).size ?? 18;
          expect(width, closeTo(paragraphWidth + iconSize + 16 + 8 + 24, 0.01));
          expect(paragraph.textDirection, direction);
          expect(paragraph.locale, const Locale('en'));
          expect(paragraph.textScaler, data.textScaler);
          expect(paragraph.maxLines, 1);
          measuredWidths.add(width);
          if (data.boldText) {
            expect(paragraph.text.style!.fontWeight, FontWeight.bold);
          }
          if (data.lineHeightScaleFactorOverride != null) {
            expect(paragraph.text.style!.height, 2);
            expect(paragraph.text.style!.letterSpacing, 2);
            expect(paragraph.text.style!.wordSpacing, 4);
          }
        }
        expect(measuredWidths[1], greaterThan(measuredWidths[0]));
        expect(measuredWidths[2], isNot(closeTo(measuredWidths[0], 0.01)));
        expect(measuredWidths[3], greaterThan(measuredWidths[0]));
        await tester.pumpWidget(const SizedBox.shrink());
        expect(tester.takeException(), isNull);
      });
    }
  });
}

Media _buildMedia() => Media(
  remoteId: 1,
  url: 'https://example.com/image.jpg',
  width: 800,
  height: 600,
  createdAt: DateTime.utc(2026),
  modifiedAt: DateTime.utc(2026),
  areaName: 'Event',
  cityName: 'Molise',
);
