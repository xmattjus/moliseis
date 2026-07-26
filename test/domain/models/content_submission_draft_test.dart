import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/content_submission_draft.dart';

void main() {
  ContentSubmissionDraft populatedState() => const ContentSubmissionDraft(
    category: ContentCategory.history,
    city: 'Rome',
    name: 'Colosseum',
    description: 'Ancient arena',
    userEmail: 'jane@example.com',
    userName: 'Jane',
    acceptedTerms: true,
  );

  group('ContentSubmissionDraft', () {
    group('equality', () {
      test('same values are equal', () {
        const a = ContentSubmissionDraft(
          category: ContentCategory.nature,
          city: 'Milan',
        );
        const b = ContentSubmissionDraft(
          category: ContentCategory.nature,
          city: 'Milan',
        );
        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('default (all null) states are equal', () {
        const a = ContentSubmissionDraft();
        const b = ContentSubmissionDraft();
        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('differing field makes state unequal', () {
        const a = ContentSubmissionDraft(category: ContentCategory.nature);
        const b = ContentSubmissionDraft(category: ContentCategory.food);
        expect(a, isNot(equals(b)));
      });

      test('null vs non-null field makes state unequal', () {
        const a = ContentSubmissionDraft(city: 'Rome');
        const b = ContentSubmissionDraft();
        expect(a, isNot(equals(b)));
      });

      test('each field independently affects equality', () {
        const base = ContentSubmissionDraft();

        final fieldVariants = <(String, ContentSubmissionDraft)>[
          (
            'category',
            const ContentSubmissionDraft(category: ContentCategory.nature),
          ),
          ('city', const ContentSubmissionDraft(city: 'Rome')),
          ('name', const ContentSubmissionDraft(name: 'Name')),
          ('description', const ContentSubmissionDraft(description: 'Desc')),
          (
            'startDate',
            ContentSubmissionDraft(startDate: DateTime.utc(2026)),
          ),
          (
            'endDate',
            ContentSubmissionDraft(endDate: DateTime.utc(2026)),
          ),
          (
            'userEmail',
            const ContentSubmissionDraft(userEmail: 'a@b.com'),
          ),
          ('userName', const ContentSubmissionDraft(userName: 'User')),
          (
            'acceptedTerms',
            const ContentSubmissionDraft(acceptedTerms: true),
          ),
        ];

        for (final (name, state) in fieldVariants) {
          expect(
            base,
            isNot(equals(state)),
            reason: '$name should affect equality',
          );
        }
      });
    });

    group('copyWith', () {
      test('preserves all values when no arguments are passed', () {
        final state = populatedState();
        final result = state.copyWith();

        expect(result.category, ContentCategory.history);
        expect(result.city, 'Rome');
        expect(result.name, 'Colosseum');
        expect(result.description, 'Ancient arena');
        expect(result.userEmail, 'jane@example.com');
        expect(result.userName, 'Jane');
        expect(result.acceptedTerms, isTrue);
        expect(result.startDate, isNull);
        expect(result.endDate, isNull);
      });

      test('overwrites a single field with non-null value', () {
        final state = populatedState();
        final result = state.copyWith(category: ContentCategory.food);

        expect(result.category, ContentCategory.food);
        expect(result.city, 'Rome');
        expect(result.name, 'Colosseum');
        expect(result.description, 'Ancient arena');
        expect(result.userEmail, 'jane@example.com');
        expect(result.userName, 'Jane');
        expect(result.acceptedTerms, isTrue);
      });

      test('clears category to null when null is explicitly passed', () {
        final state = populatedState();
        final result = state.copyWith(category: null);

        expect(result.category, isNull);
        expect(result.city, 'Rome');
        expect(result.name, 'Colosseum');
        expect(result.description, 'Ancient arena');
        expect(result.userEmail, 'jane@example.com');
        expect(result.userName, 'Jane');
        expect(result.acceptedTerms, isTrue);
      });

      test('clears city to null when null is explicitly passed', () {
        final state = populatedState();
        final result = state.copyWith(city: null);

        expect(result.category, ContentCategory.history);
        expect(result.city, isNull);
        expect(result.name, 'Colosseum');
      });

      test('clears name to null when null is explicitly passed', () {
        final state = populatedState();
        final result = state.copyWith(name: null);

        expect(result.category, ContentCategory.history);
        expect(result.city, 'Rome');
        expect(result.name, isNull);
      });

      test('clears description to null when null is explicitly passed', () {
        final state = populatedState();
        final result = state.copyWith(description: null);

        expect(result.category, ContentCategory.history);
        expect(result.city, 'Rome');
        expect(result.name, 'Colosseum');
        expect(result.description, isNull);
      });

      test('clears userEmail to null when null is explicitly passed', () {
        final state = populatedState();
        final result = state.copyWith(userEmail: null);

        expect(result.userEmail, isNull);
        expect(result.userName, 'Jane');
        expect(result.category, ContentCategory.history);
      });

      test('clears userName to null when null is explicitly passed', () {
        final state = populatedState();
        final result = state.copyWith(userName: null);

        expect(result.userName, isNull);
        expect(result.userEmail, 'jane@example.com');
        expect(result.category, ContentCategory.history);
      });

      test('clears acceptedTerms to null when null is explicitly passed', () {
        final state = populatedState();
        final result = state.copyWith(acceptedTerms: null);

        expect(result.acceptedTerms, isNull);
        expect(result.category, ContentCategory.history);
      });

      test('clears startDate to null when null is explicitly passed', () {
        final state = populatedState().copyWith(
          startDate: DateTime.utc(2026),
        );
        expect(state.startDate, isNotNull);

        final result = state.copyWith(startDate: null);
        expect(result.startDate, isNull);
      });

      test('clears endDate to null when null is explicitly passed', () {
        final state = populatedState().copyWith(
          endDate: DateTime.utc(2026),
        );
        expect(state.endDate, isNotNull);

        final result = state.copyWith(endDate: null);
        expect(result.endDate, isNull);
      });

      test('userName fallback uses userName not userEmail', () {
        const state = ContentSubmissionDraft(
          userName: 'Alice',
          userEmail: 'alice@example.com',
        );

        final result = state.copyWith();

        expect(result.userName, 'Alice');
        expect(result.userEmail, 'alice@example.com');
      });

      test('clears multiple fields in a single call', () {
        final state = populatedState();
        final result = state.copyWith(
          category: null,
          city: null,
          name: null,
        );

        expect(result.category, isNull);
        expect(result.city, isNull);
        expect(result.name, isNull);
        expect(result.description, 'Ancient arena');
        expect(result.userEmail, 'jane@example.com');
        expect(result.userName, 'Jane');
        expect(result.acceptedTerms, isTrue);
      });

      test('can set a field from null to non-null', () {
        const state = ContentSubmissionDraft();
        final result = state.copyWith(category: ContentCategory.experience);

        expect(result.category, ContentCategory.experience);
        expect(result.city, isNull);
      });
    });
  });
}
