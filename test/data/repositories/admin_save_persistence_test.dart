import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/data/data-sources/admin_submission_draft_entity.dart';
import 'package:moliseis/data/data-sources/admin_submission_staged_asset_entity.dart';
import 'package:moliseis/data/mappers/admin_submission_staged_asset_mapper.dart';
import 'package:moliseis/data/repositories/admin_submission_draft_repository_impl.dart';
import 'package:moliseis/data/repositories/admin_submission_staged_asset_repository_impl.dart';
import 'package:moliseis/domain/models/admin_submission_draft.dart';
import 'package:moliseis/domain/models/admin_submission_staged_asset.dart';
import 'package:moliseis/domain/models/admin_submission_status.dart';
import 'package:moliseis/domain/models/submission_asset.dart';
import 'package:moliseis/domain/use_cases/admin_draft_session.dart';
import 'package:moliseis/generated/objectbox.g.dart';
import 'package:moliseis/utils/result.dart';

import '../../support/mock_logger.dart';
import '../../support/objectbox_test_store.dart';

void main() {
  const account = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
  const attempt = '11111111-1111-4111-8111-111111111111';
  const nextNonce = '22222222-2222-4222-8222-222222222222';
  const token = '2026-10-27T12:00:00.123456+00:00';
  late TestObjectBoxEnvironment env;
  late Directory support;
  late AdminSubmissionDraftRepositoryImpl drafts;
  late AdminSubmissionStagedAssetRepositoryImpl staged;
  late AdminDraftSession session;
  late AdminDraftOwner owner;
  final baseline = AdminRemoteBaseline(
    snapshot: AdminDraftSnapshot(name: 'A'),
    status: AdminSubmissionStatus.pending,
    modifiedAt: DateTime.parse(token),
    modifiedAtToken: token,
  );

  setUp(() async {
    env = await TestObjectBoxEnvironment.create();
    support = await Directory.systemTemp.createTemp('admin_save_persistence_');
    drafts = AdminSubmissionDraftRepositoryImpl(
      objectBoxI: TestObjectBox(env.store),
      logger: MockLogger(),
    );
    staged = AdminSubmissionStagedAssetRepositoryImpl(
      objectBoxI: TestObjectBox(env.store),
      logger: MockLogger(),
      draftRepository: drafts,
      getSupportDirectory: () async => support,
    );
    session = AdminDraftSession(
      draftRepository: drafts,
      stagedAssetRepository: staged,
    );
    owner = AdminDraftOwner(accountId: account);
  });
  tearDown(() async {
    await env.dispose();
    await support.delete(recursive: true);
  });

  test('Create adoption is atomic across retained draft and '
      'files and resumes after reopen', () async {
    await session.activate(owner);
    final activation = session.captureActivation()!;
    session.setSnapshot(AdminDraftSnapshot(name: 'A'), activation: activation);
    final source = await File('${support.path}/source').writeAsBytes([1, 2, 3]);
    final asset =
        (await session.acquire(source, capacity: session.capacityContext)
                as Success<AdminSubmissionStagedAsset>)
            .value;
    final file =
        (await staged.resolveAbsolutePath(asset) as Success<File>).value;
    final rowId = env.store
        .box<AdminSubmissionDraftEntity>()
        .getAll()
        .single
        .id;
    final assetId = env.store
        .box<AdminSubmissionStagedAssetEntity>()
        .getAll()
        .single
        .id;
    await session.beginFieldWrite(
      AdminFieldWriteIntent(
        kind: AdminFieldWriteKind.create,
        attemptId: attempt,
        snapshot: AdminDraftSnapshot(name: 'A'),
      ),
      activation: activation,
      checkpointAtCapture: session.state?.physicalCheckpoint,
    );
    session.setSnapshot(
      AdminDraftSnapshot(name: 'B', latitudeText: '-'),
      activation: activation,
    );
    await session.checkpoint();
    await session.setNavigationIntent(
      activation: activation,
      requestNonce: nextNonce,
    );
    expect(
      await session.adoptRemoteIdentity(
        activation: activation,
        attemptId: attempt,
        submissionId: 42,
        baseline: baseline,
      ),
      isA<Success<void>>(),
    );
    expect(session.state!.current.name, 'B');
    expect(session.state!.physicalCheckpoint!.snapshot.latitudeText, '-');
    expect(session.state!.physicalCheckpoint!.fieldWriteIntent, isNull);
    expect(session.state!.owner.sessionId, owner.sessionId);
    expect(
      session.setSnapshot(
        AdminDraftSnapshot(name: 'stale'),
        activation: activation,
      ),
      isA<Error<void>>(),
    );
    expect(
      env.store.box<AdminSubmissionDraftEntity>().getAll().single.id,
      rowId,
    );
    final descriptor = env.store
        .box<AdminSubmissionStagedAssetEntity>()
        .getAll()
        .single;
    expect(descriptor.id, assetId);
    expect(descriptor.submissionId, 42);
    expect(descriptor.relativePath, asset.relativePath);
    expect(await file.readAsBytes(), [1, 2, 3]);
    env.close();
    final reopened = await openStore(directory: env.directory.path);
    addTearDown(reopened.close);
    final restored = AdminSubmissionDraftRepositoryImpl(
      objectBoxI: TestObjectBox(reopened),
      logger: MockLogger(),
    );
    final draft = (await restored.loadDraftBySession(
      accountId: account,
      sessionId: owner.sessionId,
    )).getOrNull()!;
    expect(draft.owner.submissionId, 42);
    expect(draft.snapshot.name, 'B');
    expect(draft.remoteBaseline!.modifiedAtToken, token);
    expect(draft.navigationIntent!.requestNonce, nextNonce);
    expect((await restored.loadDraft(accountId: account)).getOrNull(), isNull);
    expect(
      (await restored.loadDraftBySession(
        accountId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
        sessionId: owner.sessionId,
      )).getOrNull(),
      isNull,
    );
    expect(
      await restored.adoptRemoteIdentity(
        owner: owner,
        submissionId: 42,
        attemptId: attempt,
        remoteBaseline: baseline,
      ),
      isA<Success<AdminSubmissionDraft>>(),
    );
  });

  for (final conflict in ['destination', 'malformed descriptor']) {
    test(
      'adoption $conflict leaves all old ownership and intent intact',
      () async {
        await session.activate(owner);
        final activation = session.captureActivation()!;
        await session.beginFieldWrite(
          AdminFieldWriteIntent(
            kind: AdminFieldWriteKind.create,
            attemptId: attempt,
            snapshot: AdminDraftSnapshot(name: 'A'),
          ),
          activation: activation,
          checkpointAtCapture: session.state?.physicalCheckpoint,
        );
        final box = env.store.box<AdminSubmissionStagedAssetEntity>();
        final digest = 'a' * 40;
        box.put(
          AdminSubmissionStagedAsset(
            owner: owner,
            digest: digest,
            relativePath: '$account/${owner.sessionId}/$digest',
          ).toEntity(),
        );
        if (conflict == 'destination') {
          await drafts.saveDraft(
            AdminSubmissionDraft(
              owner: AdminDraftOwner(accountId: account, submissionId: 42),
              snapshot: AdminDraftSnapshot(name: 'other work'),
            ),
          );
        } else {
          box.put(
            AdminSubmissionStagedAssetEntity(
              accountId: account,
              sessionId: owner.sessionId,
              submissionId: null,
              digest: 'invalid',
              relativePath: 'invalid',
            ),
          );
        }
        expect(
          await session.adoptRemoteIdentity(
            activation: activation,
            attemptId: attempt,
            submissionId: 42,
            baseline: baseline,
          ),
          isA<Error<void>>(),
        );
        expect(box.getAll().every((row) => row.submissionId == null), isTrue);
        expect(
          (await drafts.loadDraft(
            accountId: account,
          )).getOrNull()!.fieldWriteIntent!.attemptId,
          attempt,
        );
        env.close();
        final reopened = await openStore(directory: env.directory.path);
        addTearDown(reopened.close);
        expect(
          reopened.box<AdminSubmissionStagedAssetEntity>().getAll().every(
            (row) => row.submissionId == null,
          ),
          isTrue,
        );
      },
    );
  }

  test('Update intent survives newer incomplete checkpoint and '
      'settlement preserves it', () async {
    owner = AdminDraftOwner(accountId: account, submissionId: 42);
    await session.activate(owner);
    final activation = session.captureActivation()!;
    final intent = AdminFieldWriteIntent(
      kind: AdminFieldWriteKind.update,
      attemptId: attempt,
      snapshot: AdminDraftSnapshot(name: 'A'),
      expectedModifiedAt: token,
    );
    await session.beginFieldWrite(
      intent,
      activation: activation,
      checkpointAtCapture: session.state?.physicalCheckpoint,
    );
    session.setSnapshot(
      AdminDraftSnapshot(name: 'B', longitudeText: '-'),
      activation: activation,
    );
    await session.checkpoint();
    expect(session.state!.physicalCheckpoint!.fieldWriteIntent, intent);
    expect(
      await session.beginFieldWrite(
        AdminFieldWriteIntent(
          kind: AdminFieldWriteKind.update,
          attemptId: nextNonce,
          snapshot: AdminDraftSnapshot(name: 'B'),
          expectedModifiedAt: token,
        ),
        activation: activation,
        checkpointAtCapture: session.state?.physicalCheckpoint,
      ),
      isA<Error<void>>(),
    );
    expect(
      await session.confirmFieldWrite(
        activation: activation,
        attemptId: attempt,
        baseline: baseline,
      ),
      isA<Success<void>>(),
    );
    expect(session.state!.current.name, 'B');
    expect(session.state!.physicalCheckpoint!.snapshot.longitudeText, '-');
    expect(session.state!.physicalCheckpoint!.fieldWriteIntent, isNull);
    env.close();
    final reopened = await openStore(directory: env.directory.path);
    addTearDown(reopened.close);
    final restored = AdminSubmissionDraftRepositoryImpl(
      objectBoxI: TestObjectBox(reopened),
      logger: MockLogger(),
    );
    final draft = (await restored.loadDraft(
      accountId: account,
      submissionId: 42,
    )).getOrNull()!;
    expect(draft.snapshot.name, 'B');
    expect(draft.remoteBaseline!.modifiedAtToken, token);
    expect(draft.fieldWriteIntent, isNull);
  });

  test('unresolved Create A reopens unchanged while latest '
      'checkpoint B is incomplete', () async {
    await session.activate(owner);
    final activation = session.captureActivation()!;
    final intent = AdminFieldWriteIntent(
      kind: AdminFieldWriteKind.create,
      attemptId: attempt,
      snapshot: AdminDraftSnapshot(name: 'valid A'),
    );
    await session.beginFieldWrite(
      intent,
      activation: activation,
      checkpointAtCapture: session.state?.physicalCheckpoint,
    );
    session.setSnapshot(
      AdminDraftSnapshot(name: '', latitudeText: '-'),
      activation: activation,
    );
    await session.checkpoint();
    env.close();
    final reopened = await openStore(directory: env.directory.path);
    addTearDown(reopened.close);
    final restored = AdminSubmissionDraftRepositoryImpl(
      objectBoxI: TestObjectBox(reopened),
      logger: MockLogger(),
    );
    final draft = (await restored.loadDraft(accountId: account)).getOrNull()!;
    expect(draft.snapshot.latitudeText, '-');
    expect(draft.fieldWriteIntent, intent);
  });

  test('upload and association confirmations are separate '
      'monotone reopened receipts', () async {
    owner = AdminDraftOwner(accountId: account, submissionId: 42);
    await drafts.saveDraft(
      AdminSubmissionDraft(owner: owner, snapshot: AdminDraftSnapshot()),
    );
    final source = await File('${support.path}/source').writeAsBytes([1, 2, 3]);
    final asset =
        (await staged.acquire(owner: owner, source: source, associatedCount: 0)
                as Success<AdminSubmissionStagedAsset>)
            .value;
    final progress = AdminStagedAssetProgress(
      upload: const SubmissionAsset(
        secureUrl: 'https://example.test/a.jpg',
        width: 10,
        height: 20,
      ),
    );
    expect(
      await staged.saveProgress(asset: asset, progress: progress),
      isA<Success<void>>(),
    );
    final rowId = env.store
        .box<AdminSubmissionStagedAssetEntity>()
        .getAll()
        .single
        .id;
    final file =
        (await staged.resolveAbsolutePath(asset) as Success<File>).value;
    await file.delete();
    final confirmed = AdminStagedAssetProgress(
      upload: progress.upload,
      associationId: 7,
    );
    expect(
      await staged.saveProgress(asset: asset, progress: confirmed),
      isA<Success<void>>(),
    );
    expect(
      await staged.saveProgress(asset: asset, progress: progress),
      isA<Error<void>>(),
    );
    env.close();
    final reopened = await openStore(directory: env.directory.path);
    addTearDown(reopened.close);
    final restoredDrafts = AdminSubmissionDraftRepositoryImpl(
      objectBoxI: TestObjectBox(reopened),
      logger: MockLogger(),
    );
    final restored = AdminSubmissionStagedAssetRepositoryImpl(
      objectBoxI: TestObjectBox(reopened),
      logger: MockLogger(),
      draftRepository: restoredDrafts,
      getSupportDirectory: () async => support,
    );
    final assets = (await restored.reconcileAndLoad(owner)).getOrNull()!;
    expect(assets.single.progress, confirmed);
    expect(
      reopened.box<AdminSubmissionStagedAssetEntity>().getAll().single.id,
      rowId,
    );
  });

  test('captured upload source is revalidated after staging', () async {
    await session.activate(owner);
    final source = await File('${support.path}/source').writeAsBytes([1, 2]);
    final asset =
        (await session.acquire(source, capacity: session.capacityContext)
                as Success<AdminSubmissionStagedAsset>)
            .value;
    final file = (await session.resolveAssetFile(asset)).getOrNull()!;
    await file.writeAsBytes([9]);
    expect(await session.resolveAssetFile(asset), isA<Error<File>>());
    expect(env.store.box<AdminSubmissionStagedAssetEntity>().count(), 1);
  });

  test(
    'malformed receipt blocks retry while retaining verified private bytes',
    () async {
      owner = AdminDraftOwner(accountId: account, submissionId: 42);
      await drafts.saveDraft(
        AdminSubmissionDraft(owner: owner, snapshot: AdminDraftSnapshot()),
      );
      final source = await File('${support.path}/source').writeAsBytes([1]);
      final asset =
          (await staged.acquire(
                    owner: owner,
                    source: source,
                    associatedCount: 0,
                  )
                  as Success<AdminSubmissionStagedAsset>)
              .value;
      final box = env.store.box<AdminSubmissionStagedAssetEntity>();
      final row = box.getAll().single;
      box.put(
        AdminSubmissionStagedAssetEntity(
          id: row.id,
          accountId: row.accountId,
          sessionId: row.sessionId,
          submissionId: row.submissionId,
          digest: row.digest,
          relativePath: row.relativePath,
          progressPayload: '{',
        ),
      );
      final restored = (await staged.reconcileAndLoad(
        owner,
      )).getOrNull()!.single;
      expect(restored.progressInvalid, isTrue);
      expect(
        (await staged.resolveAbsolutePath(restored)).getOrNull()!.existsSync(),
        isTrue,
      );
      expect(
        await staged.saveProgress(
          asset: asset,
          progress: AdminStagedAssetProgress(
            upload: const SubmissionAsset(
              secureUrl: 'https://example.test/a.jpg',
              width: 1,
              height: 1,
            ),
          ),
        ),
        isA<Error<void>>(),
      );
    },
  );

  test(
    'navigation replacement is account-scoped and old nonce cannot consume B',
    () async {
      await session.activate(owner);
      final activation = session.captureActivation()!;
      expect(
        await session.setNavigationIntent(
          activation: activation,
          requestNonce: attempt,
        ),
        isA<Success<void>>(),
      );
      expect(
        await session.setNavigationIntent(
          activation: activation,
          requestNonce: nextNonce,
        ),
        isA<Success<void>>(),
      );
      await session.clearNavigationIntent(
        activation: activation,
        requestNonce: attempt,
      );
      expect(
        (await drafts.loadNavigationDraft(
          accountId: account,
        )).getOrNull()!.navigationIntent!.requestNonce,
        nextNonce,
      );
      final other = AdminDraftOwner(accountId: account, submissionId: 42);
      await drafts.saveDraft(
        AdminSubmissionDraft(
          owner: other,
          snapshot: AdminDraftSnapshot(name: 'retained'),
        ),
      );
      await drafts.saveNavigationIntent(owner: other, requestNonce: attempt);
      expect(
        (await drafts.loadDraft(
          accountId: account,
        )).getOrNull()!.navigationIntent,
        isNull,
      );
      expect(
        (await drafts.loadNavigationDraft(
          accountId: account,
        )).getOrNull()!.owner,
        other,
      );
      expect(
        (await drafts.loadDraft(accountId: account)).getOrNull()!.owner,
        owner,
      );
      expect(
        (await drafts.loadNavigationDraft(
          accountId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
        )).getOrNull(),
        isNull,
      );
    },
  );
}
