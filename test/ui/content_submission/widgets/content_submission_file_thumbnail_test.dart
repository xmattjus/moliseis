import 'dart:io';

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/ui/content_submission/widgets/content_submission_file_thumbnail.dart';
import 'package:moliseis/ui/core/ui/media/bounded_cover_image.dart';
import 'package:moliseis/ui/core/ui/media/image_error_placeholder.dart';
import 'package:moliseis/utils/logging/logging.dart';
import 'package:provider/provider.dart';

import '../../../support/image_decode_support.dart';
import '../../../support/mock_logger.dart';
import '../../../support/test_image_files.dart';
import '../../../support/typography_harness.dart';

void main() {
  for (final dpr in [1.0, 2.0, 2.625, 3.0]) {
    testWidgets(
      'shared staged preview decodes and crops actual pixels DPR $dpr',
      (tester) async {
        final files = TestImageFiles.create();
        addTearDown(files.dispose);
        tester.view.devicePixelRatio = dpr;
        addTearDown(tester.view.resetDevicePixelRatio);
        for (final dimensions in [
          (400, 400),
          (400, 300),
          (300, 400),
          (400, 100),
          (100, 400),
          (12000, 1000),
          (16, 8),
        ]) {
          final file = files.createSizedPng(dimensions.$1, dimensions.$2);
          final frame = await tester.runAsync(() async {
            await tester.pumpWidget(
              typographyHarness(
                child: Scaffold(
                  body: Center(
                    child: ContentSubmissionFileThumbnail(file: file),
                  ),
                ),
              ),
            );
            final widget = tester.widget<Image>(find.byType(Image));
            return await decodeImage(widget.image);
          });
          await tester.pump();
          final expected = boundedCoverSize(
            intrinsicWidth: dimensions.$1,
            intrinsicHeight: dimensions.$2,
            targetWidth: (86 * dpr).ceil(),
            targetHeight: (86 * dpr).ceil(),
          );
          expect(
            (frame!.image.width, frame.image.height),
            (expected.width, expected.height),
          );
          final raw = tester.widget<RawImage>(find.byType(RawImage));
          expect(
            (raw.image!.width, raw.image!.height),
            (expected.width, expected.height),
          );
          expect(
            tester.getSize(find.byType(ContentSubmissionFileThumbnail)),
            const Size(86, 86),
          );
          expect(raw.fit, BoxFit.cover);
          final crop = applyBoxFit(
            raw.fit!,
            Size(raw.image!.width.toDouble(), raw.image!.height.toDouble()),
            const Size(86, 86),
          );
          expect(crop.destination, const Size(86, 86));
          expect(crop.source.width, crop.source.height);
          final render = tester.renderObject<RenderImage>(
            find.byType(RawImage),
          );
          expect(render.size, const Size(86, 86));
          expect(find.byType(ImageErrorPlaceholder), findsNothing);
          expect(tester.takeException(), isNull);
          frame.dispose();
        }
        await tester.pumpWidget(const SizedBox.shrink());
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
      },
    );
  }

  for (final failure in ['missing', 'empty', 'corrupt', 'unreadable']) {
    testWidgets(
      '$failure file has one neutral accessible error and useful log',
      (tester) async {
        final files = TestImageFiles.create();
        addTearDown(files.dispose);
        final file = files.createSizedPng(400, 300);
        switch (failure) {
          case 'missing':
            file.deleteSync();
          case 'empty':
            file.writeAsBytesSync([]);
          case 'corrupt':
            file.writeAsBytesSync([0, 1, 2]);
          case 'unreadable':
            // A directory cannot be decoded as a file, even when CI users
            // bypass ordinary permission bits.
            file.deleteSync();
            Directory(file.path).createSync();
        }
        final logger = MockLogger();
        final semantics = tester.ensureSemantics();
        final child = Provider<Logger?>.value(
          value: logger,
          child: ContentSubmissionFileThumbnail(file: file),
        );
        await tester.runAsync(() async {
          await tester.pumpWidget(
            typographyHarness(
              child: Scaffold(body: Center(child: child)),
            ),
          );
          final image = tester.widget<Image>(find.byType(Image));
          await expectLater(decodeImage(image.image), throwsA(anything));
        });
        await tester.pump();
        expect(find.byType(ImageErrorPlaceholder), findsOneWidget);
        expect(
          find.bySemanticsLabel('Immagine non disponibile'),
          findsOneWidget,
        );
        expect(
          tester.getSize(find.byType(ImageErrorPlaceholder)),
          const Size(86, 86),
        );
        expect(tester.takeException(), isNull);
        final call = logger.firstCallOfType<ImageLoadFailed>()!;
        expect((call.event as ImageLoadFailed).url, 'staged-local-image');
        expect(call.error, isNotNull);
        expect(call.stackTrace, isNotNull);
        expect(logger.eventsOfType<ImageLoadFailed>(), hasLength(1));
        await tester.pumpWidget(
          typographyHarness(
            child: Scaffold(body: Center(child: child)),
          ),
        );
        await tester.pump();
        expect(logger.eventsOfType<ImageLoadFailed>(), hasLength(1));
        expect(find.byType(Scrollable), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        semantics.dispose();
      },
    );
  }

  testWidgets(
    'replacement and disposal revoke captured stale error callbacks',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      final files = TestImageFiles.create();
      addTearDown(files.dispose);
      final first = files.createSizedPng(400, 300);
      final second = files.createSizedPng(300, 400);
      final logger = MockLogger();
      await tester.runAsync(
        () => tester.pumpWidget(
          typographyHarness(
            child: Provider<Logger?>.value(
              value: logger,
              child: ContentSubmissionFileThumbnail(file: first),
            ),
          ),
        ),
      );
      final old = tester.widget<Image>(find.byType(Image));
      final oldContext = tester.element(find.byType(Image));
      await tester.runAsync(
        () => tester.pumpWidget(
          typographyHarness(
            child: Provider<Logger?>.value(
              value: logger,
              child: ContentSubmissionFileThumbnail(file: second),
            ),
          ),
        ),
      );
      expect(
        old.errorBuilder!(
          oldContext,
          StateError('obsolete'),
          StackTrace.current,
        ),
        isA<SizedBox>(),
      );
      final current = tester.widget<Image>(find.byType(Image));
      final currentContext = tester.element(find.byType(Image));
      final frame = await tester.runAsync(() => decodeImage(current.image));
      frame!.dispose();
      await tester.pump();
      final raw = tester.widget<RawImage>(find.byType(RawImage));
      expect((raw.image!.width, raw.image!.height), (86, 115));
      await tester.pumpWidget(const SizedBox.shrink());
      expect(
        current.errorBuilder!(
          currentContext,
          StateError('disposed'),
          StackTrace.current,
        ),
        isA<SizedBox>(),
      );
      expect(logger.calls, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
