import 'package:collection/collection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/data/data-sources/content_submission_draft_entry.dart';
import 'package:moliseis/data/repositories/content_submission_draft_repository_impl.dart';
import 'package:moliseis/domain/core/event_time.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/content_submission_draft.dart';

import '../../support/mock_logger.dart';
import '../../support/objectbox_test_store.dart';

void main() {
  group('ContentSubmissionDraftRepositoryImpl', () {
    late TestObjectBoxEnvironment objectBoxEnvironment;
    late ContentSubmissionDraftRepositoryImpl repository;

    setUp(() async {
      objectBoxEnvironment = await TestObjectBoxEnvironment.create();
      repository = ContentSubmissionDraftRepositoryImpl(
        logger: MockLogger(),
        objectBoxI: TestObjectBox(objectBoxEnvironment.store),
      );
    });

    tearDown(() async {
      await objectBoxEnvironment.dispose();
    });

    test(
      'persists a rich Delta through ObjectBox',
      () async {
        final descriptionDelta = <Map<String, dynamic>>[
          {
            'insert': 'Prima ',
            'attributes': <String, dynamic>{'bold': true},
          },
          {
            'insert': 'sezione',
            'attributes': <String, dynamic>{'underline': true},
          },
          {
            'insert': '\n',
            'attributes': <String, dynamic>{'list': 'bullet'},
          },
          {
            'insert': 'Seconda riga\n',
            'attributes': <String, dynamic>{'italic': true},
          },
        ];
        final draft = ContentSubmissionDraft(
          description: 'Prima sezione\nSeconda riga',
          descriptionDelta: descriptionDelta,
        );

        final saveResult = await repository.saveDraft(draft);
        final loadResult = await repository.loadDraft();
        final loaded = loadResult.getOrNull();

        expect(saveResult.isSuccess, isTrue);
        expect(loadResult.isSuccess, isTrue);
        expect(loaded, isNotNull);
        expect(loaded!.description, draft.description);
        expect(loaded.descriptionDelta, hasLength(descriptionDelta.length));

        for (var index = 0; index < descriptionDelta.length; index++) {
          expect(
            loaded.descriptionDelta![index]['insert'],
            descriptionDelta[index]['insert'],
          );
          expect(
            loaded.descriptionDelta![index]['attributes'],
            descriptionDelta[index]['attributes'],
          );
        }

        expect(
          const DeepCollectionEquality().equals(
            loaded.descriptionDelta,
            descriptionDelta,
          ),
          isTrue,
        );
      },
    );

    test(
      'persists a 5,000-character unbroken rich description without '
      'truncation',
      () async {
        final description = 'a' * 5000;
        final descriptionDelta = <Map<String, dynamic>>[
          {'insert': '$description\n'},
        ];

        final draft = ContentSubmissionDraft(
          description: description,
          descriptionDelta: descriptionDelta,
        );
        final saveResult = await repository.saveDraft(draft);
        final loadResult = await repository.loadDraft();
        final loaded = loadResult.getOrNull();

        expect(saveResult.isSuccess, isTrue);
        expect(loadResult.isSuccess, isTrue);
        expect(loaded, isNotNull);
        expect(loaded!.description, description);
        expect(loaded.description?.length, 5000);
        expect(
          const DeepCollectionEquality().equals(
            loaded.descriptionDelta,
            descriptionDelta,
          ),
          isTrue,
        );
      },
    );

    test('preserves a legacy draft with a null Delta', () async {
      final draft = ContentSubmissionDraft(
        description: 'Legacy Markdown description',
      );

      final saveResult = await repository.saveDraft(draft);
      final loaded = (await repository.loadDraft()).getOrNull();

      expect(saveResult.isSuccess, isTrue);
      expect(loaded?.description, draft.description);
      expect(loaded?.descriptionDelta, isNull);
    });

    test('persists an enabled incomplete event start day', () async {
      final draft = ContentSubmissionDraft(
        eventDates: EventDateDraft.unresolvedStart(
          EventCalendarDate(2026, 7, 25),
        ),
      );

      await repository.saveDraft(draft);
      final loaded = (await repository.loadDraft()).getOrNull();

      expect(loaded?.eventDates, draft.eventDates);
    });

    test(
      'round-trips a complete session and safely projects pre-identity '
      'records',
      () async {
        const identity = '2a1b0c3d-4e5f-4a6b-8c9d-0e1f2a3b4c5d';
        await objectBoxEnvironment.store
            .box<ContentSubmissionDraftEntity>()
            .putAsync(ContentSubmissionDraftEntity(city: 'Legacy Rome'));

        final legacyLoad = await repository.loadDraft();
        expect(legacyLoad.getOrNull(), isNull);
        expect(
          await objectBoxEnvironment.store
              .box<ContentSubmissionDraftEntity>()
              .getAsync(1),
          isNotNull,
        );

        final draft = ContentSubmissionDraft(
          clientSubmissionId: identity,
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
          eventDates: EventDateDraft.exact(
            startCalendarDate: EventCalendarDate(2026, 7, 25),
            startInstantUtc: DateTime.utc(2026, 7, 25, 10),
            endInstantUtc: DateTime.utc(2026, 7, 26, 18),
          ),
          userEmail: 'jane@example.com',
          userName: 'Jane',
          acceptedTerms: true,
        );
        expect((await repository.saveDraft(draft)).isSuccess, isTrue);
        final loaded = (await repository.loadDraft()).getOrNull();
        expect(loaded, draft);
        expect(loaded?.clientSubmissionId, identity);

        final updated = draft.copyWith(description: 'Restored ancient arena');
        expect((await repository.saveDraft(updated)).isSuccess, isTrue);
        final reloaded = (await repository.loadDraft()).getOrNull();
        expect(reloaded, updated);
        expect(reloaded?.clientSubmissionId, identity);

        expect((await repository.clearDraft()).isSuccess, isTrue);
        expect(
          await objectBoxEnvironment.store
              .box<ContentSubmissionDraftEntity>()
              .getAsync(1),
          isNull,
        );
        expect((await repository.loadDraft()).getOrNull(), isNull);
      },
    );
  });
}
