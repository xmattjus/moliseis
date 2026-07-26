import 'dart:async' show Completer, unawaited;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:moliseis/ui/content_submission/view_models/content_submission_view_model.dart';
import 'package:moliseis/ui/content_submission/widgets/content_submission_add_asset_form.dart';
import 'package:moliseis/ui/core/ui/custom_circular_progress_indicator.dart';

import '../../../support/fake_image_picker.dart';
import '../../../support/fake_repositories.dart';
import '../../../support/mock_logger.dart';

void main() {
  Widget buildTestApp(ContentSubmissionViewModel viewModel) {
    return MaterialApp(
      home: Scaffold(body: ContentSubmissionAddAssetForm(viewModel: viewModel)),
    );
  }

  ContentSubmissionViewModel buildViewModel({
    FakeImagePicker? imagePicker,
    FakeContentSubmissionDraftRepository? draftRepository,
  }) {
    return ContentSubmissionViewModel(
      logger: MockLogger(),
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
  });
}
