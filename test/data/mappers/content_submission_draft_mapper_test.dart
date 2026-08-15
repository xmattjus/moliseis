import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/data/data-sources/content_submission_draft_entry.dart';
import 'package:moliseis/data/mappers/content_submission_draft_mapper.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/content_submission_draft.dart';

void main() {
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

          final restored = draft.toEntity().toModel();

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
          startDate: startDate,
          endDate: endDate,
        );

        final restored = draft.toEntity().toModel();

        expect(restored.startDate, startDate);
        expect(restored.endDate, endDate);
      },
    );

    test('round-trips an empty draft without data loss', () {
      final draft = ContentSubmissionDraft();

      final restored = draft.toEntity().toModel();

      expect(restored, equals(draft));
      expect(restored.category, isNull);
      expect(restored.city, isNull);
      expect(restored.name, isNull);
      expect(restored.description, isNull);
      expect(restored.descriptionDelta, isNull);
      expect(restored.startDate, isNull);
      expect(restored.endDate, isNull);
      expect(restored.userEmail, isNull);
      expect(restored.userName, isNull);
      expect(restored.acceptedTerms, isNull);
    });

    test('null categoryIndex round-trips to null category and back', () {
      final entity = ContentSubmissionDraftEntity();

      expect(entity.toModel().category, isNull);
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
          categoryIndex: category.index,
        );

        expect(
          entity.toModel().category,
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

      final model = entity.toModel();

      expect(
        identical(model.descriptionDelta, entity.descriptionDelta),
        isFalse,
      );
      expect(
        identical(model.descriptionDelta![0], entity.descriptionDelta![0]),
        isFalse,
      );
    });
  });
}
