import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/ui/content_submission/widgets/content_submission_file_thumbnail.dart';
import 'package:moliseis/ui/core/utils/content_submission_asset_size.dart';

import '../../../support/test_image_files.dart';
import '../../../support/typography_harness.dart';

void main() {
  for (final dpr in [1.0, 2.0, 3.0]) {
    testWidgets('public and admin staged preview respects aspect at DPR $dpr', (
      tester,
    ) async {
      final files = TestImageFiles.create();
      addTearDown(files.dispose);
      tester.view.devicePixelRatio = dpr;
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        typographyHarness(
          child: Scaffold(
            body: Center(
              child: ContentSubmissionFileThumbnail(
                file: File(files.createPng().path),
              ),
            ),
          ),
        ),
      );
      final preview = tester.widget<Image>(find.byType(Image));
      final provider = preview.image as ResizeImage;
      expect(provider.width, (86 * dpr).ceil());
      expect(provider.height, (86 * dpr).ceil());
      expect(provider.policy, ResizeImagePolicy.fit);
      expect(provider.imageProvider, isA<FileImage>());
      expect(preview.width, contentSubmissionAssetSize.width);
      expect(preview.height, contentSubmissionAssetSize.height);
      expect(preview.fit, BoxFit.cover);
      expect(tester.takeException(), isNull);
    });
  }
}
