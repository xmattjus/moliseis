import 'dart:async' show Completer, unawaited;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:moliseis/ui/core/ui/custom_circular_progress_indicator.dart';
import 'package:moliseis/ui/user_contribution/view_models/user_contribution_view_model.dart';
import 'package:moliseis/ui/user_contribution/widgets/user_contribution_media_uploader.dart';

import '../../../support/fake_image_picker.dart';
import '../../../support/fake_repositories.dart';
import '../../../support/mock_logger.dart';

void main() {
  Widget buildTestApp(UserContributionViewModel viewModel) {
    return MaterialApp(
      home: Scaffold(body: UserContributionMediaUploader(viewModel: viewModel)),
    );
  }

  UserContributionViewModel buildViewModel({FakeImagePicker? imagePicker}) {
    return UserContributionViewModel(
      logger: MockLogger(),
      userContributionRepository: FakeUserContributionRepository(),
      imagePicker: imagePicker ?? FakeImagePicker(),
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
        imagePicker: FakeImagePicker(
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
          imagePicker: FakeImagePicker(
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
