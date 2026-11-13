import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/domain/models/admin_submission_staged_asset.dart';
import 'package:moliseis/domain/models/submission_asset.dart';
import 'package:moliseis/ui/admin/submissions/widgets/admin_submission_media_section.dart';
import 'package:moliseis/ui/core/utils/content_submission_asset_size.dart';
import 'package:moliseis/utils/result.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../../../support/admin_editor_interactions.dart';
import '../../../../support/admin_media_app.dart';
import '../../../../support/admin_save_route_harness.dart';
import '../../../../support/command_test_support.dart';
import '../../../../support/test_image_files.dart';

void main() {
  late AdminSaveRouteHarness harness;
  late TestImageFiles files;
  setUp(() => files = TestImageFiles.create());
  tearDown(() => files.dispose());

  testOwnerUI('real editor retains resolution across edits, notifications '
      'and upload receipts', (tester) async {
    harness = AdminSaveRouteHarness(persistedTargets: [1]);
    final owner = harness.local.drafts.drafts.values.single.owner;
    final asset = AdminSubmissionStagedAsset(
      owner: owner,
      digest: 'a' * 40,
      relativePath: '${owner.accountId}/${owner.sessionId}/${'a' * 40}',
    );
    harness.local.staged.assets[owner] = [asset];
    final file = File(files.createPng().path);
    var resolutions = 0;
    harness.local.staged.onResolve = (_) async {
      resolutions++;
      return Result.success(file);
    };
    await harness.openEditor(tester, target: 1);
    await revealAdminEditorWidget(tester, find.text('Foto'));
    expect(resolutions, 1);
    final image = find.descendant(
      of: find.byType(AdminSubmissionMediaSection),
      matching: find.byType(Image),
    );
    expect(image, findsOneWidget);
    expect(
      find.ancestor(of: image, matching: find.byType(SentryMask)),
      findsOneWidget,
    );
    for (var edit = 0; edit < 3; edit++) {
      final activation = harness.owner.activation;
      harness.owner.setName('Title $edit', activation: activation);
      harness.owner.setCity('City $edit', activation: activation);
      harness.owner.setDescription(
        description: 'Description $edit',
        descriptionDelta: null,
        activation: activation,
      );
      harness.owner.setCandidateSearch('Query $edit', activation: activation);
      await tester.pump();
    }
    expect(resolutions, 1);
    expect(
      await harness.local.session.saveAssetProgress(
        asset,
        AdminStagedAssetProgress(
          upload: const SubmissionAsset(
            secureUrl: 'https://example.com/confirmed.jpg',
            width: 4000,
            height: 3000,
          ),
        ),
        activation: harness.owner.activation!,
      ),
      isA<Success<void>>(),
    );
    harness.owner.setCandidateSearch(
      'Notification after receipt',
      activation: harness.owner.activation,
    );
    await tester.pump();
    expect(harness.owner.stagedAssets.single.progress, isNotNull);
    expect(resolutions, 1);
    expect(tester.takeException(), isNull);
  }, disposeOwners: () => harness.dispose());

  for (final dpr in [1.0, 2.0, 3.0]) {
    testOwnerUI('staged thumbnail requests physical decode size at DPR $dpr', (
      tester,
    ) async {
      harness = AdminSaveRouteHarness(persistedTargets: [1]);
      final owner = harness.local.drafts.drafts.values.single.owner;
      final asset = AdminSubmissionStagedAsset(
        owner: owner,
        digest: 'a' * 40,
        relativePath: '${owner.accountId}/${owner.sessionId}/${'a' * 40}',
      );
      harness.local.staged.assets[owner] = [asset];
      harness.local.staged.onResolve = (_) async =>
          Result.success(File(files.createPng().path));
      await harness.openEditor(tester, target: 1);
      tester.view.devicePixelRatio = dpr;
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(adminMediaApp(harness.owner));
      await tester.pumpAndSettle();
      final image = tester.widget<Image>(find.byType(Image));
      final resize = image.image as ResizeImage;
      expect(resize.width, (86 * dpr).ceil());
      expect(resize.height, (86 * dpr).ceil());
      expect(resize.policy, ResizeImagePolicy.fit);
      expect(image.width, contentSubmissionAssetSize.width);
      expect(image.height, contentSubmissionAssetSize.height);
      expect(image.fit, BoxFit.cover);
      expect(resize.width, lessThan(300));
      expect(tester.takeException(), isNull);
    }, disposeOwners: () => harness.dispose());
  }

  testOwnerUI('failed preview retries only explicitly and removal evicts it', (
    tester,
  ) async {
    harness = AdminSaveRouteHarness(persistedTargets: [1]);
    final owner = harness.local.drafts.drafts.values.single.owner;
    final asset = AdminSubmissionStagedAsset(
      owner: owner,
      digest: 'a' * 40,
      relativePath: '${owner.accountId}/${owner.sessionId}/${'a' * 40}',
    );
    harness.local.staged.assets[owner] = [asset];
    var resolutions = 0;
    final file = File(files.createPng().path);
    harness.local.staged.onResolve = (_) async {
      resolutions++;
      return resolutions == 1
          ? Result.error(Exception('Recoverable preview failure'))
          : Result.success(file);
    };
    await harness.openEditor(tester, target: 1);
    await revealAdminEditorWidget(tester, find.text('Foto'));
    final retry = find.byTooltip('Riprova anteprima foto');
    await revealAdminEditorWidget(tester, retry);
    expect(retry.hitTestable(), findsOneWidget);
    expect(find.byIcon(Icons.image), findsOneWidget);
    final removeTarget = find.byWidgetPredicate(
      (widget) => widget is Tooltip && widget.message == 'Rimuovi foto',
    );
    expect(
      tester.getRect(retry).overlaps(tester.getRect(removeTarget)),
      isFalse,
    );

    expect(
      tester.getSize(find.widgetWithIcon(IconButton, Icons.refresh)).height,
      greaterThanOrEqualTo(48),
    );
    harness.owner.setCandidateSearch(
      'Unrelated',
      activation: harness.owner.activation,
    );
    await tester.pump();
    expect(resolutions, 1);
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(resolutions, 2);
    expect(retry, findsNothing);
    final remove = find.byWidgetPredicate(
      (widget) => widget is Tooltip && widget.message == 'Rimuovi foto',
    );
    await revealAdminEditorWidget(tester, remove);
    await tester.tap(remove);
    await tester.pumpAndSettle();
    expect(harness.owner.stagedAssets, isEmpty);
    expect(harness.local.staged.removals.single.digest, asset.digest);
    expect(find.byType(Image), findsNothing);
    expect(resolutions, 2);
  }, disposeOwners: () => harness.dispose());

  testOwnerUI(
    'replacement file resolves independently and ignores obsolete completion',
    (tester) async {
      harness = AdminSaveRouteHarness(persistedTargets: [1]);
      final owner = harness.local.drafts.drafts.values.single.owner;
      final asset = AdminSubmissionStagedAsset(
        owner: owner,
        digest: 'a' * 40,
        relativePath: '${owner.accountId}/${owner.sessionId}/${'a' * 40}',
      );
      harness.local.staged.assets[owner] = [asset];
      final old = Completer<Result<File>>();
      final resolved = <String>[];
      final replacementFile = File(files.createPng().path);
      harness.local.staged.onResolve = (asset) {
        resolved.add(asset.digest);
        return asset.digest == 'a' * 40
            ? old.future
            : Future.value(Result.success(replacementFile));
      };
      await harness.openEditor(tester, target: 1);
      await revealAdminEditorWidget(tester, find.text('Foto'));
      await tester.pumpWidget(adminMediaApp(harness.owner));
      await tester.pump();
      expect(await harness.local.session.remove(asset), isA<Success<void>>());
      final replacement = AdminSubmissionStagedAsset(
        owner: owner,
        digest: 'b' * 40,
        relativePath: '${owner.accountId}/${owner.sessionId}/${'b' * 40}',
      );
      harness.local.staged.onAcquire = (_, _) async =>
          Result.success(replacement);
      expect(
        await harness.local.session.acquire(
          replacementFile,
          capacity: harness.local.session.capacityContext,
        ),
        isA<Success<AdminSubmissionStagedAsset>>(),
      );
      harness.owner.setCandidateSearch(
        'Replacement',
        activation: harness.owner.activation,
      );
      await tester.pumpAndSettle();
      expect(resolved.last, replacement.digest);
      expect(
        resolved.where((digest) => digest == replacement.digest),
        hasLength(1),
      );
      final oldFile = File(files.createPng().path);
      old.complete(Result.success(oldFile));
      await tester.pumpAndSettle();
      final resize =
          tester.widget<Image>(find.byType(Image)).image as ResizeImage;
      expect(
        (resize.imageProvider as FileImage).file.path,
        replacementFile.path,
      );
      expect(tester.takeException(), isNull);
    },
    disposeOwners: () => harness.dispose(),
  );

  testOwnerUI(
    'same file re-resolves after activation replacement without stale pixels',
    (tester) async {
      harness = AdminSaveRouteHarness(persistedTargets: [1]);
      final owner = harness.local.drafts.drafts.values.single.owner;
      final asset = AdminSubmissionStagedAsset(
        owner: owner,
        digest: 'a' * 40,
        relativePath: '${owner.accountId}/${owner.sessionId}/${'a' * 40}',
      );
      harness.local.staged.assets[owner] = [asset];
      final old = Completer<Result<File>>();
      final current = Completer<Result<File>>();
      var resolutions = 0;
      harness.local.staged.onResolve = (_) {
        resolutions++;
        return resolutions == 1 ? old.future : current.future;
      };
      await harness.openEditor(tester, target: 1);
      await revealAdminEditorWidget(tester, find.text('Foto'));
      await tester.pumpWidget(adminMediaApp(harness.owner));
      await tester.pump();
      final previous = harness.owner.activation!;
      harness.owner.revoke();
      expect(
        await harness.owner.activate(
          accountId: owner.accountId,
          submissionId: owner.submissionId,
          sessionId: owner.sessionId,
        ),
        isA<Success<void>>(),
      );
      await tester.pump();
      expect(harness.owner.activation!.generation, isNot(previous.generation));
      final beforeCurrent = resolutions;
      expect(beforeCurrent, greaterThan(1));
      old.complete(Result.success(File(files.createPng().path)));
      await tester.pump();
      expect(find.byType(Image), findsNothing);
      final file = File(files.createPng().path);
      current.complete(Result.success(file));
      await tester.pumpAndSettle();
      final resize =
          tester.widget<Image>(find.byType(Image)).image as ResizeImage;
      expect((resize.imageProvider as FileImage).file.path, file.path);
      expect(resolutions, beforeCurrent);
      expect(tester.takeException(), isNull);
    },
    disposeOwners: () => harness.dispose(),
  );

  for (final completed in [false, true]) {
    testOwnerUI(
      'different editor owner rejects previous preview (completed: $completed)',
      (tester) async {
        harness = AdminSaveRouteHarness(persistedTargets: [1]);
        final replacement = AdminSaveRouteHarness(persistedTargets: [1]);
        final originalOwner = harness.local.drafts.drafts.values.single.owner;
        final replacementOwner =
            replacement.local.drafts.drafts.values.single.owner;
        for (final entry in [
          (harness, originalOwner),
          (replacement, replacementOwner),
        ]) {
          entry.$1.local.staged.assets[entry.$2] = [
            AdminSubmissionStagedAsset(
              owner: entry.$2,
              digest: 'a' * 40,
              relativePath:
                  '${entry.$2.accountId}/${entry.$2.sessionId}/${'a' * 40}',
            ),
          ];
        }
        final firstFile = File(files.createPng().path);
        final previous = Completer<Result<File>>();
        harness.local.staged.onResolve = (_) => completed
            ? Future.value(Result.success(firstFile))
            : previous.future;
        final next = Completer<Result<File>>();
        var replacementResolutions = 0;
        replacement.local.staged.onResolve = (_) {
          replacementResolutions++;
          return next.future;
        };
        try {
          await harness.openEditor(tester, target: 1);
          await tester.pumpWidget(adminMediaApp(harness.owner));
          await tester.pumpAndSettle();
          expect(find.byType(Image), completed ? findsOneWidget : findsNothing);
          expect(
            await replacement.owner.activate(
              accountId: replacementOwner.accountId,
              submissionId: replacementOwner.submissionId,
              sessionId: replacementOwner.sessionId,
            ),
            isA<Success<void>>(),
          );
          await tester.pumpWidget(adminMediaApp(replacement.owner));
          await tester.pump();
          expect(replacementResolutions, 1);
          expect(find.byType(Image), findsNothing);
          if (!completed) {
            previous.complete(Result.success(firstFile));
            await tester.pump();
            expect(find.byType(Image), findsNothing);
          }
          final nextFile = File(files.createPng().path);
          next.complete(Result.success(nextFile));
          await tester.pumpAndSettle();
          final resize =
              tester.widget<Image>(find.byType(Image)).image as ResizeImage;
          expect((resize.imageProvider as FileImage).file.path, nextFile.path);
          expect(replacementResolutions, 1);
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          replacement.dispose();
          await pumpCommandTurns(tester);
          await tester.pump(const Duration(milliseconds: 50));
        }
      },
      disposeOwners: () => harness.dispose(),
    );
  }
}
