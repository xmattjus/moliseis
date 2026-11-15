import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/ui/content_submission/widgets/content_submission_file_thumbnail.dart';
import 'package:moliseis/ui/core/ui/media/app_network_image.dart';
import 'package:moliseis/ui/core/ui/media/bounded_cover_image.dart';
import 'package:moliseis/ui/core/ui/media/image_error_placeholder.dart';

import '../test/support/image_decode_support.dart';
import '../test/support/network_image_harness.dart';
import '../test/support/test_image_files.dart';
import '../test/support/typography_harness.dart';

/// Native functional compatibility, independently of Profile/device acceptance.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'native local preview preserves actual proportional decode and crop',
    (tester) async {
      final files = TestImageFiles.create();
      addTearDown(files.dispose);
      final file = files.createSizedPng(4000, 3000);
      await tester.pumpWidget(
        typographyHarness(
          child: Scaffold(
            body: Center(child: ContentSubmissionFileThumbnail(file: file)),
          ),
        ),
      );
      final image = tester.widget<Image>(find.byType(Image));
      final frame = await decodeImage(image.image);
      final expected = boundedCoverSize(
        intrinsicWidth: 4000,
        intrinsicHeight: 3000,
        targetWidth: (86 * tester.view.devicePixelRatio).ceil(),
        targetHeight: (86 * tester.view.devicePixelRatio).ceil(),
      );
      expect(
        (frame.image.width, frame.image.height),
        (expected.width, expected.height),
      );
      frame.dispose();
      await tester.pumpAndSettle();
      final rendered = tester.widget<RawImage>(find.byType(RawImage));
      expect(
        (rendered.image!.width, rendered.image!.height),
        (expected.width, expected.height),
      );
      expect(rendered.fit, BoxFit.cover);
      expect(
        tester.getSize(find.byType(ContentSubmissionFileThumbnail)),
        const Size(86, 86),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'native remote failure settles loading with one compact accessible error',
    (tester) async {
      final manager = ControlledImageCacheManager();
      addTearDown(manager.dispose);
      final states = <bool>[];
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        networkImageHarness(
          manager: manager,
          child: SizedBox.square(
            dimension: 32,
            child: AppNetworkImage(
              url: 'https://example.test/native-error.png',
              width: 32,
              height: 32,
              onImageLoading: states.add,
            ),
          ),
        ),
      );
      expect(states, [true]);
      manager.fail(0, StateError('controlled native acquisition failure'));
      await tester.pumpAndSettle();
      expect(states, [true, false]);
      expect(find.bySemanticsLabel('Immagine non disponibile'), findsOneWidget);
      final placeholder = find.byType(ImageErrorPlaceholder);
      final icon = find.descendant(
        of: placeholder,
        matching: find.byType(Icon),
      );
      final bounds = tester.getRect(placeholder);
      final iconBounds = tester.getRect(icon);
      expect(iconBounds.width, greaterThan(0));
      expect(iconBounds.center, bounds.center);
      expect(bounds.intersect(iconBounds), iconBounds);
      expect(find.byType(Scrollable), findsNothing);
      expect(tester.takeException(), isNull);
      semantics.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
