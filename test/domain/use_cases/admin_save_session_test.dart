import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/domain/models/admin_submission_draft.dart';
import 'package:moliseis/domain/use_cases/admin_draft_session.dart';
import 'package:moliseis/utils/result.dart';

import '../../support/admin_draft_repositories.dart';

void main() {
  const attempt = '11111111-1111-4111-8111-111111111111';
  const token = '2026-10-27T12:00:00.123456+00:00';

  test(
    'equal owner and generation cannot transfer a foreign session token',
    () async {
      final h = AdminDraftSessionHarness()..seed();
      await h.session.activate(h.owner);
      final other = AdminDraftSession(
        draftRepository: h.drafts,
        stagedAssetRepository: h.staged,
      );
      await other.activate(h.owner);
      final foreign = other.captureActivation()!;
      expect(foreign.owner, same(h.session.state!.owner));
      expect(foreign.generation, h.session.captureActivation()!.generation);
      expect(h.session.isActivationCurrent(foreign), isFalse);
      expect(
        h.session.isActivationCurrent(h.session.captureActivation()),
        isTrue,
      );
      h.session.revoke();
      expect(h.session.isActivationCurrent(foreign), isFalse);
    },
  );

  test(
    'typing during adoption survives the storage await and owner rotation',
    () async {
      final h = AdminDraftSessionHarness();
      final owner = AdminDraftOwner(
        accountId: AdminDraftSessionHarness.accountA,
      );
      await h.session.activate(owner);
      final activation = h.session.captureActivation()!;
      final a = AdminDraftSnapshot(name: 'Save A');
      h.session.setSnapshot(a, activation: activation);
      await h.session.beginFieldWrite(
        AdminFieldWriteIntent(
          kind: AdminFieldWriteKind.create,
          attemptId: attempt,
          snapshot: a,
        ),
        activation: activation,
        checkpointAtCapture: h.session.state!.physicalCheckpoint,
      );
      final entered = Completer<void>();
      final release = Completer<void>();
      h.drafts.onAdopt = () {
        entered.complete();
        return release.future;
      };
      final adopting = h.session.adoptRemoteIdentity(
        activation: activation,
        attemptId: attempt,
        submissionId: 42,
        baseline: h.remote('Save A'),
      );
      await entered.future;
      final b = AdminDraftSnapshot(name: 'typing B', latitudeText: '-');
      expect(
        h.session.setSnapshot(b, activation: activation),
        isA<Success<void>>(),
      );
      final effective = h.session.state!.effective;
      release.complete();
      expect(await adopting, isA<Success<void>>());
      expect(h.session.state!.current, b);
      expect(h.session.state!.effective, same(effective));
      expect(h.session.state!.physicalCheckpoint!.snapshot, a);
      expect(h.session.state!.owner.submissionId, 42);
      expect(h.session.state!.owner.sessionId, owner.sessionId);
      expect(h.session.state!.hasUncheckpointedChanges, isTrue);
      expect(h.session.isActivationCurrent(activation), isFalse);
      expect(
        h.session.isActivationCurrent(h.session.captureActivation()),
        isTrue,
      );
    },
  );

  test(
    'Save A checkpoints A while newer typing B remains uncheckpointed',
    () async {
      final h = AdminDraftSessionHarness()..seed();
      await h.session.activate(h.owner);
      final activation = h.session.captureActivation()!;
      final checkpointAtCapture = h.session.state!.physicalCheckpoint;
      final a = AdminDraftSnapshot(name: 'Save A');
      h.session.setSnapshot(a, activation: activation);
      final entered = Completer<void>();
      final release = Completer<Result<void>>();
      h.drafts.onSave = (_) {
        entered.complete();
        return release.future;
      };
      final saving = h.session.beginFieldWrite(
        AdminFieldWriteIntent(
          kind: AdminFieldWriteKind.update,
          attemptId: attempt,
          snapshot: a,
          expectedModifiedAt: token,
        ),
        activation: activation,
        checkpointAtCapture: checkpointAtCapture,
      );
      await entered.future;
      final b = AdminDraftSnapshot(name: 'typing B', latitudeText: '-');
      h.session.setSnapshot(b, activation: activation);
      release.complete(const Result.success(null));
      expect(await saving, isA<Success<void>>());
      expect(h.session.state!.current, b);
      expect(h.session.state!.effective, a);
      expect(h.session.state!.physicalCheckpoint!.snapshot, a);
      expect(h.session.state!.hasUncheckpointedChanges, isTrue);
    },
  );

  test(
    'queued Save A retains newer explicit checkpoint B and original intent A',
    () async {
      final h = AdminDraftSessionHarness()..seed();
      await h.session.activate(h.owner);
      final activation = h.session.captureActivation()!;
      final capturedP = h.session.state!.physicalCheckpoint;
      final a = AdminDraftSnapshot(name: 'Save A');
      final b = AdminDraftSnapshot(name: 'explicit B', latitudeText: '-');
      h.session.setSnapshot(b, activation: activation);
      final entered = Completer<void>();
      final release = Completer<Result<void>>();
      var writes = 0;
      h.drafts.onSave = (_) {
        if (++writes == 1) {
          entered.complete();
          return release.future;
        }
        return Future.value(const Result.success(null));
      };
      final checkpointB = h.session.checkpoint();
      await entered.future;
      final intent = AdminFieldWriteIntent(
        kind: AdminFieldWriteKind.update,
        attemptId: attempt,
        snapshot: a,
        expectedModifiedAt: token,
      );
      final saving = h.session.beginFieldWrite(
        intent,
        activation: activation,
        checkpointAtCapture: capturedP,
      );
      release.complete(const Result.success(null));
      expect(await checkpointB, isA<Success<void>>());
      expect(await saving, isA<Success<void>>());
      expect(h.session.state!.physicalCheckpoint!.snapshot, b);
      expect(h.session.state!.physicalCheckpoint!.fieldWriteIntent, intent);
      expect(h.session.state!.current, b);
      expect(h.session.state!.hasUncheckpointedChanges, isFalse);
    },
  );

  test('failed intent write starts no durable remote intent '
      'and queue remains usable', () async {
    final h = AdminDraftSessionHarness()..seed();
    await h.session.activate(h.owner);
    final activation = h.session.captureActivation()!;
    final before = h.session.state!.physicalCheckpoint;
    h.drafts.onSave = (_) async => Result.error(Exception('disk unavailable'));
    expect(
      await h.session.beginFieldWrite(
        AdminFieldWriteIntent(
          kind: AdminFieldWriteKind.update,
          attemptId: attempt,
          snapshot: AdminDraftSnapshot(name: 'Save A'),
          expectedModifiedAt: token,
        ),
        activation: activation,
        checkpointAtCapture: before,
      ),
      isA<Error<void>>(),
    );
    expect(h.session.state!.physicalCheckpoint, before);
    h.drafts.onSave = null;
    expect(await h.session.checkpoint(), isA<Success<void>>());
  });

  test(
    'revoked intent commit retains old durable work without publication into B',
    () async {
      final h = AdminDraftSessionHarness()..seed();
      await h.session.activate(h.owner);
      final activation = h.session.captureActivation()!;
      final entered = Completer<void>();
      final release = Completer<Result<void>>();
      h.drafts.onSave = (_) {
        entered.complete();
        return release.future;
      };
      final saving = h.session.beginFieldWrite(
        AdminFieldWriteIntent(
          kind: AdminFieldWriteKind.update,
          attemptId: attempt,
          snapshot: AdminDraftSnapshot(name: 'Save A'),
          expectedModifiedAt: token,
        ),
        activation: activation,
        checkpointAtCapture: h.session.state!.physicalCheckpoint,
      );
      await entered.future;
      h.session.revoke();
      final b = AdminDraftOwner(accountId: AdminDraftSessionHarness.accountB);
      final activating = h.session.activate(b);
      release.complete(const Result.success(null));
      expect(await saving, isA<Success<void>>());
      expect(await activating, isA<Success<void>>());
      expect(h.session.state!.owner, b);
      expect(h.session.state!.physicalCheckpoint, isNull);
      expect(
        h.drafts.drafts[h.owner.lookupKey]!.fieldWriteIntent!.attemptId,
        attempt,
      );
      expect(
        await h.session.confirmFieldWrite(
          activation: activation,
          attemptId: attempt,
          baseline: h.remote('Save A'),
        ),
        isA<Error<void>>(),
      );
    },
  );
}
