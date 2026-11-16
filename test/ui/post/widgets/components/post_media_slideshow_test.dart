import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/ui/core/themes/app_theme_data.dart';
import 'package:moliseis/ui/core/ui/media/app_network_image.dart';
import 'package:moliseis/ui/post/widgets/components/post_media_slideshow.dart';
import 'package:moliseis/utils/extensions/extensions.dart';
import 'package:provider/provider.dart';

import '../../../../support/fake_cache_manager.dart';
import '../../../../support/network_image_harness.dart';
import '../../../../support/post_media_slideshow_harness.dart';
import '../../../../support/test_image_files.dart';
import '../../../../support/typography_measurement_harness.dart';

void main() {
  setUp(() {
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
  });

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
                media: [slideshowMedia(1)],
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

  group('page ownership and autoplay', () {
    testWidgets('offscreen completion cannot settle the active page; '
        'a settled page is admitted on selection without replay', (
      tester,
    ) async {
      final files = TestImageFiles.create();
      addTearDown(files.dispose);
      final bytes = files.createSizedPng(64, 64).readAsBytesSync();
      final manager = ControlledImageCacheManager();
      final fixture = PostMediaSlideshowHarness(
        media: [slideshowMedia(1), slideshowMedia(2)],
        cacheManager: manager,
      );
      addTearDown(fixture.dispose);
      await fixture.pump(tester);
      // Page 0 stays active while page 1 is built offscreen.
      final controller = fixture.controller(tester)..jumpTo(240);
      await tester.pump();
      await tester.pump();
      final a = manager.lastRequestFor(slideshowMedia(1).url);
      final b = manager.lastRequestFor(slideshowMedia(2).url);
      expect((a, b), (0, 1));
      await completeSlideshowImage(tester, manager, b, bytes);
      expect(fixture.controlsEnabled(tester), isFalse);
      expect(controller.offset, 240);

      controller.jumpToPage(1);
      await tester.pump();
      await tester.pump();
      expect(fixture.controlsEnabled(tester), isTrue);
      expect(manager.requests, hasLength(2));

      // A's request completes after its page was disposed.
      manager.complete(a, bytes);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
      await tester.pump();
      expect(fixture.controlsEnabled(tester), isTrue);
      await tester.pump(const Duration(seconds: 6));
      await tester.pump(const Duration(seconds: 2));
      expect(controller.page, closeTo(0, 0.01));
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    });

    testWidgets('list ABA and reorder revoke owners; a retained ABA decode '
        'is synchronously admissible', (tester) async {
      final files = TestImageFiles.create();
      addTearDown(files.dispose);
      final bytes = files.createSizedPng(64, 64).readAsBytesSync();
      final manager = ControlledImageCacheManager();
      final fixture = PostMediaSlideshowHarness(
        media: [slideshowMedia(1), slideshowMedia(2)],
        cacheManager: manager,
      );
      addTearDown(fixture.dispose);
      await fixture.pump(tester);
      await completeSlideshowImage(tester, manager, 0, bytes);
      expect(fixture.controlsEnabled(tester), isTrue);
      final firstOwner = fixture.image(tester, 1).onImageLoading!;

      fixture.media[0] = slideshowMedia(3);
      fixture.rebuild();
      await tester.pump();
      expect(fixture.controlsEnabled(tester), isFalse);
      expect(manager.lastRequestFor(slideshowMedia(3).url), greaterThan(0));

      fixture.media[0] = slideshowMedia(1);
      fixture.rebuild();
      await tester.pump();
      await tester.pump();
      final reads = manager.requests.length;
      expect(fixture.controlsEnabled(tester), isTrue);
      expect(manager.lastRequestFor(slideshowMedia(1).url), 0);
      // Adversarial: the A owner replaced by C stays revoked after A returns.
      firstOwner(true);
      await tester.pump();
      await tester.pump();
      expect(fixture.controlsEnabled(tester), isTrue);

      // Capture the callback that holds authority immediately before reorder.
      final live = fixture.image(tester, 1).onImageLoading!;
      live(true);
      await tester.pump();
      await tester.pump();
      expect(fixture.controlsEnabled(tester), isFalse);
      live(false);
      await tester.pump();
      await tester.pump();
      expect(fixture.controlsEnabled(tester), isTrue);

      fixture
        ..media = fixture.media.reversed.toList()
        ..rebuild();
      await tester.pump();
      expect(fixture.controlsEnabled(tester), isFalse);
      live(false);
      await tester.pump();
      await tester.pump();
      expect(fixture.controlsEnabled(tester), isFalse);
      final b = manager.lastRequestFor(slideshowMedia(2).url);
      expect(b, reads);
      await completeSlideshowImage(tester, manager, b, bytes);
      expect(fixture.controlsEnabled(tester), isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    });

    testWidgets('unchanged rebuild and partial list replacement preserve '
        'ready slots without new requests', (tester) async {
      final files = TestImageFiles.create();
      addTearDown(files.dispose);
      final manager = ControlledImageCacheManager();
      final fixture = PostMediaSlideshowHarness(
        media: [slideshowMedia(1), slideshowMedia(2)],
        cacheManager: manager,
      );
      addTearDown(fixture.dispose);
      await fixture.pump(tester);
      await completeSlideshowImage(
        tester,
        manager,
        0,
        files.createSizedPng(64, 64).readAsBytesSync(),
      );
      expect(fixture.controlsEnabled(tester), isTrue);
      // Without a retained decode, replacing A's child would force a reload.
      PaintingBinding.instance.imageCache
        ..clear()
        ..clearLiveImages();
      fixture.rebuild();
      await tester.pump();
      expect(fixture.controlsEnabled(tester), isTrue);

      fixture
        ..media = [slideshowMedia(1), slideshowMedia(3)]
        ..rebuild();
      await tester.pump();
      expect(fixture.controlsEnabled(tester), isTrue);
      expect(manager.requests, hasLength(1));

      // Retained A readiness alone admits autoplay to the replaced slot.
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(seconds: 6));
      await tester.pump(const Duration(seconds: 2));
      expect(fixture.controller(tester).page, closeTo(1, 0.01));
      expect(manager.lastRequestFor(slideshowMedia(3).url), 1);
      await tester.pump();
      expect(fixture.controlsEnabled(tester), isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    });

    // Adversarial: AppNetworkImage generations already fence real obsolete
    // events; this exercises the slideshow's own request revocation.
    testWidgets(
      'revoked page callback cannot settle a replaced bucket; queued updates '
      'read the current owner',
      (tester) async {
        final fixture = PostMediaSlideshowHarness(
          media: [slideshowMedia(1), slideshowMedia(2)],
        );
        addTearDown(fixture.dispose);
        await fixture.pump(tester);
        final obsolete = fixture.image(tester, 1).onImageLoading!;
        obsolete(false);
        fixture
          ..width = 300
          ..rebuild();
        await tester.pump();
        await tester.pump();
        obsolete(false);
        await tester.pump();
        await tester.pump();
        expect(fixture.controlsEnabled(tester), isFalse);
        final current = fixture.image(tester, 1).onImageLoading!;
        current(false);
        current(true);
        await tester.pump();
        await tester.pump();
        expect(fixture.controlsEnabled(tester), isFalse);
        current(false);
        await tester.pump();
        await tester.pump();
        expect(fixture.controlsEnabled(tester), isTrue);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets('visibility listener rebinds, count changes safely '
        'and pause intent survives', (tester) async {
      final fixture = PostMediaSlideshowHarness(media: []);
      addTearDown(fixture.dispose);
      await fixture.pump(tester);
      fixture
        ..media = [slideshowMedia(1)]
        ..rebuild();
      await tester.pump();
      await tester.pump();
      fixture
        ..media = [slideshowMedia(1), slideshowMedia(2)]
        ..rebuild();
      await tester.pump();
      await tester.pump();
      fixture.image(tester, 1).onImageLoading!(false);
      await tester.pump();
      await tester.pump();
      final oldVisibility = fixture.visibility;
      fixture
        ..visibility = ValueNotifier(false)
        ..rebuild();
      await tester.pump();
      await tester.pump();
      oldVisibility
        ..value = false
        ..dispose();
      await tester.pump(const Duration(seconds: 6));
      expect(fixture.controller(tester).page, 0);
      expect(fixture.controlsEnabled(tester), isFalse);
      fixture.visibility.value = true;
      await tester.pump();
      await tester.pump();
      expect(fixture.controlsEnabled(tester), isTrue);
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      await tester.pump();
      fixture.visibility.value = false;
      fixture.visibility.value = true;
      await tester.pump(const Duration(seconds: 6));
      expect(fixture.controller(tester).page, 0);
      fixture
        ..media = []
        ..rebuild();
      await tester.pump();
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    });
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
                      media: [slideshowMedia(1), slideshowMedia(1)],
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
