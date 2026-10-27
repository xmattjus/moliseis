import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/domain/core/event_time.dart';
import 'package:moliseis/domain/models/admin_submission_draft.dart';
import 'package:moliseis/domain/models/admin_submission_status.dart';
import 'package:moliseis/domain/models/content_category.dart';

void main() {
  const account = '11111111-1111-4111-8111-111111111111';
  const session = '22222222-2222-4222-8222-222222222222';

  test(
    'fresh ownership is secure UUID-v4 and remains stable in checkpoints',
    () {
      final owner = AdminDraftOwner(accountId: account);
      expect(AdminDraftOwner.isValidSessionId(owner.sessionId), isTrue);
      expect(
        AdminDraftOwner(accountId: account).sessionId,
        isNot(owner.sessionId),
      );
      final a = AdminSubmissionDraft(
        owner: owner,
        snapshot: AdminDraftSnapshot(),
      );
      final b = AdminSubmissionDraft(
        owner: owner,
        snapshot: a.snapshot.copyWith(name: 'B'),
      );
      expect(a.owner, b.owner);
      expect(a.owner.submissionId, isNull);
      expect(a.owner.lookupKey, '$account/new');
    },
  );

  test('account session and target each participate in owner equality', () {
    final owner = AdminDraftOwner(accountId: account, sessionId: session);
    expect(owner, AdminDraftOwner(accountId: account, sessionId: session));
    expect(
      owner.hashCode,
      AdminDraftOwner(accountId: account, sessionId: session).hashCode,
    );
    expect(
      owner,
      isNot(
        AdminDraftOwner(
          accountId: account,
          sessionId: session,
          submissionId: 1,
        ),
      ),
    );
    expect(owner, isNot(AdminDraftOwner(accountId: account)));
    expect(
      owner,
      isNot(AdminDraftOwner(accountId: session, sessionId: session)),
    );
  });

  test('invalid ownership is rejected before filesystem use', () {
    expect(
      () => AdminDraftOwner(accountId: '../elsewhere'),
      throwsArgumentError,
    );
    expect(
      () => AdminDraftOwner(accountId: account, sessionId: '../elsewhere'),
      throwsArgumentError,
    );
    expect(
      () => AdminDraftOwner(accountId: account, submissionId: 0),
      throwsArgumentError,
    );
  });

  test(
    'snapshot preserves nullable incomplete fields and exact coordinates',
    () {
      final snapshot = AdminDraftSnapshot(
        category: ContentCategory.history,
        city: ' Town ',
        name: 'Name',
        latitudeText: ' 41,0 ',
        longitudeText: '-',
        eventDates: EventDateDraft.unresolvedStart(
          EventCalendarDate(2026, 10, 27),
          endCalendarDate: EventCalendarDate(2026, 10, 29),
        ),
      );
      expect(snapshot.copyWith(), snapshot);
      expect(snapshot.copyWith().hashCode, snapshot.hashCode);
      expect(snapshot.latitudeText, ' 41,0 ');
      expect(snapshot.longitudeText, '-');
      expect(snapshot.eventDates.startInstantUtc, isNull);
      expect(snapshot.copyWith(category: null, name: null).category, isNull);
      expect(snapshot.copyWith(name: null).name, isNull);
      expect(snapshot.copyWith(latitudeText: '41,0'), isNot(snapshot));
      expect(
        snapshot.copyWith(eventDates: const EventDateDraft.disabled()),
        isNot(snapshot),
      );
    },
  );

  test('Delta nested values are copied frozen and structurally compared', () {
    final attributes = <String, dynamic>{'bold': true};
    final delta = <Map<String, dynamic>>[
      {'insert': 'A', 'attributes': attributes},
    ];
    final snapshot = AdminDraftSnapshot(descriptionDelta: delta);
    final expected = snapshot.copyWith();
    final hash = snapshot.hashCode;
    attributes['bold'] = false;
    delta.add({'insert': 'B'});
    expect(snapshot, expected);
    expect(snapshot.hashCode, hash);
    expect(snapshot.descriptionDelta!.single['attributes'], {'bold': true});
    expect(
      () => snapshot.descriptionDelta!.add({'insert': 'C'}),
      throwsUnsupportedError,
    );
    expect(
      () => (snapshot.descriptionDelta!.single['attributes'] as Map)['bold'] =
          false,
      throwsUnsupportedError,
    );
  });

  test(
    'remote projection normalizes server fields without changing raw equality',
    () {
      final raw = AdminDraftSnapshot(
        city: ' Town ',
        name: ' Name ',
        latitudeText: '41,0',
        longitudeText: ' 14.00 ',
      );
      final remote = AdminDraftSnapshot(
        category: ContentCategory.unknown,
        city: 'Town',
        name: 'Name',
        latitudeText: '41.0',
        longitudeText: '14.0',
      );
      expect(raw.sameRemoteProjection(remote), isTrue);
      expect(remote.sameRemoteProjection(raw), isTrue);
      expect(raw.fieldsEqualTo(remote), isFalse);
      expect(raw.fieldsEqualTo(remote, semanticCoordinates: true), isFalse);
      expect(raw.category, isNull);
      expect(raw.city, ' Town ');
      expect(raw.name, ' Name ');
      expect(raw.latitudeText, '41,0');
      expect(
        raw.sameRemoteProjection(remote.copyWith(name: 'Different')),
        isFalse,
      );
      expect(
        raw.sameRemoteProjection(
          remote.copyWith(category: ContentCategory.nature),
        ),
        isFalse,
      );
    },
  );

  test(
    'remote projection never confirms incomplete or invalid coordinates',
    () {
      final remote = AdminDraftSnapshot(
        category: ContentCategory.unknown,
        city: 'Town',
        name: 'Name',
        latitudeText: '41.0',
        longitudeText: '14.0',
      );
      for (final latitude in ['-', 'NaN', 'Infinity', '91', '']) {
        final raw = remote.copyWith(latitudeText: latitude);
        expect(raw.sameRemoteProjection(remote), isFalse, reason: latitude);
        expect(raw.sameRemoteProjection(raw), isFalse, reason: latitude);
      }
    },
  );

  test('semantic remote coordinates do not change exact local equality', () {
    final a = AdminDraftSnapshot(
      latitudeText: ' 41,0 ',
      longitudeText: '14,00',
    );
    final b = AdminDraftSnapshot(latitudeText: '41.0', longitudeText: '14.0');
    expect(a, isNot(b));
    expect(a.fieldsEqualTo(b, semanticCoordinates: true), isTrue);
    expect(a.latitudeText, ' 41,0 ');
    expect(
      a
          .copyWith(latitudeText: 'NaN')
          .fieldsEqualTo(b, semanticCoordinates: true),
      isFalse,
    );
    expect(
      a
          .copyWith(latitudeText: '91')
          .fieldsEqualTo(b, semanticCoordinates: true),
      isFalse,
    );
    expect(
      AdminDraftSnapshot().fieldsEqualTo(
        AdminDraftSnapshot(),
        semanticCoordinates: true,
      ),
      isTrue,
    );
    expect(
      AdminDraftSnapshot(latitudeText: '-').fieldsEqualTo(
        AdminDraftSnapshot(latitudeText: '-'),
        semanticCoordinates: true,
      ),
      isFalse,
    );
  });

  test(
    'checkpoint equality includes owner fields and historical remote data',
    () {
      final owner = AdminDraftOwner(
        accountId: account,
        sessionId: session,
        submissionId: 1,
      );
      final snapshot = AdminDraftSnapshot(name: 'A');
      final baseline = AdminRemoteBaseline(
        snapshot: snapshot,
        status: AdminSubmissionStatus.pending,
        modifiedAt: DateTime.utc(2026, 10, 27),
      );
      final draft = AdminSubmissionDraft(
        owner: owner,
        snapshot: snapshot,
        remoteBaseline: baseline,
      );
      final equal = AdminSubmissionDraft(
        owner: owner,
        snapshot: snapshot,
        remoteBaseline: baseline,
      );
      expect(draft, equal);
      expect(draft.hashCode, equal.hashCode);
      expect(
        draft,
        isNot(AdminSubmissionDraft(owner: owner, snapshot: snapshot)),
      );
      expect(
        baseline,
        isNot(
          AdminRemoteBaseline(
            snapshot: snapshot,
            status: AdminSubmissionStatus.accepted,
            modifiedAt: baseline.modifiedAt,
          ),
        ),
      );
    },
  );
}
