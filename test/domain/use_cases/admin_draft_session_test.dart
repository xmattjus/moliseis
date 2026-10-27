import 'dart:async';
import 'dart:io' show File;

import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/domain/models/admin_submission_draft.dart';
import 'package:moliseis/domain/models/admin_submission_staged_asset.dart';
import 'package:moliseis/domain/use_cases/admin_draft_session.dart';
import 'package:moliseis/utils/result.dart';

import '../../support/admin_draft_repositories.dart';

void main() {
  late AdminDraftSessionHarness h;
  setUp(() => h = AdminDraftSessionHarness());

  group('initialization and checkpoints', () {
    test(
      'restoration is shared and waits for complete reconciliation',
      () async {
        h.seed();
        final read = Completer<Result<AdminSubmissionDraft?>>();
        final readEntered = Completer<void>();
        final reconcile = Completer<Result<List<AdminSubmissionStagedAsset>>>();
        final reconcileEntered = Completer<void>();
        h.drafts.onLoad = (_, _) {
          readEntered.complete();
          return read.future;
        };
        h.staged.onReconcile = (_) {
          reconcileEntered.complete();
          return reconcile.future;
        };
        final activated = h.session.activate(h.owner);
        final shared = h.session.initialize();
        expect(identical(activated, shared), isTrue);
        await readEntered.future;
        expect(h.drafts.loadCalls, 1);
        expect(h.session.state!.ready, isFalse);
        read.complete(Result.success(h.drafts.drafts[h.owner.lookupKey]));
        await reconcileEntered.future;
        expect(h.session.state!.ready, isFalse);
        reconcile.complete(const Result.success([]));
        expect(await activated, isA<Success<void>>());
        final state = h.session.state!;
        expect(state.current, state.effective);
        expect(state.current, state.physicalCheckpoint!.snapshot);
        expect(state.remoteBaseline, h.remote('A'));
        expect(state.acceptedRemoteRevision, isNull);
        expect(h.session.capacityContext, isNull);
        expect(h.drafts.saves, isEmpty);
      },
    );

    test(
      'restoration adopts only the loaded session identity for the same target',
      () async {
        h.seed();
        final provisional = AdminDraftOwner(
          accountId: h.owner.accountId,
          submissionId: 7,
        );
        expect(provisional.sessionId, isNot(h.owner.sessionId));
        await h.session.activate(provisional);
        expect(h.session.state!.owner, h.owner);
        expect(h.session.state!.current.name, 'A');
        expect(h.drafts.saves, isEmpty);
      },
    );

    test(
      'revoked pending initialization cannot restore into replacement B',
      () async {
        h.seed();
        final read = Completer<Result<AdminSubmissionDraft?>>();
        final entered = Completer<void>();
        h.drafts.onLoad = (account, _) {
          if (account == h.owner.accountId) {
            entered.complete();
            return read.future;
          }
          return Future.value(const Result.success(null));
        };
        final old = h.session.activate(h.owner);
        await entered.future;
        h.session.revoke();
        final other = AdminDraftOwner(
          accountId: AdminDraftSessionHarness.accountB,
        );
        final next = h.session.activate(other);
        read.complete(Result.success(h.drafts.drafts[h.owner.lookupKey]));
        expect(await old, isA<Error<void>>());
        expect(await next, isA<Success<void>>());
        expect(h.session.state!.owner, other);
        expect(h.session.state!.current.name, isNull);
        expect(h.session.state!.remoteBaseline, isNull);
        expect(h.session.state!.assets, isEmpty);
      },
    );

    test('absence has fresh clean C/E, null P, no ordinary write', () async {
      final owner = AdminDraftOwner(
        accountId: AdminDraftSessionHarness.accountA,
      );
      expect(await h.session.activate(owner), isA<Success<void>>());
      expect(h.session.state!.durability, AdminDraftDurability.absent);
      expect(h.session.state!.current, h.session.state!.effective);
      expect(h.session.state!.physicalCheckpoint, isNull);
      expect(h.session.state!.remoteBaseline, isNull);
      expect(h.session.state!.hasUncheckpointedChanges, isFalse);
      await h.session.checkpoint();
      expect(h.drafts.saves, isEmpty);
      await h.session.checkpoint(requireDurableOwner: true);
      expect(h.drafts.saves.single.owner, owner);
      expect(h.session.state!.currentMatchesDisk, isTrue);
      await h.session.checkpoint();
      expect(h.drafts.saves, hasLength(1));
    });

    test(
      'unknown loading blocks writes/intake and explicit retry restores',
      () async {
        h.drafts.onLoad = (_, _) async =>
            Result.error(Exception('Read failed'));
        expect(await h.session.activate(h.owner), isA<Error<void>>());
        expect(h.session.state!.durability, AdminDraftDurability.unknown);
        expect(h.session.state!.physicalCheckpoint, isNull);
        expect(
          h.session.setSnapshot(AdminDraftSnapshot(name: 'unsafe')),
          isA<Error<void>>(),
        );
        expect(await h.session.checkpoint(), isA<Error<void>>());
        expect(
          await h.session.acquire(File('unused'), capacity: null),
          isA<Error<AdminSubmissionStagedAsset>>(),
        );
        expect(h.drafts.saves, isEmpty);
        expect(h.staged.acquisitions, isEmpty);
        h.seed();
        h.drafts.onLoad = null;
        expect(await h.session.initialize(), isA<Success<void>>());
        expect(h.session.state!.current.name, 'A');
      },
    );

    test(
      'reconciliation failure publishes no partial restoration; retry succeeds',
      () async {
        h.seed();
        h.staged.onReconcile = (_) async =>
            Result.error(Exception('Reconcile failed'));
        expect(await h.session.activate(h.owner), isA<Error<void>>());
        expect(h.session.state!.ready, isFalse);
        expect(h.session.state!.assets, isEmpty);
        h.staged.onReconcile = null;
        expect(await h.session.initialize(), isA<Success<void>>());
        expect(h.session.state!.physicalCheckpoint!.snapshot.name, 'A');
      },
    );

    test(
      'checkpoint A settles after mutation B and only A becomes physical/effective',
      () async {
        h.seed();
        await h.session.activate(h.owner);
        h.session.setSnapshot(AdminDraftSnapshot(name: 'write A'));
        final entered = Completer<void>();
        final pending = Completer<Result<void>>();
        h.drafts.onSave = (_) {
          entered.complete();
          return pending.future;
        };
        final checkpoint = h.session.checkpoint();
        await entered.future;
        h.session.setSnapshot(AdminDraftSnapshot(name: 'B'));
        expect(h.drafts.saves.single.snapshot.name, 'write A');
        pending.complete(const Result.success(null));
        await checkpoint;
        expect(h.session.state!.physicalCheckpoint!.snapshot.name, 'write A');
        expect(h.session.state!.effective.name, 'write A');
        expect(h.session.state!.current.name, 'B');
        expect(h.session.state!.hasUncheckpointedChanges, isTrue);
        expect(h.session.state!.remoteBaseline, h.remote('A'));
      },
    );

    test(
      'failed checkpoint preserves physical/effective and later queue remains usable',
      () async {
        h.seed();
        await h.session.activate(h.owner);
        h.session.setSnapshot(AdminDraftSnapshot(name: 'C'));
        h.drafts.onSave = (_) async => Result.error(Exception('Write failed'));
        expect(await h.session.checkpoint(), isA<Error<void>>());
        expect(h.session.state!.physicalCheckpoint!.snapshot.name, 'A');
        expect(h.session.state!.effective.name, 'A');
        expect(h.session.state!.current.name, 'C');
        h.drafts.onSave = null;
        expect(await h.session.checkpoint(), isA<Success<void>>());
        expect(h.session.state!.physicalCheckpoint!.snapshot.name, 'C');
        expect(h.session.state!.remoteBaseline, h.remote('A'));
      },
    );

    test(
      'unexpected throw retains its identity and releases arbitration',
      () async {
        h.seed();
        await h.session.activate(h.owner);
        h.session.setSnapshot(AdminDraftSnapshot(name: 'C'));
        final defect = StateError('Unexpected defect');
        h.drafts.onSave = (_) async => throw defect;
        await expectLater(h.session.checkpoint(), throwsA(same(defect)));
        h.drafts.onSave = null;
        expect(await h.session.checkpoint(), isA<Success<void>>());
        expect(h.session.state!.currentMatchesDisk, isTrue);
      },
    );
  });

  group('C/E/P/R hydration', () {
    test('clean A -> B is clean without writing; restart restores A', () async {
      h.seed();
      await h.session.activate(h.owner);
      final token = h.session.admitHydration()!;
      expect(
        (await h.session.acceptHydration(
          token,
          h.remote('B'),
          associatedCount: 2,
        )).getOrNull(),
        isTrue,
      );
      expect(h.session.state!.current.name, 'B');
      expect(h.session.state!.effective.name, 'B');
      expect(h.session.state!.physicalCheckpoint!.snapshot.name, 'A');
      expect(h.session.state!.remoteBaseline, h.remote('B'));
      expect(h.session.state!.hasUncheckpointedChanges, isFalse);
      expect(h.drafts.saves, isEmpty);
      final restarted = AdminDraftSession(
        draftRepository: h.drafts,
        stagedAssetRepository: h.staged,
      );
      await restarted.activate(h.owner);
      expect(restarted.state!.current.name, 'A');
      expect(restarted.state!.remoteBaseline, h.remote('A'));
      expect(restarted.capacityContext, isNull);
      final other = AdminDraftOwner(
        accountId: h.owner.accountId,
        submissionId: 8,
      );
      expect(await h.session.activate(other), isA<Success<void>>());
      expect(h.drafts.saves, isEmpty);
    });

    test(
      'absent existing target checkpoints accepted hydration without typing',
      () async {
        await h.session.activate(h.owner);
        expect(h.session.state!.durability, AdminDraftDurability.absent);
        expect(h.session.state!.physicalCheckpoint, isNull);
        await h.session.checkpoint();
        expect(h.drafts.saves, isEmpty);
        expect(
          (await h.session.acceptHydration(
            h.session.admitHydration()!,
            h.remote('B'),
            associatedCount: 1,
          )).getOrNull(),
          isTrue,
        );
        expect(h.session.state!.current.name, 'B');
        expect(h.session.state!.effective.name, 'B');
        expect(h.session.state!.physicalCheckpoint, isNull);
        expect(h.session.state!.remoteBaseline, h.remote('B'));
        expect(h.session.state!.hasUncheckpointedChanges, isFalse);
        expect(h.drafts.saves, isEmpty);
        expect(await h.session.checkpoint(), isA<Success<void>>());
        expect(h.drafts.saves.single.owner, h.owner);
        expect(h.drafts.saves.single.snapshot.name, 'B');
        expect(h.drafts.saves.single.remoteBaseline, h.remote('B'));
        expect(h.session.state!.durability, AdminDraftDurability.durable);
        expect(h.session.state!.physicalCheckpoint!.snapshot.name, 'B');
        expect(h.session.state!.currentMatchesDisk, isTrue);
        expect(h.session.state!.hasUncheckpointedChanges, isFalse);
        await h.session.checkpoint();
        expect(h.drafts.saves, hasLength(1));
      },
    );

    test('explicit unchanged hydrated checkpoint writes B; '
        'user C retains remote B', () async {
      h.seed();
      await h.session.activate(h.owner);
      await h.session.acceptHydration(
        h.session.admitHydration()!,
        h.remote('B'),
        associatedCount: 0,
      );
      await h.session.checkpoint();
      expect(h.drafts.saves.single.snapshot.name, 'B');
      expect(h.session.state!.currentMatchesDisk, isTrue);
      h.session.setSnapshot(AdminDraftSnapshot(name: 'C'));
      expect(h.session.state!.hasUncheckpointedChanges, isTrue);
      await h.session.checkpoint();
      expect(h.session.state!.effective.name, 'C');
      expect(h.session.state!.physicalCheckpoint!.snapshot.name, 'C');
      expect(h.session.state!.remoteBaseline, h.remote('B'));
    });

    test(
      'successive clean hydrations do not mistake old P for new local intent',
      () async {
        h.seed();
        await h.session.activate(h.owner);
        await h.session.acceptHydration(
          h.session.admitHydration()!,
          h.remote('B'),
          associatedCount: 1,
        );
        expect(
          (await h.session.acceptHydration(
            h.session.admitHydration()!,
            h.remote('C'),
            associatedCount: 2,
          )).getOrNull(),
          isTrue,
        );
        expect(h.session.state!.current.name, 'C');
        expect(h.session.state!.effective.name, 'C');
        expect(h.session.state!.physicalCheckpoint!.snapshot.name, 'A');
        expect(h.session.state!.hasUncheckpointedChanges, isFalse);
        expect(h.drafts.saves, isEmpty);
      },
    );

    test('checkpointed incompatible remote intent and '
        'uncheckpointed typing survive', () async {
      h.seed(name: 'local', remoteName: 'server');
      await h.session.activate(h.owner);
      final physical = h.session.state!.physicalCheckpoint;
      expect(
        (await h.session.acceptHydration(
          h.session.admitHydration()!,
          h.remote('changed server'),
          associatedCount: 0,
        )).getOrNull(),
        isFalse,
      );
      expect(h.session.state!.current.name, 'local');
      expect(h.session.state!.physicalCheckpoint, same(physical));
      h.session.setSnapshot(AdminDraftSnapshot(name: 'typing'));
      expect(
        (await h.session.acceptHydration(
          h.session.admitHydration()!,
          h.remote('server'),
          associatedCount: 0,
        )).getOrNull(),
        isFalse,
      );
      expect(h.session.state!.current.name, 'typing');
      expect(h.drafts.saves, isEmpty);
    });

    test(
      'compatible remote metadata refresh preserves checkpointed edits',
      () async {
        h.seed(name: 'local', remoteName: 'server');
        await h.session.activate(h.owner);
        expect(
          (await h.session.acceptHydration(
            h.session.admitHydration()!,
            h.remote('server'),
            associatedCount: 3,
          )).getOrNull(),
          isTrue,
        );
        expect(h.session.state!.current.name, 'local');
        expect(h.session.state!.effective.name, 'local');
        expect(h.session.capacityContext!.associatedCount, 3);
      },
    );

    test(
      'foreign component token cannot publish into an equal owner activation',
      () async {
        h.seed();
        await h.session.activate(h.owner);
        final other = AdminDraftSession(
          draftRepository: h.drafts,
          stagedAssetRepository: h.staged,
        );
        await other.activate(h.owner);
        final foreign = other.admitHydration()!;
        final own = h.session.admitHydration()!;
        expect(foreign.generation, own.generation);
        expect(foreign.revision, own.revision);
        final before = h.session.state;
        expect(
          (await h.session.acceptHydration(
            foreign,
            h.remote('foreign'),
            associatedCount: 1,
          )).getOrNull(),
          isFalse,
        );
        expect(h.session.state, same(before));
        expect(
          (await h.session.rejectHydration(
            foreign,
            Exception('foreign'),
          )).getOrNull(),
          isFalse,
        );
        expect(h.session.state, same(before));
      },
    );

    test(
      'reverting hydrated B to physical A checkpoints its new remote intent',
      () async {
        h.seed();
        await h.session.activate(h.owner);
        await h.session.acceptHydration(
          h.session.admitHydration()!,
          h.remote('B'),
          associatedCount: 0,
        );
        h.session.setSnapshot(AdminDraftSnapshot(name: 'A'));
        expect(h.session.state!.hasUncheckpointedChanges, isTrue);
        await h.session.checkpoint();
        expect(h.session.state!.hasUncheckpointedChanges, isFalse);
        expect(h.session.state!.effective.name, 'A');
        expect(h.drafts.saves.single.snapshot.name, 'A');
        expect(h.drafts.saves.single.remoteBaseline, h.remote('B'));
        final restarted = AdminDraftSession(
          draftRepository: h.drafts,
          stagedAssetRepository: h.staged,
        );
        await restarted.activate(h.owner);
        expect(
          (await restarted.acceptHydration(
            restarted.admitHydration()!,
            h.remote('server C'),
            associatedCount: 0,
          )).getOrNull(),
          isFalse,
        );
        expect(restarted.state!.current.name, 'A');
      },
    );

    test('HYDRATION-01 older last cannot change any accepted state', () async {
      h.seed();
      await h.session.activate(h.owner);
      final firstResponse = Completer<AdminRemoteBaseline>();
      final secondResponse = Completer<AdminRemoteBaseline>();
      final old = h.session.admitHydration()!;
      final oldCompletion = firstResponse.future.then(
        (response) =>
            h.session.acceptHydration(old, response, associatedCount: 1),
      );
      final latest = h.session.admitHydration()!;
      final latestCompletion = secondResponse.future.then(
        (response) =>
            h.session.acceptHydration(latest, response, associatedCount: 2),
      );
      secondResponse.complete(h.remote('B2'));
      await latestCompletion;
      final accepted = h.session.state;
      firstResponse.complete(h.remote('B1'));
      expect((await oldCompletion).getOrNull(), isFalse);
      expect(h.session.state, same(accepted));
      expect(
        (await h.session.rejectHydration(old, Exception('stale'))).getOrNull(),
        isFalse,
      );
      expect(h.session.state, same(accepted));
      expect(h.drafts.saves, isEmpty);
    });

    test(
      'HYDRATION-02 older first is already superseded at admission',
      () async {
        h.seed();
        await h.session.activate(h.owner);
        final firstResponse = Completer<AdminRemoteBaseline>();
        final secondResponse = Completer<AdminRemoteBaseline>();
        final old = h.session.admitHydration()!;
        final oldCompletion = firstResponse.future.then(
          (response) =>
              h.session.acceptHydration(old, response, associatedCount: 1),
        );
        final latest = h.session.admitHydration()!;
        final latestCompletion = secondResponse.future.then(
          (response) =>
              h.session.acceptHydration(latest, response, associatedCount: 2),
        );
        final pending = h.session.state;
        firstResponse.complete(h.remote('B1'));
        expect((await oldCompletion).getOrNull(), isFalse);
        expect(h.session.state, same(pending));
        secondResponse.complete(h.remote('B2'));
        await latestCompletion;
        expect(h.session.state!.current.name, 'B2');
      },
    );

    test(
      'HYDRATION-03 newer failure does not revive older success/error',
      () async {
        h.seed();
        await h.session.activate(h.owner);
        final firstResponse = Completer<AdminRemoteBaseline>();
        final secondResponse = Completer<Exception>();
        final old = h.session.admitHydration()!;
        final oldCompletion = firstResponse.future.then(
          (response) =>
              h.session.acceptHydration(old, response, associatedCount: 1),
        );
        final latest = h.session.admitHydration()!;
        final latestCompletion = secondResponse.future.then(
          (failure) => h.session.rejectHydration(latest, failure),
        );
        final failure = Exception('newer failed');
        secondResponse.complete(failure);
        await latestCompletion;
        final failed = h.session.state;
        firstResponse.complete(h.remote('B1'));
        await oldCompletion;
        await h.session.rejectHydration(old, Exception('older failed'));
        expect(h.session.state, same(failed));
        expect(h.session.state!.hydrationError, same(failure));
        expect(h.session.state!.current.name, 'A');
        expect(h.drafts.saves, isEmpty);
      },
    );

    test(
      'HYDRATION-04 checkpoint settles P before queued latest hydration',
      () async {
        h.seed();
        await h.session.activate(h.owner);
        h.session.setSnapshot(AdminDraftSnapshot(name: 'A2'));
        final entered = Completer<void>();
        final write = Completer<Result<void>>();
        h.drafts.onSave = (_) {
          entered.complete();
          return write.future;
        };
        final checkpoint = h.session.checkpoint();
        await entered.future;
        final old = h.session.admitHydration()!;
        final oldCompletion = h.session.acceptHydration(
          old,
          h.remote('obsolete'),
          associatedCount: 0,
        );
        final latest = h.session.admitHydration()!;
        final completion = h.session.acceptHydration(
          latest,
          h.remote('A2'),
          associatedCount: 1,
        );
        expect(h.session.state!.physicalCheckpoint!.snapshot.name, 'A');
        write.complete(const Result.success(null));
        await checkpoint;
        expect((await oldCompletion).getOrNull(), isFalse);
        expect((await completion).getOrNull(), isTrue);
        expect(h.session.state!.physicalCheckpoint!.snapshot.name, 'A2');
        expect(h.session.state!.remoteBaseline, h.remote('A2'));
        expect(h.session.state!.acceptedRemoteRevision, latest.revision);
      },
    );

    test(
      'HYDRATION-04 accepted hydration precedes checkpoint capture',
      () async {
        h.seed();
        await h.session.activate(h.owner);
        final hydration = h.session.acceptHydration(
          h.session.admitHydration()!,
          h.remote('B'),
          associatedCount: 0,
        );
        final checkpoint = h.session.checkpoint();
        await hydration;
        await checkpoint;
        expect(h.drafts.saves.single.snapshot.name, 'B');
        expect(h.session.state!.currentMatchesDisk, isTrue);
      },
    );

    test(
      'HYDRATION-05 A1 -> B -> A2 rejects old equal-revision token',
      () async {
        h.seed();
        await h.session.activate(h.owner);
        final old = h.session.admitHydration()!;
        h.session.revoke();
        final other = AdminDraftOwner(
          accountId: AdminDraftSessionHarness.accountB,
        );
        await h.session.activate(other);
        await h.session.activate(h.owner);
        final latest = h.session.admitHydration()!;
        expect(latest.revision, old.revision);
        final current = h.session.state;
        await h.session.acceptHydration(
          old,
          h.remote('stale A1'),
          associatedCount: 0,
        );
        expect(h.session.state, same(current));
        await h.session.acceptHydration(
          latest,
          h.remote('fresh A2'),
          associatedCount: 0,
        );
        expect(h.session.state!.current.name, 'fresh A2');
      },
    );
  });

  group('capacity and local ownership', () {
    test(
      'CAPACITY-01 foreign target/account/session/generation are refused',
      () async {
        h.seed();
        await h.session.activate(h.owner);
        await h.session.acceptHydration(
          h.session.admitHydration()!,
          h.remote('A'),
          associatedCount: 1,
        );
        final capacity = h.session.capacityContext!;
        final other = AdminDraftOwner(
          accountId: AdminDraftSessionHarness.accountB,
          submissionId: 8,
        );
        final invalid = <AdminAssetCapacityContext>[
          (
            owner: other,
            generation: capacity.generation,
            associatedCount: 1,
            acceptedRemoteRevision: capacity.acceptedRemoteRevision,
          ),
          (
            owner: AdminDraftOwner(
              accountId: h.owner.accountId,
              submissionId: 7,
            ),
            generation: capacity.generation,
            associatedCount: 1,
            acceptedRemoteRevision: capacity.acceptedRemoteRevision,
          ),
          (
            owner: capacity.owner,
            generation: capacity.generation + 1,
            associatedCount: 1,
            acceptedRemoteRevision: capacity.acceptedRemoteRevision,
          ),
          (
            owner: capacity.owner,
            generation: capacity.generation,
            associatedCount: 0,
            acceptedRemoteRevision: capacity.acceptedRemoteRevision,
          ),
        ];
        for (final context in invalid) {
          expect(
            await h.session.acquire(File('unused'), capacity: context),
            isA<Error<AdminSubmissionStagedAsset>>(),
          );
        }
        expect(h.staged.acquisitions, isEmpty);
        expect(h.drafts.saves, isEmpty);
      },
    );

    test(
      'CAPACITY-02 stale same-timestamp context is rejected at queued entry',
      () async {
        h.seed();
        await h.session.activate(h.owner);
        await h.session.acceptHydration(
          h.session.admitHydration()!,
          h.remote('A'),
          associatedCount: 1,
        );
        final old = h.session.capacityContext!;
        h.session.setSnapshot(AdminDraftSnapshot(name: 'local checkpoint'));
        final entered = Completer<void>();
        final write = Completer<Result<void>>();
        h.drafts.onSave = (_) {
          entered.complete();
          return write.future;
        };
        final checkpoint = h.session.checkpoint();
        await entered.future;
        final latest = h.session.admitHydration()!;
        final replace = h.session.acceptHydration(
          latest,
          h.remote('A'),
          associatedCount: 2,
        );
        final intake = h.session.acquire(File('unused'), capacity: old);
        expect(h.staged.acquisitions, isEmpty);
        write.complete(const Result.success(null));
        await checkpoint;
        await replace;
        expect(await intake, isA<Error<AdminSubmissionStagedAsset>>());
        expect(
          h.session.capacityContext!.acceptedRemoteRevision,
          latest.revision,
        );
        expect(h.staged.acquisitions, isEmpty);
      },
    );

    test(
      'CAPACITY-03 new target derives zero without remote context',
      () async {
        final owner = AdminDraftOwner(
          accountId: AdminDraftSessionHarness.accountA,
        );
        await h.session.activate(owner);
        final capacity = h.session.capacityContext!;
        expect(capacity.associatedCount, 0);
        expect(capacity.acceptedRemoteRevision, isNull);
        expect(h.session.admitHydration(), isNull);
        expect(
          await h.session.acquire(File('unused'), capacity: capacity),
          isA<Success<AdminSubmissionStagedAsset>>(),
        );
        expect(h.drafts.saves.single.owner, owner);
        expect(h.staged.acquisitions.single, (
          owner: owner,
          associatedCount: 0,
        ));
      },
    );

    test(
      'CAPACITY-04 historical or absent context cannot authorize intake',
      () async {
        h.seed();
        await h.session.activate(h.owner);
        expect(h.session.capacityContext, isNull);
        expect(
          await h.session.acquire(File('unused'), capacity: null),
          isA<Error<AdminSubmissionStagedAsset>>(),
        );
        expect(h.staged.acquisitions, isEmpty);
        expect(h.drafts.saves, isEmpty);
      },
    );

    test(
      'CAPACITY-05 over-capacity restoration retains all assets and removal',
      () async {
        h.seed();
        final owned = List.generate(3, (index) {
          final digest = '${index + 1}'.padLeft(40, '0');
          return AdminSubmissionStagedAsset(
            owner: h.owner,
            digest: digest,
            relativePath: '${h.owner.accountId}/${h.owner.sessionId}/$digest',
          );
        });
        h.staged.assets[h.owner] = [...owned];
        await h.session.activate(h.owner);
        await h.session.acceptHydration(
          h.session.admitHydration()!,
          h.remote('A'),
          associatedCount: 4,
        );
        expect(h.session.state!.assets, owned);
        expect(
          await h.session.acquire(
            File('unused'),
            capacity: h.session.capacityContext,
          ),
          isA<Error<AdminSubmissionStagedAsset>>(),
        );
        expect(h.session.state!.assets, owned);
        expect(await h.session.remove(owned.first), isA<Success<void>>());
        expect(h.session.state!.assets, owned.skip(1).toList());
        expect(h.drafts.drafts[h.owner.lookupKey]!.owner, h.owner);
      },
    );

    test(
      'CAPACITY-06 local admission delegates no remote acceptance claim',
      () async {
        h.seed();
        await h.session.activate(h.owner);
        await h.session.acceptHydration(
          h.session.admitHydration()!,
          h.remote('A'),
          associatedCount: 1,
        );
        await h.session.acquire(
          File('unused'),
          capacity: h.session.capacityContext,
        );
        expect(h.staged.acquisitions.single.associatedCount, 1);
        // Later server mutation is outside these local contracts.
        expect(h.session.state!.assets, hasLength(1));
        expect(h.session.state!.remoteBaseline, h.remote('A'));
        expect(h.drafts.saves, isEmpty);
      },
    );

    test('failed first-owner checkpoint prevents acquisition', () async {
      final owner = AdminDraftOwner(
        accountId: AdminDraftSessionHarness.accountA,
      );
      await h.session.activate(owner);
      h.drafts.onSave = (_) async => Result.error(Exception('Disk failed'));
      expect(
        await h.session.acquire(
          File('unused'),
          capacity: h.session.capacityContext,
        ),
        isA<Error<AdminSubmissionStagedAsset>>(),
      );
      expect(h.staged.acquisitions, isEmpty);
      expect(h.session.state!.durability, AdminDraftDurability.absent);
      expect(h.session.state!.assets, isEmpty);
    });

    test('last removal and field replacement retain durable owner', () async {
      final owner = AdminDraftOwner(
        accountId: AdminDraftSessionHarness.accountA,
      );
      await h.session.activate(owner);
      final result = await h.session.acquire(
        File('unused'),
        capacity: h.session.capacityContext,
      );
      final asset = result.getOrNull()!;
      h.session.setSnapshot(AdminDraftSnapshot(name: 'changed'));
      await h.session.checkpoint();
      await h.session.remove(asset);
      expect(h.session.state!.assets, isEmpty);
      expect(h.drafts.drafts[owner.lookupKey]!.snapshot.name, 'changed');
      expect(h.drafts.drafts[owner.lookupKey]!.owner, owner);
    });

    test(
      'descriptor removal failure preserves published assets and owner',
      () async {
        final owner = AdminDraftOwner(
          accountId: AdminDraftSessionHarness.accountA,
        );
        await h.session.activate(owner);
        final asset = (await h.session.acquire(
          File('unused'),
          capacity: h.session.capacityContext,
        )).getOrNull()!;
        h.staged.onRemove = (_, _) async =>
            Result.error(Exception('Descriptor failed'));
        expect(await h.session.remove(asset), isA<Error<void>>());
        expect(h.session.state!.assets, [asset]);
        expect(h.drafts.drafts[owner.lookupKey]!.owner, owner);
      },
    );

    test(
      'repeated same-owner removal is a harmless idempotent success',
      () async {
        final owner = AdminDraftOwner(
          accountId: AdminDraftSessionHarness.accountA,
        );
        await h.session.activate(owner);
        final asset = (await h.session.acquire(
          File('unused'),
          capacity: h.session.capacityContext,
        )).getOrNull()!;
        expect(await h.session.remove(asset), isA<Success<void>>());
        expect(await h.session.remove(asset), isA<Success<void>>());
        expect(h.session.state!.assets, isEmpty);
        expect(h.staged.removals, hasLength(1));
        expect(h.drafts.drafts[owner.lookupKey]!.owner, owner);
      },
    );

    test(
      'duplicate accepted descriptor does not append another runtime item',
      () async {
        final owner = AdminDraftOwner(
          accountId: AdminDraftSessionHarness.accountA,
        );
        await h.session.activate(owner);
        final asset = (await h.session.acquire(
          File('unused'),
          capacity: h.session.capacityContext,
        )).getOrNull()!;
        h.staged.onAcquire = (_, _) async => Result.success(asset);
        await h.session.acquire(
          File('unused'),
          capacity: h.session.capacityContext,
        );
        expect(h.session.state!.assets, [asset]);
      },
    );

    test('post-intake reconciliation failure preserves fields '
        'and retries only assets', () async {
      h.seed();
      await h.session.activate(h.owner);
      await h.session.acceptHydration(
        h.session.admitHydration()!,
        h.remote('A'),
        associatedCount: 0,
      );
      final physical = h.session.state!.physicalCheckpoint;
      final remote = h.session.state!.remoteBaseline;
      final entered = Completer<void>();
      final reconcile = Completer<Result<List<AdminSubmissionStagedAsset>>>();
      h.staged.onReconcile = (_) {
        entered.complete();
        return reconcile.future;
      };
      final intake = h.session.acquire(
        File('unused'),
        capacity: h.session.capacityContext,
      );
      await entered.future;
      h.session.setSnapshot(AdminDraftSnapshot(name: 'uncheckpointed typing'));
      final failure = Exception('Descriptor read failed after intake');
      reconcile.complete(Result.error(failure));
      final result = await intake;
      expect(result, isA<Error<AdminSubmissionStagedAsset>>());
      expect(
        (result as Error<AdminSubmissionStagedAsset>).error,
        same(failure),
      );
      expect(h.session.state!.ready, isFalse);
      expect(h.session.state!.assets, isEmpty);
      expect(h.session.state!.current.name, 'uncheckpointed typing');
      expect(h.session.state!.effective.name, 'A');
      expect(h.session.state!.physicalCheckpoint, same(physical));
      expect(h.session.state!.remoteBaseline, same(remote));
      expect(h.session.state!.hasUncheckpointedChanges, isTrue);
      expect(h.session.state!.durability, AdminDraftDurability.durable);
      expect(h.drafts.loadCalls, 1);
      expect(h.drafts.saves, isEmpty);
      expect(h.staged.assets[h.owner], hasLength(1));

      h.staged.onReconcile = null;
      expect(await h.session.initialize(), isA<Success<void>>());
      expect(h.drafts.loadCalls, 1);
      expect(h.session.state!.ready, isTrue);
      expect(h.session.state!.assets, h.staged.assets[h.owner]);
      expect(h.session.state!.current.name, 'uncheckpointed typing');
      expect(h.session.state!.effective.name, 'A');
      expect(h.session.state!.physicalCheckpoint, same(physical));
      expect(h.session.state!.remoteBaseline, same(remote));
      expect(h.session.state!.hasUncheckpointedChanges, isTrue);
      expect(h.drafts.saves, isEmpty);
    });

    test('dirty and unsettled normal switches refuse abandonment', () async {
      h.seed();
      await h.session.activate(h.owner);
      final other = AdminDraftOwner(
        accountId: h.owner.accountId,
        submissionId: 8,
      );
      h.session.setSnapshot(AdminDraftSnapshot(name: 'typing'));
      expect(await h.session.activate(other), isA<Error<void>>());
      expect(h.session.state!.owner, h.owner);
      final entered = Completer<void>();
      final write = Completer<Result<void>>();
      h.drafts.onSave = (_) {
        entered.complete();
        return write.future;
      };
      final pending = h.session.checkpoint();
      await entered.future;
      expect(await h.session.activate(other), isA<Error<void>>());
      write.complete(const Result.success(null));
      await pending;
      expect(await h.session.activate(other), isA<Success<void>>());
    });

    test(
      'revoke during checkpoint retains original write without publishing to B',
      () async {
        h.seed();
        await h.session.activate(h.owner);
        h.session.setSnapshot(AdminDraftSnapshot(name: 'retained A'));
        final entered = Completer<void>();
        final write = Completer<Result<void>>();
        h.drafts.onSave = (_) {
          entered.complete();
          return write.future;
        };
        final pending = h.session.checkpoint();
        await entered.future;
        h.session.revoke();
        expect(h.session.state, isNull);
        final other = AdminDraftOwner(
          accountId: AdminDraftSessionHarness.accountB,
        );
        final next = h.session.activate(other);
        write.complete(const Result.success(null));
        await pending;
        await next;
        expect(h.session.state!.owner, other);
        expect(h.session.state!.current.name, isNull);
        expect(h.drafts.drafts[h.owner.lookupKey]!.snapshot.name, 'retained A');
        expect(h.drafts.drafts[other.lookupKey], isNull);
      },
    );

    test(
      'revoke during acquisition retains old asset but never exposes it to B',
      () async {
        h.seed();
        await h.session.activate(h.owner);
        await h.session.acceptHydration(
          h.session.admitHydration()!,
          h.remote('A'),
          associatedCount: 0,
        );
        final entered = Completer<void>();
        final acquisition = Completer<Result<AdminSubmissionStagedAsset>>();
        h.staged.onAcquire = (_, _) {
          entered.complete();
          return acquisition.future;
        };
        final pending = h.session.acquire(
          File('unused'),
          capacity: h.session.capacityContext,
        );
        await entered.future;
        h.session.revoke();
        final other = AdminDraftOwner(
          accountId: AdminDraftSessionHarness.accountB,
        );
        final next = h.session.activate(other);
        const digest = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
        final asset = AdminSubmissionStagedAsset(
          owner: h.owner,
          digest: digest,
          relativePath: '${h.owner.accountId}/${h.owner.sessionId}/$digest',
        );
        h.staged.assets[h.owner] = [asset];
        acquisition.complete(Result.success(asset));
        await pending;
        await next;
        expect(h.session.state!.owner, other);
        expect(h.session.state!.assets, isEmpty);
        expect(h.staged.assets[h.owner], [asset]);
      },
    );
  });
}
