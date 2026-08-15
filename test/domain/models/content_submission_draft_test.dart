import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/content_submission_draft.dart';

void main() {
  ContentSubmissionDraft populatedState() => ContentSubmissionDraft(
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

  group('ContentSubmissionDraft', () {
    group('equality', () {
      test('same values are equal', () {
        final a = ContentSubmissionDraft(
          category: ContentCategory.nature,
          city: 'Milan',
        );
        final b = ContentSubmissionDraft(
          category: ContentCategory.nature,
          city: 'Milan',
        );
        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('default (all null) states are equal', () {
        final a = ContentSubmissionDraft();
        final b = ContentSubmissionDraft();
        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('keeps null Delta distinct from an empty Delta', () {
        final nullDelta = ContentSubmissionDraft();
        final emptyDelta = ContentSubmissionDraft(descriptionDelta: const []);

        expect(nullDelta.descriptionDelta, isNull);
        expect(emptyDelta.descriptionDelta, isEmpty);
        expect(nullDelta, isNot(equals(emptyDelta)));
      });

      test('differing field makes state unequal', () {
        final a = ContentSubmissionDraft(category: ContentCategory.nature);
        final b = ContentSubmissionDraft(category: ContentCategory.food);
        expect(a, isNot(equals(b)));
      });

      test('null vs non-null field makes state unequal', () {
        final a = ContentSubmissionDraft(city: 'Rome');
        final b = ContentSubmissionDraft();
        expect(a, isNot(equals(b)));
      });

      test('each field independently affects equality', () {
        final base = ContentSubmissionDraft();

        final fieldVariants = <(String, ContentSubmissionDraft)>[
          (
            'category',
            ContentSubmissionDraft(category: ContentCategory.nature),
          ),
          ('city', ContentSubmissionDraft(city: 'Rome')),
          ('name', ContentSubmissionDraft(name: 'Name')),
          ('description', ContentSubmissionDraft(description: 'Desc')),
          (
            'descriptionDelta',
            ContentSubmissionDraft(
              descriptionDelta: const [
                {'insert': 'Desc\n'},
              ],
            ),
          ),
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
            ContentSubmissionDraft(userEmail: 'a@b.com'),
          ),
          ('userName', ContentSubmissionDraft(userName: 'User')),
          (
            'acceptedTerms',
            ContentSubmissionDraft(acceptedTerms: true),
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

      test('uses deep, order-sensitive equality for descriptionDelta', () {
        final original = ContentSubmissionDraft(
          descriptionDelta: const [
            {
              'insert': 'Visita ',
              'attributes': {'bold': true},
            },
            {'insert': 'guidata\n'},
          ],
        );
        final equivalentWithReorderedMapKeys = ContentSubmissionDraft(
          descriptionDelta: const [
            {
              'attributes': {'bold': true},
              'insert': 'Visita ',
            },
            {'insert': 'guidata\n'},
          ],
        );
        final reorderedOperations = ContentSubmissionDraft(
          descriptionDelta: const [
            {'insert': 'guidata\n'},
            {
              'insert': 'Visita ',
              'attributes': {'bold': true},
            },
          ],
        );
        final changedText = ContentSubmissionDraft(
          descriptionDelta: const [
            {
              'insert': 'Visita ',
              'attributes': {'bold': true},
            },
            {'insert': 'evento\n'},
          ],
        );

        expect(original, equivalentWithReorderedMapKeys);
        expect(original.hashCode, equivalentWithReorderedMapKeys.hashCode);
        expect(original, isNot(reorderedOperations));
        expect(original, isNot(changedText));
      });
    });

    group('descriptionDelta ownership', () {
      test('retains a frozen snapshot and hash code after source mutation', () {
        final sourceTags = <String>['featured'];
        final sourceAttributes = <String, dynamic>{
          'bold': true,
          'tags': sourceTags,
        };
        final sourceOperation = <String, dynamic>{
          'insert': 'Original\n',
          'attributes': sourceAttributes,
        };
        final source = <Map<String, dynamic>>[sourceOperation];
        final draft = ContentSubmissionDraft(descriptionDelta: source);
        final originalHashCode = draft.hashCode;

        sourceOperation['insert'] = 'Mutated\n';
        sourceAttributes['bold'] = false;
        sourceTags.add('mutated');
        source.add(<String, dynamic>{'insert': 'Added\n'});

        expect(draft.descriptionDelta, [
          {
            'insert': 'Original\n',
            'attributes': {
              'bold': true,
              'tags': ['featured'],
            },
          },
        ]);
        expect(draft.hashCode, originalHashCode);
      });

      test('does not expose mutable Delta collections', () {
        final source = <Map<String, dynamic>>[
          {
            'insert': 'Original\n',
            'attributes': <String, dynamic>{
              'bold': true,
              'tags': <String>['featured'],
            },
          },
        ];
        final draft = ContentSubmissionDraft(
          descriptionDelta: source,
        );
        final delta = switch (draft.descriptionDelta) {
          final delta? => delta,
          null => throw StateError('Expected a non-null Delta.'),
        };
        final operation = delta.single;
        final attributes = operation['attributes']! as Map<String, dynamic>;
        final tags = attributes['tags']! as List<Object?>;

        expect(
          () => delta.add(<String, dynamic>{}),
          throwsUnsupportedError,
        );
        expect(
          () => operation['insert'] = 'Changed\n',
          throwsUnsupportedError,
        );
        expect(
          () => attributes['bold'] = false,
          throwsUnsupportedError,
        );
        expect(() => tags.add('changed'), throwsUnsupportedError);
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
        expect(result.descriptionDelta, populatedState().descriptionDelta);
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
        expect(result.descriptionDelta, populatedState().descriptionDelta);
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

      test('preserves, replaces, and clears descriptionDelta', () {
        final state = populatedState();
        final replacementTags = <String>['featured'];
        final replacementAttributes = <String, dynamic>{
          'bold': true,
          'tags': replacementTags,
        };
        final replacement = <Map<String, dynamic>>[
          {
            'insert': 'Nuova descrizione\n',
            'attributes': replacementAttributes,
          },
        ];
        final preserved = state.copyWith();
        final copied = state.copyWith(descriptionDelta: replacement);

        replacement.single['insert'] = 'Mutata\n';
        replacementAttributes['bold'] = false;
        replacementTags.add('mutated');
        replacement.add(<String, dynamic>{'insert': 'Added\n'});

        expect(preserved.descriptionDelta, state.descriptionDelta);
        expect(copied.descriptionDelta, [
          {
            'insert': 'Nuova descrizione\n',
            'attributes': {
              'bold': true,
              'tags': ['featured'],
            },
          },
        ]);

        final copiedDelta = switch (copied.descriptionDelta) {
          final delta? => delta,
          null => throw StateError('Expected a non-null Delta.'),
        };
        final copiedOperation = copiedDelta.single;
        final copiedAttributes =
            copiedOperation['attributes']! as Map<String, dynamic>;
        final copiedTags = copiedAttributes['tags']! as List<Object?>;

        expect(
          () => copiedDelta.add(<String, dynamic>{}),
          throwsUnsupportedError,
        );
        expect(
          () => copiedOperation['insert'] = 'Changed\n',
          throwsUnsupportedError,
        );
        expect(
          () => copiedAttributes['bold'] = false,
          throwsUnsupportedError,
        );
        expect(() => copiedTags.add('changed'), throwsUnsupportedError);
        expect(state.copyWith(descriptionDelta: null).descriptionDelta, isNull);
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
        final state = ContentSubmissionDraft(
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
        final state = ContentSubmissionDraft();
        final result = state.copyWith(category: ContentCategory.experience);

        expect(result.category, ContentCategory.experience);
        expect(result.city, isNull);
      });
    });

    test('does not include raw Delta content in toString', () {
      final draft = ContentSubmissionDraft(
        descriptionDelta: const [
          {'insert': 'private authored text\n'},
        ],
      );

      expect(
        draft.toString(),
        contains('descriptionDelta (operation count): 1'),
      );
      expect(draft.toString(), isNot(contains('private authored text')));
    });
  });
}
