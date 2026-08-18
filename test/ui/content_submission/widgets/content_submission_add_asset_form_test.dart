import 'dart:async' show Completer, unawaited;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:moliseis/config/dependencies.dart';
import 'package:moliseis/ui/content_submission/view_models/content_submission_view_model.dart';
import 'package:moliseis/ui/content_submission/widgets/content_submission_add_asset_form.dart';
import 'package:moliseis/ui/core/themes/app_theme_data.dart';
import 'package:moliseis/ui/core/ui/cards/card_base.dart';
import 'package:moliseis/ui/core/ui/custom_circular_progress_indicator.dart';
import 'package:moliseis/utils/constants.dart';
import 'package:moliseis/utils/logging/logging.dart';
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
            body: ContentSubmissionAddAssetForm(viewModel: viewModel),
          ),
        ),
      ),
    );
  }

  ContentSubmissionViewModel buildViewModel({
    FakeImagePicker? imagePicker,
    FakeContentSubmissionDraftRepository? draftRepository,
    MockLogger? logger,
  }) {
    return ContentSubmissionViewModel(
      logger: logger ?? MockLogger(),
      contentSubmissionRepository: FakeContentSubmissionRepository(),
      draftRepository:
          draftRepository ?? FakeContentSubmissionDraftRepository(),
      imagePicker: imagePicker ?? FakeImagePicker(),
    );
  }

  group('ContentSubmissionAddAssetForm', () {
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
        await tester.tap(find.byType(CardBase));
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
      await tester.tap(find.byType(CardBase));
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
      await tester.tap(find.byType(CardBase));
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

    testWidgets('does not show a warning when every selected image is valid', (
      tester,
    ) async {
      final imageFiles = TestImageFiles.create();
      addTearDown(imageFiles.dispose);
      final file = imageFiles.createPng(name: 'valid.png');
      final logger = MockLogger();
      final vm = buildViewModel(
        logger: logger,
        imagePicker: FakeImagePicker(
          onPickMultipleMedia: () async => [file],
        ),
      );

      await tester.pumpWidget(buildTestApp(vm, logger: logger));
      await tester.tap(find.byType(CardBase));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(vm.assets, hasLength(1));
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
