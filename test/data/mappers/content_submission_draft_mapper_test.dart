import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/data/data-sources/content_submission_draft_entry.dart';
import 'package:moliseis/data/mappers/content_submission_draft_mapper.dart';
import 'package:moliseis/domain/core/event_time.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/content_submission_draft.dart';

void main() {
  const clientSubmissionId = '2a1b0c3d-4e5f-4a6b-8c9d-0e1f2a3b4c5d';

  group('ContentSubmissionDraftMapper round-trip', () {
    final startDate = DateTime.utc(2026, 7, 25, 10, 30);
    final endDate = DateTime.utc(2026, 7, 26, 18);

    test(
      'preserves every populated field through entity -> model -> entity',
      () {
        final draft = ContentSubmissionDraft(
          category: ContentCategory.history,
          city: 'Rome',
          name: 'Colosseum',
          description: 'Ancient arena',
          descriptionDelta: const [
            {
              'insert': 'Ancient ',
              'attributes': {'bold': true},
            },
            {'insert': 'arena\n'},
          ],
          userEmail: 'jane@example.com',
          userName: 'Jane',
          acceptedTerms: true,
        );

        final entity = draft.toEntity();
        final restored = entity.toModel();

        expect(restored, equals(draft));
      },
    );

    test(
      'preserves category through a full round-trip (regression guard for '
      'silent category loss)',
      () {
        // The previous mapper dropped `category`/`categoryIndex` entirely, so
        // a draft that set a category lost it after every save/load cycle.
        for (final category in ContentCategory.values) {
          final draft = ContentSubmissionDraft(category: category);

          final restored = draft.toEntity().toModel()!;

          expect(
            restored.category,
            category,
            reason: '$category should round-trip through the entity',
          );
        }
      },
    );

    test(
      'preserves dates through a full round-trip (regression guard for '
      'silent date loss)',
      () {
        final draft = ContentSubmissionDraft(
          eventDates: EventDateDraft.exact(
            startCalendarDate: EventCalendarDate(2026, 7, 25),
            startInstantUtc: startDate,
            endInstantUtc: endDate,
          ),
        );

        final restored = draft.toEntity().toModel()!;

        expect(restored.eventDates.startInstantUtc, startDate);
        expect(restored.eventDates.endInstantUtc, endDate);
      },
    );

    test('preserves an enabled incomplete start day through a round-trip', () {
      final draft = ContentSubmissionDraft(
        eventDates: EventDateDraft.unresolvedStart(
          EventCalendarDate(2026, 7, 25),
        ),
      );

      final entity = draft.toEntity();
      final restored = entity.toModel()!;

      expect(entity.isEvent, isTrue);
      expect(entity.pendingStartCalendarDate, '2026-07-25');
      expect(restored.eventDates, draft.eventDates);
    });

    test('normalizes canonical persisted instants to UTC', () {
      final instant = DateTime.fromMicrosecondsSinceEpoch(
        123456789,
      );
      final startOnly = ContentSubmissionDraftEntity(
        clientSubmissionId: clientSubmissionId,
        isEvent: true,
        startDate: instant,
      ).toModel()!;

      expect(startOnly.eventDates.enabled, isTrue);
      expect(startOnly.eventDates.startInstantUtc?.isUtc, isTrue);
      expect(
        startOnly.eventDates.startInstantUtc?.microsecondsSinceEpoch,
        instant.microsecondsSinceEpoch,
      );
    });

    test('maps disabled and ranged canonical rows', () {
      final start = DateTime.utc(2026, 7, 25, 10, 30);
      final end = DateTime.utc(2026, 7, 26, 18);
      final disabled = ContentSubmissionDraftEntity(
        clientSubmissionId: clientSubmissionId,
        isEvent: false,
      ).toModel()!;
      final range = ContentSubmissionDraftEntity(
        clientSubmissionId: clientSubmissionId,
        isEvent: true,
        startDate: start,
        endDate: end,
      ).toModel()!;

      expect(disabled.eventDates, const EventDateDraft.disabled());
      expect(range.eventDates.enabled, isTrue);
      expect(range.eventDates.startInstantUtc, start);
      expect(range.eventDates.endInstantUtc, end);
    });

    test('round-trips an empty draft without data loss', () {
      final draft = ContentSubmissionDraft();

      final restored = draft.toEntity().toModel()!;

      expect(restored, equals(draft));
      expect(restored.category, isNull);
      expect(restored.city, isNull);
      expect(restored.name, isNull);
      expect(restored.description, isNull);
      expect(restored.descriptionDelta, isNull);
      expect(restored.eventDates, const EventDateDraft.disabled());
      expect(restored.userEmail, isNull);
      expect(restored.userName, isNull);
      expect(restored.acceptedTerms, isNull);
    });

    test('null categoryIndex round-trips to null category and back', () {
      final entity = ContentSubmissionDraftEntity();

      expect(entity.toModel(), isNull);
      // And the reverse: a model with null category writes a null index.
      expect(ContentSubmissionDraft().toEntity().categoryIndex, isNull);
    });

    test('writes the enum index for each category', () {
      for (final category in ContentCategory.values) {
        final entity = ContentSubmissionDraft(category: category).toEntity();

        expect(
          entity.categoryIndex,
          category.index,
          reason: '$category should serialise to its enum index',
        );
      }
    });

    test('reads the enum index for each category', () {
      for (final category in ContentCategory.values) {
        final entity = ContentSubmissionDraftEntity(
          clientSubmissionId: clientSubmissionId,
          categoryIndex: category.index,
        );

        expect(
          entity.toModel()!.category,
          category,
          reason: '${category.index} should deserialise back to $category',
        );
      }
    });

    test('makes defensive copies of Delta operations at mapper boundaries', () {
      final source = <Map<String, dynamic>>[
        {
          'insert': 'Original\n',
          'attributes': <String, dynamic>{'bold': true},
        },
      ];
      final entity = ContentSubmissionDraft(
        descriptionDelta: source,
      ).toEntity();

      source[0]['insert'] = 'Mutated\n';
      (source[0]['attributes']! as Map<String, dynamic>)['bold'] = false;

      expect(entity.descriptionDelta, [
        {
          'insert': 'Original\n',
          'attributes': {'bold': true},
        },
      ]);

      final model = entity.toModel()!;

      expect(
        identical(model.descriptionDelta, entity.descriptionDelta),
        isFalse,
      );
      expect(
        identical(model.descriptionDelta![0], entity.descriptionDelta![0]),
        isFalse,
      );
    });

    test('does not recover an entity with an invalid client identity', () {
      final entity = ContentSubmissionDraftEntity(
        clientSubmissionId: 'not-a-uuid',
        city: 'Rome',
      );

      expect(entity.toModel(), isNull);
    });
  });
}
