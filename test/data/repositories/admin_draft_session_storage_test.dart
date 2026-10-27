import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/data/data-sources/admin_submission_draft_entity.dart';
import 'package:moliseis/data/repositories/admin_submission_draft_repository_impl.dart';
import 'package:moliseis/data/repositories/admin_submission_staged_asset_repository_impl.dart';
import 'package:moliseis/domain/models/admin_submission_draft.dart';
import 'package:moliseis/domain/models/admin_submission_staged_asset.dart';
import 'package:moliseis/domain/use_cases/admin_draft_session.dart';
import 'package:moliseis/utils/result.dart';

import '../../support/mock_logger.dart';
import '../../support/objectbox_test_store.dart';

void main() {
  for (final corruption in ['missing', 'corrupt', 'failed intake']) {
    test('session publishes durable survivors after $corruption', () async {
      final env = await TestObjectBoxEnvironment.create();
      final support = await Directory.systemTemp.createTemp('admin_session_');
      addTearDown(() async {
        await env.dispose();
        await support.delete(recursive: true);
      });
      final objectbox = TestObjectBox(env.store);
      final drafts = AdminSubmissionDraftRepositoryImpl(
        objectBoxI: objectbox,
        logger: MockLogger(),
      );
      final staged = AdminSubmissionStagedAssetRepositoryImpl(
        objectBoxI: objectbox,
        logger: MockLogger(),
        draftRepository: drafts,
        getSupportDirectory: () async => support,
      );
      final session = AdminDraftSession(
        draftRepository: drafts,
        stagedAssetRepository: staged,
      );
      final owner = AdminDraftOwner(
        accountId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      );
      expect(await session.activate(owner), isA<Success<void>>());
      final firstSource = File('${support.path}/source-a');
      await firstSource.writeAsBytes([1, 2, 3]);
      final first =
          (await session.acquire(firstSource, capacity: session.capacityContext)
                  as Success<AdminSubmissionStagedAsset>)
              .value;
      final file =
          (await staged.resolveAbsolutePath(first) as Success<File>).value;
      if (corruption == 'corrupt') {
        await file.writeAsBytes([9]);
      } else {
        await file.delete();
      }
      final secondSource = File('${support.path}/source-b');
      if (corruption != 'failed intake') {
        await secondSource.writeAsBytes([4, 5]);
      }
      final result = await session.acquire(
        secondSource,
        capacity: session.capacityContext,
      );
      expect(
        session.state!.assets.any((asset) => asset.digest == first.digest),
        isFalse,
      );
      expect(
        await staged.reconcileAndLoad(owner),
        isA<Success<List<AdminSubmissionStagedAsset>>>(),
      );
      if (corruption == 'failed intake') {
        expect(result, isA<Error<AdminSubmissionStagedAsset>>());
        expect(session.state!.assets, isEmpty);
      } else {
        expect(result, isA<Success<AdminSubmissionStagedAsset>>());
        expect(session.state!.assets, [
          (result as Success<AdminSubmissionStagedAsset>).value,
        ]);
      }
      expect(env.store.box<AdminSubmissionDraftEntity>().count(), 1);
      final expectedAssets = session.state!.assets;
      session.revoke();
      final reopened = AdminDraftSession(
        draftRepository: drafts,
        stagedAssetRepository: staged,
      );
      expect(await reopened.activate(owner), isA<Success<void>>());
      expect(reopened.state!.assets, expectedAssets);
    });
  }
}
