import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/data/data-sources/admin_submission_draft_entity.dart';
import 'package:moliseis/data/mappers/admin_submission_draft_mapper.dart';
import 'package:moliseis/domain/core/event_time.dart';
import 'package:moliseis/domain/models/admin_submission_draft.dart';
import 'package:moliseis/domain/models/admin_submission_status.dart';
import 'package:moliseis/domain/models/content_category.dart';

void main() {
  final owner = AdminDraftOwner(
    accountId: '11111111-1111-4111-8111-111111111111',
    sessionId: '22222222-2222-4222-8222-222222222222',
    submissionId: 12,
  );

  test('complete checkpoint and historical remote baseline round-trip', () {
    final snapshot = AdminDraftSnapshot(
      category: ContentCategory.nature,
      city: ' City ',
      name: ' Name ',
      description: 'Text',
      descriptionDelta: const [
        {
          'insert': 'Text\n',
          'attributes': {'bold': true},
        },
      ],
      latitudeText: ' 41,0 ',
      longitudeText: '-',
      eventDates: EventDateDraft.unresolvedStart(
        EventCalendarDate(2026, 10, 27),
        endCalendarDate: EventCalendarDate(2026, 10, 29),
      ),
    );
    final draft = AdminSubmissionDraft(
      owner: owner,
      snapshot: snapshot,
      remoteBaseline: AdminRemoteBaseline(
        snapshot: snapshot.copyWith(name: 'Remote'),
        status: AdminSubmissionStatus.pending,
        modifiedAt: DateTime.utc(2026, 10, 27),
      ),
    );
    final entity = draft.toEntity(id: 42);
    expect(entity.id, 42);
    expect(entity.toModel(), draft);
    expect(entity.toModel().snapshot.latitudeText, ' 41,0 ');
  });

  test(
    'disabled enabled-empty exact and all-day temporal modes round-trip',
    () {
      final policy = EventTimePolicy();
      final day = EventCalendarDate(2026, 10, 27);
      final allDay = policy
          .changeAllDay(EventDateDraft.unresolvedStart(day), allDay: true)
          .draft;
      final values = [
        const EventDateDraft.disabled(),
        const EventDateDraft.enabledEmpty(),
        const EventDateDraft.enabledEmpty(allDay: true),
        EventDateDraft.unresolvedStart(day),
        EventDateDraft.exact(
          startCalendarDate: day,
          startInstantUtc: DateTime.utc(2026, 10, 27, 10),
          endInstantUtc: DateTime.utc(2026, 10, 29),
        ),
        allDay,
        policy.changeAllDay(allDay, allDay: false).draft,
      ];
      for (final dates in values) {
        final draft = AdminSubmissionDraft(
          owner: owner,
          snapshot: AdminDraftSnapshot(eventDates: dates),
        );
        expect(draft.toEntity().toModel(), draft, reason: '$dates');
      }
    },
  );

  test('every category and null round-trip without index fallback', () {
    for (final category in <ContentCategory?>[
      null,
      ...ContentCategory.values,
    ]) {
      final draft = AdminSubmissionDraft(
        owner: owner,
        snapshot: AdminDraftSnapshot(category: category),
      );
      expect(draft.toEntity().toModel().snapshot.category, category);
    }
  });

  test(
    'unsupported malformed and wrong-key rows fail rather than disappear',
    () {
      final draft = AdminSubmissionDraft(
        owner: owner,
        snapshot: AdminDraftSnapshot(),
      );
      for (final payload in [
        '{',
        '[]',
        '{"version":2}',
        '{"version":1,"snapshot":{}}',
      ]) {
        final entity = AdminSubmissionDraftEntity(
          lookupKey: owner.lookupKey,
          accountId: owner.accountId,
          sessionId: owner.sessionId,
          submissionId: owner.submissionId,
          payload: payload,
        );
        expect(entity.toModel, throwsFormatException);
      }
      final wrongKey = AdminSubmissionDraftEntity(
        lookupKey: 'wrong',
        accountId: owner.accountId,
        sessionId: owner.sessionId,
        submissionId: owner.submissionId,
        payload: draft.toEntity().payload,
      );
      expect(wrongKey.toModel, throwsFormatException);
    },
  );

  test(
    'invalid nested values are decoding failures, not raw cast failures',
    () {
      final entity = AdminSubmissionDraft(
        owner: owner,
        snapshot: AdminDraftSnapshot(),
      ).toEntity();
      final data = jsonDecode(entity.payload) as Map<String, dynamic>;
      for (final invalid in <String, Object?>{
        'category': 'future-category',
        'city': 1,
        'delta': [1],
        'latitude': null,
        'dates': {'enabled': false, 'allDay': false, 'startDay': '2026-02-31'},
      }.entries) {
        final snapshot = Map<String, dynamic>.from(data['snapshot'] as Map);
        snapshot[invalid.key] = invalid.value;
        final row = AdminSubmissionDraftEntity(
          lookupKey: owner.lookupKey,
          accountId: owner.accountId,
          sessionId: owner.sessionId,
          submissionId: owner.submissionId,
          payload: jsonEncode({...data, 'snapshot': snapshot}),
        );
        expect(row.toModel, throwsFormatException, reason: invalid.key);
      }
    },
  );

  test('new local target cannot inherit historical remote baseline', () {
    final draft = AdminSubmissionDraft(
      owner: AdminDraftOwner(accountId: owner.accountId),
      snapshot: AdminDraftSnapshot(),
      remoteBaseline: AdminRemoteBaseline(
        snapshot: AdminDraftSnapshot(),
        status: AdminSubmissionStatus.pending,
        modifiedAt: DateTime.utc(2026),
      ),
    );
    expect(draft.toEntity, throwsFormatException);
  });
}
