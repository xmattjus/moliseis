import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/domain/models/admin_submission_draft.dart';
import 'package:moliseis/domain/models/admin_submission_staged_asset.dart';
import 'package:moliseis/domain/models/submission_asset.dart';
import 'package:moliseis/utils/result.dart';

import '../../support/admin_draft_repositories.dart';

void main() {
  const attemptA = '11111111-1111-4111-8111-111111111111';
  const attemptB = '22222222-2222-4222-8222-222222222222';
  const token = '2026-10-27T12:00:00.123456+00:00';

  test(
    'rejection settlement preserves latest C/P, R and private receipts',
    () async {
      final h = AdminDraftSessionHarness()..seed(name: 'server');
      final receipt = AdminSubmissionStagedAsset(
        owner: h.owner,
        digest: 'a' * 40,
        relativePath: '${h.owner.accountId}/${h.owner.sessionId}/${'a' * 40}',
        progress: AdminStagedAssetProgress(
          upload: const SubmissionAsset(
            secureUrl: 'https://example.test/confirmed.jpg',
            width: 20,
            height: 30,
          ),
          associationId: 90,
        ),
      );
      h.staged.assets[h.owner] = [receipt];
      await h.session.activate(h.owner);
      final activation = h.session.captureActivation()!;
      final hydration = h.session.admitHydration()!;
      await h.session.acceptHydration(
        hydration,
        h.remote('server'),
        associatedCount: 1,
      );
      expect(h.session.capacityContext, isNotNull);
      await h.session.beginFieldWrite(
        AdminFieldWriteIntent(
          kind: AdminFieldWriteKind.update,
          attemptId: attemptA,
          snapshot: AdminDraftSnapshot(name: 'Save A'),
          expectedModifiedAt: token,
        ),
        activation: activation,
        checkpointAtCapture: h.session.state!.physicalCheckpoint,
      );
      final b = AdminDraftSnapshot(name: 'checkpoint B', latitudeText: '41,');
      h.session.setSnapshot(b, activation: activation);
      await h.session.checkpoint();
      await h.session.setNavigationIntent(
        activation: activation,
        requestNonce: attemptB,
      );
      final c = b.copyWith(name: 'typing C');
      h.session.setSnapshot(c, activation: activation);
      final before = h.session.state!;
      final pendingHydration = h.session.admitHydration()!;
      expect(
        await h.session.settleFieldWriteIntent(
          activation: activation,
          attemptId: attemptA,
          kind: AdminFieldWriteKind.update,
        ),
        isA<Success<void>>(),
      );
      final after = h.session.state!;
      expect(after.current, c);
      expect(after.effective, before.effective);
      expect(after.physicalCheckpoint!.snapshot, b);
      expect(after.physicalCheckpoint!.fieldWriteIntent, isNull);
      expect(after.remoteBaseline, same(before.remoteBaseline));
      expect(
        after.physicalCheckpoint!.remoteBaseline,
        before.physicalCheckpoint!.remoteBaseline,
      );
      expect(
        after.physicalCheckpoint!.navigationIntent!.requestNonce,
        attemptB,
      );
      expect(after.assets, [receipt]);
      expect(h.session.capacityContext, isNull);
      expect(after.acceptedRemoteRevision, isNull);
      expect(
        (await h.session.acceptHydration(
          pendingHydration,
          h.remote('stale'),
          associatedCount: 0,
        )).getOrNull(),
        isFalse,
      );
      expect(h.session.state!.current, c);
      final writes = h.drafts.saves.length;
      expect(
        await h.session.settleFieldWriteIntent(
          activation: activation,
          attemptId: attemptA,
          kind: AdminFieldWriteKind.update,
        ),
        isA<Success<void>>(),
      );
      expect(h.drafts.saves.length, writes);
    },
  );

  test(
    'settlement matches kind and attempt and cannot clear a later intent',
    () async {
      final h = AdminDraftSessionHarness()..seed();
      await h.session.activate(h.owner);
      final activation = h.session.captureActivation()!;
      final a = AdminFieldWriteIntent(
        kind: AdminFieldWriteKind.update,
        attemptId: attemptA,
        snapshot: AdminDraftSnapshot(name: 'A'),
        expectedModifiedAt: token,
      );
      await h.session.beginFieldWrite(
        a,
        activation: activation,
        checkpointAtCapture: h.session.state!.physicalCheckpoint,
      );
      for (final mismatch in [
        (attempt: attemptB, kind: AdminFieldWriteKind.update),
        (attempt: attemptA, kind: AdminFieldWriteKind.create),
      ]) {
        expect(
          await h.session.settleFieldWriteIntent(
            activation: activation,
            attemptId: mismatch.attempt,
            kind: mismatch.kind,
          ),
          isA<Error<void>>(),
        );
        expect(h.session.state!.physicalCheckpoint!.fieldWriteIntent, a);
      }
      await h.session.settleFieldWriteIntent(
        activation: activation,
        attemptId: attemptA,
        kind: AdminFieldWriteKind.update,
      );
      final b = AdminFieldWriteIntent(
        kind: AdminFieldWriteKind.update,
        attemptId: attemptB,
        snapshot: AdminDraftSnapshot(name: 'B'),
        expectedModifiedAt: token,
      );
      await h.session.beginFieldWrite(
        b,
        activation: activation,
        checkpointAtCapture: h.session.state!.physicalCheckpoint,
      );
      expect(
        await h.session.settleFieldWriteIntent(
          activation: activation,
          attemptId: attemptA,
          kind: AdminFieldWriteKind.update,
        ),
        isA<Error<void>>(),
      );
      expect(h.session.state!.physicalCheckpoint!.fieldWriteIntent, b);
    },
  );

  test(
    'failed settlement keeps intent and newer checkpoint for local retry',
    () async {
      final h = AdminDraftSessionHarness()..seed();
      await h.session.activate(h.owner);
      final activation = h.session.captureActivation()!;
      final intent = AdminFieldWriteIntent(
        kind: AdminFieldWriteKind.update,
        attemptId: attemptA,
        snapshot: AdminDraftSnapshot(name: 'A'),
        expectedModifiedAt: token,
      );
      await h.session.beginFieldWrite(
        intent,
        activation: activation,
        checkpointAtCapture: h.session.state!.physicalCheckpoint,
      );
      final b = AdminDraftSnapshot(name: 'B', latitudeText: '-');
      h.session.setSnapshot(b, activation: activation);
      await h.session.checkpoint();
      h.drafts.onSave = (_) async =>
          Result.error(Exception('checkpoint unavailable'));
      expect(
        await h.session.settleFieldWriteIntent(
          activation: activation,
          attemptId: attemptA,
          kind: AdminFieldWriteKind.update,
        ),
        isA<Error<void>>(),
      );
      expect(h.session.state!.physicalCheckpoint!.fieldWriteIntent, intent);
      expect(h.drafts.drafts[h.owner.lookupKey]!.fieldWriteIntent, intent);
      expect(h.session.state!.current, b);
      h.drafts.onSave = null;
      expect(
        await h.session.settleFieldWriteIntent(
          activation: activation,
          attemptId: attemptA,
          kind: AdminFieldWriteKind.update,
        ),
        isA<Success<void>>(),
      );
      expect(h.drafts.drafts[h.owner.lookupKey]!.snapshot, b);
      expect(h.drafts.drafts[h.owner.lookupKey]!.fieldWriteIntent, isNull);
    },
  );

  test(
    'in-flight A1 settlement never publishes into B or lends authority to A2',
    () async {
      final h = AdminDraftSessionHarness()..seed();
      await h.session.activate(h.owner);
      final a1 = h.session.captureActivation()!;
      await h.session.beginFieldWrite(
        AdminFieldWriteIntent(
          kind: AdminFieldWriteKind.update,
          attemptId: attemptA,
          snapshot: AdminDraftSnapshot(name: 'A'),
          expectedModifiedAt: token,
        ),
        activation: a1,
        checkpointAtCapture: h.session.state!.physicalCheckpoint,
      );
      final entered = Completer<void>();
      final release = Completer<Result<void>>();
      h.drafts.onSave = (_) {
        entered.complete();
        return release.future;
      };
      final settling = h.session.settleFieldWriteIntent(
        activation: a1,
        attemptId: attemptA,
        kind: AdminFieldWriteKind.update,
      );
      await entered.future;
      h.session.revoke();
      final ownerB = AdminDraftOwner(
        accountId: AdminDraftSessionHarness.accountB,
      );
      final activatingB = h.session.activate(ownerB);
      release.complete(const Result.success(null));
      await settling;
      await activatingB;
      expect(h.session.state!.owner, ownerB);
      expect(h.session.state!.physicalCheckpoint, isNull);
      h.drafts.onSave = null;
      await h.session.activate(h.owner);
      final a2 = h.session.captureActivation()!;
      expect(h.session.isActivationCurrent(a1), isFalse);
      expect(
        await h.session.settleFieldWriteIntent(
          activation: a1,
          attemptId: attemptA,
          kind: AdminFieldWriteKind.update,
        ),
        isA<Error<void>>(),
      );
      expect(h.session.isActivationCurrent(a2), isTrue);
    },
  );

  test(
    'Create correction retains stable UUID and newer checkpoint B2',
    () async {
      final h = AdminDraftSessionHarness();
      final owner = AdminDraftOwner(
        accountId: AdminDraftSessionHarness.accountA,
      );
      await h.session.activate(owner);
      final activation = h.session.captureActivation()!;
      final original = AdminFieldWriteIntent(
        kind: AdminFieldWriteKind.create,
        attemptId: attemptA,
        snapshot: AdminDraftSnapshot(name: 'A'),
      );
      await h.session.beginFieldWrite(
        original,
        activation: activation,
        checkpointAtCapture: null,
      );
      final capturedP = h.session.state!.physicalCheckpoint;
      final replacement = AdminFieldWriteIntent(
        kind: AdminFieldWriteKind.create,
        attemptId: attemptB,
        snapshot: AdminDraftSnapshot(name: 'corrected B'),
      );
      final b2 = AdminDraftSnapshot(name: 'newer B2', latitudeText: '-');
      h.session.setSnapshot(b2, activation: activation);
      await h.session.checkpoint();
      await h.session.setNavigationIntent(
        activation: activation,
        requestNonce: attemptB,
      );
      final c = b2.copyWith(name: 'uncheckpointed C');
      h.session.setSnapshot(c, activation: activation);
      expect(
        await h.session.replaceRejectedCreateIntent(
          activation: activation,
          attemptId: attemptB,
          replacement: replacement,
          checkpointAtCapture: capturedP,
        ),
        isA<Error<void>>(),
      );
      expect(
        await h.session.replaceRejectedCreateIntent(
          activation: activation,
          attemptId: attemptA,
          replacement: original,
          checkpointAtCapture: capturedP,
        ),
        isA<Error<void>>(),
      );
      expect(
        await h.session.replaceRejectedCreateIntent(
          activation: activation,
          attemptId: attemptA,
          replacement: replacement,
          checkpointAtCapture: capturedP,
        ),
        isA<Success<void>>(),
      );
      expect(h.session.state!.owner, owner);
      expect(h.session.state!.owner.submissionId, isNull);
      expect(h.session.state!.current, c);
      expect(h.session.state!.physicalCheckpoint!.snapshot, b2);
      expect(
        h.session.state!.physicalCheckpoint!.fieldWriteIntent,
        replacement,
      );
      expect(
        h.session.state!.physicalCheckpoint!.navigationIntent!.requestNonce,
        attemptB,
      );
      h.session.revoke();
      await h.session.activate(owner);
      expect(
        h.session.state!.physicalCheckpoint!.fieldWriteIntent,
        replacement,
      );
      expect(h.session.state!.current, b2);
      expect(
        await h.session.replaceRejectedCreateIntent(
          activation: activation,
          attemptId: attemptB,
          replacement: original,
          checkpointAtCapture: capturedP,
        ),
        isA<Error<void>>(),
      );
    },
  );

  for (final kind in AdminFieldWriteKind.values) {
    test(
      'foreign session cannot settle ${kind.name} with equal owner/generation',
      () async {
        final h = AdminDraftSessionHarness();
        final owner = kind == AdminFieldWriteKind.update
            ? h.owner
            : AdminDraftOwner(accountId: AdminDraftSessionHarness.accountA);
        await h.session.activate(owner);
        final activation = h.session.captureActivation()!;
        final intent = AdminFieldWriteIntent(
          kind: kind,
          attemptId: attemptA,
          snapshot: AdminDraftSnapshot(name: 'A'),
          expectedModifiedAt: kind == AdminFieldWriteKind.update ? token : null,
        );
        await h.session.beginFieldWrite(
          intent,
          activation: activation,
          checkpointAtCapture: h.session.state!.physicalCheckpoint,
        );
        final other = AdminDraftSessionHarness();
        await other.session.activate(owner);
        final foreign = other.session.captureActivation()!;
        expect(foreign.owner, same(activation.owner));
        expect(foreign.generation, activation.generation);
        expect(
          await h.session.settleFieldWriteIntent(
            activation: foreign,
            attemptId: attemptA,
            kind: kind,
          ),
          isA<Error<void>>(),
        );
        expect(h.session.state!.physicalCheckpoint!.fieldWriteIntent, intent);
        if (kind == AdminFieldWriteKind.create) {
          expect(
            await h.session.replaceRejectedCreateIntent(
              activation: foreign,
              attemptId: attemptA,
              replacement: AdminFieldWriteIntent(
                kind: kind,
                attemptId: attemptB,
                snapshot: AdminDraftSnapshot(name: 'B'),
              ),
              checkpointAtCapture: h.session.state!.physicalCheckpoint,
            ),
            isA<Error<void>>(),
          );
          expect(h.session.state!.physicalCheckpoint!.fieldWriteIntent, intent);
        }
      },
    );
  }

  test(
    'failed Create correction preserves original attempt until local retry',
    () async {
      final h = AdminDraftSessionHarness();
      final owner = AdminDraftOwner(
        accountId: AdminDraftSessionHarness.accountA,
      );
      await h.session.activate(owner);
      final activation = h.session.captureActivation()!;
      final original = AdminFieldWriteIntent(
        kind: AdminFieldWriteKind.create,
        attemptId: attemptA,
        snapshot: AdminDraftSnapshot(name: 'A'),
      );
      await h.session.beginFieldWrite(
        original,
        activation: activation,
        checkpointAtCapture: null,
      );
      final b = AdminDraftSnapshot(name: 'corrected B');
      h.session.setSnapshot(b, activation: activation);
      await h.session.checkpoint();
      final captured = h.session.state!.physicalCheckpoint;
      final corrected = AdminFieldWriteIntent(
        kind: AdminFieldWriteKind.create,
        attemptId: attemptB,
        snapshot: b,
      );
      h.drafts.onSave = (_) async =>
          Result.error(Exception('store unavailable'));
      expect(
        await h.session.replaceRejectedCreateIntent(
          activation: activation,
          attemptId: attemptA,
          replacement: corrected,
          checkpointAtCapture: captured,
        ),
        isA<Error<void>>(),
      );
      expect(h.session.state!.current, b);
      expect(h.session.state!.physicalCheckpoint!.fieldWriteIntent, original);
      expect(h.drafts.drafts[owner.lookupKey]!.fieldWriteIntent, original);
      h.drafts.onSave = null;
      expect(
        await h.session.replaceRejectedCreateIntent(
          activation: activation,
          attemptId: attemptA,
          replacement: corrected,
          checkpointAtCapture: captured,
        ),
        isA<Success<void>>(),
      );
      expect(h.drafts.drafts[owner.lookupKey]!.fieldWriteIntent, corrected);
      expect(h.drafts.drafts[owner.lookupKey]!.snapshot, b);
    },
  );
}
