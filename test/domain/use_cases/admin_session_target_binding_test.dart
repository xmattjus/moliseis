import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/domain/models/admin_submission_draft.dart';
import 'package:moliseis/utils/result.dart';

import '../../support/admin_draft_repositories.dart';

void main() {
  test('matching explicit target resumes its durable session', () async {
    final h = AdminDraftSessionHarness()..seed();

    expect(
      await h.session.activateBySession(
        accountId: h.owner.accountId,
        sessionId: h.owner.sessionId,
        expectedSubmissionId: h.owner.submissionId,
      ),
      isA<Success<void>>(),
    );
    expect(h.session.state!.owner, h.owner);
  });

  test('mismatching hint preserves the active target and its work', () async {
    final h = AdminDraftSessionHarness()..seed();
    await h.session.activate(h.owner);
    final activation = h.session.captureActivation()!;
    final unrelated = AdminDraftOwner(
      accountId: h.owner.accountId,
      submissionId: 456,
    );
    h.drafts.drafts[unrelated.lookupKey] = AdminSubmissionDraft(
      owner: unrelated,
      snapshot: AdminDraftSnapshot(name: 'Unrelated target'),
    );
    final before = h.session.state;

    expect(
      await h.session.activateBySession(
        accountId: h.owner.accountId,
        sessionId: unrelated.sessionId,
        expectedSubmissionId: 123,
      ),
      isA<Error<void>>(),
    );
    expect(h.session.state, same(before));
    expect(h.session.isActivationCurrent(activation), isTrue);

    final current = AdminDraftSnapshot(name: 'Uncheckpointed private work');
    h.session.setSnapshot(current, activation: activation);
    expect(
      await h.session.activateBySession(
        accountId: h.owner.accountId,
        sessionId: h.owner.sessionId,
        expectedSubmissionId: 123,
      ),
      isA<Error<void>>(),
    );
    expect(h.session.state!.owner, h.owner);
    expect(h.session.state!.current, current);
    expect(h.session.state!.physicalCheckpoint!.snapshot.name, 'A');
    expect(h.drafts.saves, isEmpty);
  });

  test(
    'missing and foreign hints fail closed without replacing state',
    () async {
      final h = AdminDraftSessionHarness()..seed();
      await h.session.activate(h.owner);
      final before = h.session.state;
      final foreign = AdminDraftOwner(
        accountId: AdminDraftSessionHarness.accountB,
        submissionId: 7,
      );
      h.drafts.drafts[foreign.lookupKey] = AdminSubmissionDraft(
        owner: foreign,
        snapshot: AdminDraftSnapshot(name: 'Private B'),
      );

      for (final sessionId in [
        '99999999-9999-4999-8999-999999999999',
        foreign.sessionId,
      ]) {
        expect(
          await h.session.activateBySession(
            accountId: h.owner.accountId,
            sessionId: sessionId,
            expectedSubmissionId: 7,
          ),
          isA<Error<void>>(),
        );
        expect(h.session.state, same(before));
      }
    },
  );

  test('targetless resume accepts an adopted session', () async {
    final h = AdminDraftSessionHarness()..seed();

    expect(
      await h.session.activateBySession(
        accountId: h.owner.accountId,
        sessionId: h.owner.sessionId,
      ),
      isA<Success<void>>(),
    );
    expect(h.session.state!.owner.submissionId, 7);
    expect(h.session.state!.owner.sessionId, h.owner.sessionId);
  });

  test('obsolete lookup cannot replace B or authorize A2', () async {
    final h = AdminDraftSessionHarness()..seed();
    await h.session.activate(h.owner);
    final a1 = h.session.captureActivation()!;
    final obsolete = h.session.activateBySession(
      accountId: h.owner.accountId,
      sessionId: h.owner.sessionId,
      expectedSubmissionId: h.owner.submissionId,
    );
    h.session.revoke();
    final b = AdminDraftOwner(accountId: AdminDraftSessionHarness.accountB);
    await h.session.activate(b);
    expect(await obsolete, isA<Error<void>>());
    expect(h.session.state!.owner, b);

    expect(
      await h.session.activateBySession(
        accountId: h.owner.accountId,
        sessionId: h.owner.sessionId,
        expectedSubmissionId: h.owner.submissionId,
      ),
      isA<Success<void>>(),
    );
    expect(h.session.state!.owner, h.owner);
    expect(h.session.isActivationCurrent(a1), isFalse);
  });
}
