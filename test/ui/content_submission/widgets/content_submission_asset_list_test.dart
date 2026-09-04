import 'dart:async' show Completer, unawaited;
import 'dart:io' show Directory, File;

import 'package:crypto/crypto.dart' show sha1;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:moliseis/config/dependencies.dart';
import 'package:moliseis/domain/models/content_submission_draft.dart';
import 'package:moliseis/domain/models/content_submission_staged_asset.dart';
import 'package:moliseis/ui/content_submission/view_models/content_submission_view_model.dart';
import 'package:moliseis/ui/content_submission/widgets/content_submission_asset_list.dart';
import 'package:moliseis/ui/content_submission/widgets/content_submission_asset_list_item.dart';
import 'package:moliseis/ui/core/themes/app_theme_data.dart';
import 'package:moliseis/ui/core/ui/custom_circular_progress_indicator.dart';
import 'package:moliseis/ui/core/ui/empty_box.dart';
import 'package:moliseis/utils/constants.dart';
import 'package:moliseis/utils/logging/logging.dart';
import 'package:moliseis/utils/result.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../../support/fake_image_picker.dart';
import '../../../support/fake_repositories.dart';
import '../../../support/mock_logger.dart';
import '../../../support/test_image_files.dart';

void main() {
  Widget buildTestApp(
    ContentSubmissionViewModel viewModel, {
    MockLogger? logger,
  }) {
    return Provider<Logger>.value(
      value: logger ?? MockLogger(),
      child: Builder(
        builder: (context) => MaterialApp(
          scaffoldMessengerKey: $scaffoldMessengerKey,
          theme: AppThemeData.light(context: context),
          home: Scaffold(
            body: ContentSubmissionAssetList(viewModel: viewModel),
          ),
        ),
      ),
    );
  }

  ContentSubmissionViewModel buildViewModel({
    FakeImagePicker? imagePicker,
    FakeContentSubmissionDraftRepository? draftRepository,
    FakeContentSubmissionStagedAssetRepository? stagedAssetRepository,
    MockLogger? logger,
  }) {
    return ContentSubmissionViewModel(
      logger: logger ?? MockLogger(),
      contentSubmissionRepository: FakeContentSubmissionRepository(),
      draftRepository:
          draftRepository ?? FakeContentSubmissionDraftRepository(),
      stagedAssetRepository:
          stagedAssetRepository ?? FakeContentSubmissionStagedAssetRepository(),
      imagePicker: imagePicker ?? FakeImagePicker(),
    );
  }

  group('ContentSubmissionAssetList', () {
    testWidgets('shows add-photo button when idle with no asset', (
      tester,
    ) async {
      final vm = buildViewModel();

      await tester.pumpWidget(buildTestApp(vm));

      expect(find.byIcon(Symbols.add_a_photo), findsOneWidget);
      expect(find.byType(CustomCircularProgressIndicator), findsNothing);
    });

    testWidgets('shows spinner while addMedia is running', (tester) async {
      final completer = Completer<List<XFile>>();
      final vm = buildViewModel(
        imagePicker: FakeImagePicker(
          onPickMultipleMedia: () => completer.future,
        ),
      );

      // Execute without awaiting so the command stays in the running state.
      unawaited(vm.addAsset.execute());

      await tester.pumpWidget(buildTestApp(vm));

      expect(find.byType(CustomCircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(Symbols.add_a_photo), findsNothing);

      // Resolve the picker and allow the widget to settle.
      completer.complete([]);
      await tester.pumpAndSettle();

      expect(find.byType(CustomCircularProgressIndicator), findsNothing);
      expect(find.byIcon(Symbols.add_a_photo), findsOneWidget);
    });

    testWidgets('shows spinner while retrieveLostAssets is running', (
      tester,
    ) async {
      // testWidgets calls _verifyInvariants before addTearDown fires, so the
      // platform override must be cleared inside the test body via try/finally.
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        final completer = Completer<LostDataResponse>();
        final vm = buildViewModel(
          imagePicker: FakeImagePicker(
            onRetrieveLostData: () => completer.future,
          ),
        );

        // Execute without awaiting so the command stays in the running state.
        unawaited(vm.retrieveLostAssets.execute());

        await tester.pumpWidget(buildTestApp(vm));

        expect(find.byType(CustomCircularProgressIndicator), findsOneWidget);
        expect(find.byIcon(Symbols.add_a_photo), findsNothing);

        // Resolve the recovery and allow the widget to settle.
        completer.complete(LostDataResponse.empty());
        await tester.pumpAndSettle();

        expect(find.byType(CustomCircularProgressIndicator), findsNothing);
        expect(find.byIcon(Symbols.add_a_photo), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets(
      'shows a warning snack bar on file size limit reached',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        const message = 'Le foto oltre i 10 MB sono state escluse';
        const rejectedName = 'oversized-secret.png';
        final logger = MockLogger();
        final vm = buildViewModel(
          logger: logger,
          imagePicker: FakeImagePicker(
            onPickMultipleMedia: () async => [
              XFile.fromData(
                Uint8List.fromList([1]),
                path: '/tmp/$rejectedName',
                length: kCloudinaryMaxUploadBytes + 1,
              ),
            ],
          ),
        );

        await tester.pumpWidget(buildTestApp(vm, logger: logger));
        await tester.tap(
          find.byKey(
            const ValueKey('content-submission-asset-list-add-button'),
          ),
        );
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));

        expect(find.byType(SnackBar), findsOneWidget);
        expect(find.byIcon(Symbols.warning), findsOneWidget);
        expect(find.text(message), findsOneWidget);
        expect(find.text(rejectedName), findsNothing);
        final text = tester.widget<Text>(find.text(message));
        expect(text.maxLines, 2);
        expect(text.overflow, TextOverflow.ellipsis);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('shows a warning snack bar on assets number limit reached and '
        'hides add photo', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const message = 'Le foto oltre il limite di 5 sono state escluse';
      final imageFiles = TestImageFiles.create();
      addTearDown(imageFiles.dispose);
      final selectedFiles = List<XFile>.generate(
        ContentSubmissionViewModel.maximumAssetCount + 1,
        (index) => imageFiles.createPng(name: 'count-$index.png'),
      );
      final logger = MockLogger();
      final vm = buildViewModel(
        logger: logger,
        imagePicker: FakeImagePicker(
          onPickMultipleMedia: () async => selectedFiles,
        ),
      );

      await tester.pumpWidget(buildTestApp(vm, logger: logger));
      await tester.tap(
        find.byKey(const ValueKey('content-submission-asset-list-add-button')),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.byIcon(Symbols.warning), findsOneWidget);
      expect(find.text(message), findsOneWidget);
      expect(
        vm.assets,
        hasLength(ContentSubmissionViewModel.maximumAssetCount),
      );
      expect(find.byIcon(Symbols.add_a_photo), findsNothing);
      final text = tester.widget<Text>(find.text(message));
      expect(text.maxLines, 2);
      expect(text.overflow, TextOverflow.ellipsis);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows a combined asset rejection warning snack bar', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const sizeMessage = 'Le foto oltre i 10 MB sono state escluse';
      const countMessage = 'Le foto oltre il limite di 5 sono state escluse';
      const combinedMessage =
          'Le foto oltre i 10 MB o il limite di 5 sono state escluse';
      final imageFiles = TestImageFiles.create();
      addTearDown(imageFiles.dispose);
      final validFiles = List<XFile>.generate(
        ContentSubmissionViewModel.maximumAssetCount,
        (index) => imageFiles.createPng(name: 'combined-$index.png'),
      );
      final logger = MockLogger();
      final vm = buildViewModel(
        logger: logger,
        imagePicker: FakeImagePicker(
          onPickMultipleMedia: () async => [
            XFile.fromData(
              Uint8List.fromList([1]),
              path: '/tmp/combined-oversized.png',
              length: kCloudinaryMaxUploadBytes + 1,
            ),
            ...validFiles,
          ],
        ),
      );

      await tester.pumpWidget(buildTestApp(vm, logger: logger));
      await tester.tap(
        find.byKey(const ValueKey('content-submission-asset-list-add-button')),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.byIcon(Symbols.warning), findsOneWidget);
      expect(find.text(combinedMessage), findsOneWidget);
      expect(find.text(sizeMessage), findsNothing);
      expect(find.text(countMessage), findsNothing);
      final text = tester.widget<Text>(find.text(combinedMessage));
      expect(text.maxLines, 2);
      expect(text.overflow, TextOverflow.ellipsis);

      await tester.pump(const Duration(seconds: 3));
      // Expose any queued follow-up without advancing through its full timer.
      $scaffoldMessengerKey.currentState!.removeCurrentSnackBar();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text(combinedMessage), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders a selected thumbnail from its staged file', (
      tester,
    ) async {
      final imageFiles = TestImageFiles.create();
      addTearDown(imageFiles.dispose);
      final pickerFile = imageFiles.createPng(name: 'valid.png');
      final stagingDirectory = Directory.systemTemp.createTempSync(
        'content_submission_widget_staging_',
      );
      addTearDown(() => stagingDirectory.deleteSync(recursive: true));
      final stagedRepository = FakeContentSubmissionStagedAssetRepository(
        stagingDirectory: stagingDirectory,
      );
      final logger = MockLogger();
      final vm = buildViewModel(
        logger: logger,
        stagedAssetRepository: stagedRepository,
        imagePicker: FakeImagePicker(
          onPickMultipleMedia: () async => [pickerFile],
        ),
      );

      await tester.pumpWidget(buildTestApp(vm, logger: logger));
      await tester.tap(
        find.byKey(const ValueKey('content-submission-asset-list-add-button')),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(vm.assets, hasLength(1));
      final stagedPath = vm.assets.single.file.path;
      expect(stagedPath, isNot(pickerFile.path));
      expect(p.isWithin(stagingDirectory.path, stagedPath), isTrue);
      expect(File(stagedPath).existsSync(), isTrue);
      expect(
        File(stagedPath).readAsBytesSync(),
        File(pickerFile.path).readAsBytesSync(),
      );
      expect(find.byType(ContentSubmissionAssetListItem), findsOneWidget);
      final renderedImage = tester.widget<Image>(find.byType(Image));
      expect(renderedImage.image, isA<ResizeImage>());
      final fileImage = (renderedImage.image as ResizeImage).imageProvider;
      expect(fileImage, isA<FileImage>());
      expect((fileImage as FileImage).file.path, stagedPath);
      expect(find.byType(SnackBar), findsNothing);
      await tester.pump(const Duration(milliseconds: 250));
      expect(tester.takeException(), isNull);
    });

    testWidgets('hides add photo after restoring five staged assets', (
      tester,
    ) async {
      const identity = '2a1b0c3d-4e5f-4a6b-8c9d-0e1f2a3b4c5d';
      final imageFiles = TestImageFiles.create();
      addTearDown(imageFiles.dispose);
      final stagingDirectory = Directory.systemTemp.createTempSync(
        'content_submission_widget_restored_',
      );
      addTearDown(() => stagingDirectory.deleteSync(recursive: true));
      final descriptors = <ContentSubmissionStagedAsset>[];
      for (
        var index = 0;
        index < ContentSubmissionViewModel.maximumAssetCount;
        index++
      ) {
        final validImage = imageFiles.createPng(name: 'restored-$index.png');
        final bytes = File(validImage.path).readAsBytesSync();
        final digest = sha1.convert(bytes).toString();
        final relativePath = '$identity/$digest';
        final stagedFile = File(p.join(stagingDirectory.path, relativePath));
        stagedFile.parent.createSync(recursive: true);
        stagedFile.writeAsBytesSync(bytes);
        descriptors.add(
          ContentSubmissionStagedAsset(
            clientSubmissionId: identity,
            digest: digest,
            relativePath: relativePath,
          ),
        );
      }
      final vm = buildViewModel(
        draftRepository: FakeContentSubmissionDraftRepository(
          loadDraftResult: Result.success(
            ContentSubmissionDraft(clientSubmissionId: identity),
          ),
        ),
        stagedAssetRepository: FakeContentSubmissionStagedAssetRepository(
          reconcileResult: Result.success(descriptors),
          stagingDirectory: stagingDirectory,
        ),
      );

      await vm.initialize();
      await tester.pumpWidget(buildTestApp(vm));
      await tester.drag(find.byType(ListView), const Offset(-2000, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(
        vm.assets,
        hasLength(ContentSubmissionViewModel.maximumAssetCount),
      );
      expect(
        vm.assets.map((asset) => asset.file.path),
        everyElement(startsWith('${stagingDirectory.path}${p.separator}')),
      );
      expect(
        vm.assets.map((asset) => File(asset.file.path).existsSync()),
        everyElement(isTrue),
      );
      expect(
        find.byKey(
          const ValueKey('content-submission-asset-list-add-button'),
        ),
        findsNothing,
      );
      expect(find.byType(EmptyBox), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
