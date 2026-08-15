import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/domain/models/content_submission.dart';

void main() {
  ContentSubmission submission({
    List<Map<String, dynamic>>? descriptionDelta,
  }) => ContentSubmission(
    city: 'Campobasso',
    name: 'Visita guidata',
    description: 'Visita guidata',
    descriptionDelta: descriptionDelta,
    userEmail: 'author@example.com',
    userName: 'Author',
  );

  group('ContentSubmission', () {
    test('supports null Delta and distinguishes it from an empty Delta', () {
      final nullDelta = submission();
      final emptyDelta = submission(descriptionDelta: []);

      expect(nullDelta.descriptionDelta, isNull);
      expect(emptyDelta.descriptionDelta, isEmpty);
      expect(nullDelta, isNot(equals(emptyDelta)));
    });

    test('compares structurally equal Delta operations deeply', () {
      final first = submission(
        descriptionDelta: [
          {
            'insert': 'Visita ',
            'attributes': {'bold': true},
          },
          {'insert': 'guidata\n'},
        ],
      );
      final second = submission(
        descriptionDelta: [
          {
            'insert': 'Visita ',
            'attributes': {'bold': true},
          },
          {'insert': 'guidata\n'},
        ],
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
    });

    test('treats operation order and inserted text as meaningful', () {
      final original = submission(
        descriptionDelta: [
          {'insert': 'Visita '},
          {'insert': 'guidata\n'},
        ],
      );
      final reordered = submission(
        descriptionDelta: [
          {'insert': 'guidata\n'},
          {'insert': 'Visita '},
        ],
      );
      final changedText = submission(
        descriptionDelta: [
          {'insert': 'Visita '},
          {'insert': 'libera\n'},
        ],
      );

      expect(original, isNot(reordered));
      expect(original, isNot(changedText));
    });

    test('ignores map member order in Delta operations', () {
      final first = submission(
        descriptionDelta: [
          {
            'insert': 'Visita ',
            'attributes': {'bold': true},
          },
          {'insert': 'guidata\n'},
        ],
      );
      final second = submission(
        descriptionDelta: [
          {
            'attributes': {'bold': true},
            'insert': 'Visita ',
          },
          {'insert': 'guidata\n'},
        ],
      );

      expect(first, second);
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
        final value = submission(descriptionDelta: source);
        final originalHashCode = value.hashCode;

        sourceOperation['insert'] = 'Mutated\n';
        sourceAttributes['bold'] = false;
        sourceTags.add('mutated');
        source.add(<String, dynamic>{'insert': 'Added\n'});

        expect(value.descriptionDelta, [
          {
            'insert': 'Original\n',
            'attributes': {
              'bold': true,
              'tags': ['featured'],
            },
          },
        ]);
        expect(value.hashCode, originalHashCode);
      });

      test('does not expose mutable Delta collections', () {
        final value = submission(
          descriptionDelta: [
            {
              'insert': 'Original\n',
              'attributes': <String, dynamic>{
                'bold': true,
                'tags': <String>['featured'],
              },
            },
          ],
        );
        final delta = switch (value.descriptionDelta) {
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
  });
}
