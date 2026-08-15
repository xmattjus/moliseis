import 'package:collection/collection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/data/repositories/content_submission_draft_repository_impl.dart';
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
  });
}
