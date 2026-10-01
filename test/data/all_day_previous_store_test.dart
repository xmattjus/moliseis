import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/data/data-sources/content_submission_draft_entry.dart';
import 'package:moliseis/data/data-sources/event_entity.dart';
import 'package:moliseis/data/mappers/event_entity_mapper.dart';
import 'package:moliseis/data/repositories/content_submission_draft_repository_impl.dart';
import 'package:moliseis/domain/core/event_time.dart';

import '../support/mock_logger.dart';
import '../support/objectbox_test_store.dart';

void main() {
  test(
    'reopens genuine previous ObjectBox cache and writes both temporal modes',
    () async {
      final env = await TestObjectBoxEnvironment.create(
        previousStoreGzipPath:
            'test/fixtures/objectbox/pre_all_day/data.mdb.gz',
      );
      addTearDown(env.dispose);
      final eventBox = env.store.box<EventEntity>();
      final previous = eventBox.get(71)!;
      expect(previous.allDay, isFalse);
      expect(previous.isSaved, isTrue);
      expect(previous.startDate?.toUtc(), DateTime.utc(2026, 10, 11, 22));
      expect(previous.toModel().allDay, isFalse);
      final draftBox = env.store.box<ContentSubmissionDraftEntity>();
      final before = draftBox.get(1)!;
      final repository = ContentSubmissionDraftRepositoryImpl(
        logger: MockLogger(),
        objectBoxI: TestObjectBox(env.store),
      );
      final recovered = (await repository.loadDraft()).getOrNull()!;
      expect(
        recovered.clientSubmissionId,
        '1fdbfe1e-a1b2-4b23-9b42-111111111111',
      );
      expect(recovered.eventDates.allDay, isFalse);
      expect(
        recovered.eventDates.endCalendarDate,
        EventCalendarDate(2026, 10, 14),
      );
      expect(draftBox.get(1)!.allDay, before.allDay);
      expect(draftBox.get(1)!.pendingEndCalendarDate, isNull);
      final policy = EventTimePolicy();
      final allDay = recovered.copyWith(
        eventDates: policy
            .changeAllDay(recovered.eventDates, allDay: true)
            .draft,
      );
      expect((await repository.saveDraft(allDay)).isSuccess, isTrue);
      expect((await repository.loadDraft()).getOrNull(), allDay);
      final singleDay = recovered.copyWith(
        eventDates: policy
            .changeAllDay(
              EventDateDraft.unresolvedStart(EventCalendarDate(2026, 10, 12)),
              allDay: true,
            )
            .draft,
      );
      expect((await repository.saveDraft(singleDay)).isSuccess, isTrue);
      expect((await repository.loadDraft()).getOrNull(), singleDay);
      expect(draftBox.get(1)!.endDate, isNull);
      final pending = allDay.copyWith(
        eventDates: policy.changeAllDay(allDay.eventDates, allDay: false).draft,
      );
      expect((await repository.saveDraft(pending)).isSuccess, isTrue);
      final restored = (await repository.loadDraft()).getOrNull()!;
      expect(restored, pending);
      expect(draftBox.get(1)!.pendingEndCalendarDate, '2026-10-14');
      expect(draftBox.get(1)!.endDate, isNull);
      expect(
        policy.validateForPersistence(restored.eventDates),
        EventTimeIssue.missingStartTime,
      );
      final resolved = restored.copyWith(
        eventDates: policy
            .changeStartClockTime(restored.eventDates, EventClockTime(19, 30))
            .draft,
      );
      expect((await repository.saveDraft(resolved)).isSuccess, isTrue);
      expect((await repository.loadDraft()).getOrNull(), resolved);
      expect(draftBox.get(1)!.pendingEndCalendarDate, isNull);
      eventBox.put(previous.copyWith(allDay: true));
      expect(eventBox.get(71)!.allDay, isTrue);
      expect(eventBox.get(71)!.isSaved, isTrue);
    },
  );
}
