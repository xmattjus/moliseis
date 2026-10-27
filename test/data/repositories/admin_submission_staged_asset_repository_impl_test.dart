import 'dart:io';

import 'package:crypto/crypto.dart' show sha1;
import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/data/data-sources/admin_submission_draft_entity.dart';
import 'package:moliseis/data/data-sources/admin_submission_staged_asset_entity.dart';
import 'package:moliseis/data/data-sources/content_submission_staged_asset_entity.dart';
import 'package:moliseis/data/mappers/admin_submission_staged_asset_mapper.dart';
import 'package:moliseis/data/repositories/admin_submission_draft_repository_impl.dart';
import 'package:moliseis/data/repositories/admin_submission_staged_asset_repository_impl.dart';
import 'package:moliseis/data/repositories/content_submission_draft_repository_impl.dart';
import 'package:moliseis/data/repositories/content_submission_staged_asset_repository_impl.dart';
import 'package:moliseis/domain/models/admin_submission_draft.dart';
import 'package:moliseis/domain/models/admin_submission_staged_asset.dart';
import 'package:moliseis/domain/models/content_submission_draft.dart';
import 'package:moliseis/generated/objectbox.g.dart';
import 'package:moliseis/utils/constants.dart';
import 'package:moliseis/utils/result.dart';

import '../../support/admin_staged_file_source.dart';
import '../../support/mock_logger.dart';
import '../../support/objectbox_test_store.dart';

void main() {
  late TestObjectBoxEnvironment environment;
  late Directory support;
  late MockLogger logger;
  late AdminSubmissionDraftRepositoryImpl drafts;
  late AdminSubmissionStagedAssetRepositoryImpl repository;
  late AdminDraftOwner owner;
  late File source;

  setUp(() async {
    environment = await TestObjectBoxEnvironment.create();
    support = await Directory.systemTemp.createTemp('admin_staging_');
    logger = MockLogger();
    drafts = AdminSubmissionDraftRepositoryImpl(
      logger: logger,
      objectBoxI: TestObjectBox(environment.store),
    );
    repository = AdminSubmissionStagedAssetRepositoryImpl(
      logger: logger,
      objectBoxI: TestObjectBox(environment.store),
      draftRepository: drafts,
      getSupportDirectory: () async => support,
    );
    owner = AdminDraftOwner(accountId: '10000000-0000-4000-8000-000000000001');
    expect(
      await drafts.saveDraft(
        AdminSubmissionDraft(owner: owner, snapshot: AdminDraftSnapshot()),
      ),
      isA<Success<void>>(),
    );
    source = File('${support.path}/source')..writeAsBytesSync([1, 2, 3]);
  });
  tearDown(() async {
    await environment.dispose();
    await support.delete(recursive: true);
  });

  test(
    'private copy survives source loss and duplicate consumes no capacity',
    () async {
      final asset = (await repository.acquire(
        owner: owner,
        source: source,
        associatedCount: 0,
      )).getOrNull()!;
      expect(
        asset.relativePath,
        '${owner.accountId}/${owner.sessionId}/${asset.digest}',
      );
      expect(
        (await repository.acquire(
          owner: owner,
          source: source,
          associatedCount: 0,
        )).getOrNull(),
        asset,
      );
      await source.delete();
      final file = (await repository.resolveAbsolutePath(asset)).getOrNull()!;
      expect(await file.readAsBytes(), [1, 2, 3]);
      expect((await repository.reconcileAndLoad(owner)).getOrNull(), [asset]);
      expect(
        environment.store.box<AdminSubmissionStagedAssetEntity>().count(),
        1,
      );
    },
  );

  test(
    'missing, wrong and unreadable owners cannot acquire or create substitute',
    () async {
      final foreign = AdminDraftOwner(
        accountId: owner.accountId,
        submissionId: 9,
      );
      expect(
        await repository.acquire(
          owner: foreign,
          source: source,
          associatedCount: 0,
        ),
        isA<Error<AdminSubmissionStagedAsset>>(),
      );
      final otherSession = AdminDraftOwner(accountId: owner.accountId);
      expect(
        await repository.acquire(
          owner: otherSession,
          source: source,
          associatedCount: 0,
        ),
        isA<Error<AdminSubmissionStagedAsset>>(),
      );
      expect(
        environment.store.box<AdminSubmissionStagedAssetEntity>().count(),
        0,
      );
      environment.close();
      expect(
        await repository.acquire(
          owner: owner,
          source: source,
          associatedCount: 0,
        ),
        isA<Error<AdminSubmissionStagedAsset>>(),
      );
    },
  );

  test(
    'five combined images, new-target zero and size limit are enforced',
    () async {
      final existing = AdminDraftOwner(
        accountId: owner.accountId,
        submissionId: 9,
      );
      await drafts.saveDraft(
        AdminSubmissionDraft(owner: existing, snapshot: AdminDraftSnapshot()),
      );
      expect(
        await repository.acquire(
          owner: owner,
          source: source,
          associatedCount: 1,
        ),
        isA<Error<AdminSubmissionStagedAsset>>(),
      );
      final asset = (await repository.acquire(
        owner: existing,
        source: source,
        associatedCount: 4,
      )).getOrNull()!;
      expect(
        (await repository.acquire(
          owner: existing,
          source: source,
          associatedCount: 5,
        )).getOrNull(),
        asset,
      );
      source.writeAsBytesSync([4]);
      expect(
        await repository.acquire(
          owner: existing,
          source: source,
          associatedCount: 4,
        ),
        isA<Error<AdminSubmissionStagedAsset>>(),
      );
      final output = await source.open(mode: FileMode.write);
      await output.truncate(kCloudinaryMaxUploadBytes + 1);
      await output.close();
      expect(
        await repository.acquire(
          owner: owner,
          source: source,
          associatedCount: 0,
        ),
        isA<Error<AdminSubmissionStagedAsset>>(),
      );
      expect((await repository.reconcileAndLoad(existing)).getOrNull(), [
        asset,
      ]);
    },
  );

  test(
    'source mutation and growth during copy do not disturb committed sibling',
    () async {
      final sibling = (await repository.acquire(
        owner: owner,
        source: source,
        associatedCount: 0,
      )).getOrNull()!;
      for (final grow in [false, true]) {
        source.writeAsBytesSync([9]);
        final wrapped = AdminStagedFileSource(source, (read) {
          if (read == 2) {
            if (grow) {
              source.openSync(mode: FileMode.write)
                ..truncateSync(kCloudinaryMaxUploadBytes + 1)
                ..closeSync();
            } else {
              source.writeAsBytesSync([8]);
            }
          }
        });
        expect(
          await repository.acquire(
            owner: owner,
            source: wrapped,
            associatedCount: 0,
          ),
          isA<Error<AdminSubmissionStagedAsset>>(),
        );
        expect((await repository.reconcileAndLoad(owner)).getOrNull(), [
          sibling,
        ]);
      }
    },
  );

  test(
    'copy and rename failures publish no descriptor and preserve earlier item',
    () async {
      final sibling = (await repository.acquire(
        owner: owner,
        source: source,
        associatedCount: 0,
      )).getOrNull()!;
      source.writeAsBytesSync([9]);
      final failedCopy = AdminStagedFileSource(source, (read) {
        if (read == 2) source.deleteSync();
      });
      expect(
        await repository.acquire(
          owner: owner,
          source: failedCopy,
          associatedCount: 0,
        ),
        isA<Error<AdminSubmissionStagedAsset>>(),
      );
      source.writeAsBytesSync([8]);
      final digest = sha1.convert([8]).toString();
      final failedRename = AdminStagedFileSource(source, (read) {
        if (read == 2) {
          Directory(
            '${support.path}/admin_submission/staged/${owner.accountId}/${owner.sessionId}/$digest',
          ).createSync();
        }
      });
      expect(
        await repository.acquire(
          owner: owner,
          source: failedRename,
          associatedCount: 0,
        ),
        isA<Error<AdminSubmissionStagedAsset>>(),
      );
      expect((await repository.reconcileAndLoad(owner)).getOrNull(), [sibling]);
    },
  );

  test(
    'rename before descriptor failure leaves only uncommitted orphan',
    () async {
      final digest = sha1.convert([1, 2, 3]).toString();
      final wrapped = AdminStagedFileSource(source, (read) {
        if (read == 2) environment.close();
      });
      expect(
        await repository.acquire(
          owner: owner,
          source: wrapped,
          associatedCount: 0,
        ),
        isA<Error<AdminSubmissionStagedAsset>>(),
      );
      final file = File(
        '${support.path}/admin_submission/staged/${owner.accountId}/${owner.sessionId}/$digest',
      );
      expect(file.existsSync(), isTrue);
      // Reopen the same database: retained owner and descriptor-less bytes
      // must not be mistaken for a committed attachment.
      final recovered = await openStore(directory: environment.directory.path);
      addTearDown(recovered.close);
      final recoveredDrafts = AdminSubmissionDraftRepositoryImpl(
        logger: logger,
        objectBoxI: TestObjectBox(recovered),
      );
      expect(
        (await recoveredDrafts.loadDraft(
          accountId: owner.accountId,
        )).getOrNull()?.owner,
        owner,
      );
      final reopened = AdminSubmissionStagedAssetRepositoryImpl(
        logger: logger,
        objectBoxI: TestObjectBox(recovered),
        draftRepository: recoveredDrafts,
        getSupportDirectory: () async => support,
      );
      expect((await reopened.reconcileAndLoad(owner)).getOrNull(), isEmpty);
      expect(file.existsSync(), isFalse);
    },
  );

  test(
    'reconciliation preserves explicit order and lowest valid duplicate',
    () async {
      final first = (await repository.acquire(
        owner: owner,
        source: source,
        associatedCount: 0,
      )).getOrNull()!;
      source.writeAsBytesSync([4]);
      final second = (await repository.acquire(
        owner: owner,
        source: source,
        associatedCount: 0,
      )).getOrNull()!;
      final box = environment.store.box<AdminSubmissionStagedAssetEntity>()
        ..put(first.toEntity());
      final firstId = box.getAll().first.id;
      final restored = (await repository.reconcileAndLoad(owner)).getOrNull();
      expect(restored, [first, second]);
      expect(box.count(), 2);
      expect(box.get(firstId), isNotNull);
    },
  );

  test(
    'invalid, missing, corrupt and oversized entries do not lose siblings',
    () async {
      final sibling = (await repository.acquire(
        owner: owner,
        source: source,
        associatedCount: 0,
      )).getOrNull()!;
      final box = environment.store.box<AdminSubmissionStagedAssetEntity>();
      final directory = (await repository.resolveAbsolutePath(
        sibling,
      )).getOrNull()!.parent;
      for (final kind in ['missing', 'corrupt', 'oversize', 'invalid']) {
        final digest = sha1.convert(kind.codeUnits).toString();
        final file = File('${directory.path}/$digest');
        if (kind == 'corrupt') file.writeAsBytesSync([255]);
        if (kind == 'oversize') {
          file.openSync(mode: FileMode.write)
            ..truncateSync(kCloudinaryMaxUploadBytes + 1)
            ..closeSync();
        }
        box.put(
          AdminSubmissionStagedAssetEntity(
            accountId: owner.accountId,
            sessionId: owner.sessionId,
            submissionId: null,
            digest: digest,
            relativePath: kind == 'invalid'
                ? '../outside'
                : '${owner.accountId}/${owner.sessionId}/$digest',
          ),
        );
      }
      File('${directory.path}/.unfinished.tmp').writeAsBytesSync([9]);
      File('${directory.path}/${'a' * 40}').writeAsBytesSync([9]);
      expect((await repository.reconcileAndLoad(owner)).getOrNull(), [sibling]);
      expect(box.count(), 1);
      expect(directory.listSync().map((entry) => entry.path.split('/').last), [
        sibling.digest,
      ]);
    },
  );

  test(
    'hard descriptor write failure returns unavailable without partial list',
    () async {
      final digest = 'a' * 40;
      environment.store.box<AdminSubmissionStagedAssetEntity>().put(
        AdminSubmissionStagedAssetEntity(
          accountId: owner.accountId,
          sessionId: owner.sessionId,
          submissionId: null,
          digest: digest,
          relativePath: '${owner.accountId}/${owner.sessionId}/$digest',
        ),
      );
      final failing = AdminSubmissionStagedAssetRepositoryImpl(
        logger: logger,
        objectBoxI: TestObjectBox(environment.store),
        draftRepository: drafts,
        getSupportDirectory: () async {
          environment.close();
          return support;
        },
      );
      expect(
        await failing.reconcileAndLoad(owner),
        isA<Error<List<AdminSubmissionStagedAsset>>>(),
      );
    },
  );

  test(
    'separate accounts and targets retain independent identical bytes',
    () async {
      final first = (await repository.acquire(
        owner: owner,
        source: source,
        associatedCount: 0,
      )).getOrNull()!;
      for (final other in [
        AdminDraftOwner(accountId: owner.accountId, submissionId: 7),
        AdminDraftOwner(accountId: '20000000-0000-4000-8000-000000000002'),
      ]) {
        await drafts.saveDraft(
          AdminSubmissionDraft(owner: other, snapshot: AdminDraftSnapshot()),
        );
        final asset = (await repository.acquire(
          owner: other,
          source: source,
          associatedCount: 0,
        )).getOrNull()!;
        expect(asset.digest, first.digest);
        expect(asset.relativePath, isNot(first.relativePath));
        expect((await repository.reconcileAndLoad(other)).getOrNull(), [asset]);
      }
      expect((await repository.reconcileAndLoad(owner)).getOrNull(), [first]);
    },
  );

  test(
    'over-capacity restored assets remain available and removable',
    () async {
      final existing = AdminDraftOwner(
        accountId: owner.accountId,
        submissionId: 1,
      );
      await drafts.saveDraft(
        AdminSubmissionDraft(owner: existing, snapshot: AdminDraftSnapshot()),
      );
      final first = (await repository.acquire(
        owner: existing,
        source: source,
        associatedCount: 0,
      )).getOrNull()!;
      source.writeAsBytesSync([4]);
      expect(
        await repository.acquire(
          owner: existing,
          source: source,
          associatedCount: 5,
        ),
        isA<Error<AdminSubmissionStagedAsset>>(),
      );
      expect((await repository.reconcileAndLoad(existing)).getOrNull(), [
        first,
      ]);
      expect(
        await repository.remove(owner: existing, digest: first.digest),
        isA<Success<void>>(),
      );
      expect(
        (await drafts.loadDraft(
          accountId: existing.accountId,
          submissionId: 1,
        )).getOrNull()?.owner,
        existing,
      );
    },
  );

  test(
    'exact-owner removal is idempotent after missing file and retains parent',
    () async {
      final asset = (await repository.acquire(
        owner: owner,
        source: source,
        associatedCount: 0,
      )).getOrNull()!;
      (await repository.resolveAbsolutePath(asset)).getOrNull()!.deleteSync();
      expect(
        await repository.remove(owner: owner, digest: asset.digest),
        isA<Success<void>>(),
      );
      expect(
        await repository.remove(owner: owner, digest: asset.digest),
        isA<Success<void>>(),
      );
      expect(
        (await drafts.loadDraft(accountId: owner.accountId)).getOrNull()?.owner,
        owner,
      );
      expect((await repository.reconcileAndLoad(owner)).getOrNull(), isEmpty);
    },
  );

  test('descriptor deletion failure preserves original ownership', () async {
    final asset = (await repository.acquire(
      owner: owner,
      source: source,
      associatedCount: 0,
    )).getOrNull()!;
    final file = (await repository.resolveAbsolutePath(asset)).getOrNull()!;
    environment.close();
    expect(
      await repository.remove(owner: owner, digest: asset.digest),
      isA<Error<void>>(),
    );
    expect(file.existsSync(), isTrue);
  });

  test(
    'cleanup failure leaves non-restorable residue and path-free diagnostics',
    () async {
      final asset = (await repository.acquire(
        owner: owner,
        source: source,
        associatedCount: 0,
      )).getOrNull()!;
      final file = (await repository.resolveAbsolutePath(asset)).getOrNull()!;
      final failing = AdminSubmissionStagedAssetRepositoryImpl(
        logger: logger,
        objectBoxI: TestObjectBox(environment.store),
        draftRepository: drafts,
        getSupportDirectory: () async =>
            throw FileSystemException('private ${support.path}', support.path),
      );
      expect(
        await failing.remove(owner: owner, digest: asset.digest),
        isA<Success<void>>(),
      );
      expect(
        environment.store.box<AdminSubmissionStagedAssetEntity>().count(),
        0,
      );
      expect(file.existsSync(), isTrue);
      for (final call in logger.calls) {
        expect(
          '${call.event.data}${call.extra}${call.error}${call.stackTrace}',
          isNot(contains(support.path)),
        );
      }
      expect((await repository.reconcileAndLoad(owner)).getOrNull(), isEmpty);
      expect(file.existsSync(), isFalse);
    },
  );

  for (final segment in ['admin_submission', 'staged', 'account', 'session']) {
    test(
      'linked $segment directory refuses intake and never follows destination',
      () async {
        final outside = await Directory.systemTemp.createTemp('outside_admin_');
        addTearDown(() => outside.delete(recursive: true));
        final kept = File('${outside.path}/keep')..writeAsStringSync('outside');
        final segments = [
          'admin_submission',
          'staged',
          owner.accountId,
          owner.sessionId,
        ];
        final index = [
          'admin_submission',
          'staged',
          'account',
          'session',
        ].indexOf(segment);
        final path = [support.path, ...segments.take(index)].join('/');
        Directory(path).createSync(recursive: true);
        final link = Link('$path/${segments[index]}')..createSync(outside.path);
        expect(
          await repository.acquire(
            owner: owner,
            source: source,
            associatedCount: 0,
          ),
          isA<Error<AdminSubmissionStagedAsset>>(),
        );
        expect(kept.readAsStringSync(), 'outside');
        expect(link.existsSync(), isFalse);
        expect(
          environment.store.box<AdminSubmissionStagedAssetEntity>().count(),
          0,
        );
      },
    );
  }

  test(
    'linked final file is unlinked without modifying external bytes',
    () async {
      final asset = (await repository.acquire(
        owner: owner,
        source: source,
        associatedCount: 0,
      )).getOrNull()!;
      final file = (await repository.resolveAbsolutePath(asset)).getOrNull()!
        ..deleteSync();
      final external = File('${support.path}/outside')
        ..writeAsStringSync('outside');
      Link(file.path).createSync(external.path);
      expect(await repository.resolveAbsolutePath(asset), isA<Error<File>>());
      expect(external.readAsStringSync(), 'outside');
      expect(Link(file.path).existsSync(), isFalse);
      expect((await repository.reconcileAndLoad(owner)).getOrNull(), isEmpty);
    },
  );

  test('Public reconcile and cleanup exclude inactive Admin storage', () async {
    final asset = (await repository.acquire(
      owner: owner,
      source: source,
      associatedCount: 0,
    )).getOrNull()!;
    final public = ContentSubmissionStagedAssetRepositoryImpl(
      logger: logger,
      objectBoxI: TestObjectBox(environment.store),
      getSupportDirectory: () async => support,
    );
    final digest = sha1.convert([1, 2, 3]).toString();
    await public.acquire(
      clientSubmissionId: owner.sessionId,
      digest: digest,
      source: source,
    );
    await public.reconcileAndLoad(owner.sessionId);
    await public.clearSession(owner.sessionId);
    await public.reconcileAndLoad(null);
    expect((await repository.reconcileAndLoad(owner)).getOrNull(), [asset]);
    expect(
      (await drafts.loadDraft(accountId: owner.accountId)).getOrNull()?.owner,
      owner,
    );
  });

  test(
    'reopened store retains ordered files after field checkpoint replacement',
    () async {
      final first = (await repository.acquire(
        owner: owner,
        source: source,
        associatedCount: 0,
      )).getOrNull()!;
      await drafts.saveDraft(
        AdminSubmissionDraft(
          owner: owner,
          snapshot: AdminDraftSnapshot(name: 'new fields'),
        ),
      );
      source.writeAsBytesSync([4]);
      final second = (await repository.acquire(
        owner: owner,
        source: source,
        associatedCount: 0,
      )).getOrNull()!;
      environment.close();
      final reopenedStore = await openStore(
        directory: environment.directory.path,
      );
      try {
        final reopenedDrafts = AdminSubmissionDraftRepositoryImpl(
          logger: logger,
          objectBoxI: TestObjectBox(reopenedStore),
        );
        final reopened = AdminSubmissionStagedAssetRepositoryImpl(
          logger: logger,
          objectBoxI: TestObjectBox(reopenedStore),
          draftRepository: reopenedDrafts,
          getSupportDirectory: () async => support,
        );
        expect((await reopened.reconcileAndLoad(owner)).getOrNull(), [
          first,
          second,
        ]);
        expect(
          (await reopenedDrafts.loadDraft(
            accountId: owner.accountId,
          )).getOrNull()?.snapshot.name,
          'new fields',
        );
        await reopened.remove(owner: owner, digest: first.digest);
        await reopened.remove(owner: owner, digest: second.digest);
        expect(
          (await reopenedDrafts.loadDraft(
            accountId: owner.accountId,
          )).getOrNull()?.owner,
          owner,
        );
      } finally {
        reopenedStore.close();
      }
    },
  );

  test('invalid associated counts cannot authorize acquisition', () async {
    final existing = AdminDraftOwner(
      accountId: owner.accountId,
      submissionId: 11,
    );
    await drafts.saveDraft(
      AdminSubmissionDraft(owner: existing, snapshot: AdminDraftSnapshot()),
    );
    for (final count in [-1, 6, 0x7fffffffffffffff]) {
      expect(
        await repository.acquire(
          owner: existing,
          source: source,
          associatedCount: count,
        ),
        isA<Error<AdminSubmissionStagedAsset>>(),
      );
    }
    expect(
      environment.store.box<AdminSubmissionStagedAssetEntity>().count(),
      0,
    );
  });

  test(
    'unsupported Admin ownership cannot mutate Public draft or staged bytes',
    () async {
      final publicDrafts = ContentSubmissionDraftRepositoryImpl(
        logger: logger,
        objectBoxI: TestObjectBox(environment.store),
      );
      final publicAssets = ContentSubmissionStagedAssetRepositoryImpl(
        logger: logger,
        objectBoxI: TestObjectBox(environment.store),
        getSupportDirectory: () async => support,
      );
      final publicDraft = ContentSubmissionDraft(
        clientSubmissionId: owner.sessionId,
        name: 'retained public draft',
      );
      expect(await publicDrafts.saveDraft(publicDraft), isA<Success<void>>());
      final digest = sha1.convert([1, 2, 3]).toString();
      final publicAsset = (await publicAssets.acquire(
        clientSubmissionId: publicDraft.clientSubmissionId,
        digest: digest,
        source: source,
      )).getOrNull()!;
      final publicFile = (await publicAssets.resolveAbsolutePath(
        publicAsset,
      )).getOrNull()!;
      final publicBox = environment.store
          .box<ContentSubmissionStagedAssetEntity>();
      final descriptor = publicBox.getAll().single;
      final adminBox = environment.store.box<AdminSubmissionDraftEntity>();
      final row = adminBox.getAll().single;
      adminBox.put(
        AdminSubmissionDraftEntity(
          id: row.id,
          lookupKey: row.lookupKey,
          accountId: row.accountId,
          sessionId: row.sessionId,
          submissionId: row.submissionId,
          payload: '{"version":999}',
        ),
      );

      expect(
        await repository.acquire(
          owner: owner,
          source: source,
          associatedCount: 0,
        ),
        isA<Error<AdminSubmissionStagedAsset>>(),
      );
      expect(
        await repository.reconcileAndLoad(owner),
        isA<Error<List<AdminSubmissionStagedAsset>>>(),
      );

      expect((await publicDrafts.loadDraft()).getOrNull(), publicDraft);
      expect(
        (await publicAssets.reconcileAndLoad(
          publicDraft.clientSubmissionId,
        )).getOrNull(),
        [publicAsset],
      );
      final unchanged = publicBox.getAll().single;
      expect(
        (
          unchanged.id,
          unchanged.clientSubmissionId,
          unchanged.digest,
          unchanged.relativePath,
        ),
        (
          descriptor.id,
          descriptor.clientSubmissionId,
          descriptor.digest,
          descriptor.relativePath,
        ),
      );
      expect(await publicFile.readAsBytes(), [1, 2, 3]);
      expect(
        environment.store.box<AdminSubmissionStagedAssetEntity>().count(),
        0,
      );
      expect(adminBox.get(row.id)?.payload, '{"version":999}');
    },
  );
}
