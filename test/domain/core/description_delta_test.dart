import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/domain/core/description_delta.dart';

void main() {
  group('freezeDescriptionDelta', () {
    test('returns null for null input', () {
      expect(freezeDescriptionDelta(null), isNull);
    });

    test('returns an unmodifiable empty list for empty input', () {
      final frozen = switch (freezeDescriptionDelta(<Map<String, dynamic>>[])) {
        final frozen? => frozen,
        null => throw StateError('Expected a non-null frozen Delta.'),
      };

      expect(frozen, isEmpty);
      expect(
        () => frozen.add(<String, dynamic>{}),
        throwsUnsupportedError,
      );
    });

    test('deeply freezes Delta values and every collection level', () {
      final sourceTags = <String>['featured'];
      final sourceMetadata = <String, dynamic>{'tags': sourceTags};
      final sourceAttributes = <String, dynamic>{
        'bold': true,
        'metadata': sourceMetadata,
      };
      final sourceEmbed = <String, dynamic>{'type': 'image'};
      final sourceNestedList = <String>['nested'];
      final sourceEmbeds = <Object?>[sourceEmbed, sourceNestedList];
      final source = <Map<String, dynamic>>[
        {
          'insert': 'Original\n',
          'retain': 3,
          'nullable': null,
          'attributes': sourceAttributes,
          'embeds': sourceEmbeds,
        },
      ];
      final frozen = switch (freezeDescriptionDelta(source)) {
        final frozen? => frozen,
        null => throw StateError('Expected a non-null frozen Delta.'),
      };

      source.single['insert'] = 'Mutated\n';
      source.single['retain'] = 4;
      sourceAttributes['bold'] = false;
      sourceMetadata['source'] = 'remote';
      sourceTags.add('mutated');
      sourceEmbed['type'] = 'video';
      sourceNestedList.add('mutated');
      source.add(<String, dynamic>{'insert': 'Added\n'});

      expect(frozen, [
        {
          'insert': 'Original\n',
          'retain': 3,
          'nullable': null,
          'attributes': {
            'bold': true,
            'metadata': {
              'tags': ['featured'],
            },
          },
          'embeds': [
            {'type': 'image'},
            ['nested'],
          ],
        },
      ]);

      final [operation] = frozen;
      final (attributes, embeds) = switch (operation) {
        {
          'attributes': Map<String, dynamic> attributes,
          'embeds': List<Object?> embeds,
        } =>
          (attributes, embeds),
        _ => throw StateError('Expected attributes and embeds in the Delta.'),
      };
      final metadata = switch (attributes) {
        {'metadata': final Map<String, dynamic> metadata} => metadata,
        _ => throw StateError('Expected metadata in the Delta attributes.'),
      };
      final tags = switch (metadata) {
        {'tags': final List<Object?> tags} => tags,
        _ => throw StateError('Expected tags in the Delta metadata.'),
      };
      final (embed, nestedList) = switch (embeds) {
        [Map<String, dynamic> embed, List<Object?> nestedList] => (
          embed,
          nestedList,
        ),
        _ => throw StateError('Expected the Delta embeds to have two values.'),
      };

      expect(() => frozen.add(<String, dynamic>{}), throwsUnsupportedError);
      expect(() => operation['insert'] = 'Changed\n', throwsUnsupportedError);
      expect(() => attributes['bold'] = false, throwsUnsupportedError);
      expect(() => metadata['source'] = 'local', throwsUnsupportedError);
      expect(() => tags.add('changed'), throwsUnsupportedError);
      expect(() => embeds.add('changed'), throwsUnsupportedError);
      expect(() => embed['type'] = 'video', throwsUnsupportedError);
      expect(() => nestedList.add('changed'), throwsUnsupportedError);
    });
  });
}
