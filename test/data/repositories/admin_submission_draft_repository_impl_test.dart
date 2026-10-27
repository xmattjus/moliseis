import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/data/data-sources/admin_submission_draft_entity.dart';
import 'package:moliseis/data/mappers/admin_submission_draft_mapper.dart';
import 'package:moliseis/data/repositories/admin_submission_draft_repository_impl.dart';
import 'package:moliseis/domain/core/event_time.dart';
import 'package:moliseis/domain/models/admin_submission_draft.dart';
import 'package:moliseis/utils/result.dart';

import '../../support/mock_logger.dart';
import '../../support/objectbox_test_store.dart';

void main() {
  const account = '11111111-1111-4111-8111-111111111111';
  const otherAccount = '33333333-3333-4333-8333-333333333333';
  late TestObjectBoxEnvironment environment;
  late AdminSubmissionDraftRepositoryImpl repository;
  late AdminDraftOwner owner;

  setUp(() async {
    environment = await TestObjectBoxEnvironment.create();
    repository = AdminSubmissionDraftRepositoryImpl(
      objectBoxI: TestObjectBox(environment.store),
      logger: MockLogger(),
    );
    owner = AdminDraftOwner(accountId: account);
  });
  tearDown(() async {
    await environment.dispose();
  });

  test(
    'authoritative absence is a successful null without creating an owner',
    () async {
      expect(
        await repository.loadDraft(accountId: account),
        isA<Success<AdminSubmissionDraft?>>().having(
          (r) => r.value,
          'draft',
          isNull,
        ),
      );
      expect(environment.store.box<AdminSubmissionDraftEntity>().count(), 0);
    },
  );

  test(
    'real store preserves incomplete exact snapshot and stable technical ID',
    () async {
      final draft = AdminSubmissionDraft(
        owner: owner,
        snapshot: AdminDraftSnapshot(
          latitudeText: ' - ',
          longitudeText: '14,',
          descriptionDelta: const [
            {
              'insert': 'Text\n',
              'attributes': {'bold': true},
            },
          ],
          eventDates: EventDateDraft.unresolvedStart(
            EventCalendarDate(2026, 10, 27),
            endCalendarDate: EventCalendarDate(2026, 10, 29),
          ),
        ),
      );
      expect(await repository.saveDraft(draft), isA<Success<void>>());
      final box = environment.store.box<AdminSubmissionDraftEntity>();
      final firstId = box.getAll().single.id;
      expect(
        (await repository.loadDraft(accountId: account)).getOrNull(),
        draft,
      );
      final changed = AdminSubmissionDraft(
        owner: owner,
        snapshot: draft.snapshot.copyWith(name: 'B'),
      );
      expect(await repository.saveDraft(changed), isA<Success<void>>());
      expect(box.getAll().single.id, firstId);
      expect(
        (await repository.loadDraft(accountId: account)).getOrNull(),
        changed,
      );
    },
  );

  test(
    'new persisted targets and accounts remain independently recoverable',
    () async {
      final owners = [
        owner,
        AdminDraftOwner(accountId: account, submissionId: 1),
        AdminDraftOwner(accountId: account, submissionId: 2),
        AdminDraftOwner(accountId: otherAccount),
      ];
      for (final item in owners) {
        expect(
          await repository.saveDraft(
            AdminSubmissionDraft(
              owner: item,
              snapshot: AdminDraftSnapshot(name: item.sessionId),
            ),
          ),
          isA<Success<void>>(),
        );
      }
      for (final item in owners) {
        final loaded = (await repository.loadDraft(
          accountId: item.accountId,
          submissionId: item.submissionId,
        )).getOrNull();
        expect(loaded!.owner, item);
        expect(loaded.snapshot.name, item.sessionId);
      }
      expect(environment.store.box<AdminSubmissionDraftEntity>().count(), 4);
    },
  );

  test(
    'a different session cannot overwrite an existing account target',
    () async {
      final original = AdminSubmissionDraft(
        owner: owner,
        snapshot: AdminDraftSnapshot(name: 'A'),
      );
      await repository.saveDraft(original);
      final replacement = AdminSubmissionDraft(
        owner: AdminDraftOwner(accountId: account),
        snapshot: AdminDraftSnapshot(name: 'B'),
      );
      expect(await repository.saveDraft(replacement), isA<Error<void>>());
      expect(
        (await repository.loadDraft(accountId: account)).getOrNull(),
        original,
      );
    },
  );

  test(
    'malformed checkpoint is unknown and cannot be overwritten as absence',
    () async {
      final box = environment.store.box<AdminSubmissionDraftEntity>();
      final row = AdminSubmissionDraftEntity(
        lookupKey: owner.lookupKey,
        accountId: owner.accountId,
        sessionId: owner.sessionId,
        submissionId: null,
        payload: '{"version":99}',
      );
      box.put(row);
      expect(
        await repository.loadDraft(accountId: account),
        isA<Error<AdminSubmissionDraft?>>(),
      );
      expect(
        await repository.saveDraft(
          AdminSubmissionDraft(
            owner: owner,
            snapshot: AdminDraftSnapshot(name: 'replacement'),
          ),
        ),
        isA<Error<void>>(),
      );
      expect(box.get(row.id)!.payload, row.payload);
    },
  );

  test(
    'conflicting raw target rows are quarantined rather than selecting one',
    () async {
      final box = environment.store.box<AdminSubmissionDraftEntity>()
        ..put(
          AdminSubmissionDraft(
            owner: owner,
            snapshot: AdminDraftSnapshot(name: 'A'),
          ).toEntity(),
        );
      final other = AdminDraftOwner(accountId: account);
      box.put(
        AdminSubmissionDraftEntity(
          lookupKey: '$account/conflicting',
          accountId: account,
          sessionId: other.sessionId,
          submissionId: null,
          payload: AdminSubmissionDraft(
            owner: other,
            snapshot: AdminDraftSnapshot(name: 'B'),
          ).toEntity().payload,
        ),
      );
      expect(
        await repository.loadDraft(accountId: account),
        isA<Error<AdminSubmissionDraft?>>(),
      );
      expect(
        await repository.saveDraft(
          AdminSubmissionDraft(
            owner: owner,
            snapshot: AdminDraftSnapshot(name: 'C'),
          ),
        ),
        isA<Error<void>>(),
      );
      expect(box.count(), 2);
    },
  );

  test(
    'unique lookup and session indexes reject duplicate persistence identities',
    () {
      final box = environment.store.box<AdminSubmissionDraftEntity>();
      final first = AdminSubmissionDraft(
        owner: owner,
        snapshot: AdminDraftSnapshot(),
      ).toEntity();
      box.put(first);
      expect(
        () => box.put(
          AdminSubmissionDraft(
            owner: owner,
            snapshot: AdminDraftSnapshot(),
          ).toEntity(),
        ),
        throwsException,
      );
      final reused = AdminDraftOwner(
        accountId: account,
        sessionId: owner.sessionId,
        submissionId: 42,
      );
      expect(
        () => box.put(
          AdminSubmissionDraft(
            owner: reused,
            snapshot: AdminDraftSnapshot(),
          ).toEntity(),
        ),
        throwsException,
      );
      expect(box.count(), 1);
    },
  );

  test(
    'lookup-key ownership corruption cannot masquerade as absence',
    () async {
      final box = environment.store.box<AdminSubmissionDraftEntity>()
        ..put(
          AdminSubmissionDraftEntity(
            lookupKey: owner.lookupKey,
            accountId: otherAccount,
            sessionId: owner.sessionId,
            submissionId: 99,
            payload: AdminSubmissionDraft(
              owner: owner,
              snapshot: AdminDraftSnapshot(),
            ).toEntity().payload,
          ),
        );
      expect(
        await repository.loadDraft(accountId: account),
        isA<Error<AdminSubmissionDraft?>>(),
      );
      expect(
        await repository.saveDraft(
          AdminSubmissionDraft(owner: owner, snapshot: AdminDraftSnapshot()),
        ),
        isA<Error<void>>(),
      );
      expect(box.count(), 1);
    },
  );

  test(
    'closed real store returns failure instead of authoritative absence',
    () async {
      environment.close();
      expect(
        await repository.loadDraft(accountId: account),
        isA<Error<AdminSubmissionDraft?>>(),
      );
      expect(
        await repository.saveDraft(
          AdminSubmissionDraft(owner: owner, snapshot: AdminDraftSnapshot()),
        ),
        isA<Error<void>>(),
      );
    },
  );

  test('invalid lookup is unavailable without touching other rows', () async {
    await repository.saveDraft(
      AdminSubmissionDraft(owner: owner, snapshot: AdminDraftSnapshot()),
    );
    expect(
      await repository.loadDraft(accountId: '../foreign'),
      isA<Error<AdminSubmissionDraft?>>(),
    );
    expect(
      await repository.loadDraft(accountId: account, submissionId: 0),
      isA<Error<AdminSubmissionDraft?>>(),
    );
    expect(environment.store.box<AdminSubmissionDraftEntity>().count(), 1);
  });
}
