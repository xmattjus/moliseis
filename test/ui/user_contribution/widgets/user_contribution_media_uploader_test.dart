import 'dart:async' show Completer, unawaited;
import 'dart:io' show File;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:moliseis/data/data-sources/user_contribution.dart';
import 'package:moliseis/domain/repositories/user_contribution_repository.dart';
import 'package:moliseis/ui/core/ui/custom_circular_progress_indicator.dart';
import 'package:moliseis/ui/user_contribution/view_models/user_contribution_view_model.dart';
import 'package:moliseis/ui/user_contribution/widgets/user_contribution_media_uploader.dart';
import 'package:moliseis/utils/result.dart';

import '../../../support/mock_logger.dart';

void main() {
  Widget buildTestApp(UserContributionViewModel viewModel) {
    return MaterialApp(
      home: Scaffold(body: UserContributionMediaUploader(viewModel: viewModel)),
    );
  }

  UserContributionViewModel buildViewModel({_FakeImagePicker? imagePicker}) {
    return UserContributionViewModel(
      logger: MockLogger(),
      userContributionRepository: _FakeUserContributionRepository(),
      imagePicker: imagePicker ?? _FakeImagePicker(),
    );
  }

  group('UserContributionMediaUploader', () {
    testWidgets('shows add-photo button when idle with no media', (
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
        imagePicker: _FakeImagePicker(
          onPickMultipleMedia: () => completer.future,
        ),
      );

      // Execute without awaiting so the command stays in the running state.
      unawaited(vm.addMedia.execute());

      await tester.pumpWidget(buildTestApp(vm));

      expect(find.byType(CustomCircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(Symbols.add_a_photo), findsNothing);

      // Resolve the picker and allow the widget to settle.
      completer.complete([]);
      await tester.pumpAndSettle();

      expect(find.byType(CustomCircularProgressIndicator), findsNothing);
      expect(find.byIcon(Symbols.add_a_photo), findsOneWidget);
    });

    testWidgets('shows spinner while retrieveLostMedia is running', (
      tester,
    ) async {
      // testWidgets calls _verifyInvariants before addTearDown fires, so the
      // platform override must be cleared inside the test body via try/finally.
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        final completer = Completer<LostDataResponse>();
        final vm = buildViewModel(
          imagePicker: _FakeImagePicker(
            onRetrieveLostData: () => completer.future,
          ),
        );

        // Execute without awaiting so the command stays in the running state.
        unawaited(vm.retrieveLostMedia.execute());

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

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

final class _FakeImagePicker extends ImagePicker {
  _FakeImagePicker({this.onPickMultipleMedia, this.onRetrieveLostData});

  final Future<List<XFile>> Function()? onPickMultipleMedia;
  final Future<LostDataResponse> Function()? onRetrieveLostData;

  @override
  Future<List<XFile>> pickMultipleMedia({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    int? limit,
    bool requestFullMetadata = true,
  }) async => onPickMultipleMedia != null ? await onPickMultipleMedia!() : [];

  @override
  Future<LostDataResponse> retrieveLostData() async =>
      onRetrieveLostData != null
      ? await onRetrieveLostData!()
      : LostDataResponse.empty();
}

final class _FakeUserContributionRepository
    implements UserContributionRepository {
  @override
  Future<Result<dynamic>> upload(UserContribution userContribution) async =>
      const Result.success(null);

  @override
  Future<Result<String>> uploadImage(File image) async =>
      const Result.success('https://example.com/image.jpg');
}
