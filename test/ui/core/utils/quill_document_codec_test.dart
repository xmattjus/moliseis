import 'package:collection/collection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/ui/core/utils/quill_document_codec.dart';

void main() {
  const deepEquality = DeepCollectionEquality();

  group('QuillDocumentCodec', () {
    group('documentFromDelta', () {
      test('round-trips a plain paragraph', () {
        const source = <Map<String, dynamic>>[
          {'insert': 'Visita guidata\n'},
        ];

        final document = QuillDocumentCodec.documentFromDelta(source);
        final serialized = QuillDocumentCodec.serialize(document!);

        expect(document.toPlainText(), 'Visita guidata\n');
        expect(serialized.description, 'Visita guidata');
        expect(
          deepEquality.equals(serialized.descriptionDelta, source),
          isTrue,
        );
      });

      test('round-trips every supported format', () {
        final source = <Map<String, dynamic>>[
          {
            'insert': 'Grassetto ',
            'attributes': <String, dynamic>{'bold': true},
          },
          {
            'insert': 'corsivo ',
            'attributes': <String, dynamic>{'italic': true},
          },
          {
            'insert': 'sottolineato ',
            'attributes': <String, dynamic>{'underline': true},
          },
          {
            'insert': 'collegamento',
            'attributes': <String, dynamic>{
              'link': 'https://example.com/guida',
            },
          },
          {'insert': '\nPrimo elemento'},
          {
            'insert': '\n',
            'attributes': <String, dynamic>{'list': 'ordered'},
          },
          {'insert': 'Secondo elemento'},
          {
            'insert': '\n',
            'attributes': <String, dynamic>{'list': 'bullet'},
          },
        ];

        final document = QuillDocumentCodec.documentFromDelta(source);
        final serialized = QuillDocumentCodec.serialize(document!);
        final restored = QuillDocumentCodec.documentFromDelta(
          serialized.descriptionDelta,
        );

        expect(restored, isNotNull);
        expect(restored!.toPlainText(), document.toPlainText());
        expect(
          deepEquality.equals(serialized.descriptionDelta, source),
          isTrue,
        );
      });

      test('rejects an empty operation list', () {
        expect(QuillDocumentCodec.documentFromDelta(<Object?>[]), isNull);
      });

      test('rejects noncanonical operations that Quill would normalize', () {
        final noncanonicalValues = <Object?>[
          <Object?>[
            <String, dynamic>{'insert': 'Prima '},
            <String, dynamic>{'insert': 'seconda\n'},
          ],
          <Object?>[
            <String, dynamic>{
              'insert': 'Prima ',
              'attributes': <String, dynamic>{'bold': true},
            },
            <String, dynamic>{
              'insert': 'seconda\n',
              'attributes': <String, dynamic>{'bold': true},
            },
          ],
          <Object?>[
            <String, dynamic>{'insert': ''},
            <String, dynamic>{'insert': '\n'},
          ],
          <Object?>[
            <String, dynamic>{
              'insert': 'Testo\n',
              'attributes': <String, dynamic>{},
            },
          ],
        ];

        for (final value in noncanonicalValues) {
          expect(QuillDocumentCodec.documentFromDelta(value), isNull);
        }
      });

      test('rejects operations without a string insert', () {
        expect(
          QuillDocumentCodec.documentFromDelta(<Object?>[
            <String, dynamic>{},
          ]),
          isNull,
        );
        expect(
          QuillDocumentCodec.documentFromDelta(<Object?>[
            <String, dynamic>{'insert': 1},
          ]),
          isNull,
        );
      });

      test('rejects retain and delete operations', () {
        expect(
          QuillDocumentCodec.documentFromDelta(<Object?>[
            <String, dynamic>{'retain': 1},
          ]),
          isNull,
        );
        expect(
          QuillDocumentCodec.documentFromDelta(<Object?>[
            <String, dynamic>{'delete': 1},
          ]),
          isNull,
        );
      });

      test('rejects embedded values', () {
        expect(
          QuillDocumentCodec.documentFromDelta(<Object?>[
            <String, dynamic>{
              'insert': <String, dynamic>{'image': 'https://example.com/a'},
            },
          ]),
          isNull,
        );
      });

      test('rejects unsupported and invalid attributes', () {
        final invalidOperations = <Object?>[
          <String, dynamic>{
            'insert': 'Testo\n',
            'attributes': <String, dynamic>{'strike': true},
          },
          <String, dynamic>{
            'insert': 'Testo\n',
            'attributes': <String, dynamic>{'bold': false},
          },
          <String, dynamic>{
            'insert': 'Testo\n',
            'attributes': <String, dynamic>{'italic': 'true'},
          },
          <String, dynamic>{
            'insert': 'Testo\n',
            'attributes': <String, dynamic>{'list': 'checked'},
          },
          <String, dynamic>{
            'insert': 'Testo\n',
            'attributes': <String, dynamic>{'list': 'bullet'},
          },
        ];

        for (final operation in invalidOperations) {
          expect(
            QuillDocumentCodec.documentFromDelta(<Object?>[operation]),
            isNull,
          );
        }
      });

      test('rejects null attribute values', () {
        expect(
          QuillDocumentCodec.documentFromDelta(<Object?>[
            <String, dynamic>{
              'insert': 'Testo\n',
              'attributes': <String, dynamic>{'bold': null},
            },
          ]),
          isNull,
        );
      });

      test('rejects documents without a terminal newline', () {
        expect(
          QuillDocumentCodec.documentFromDelta(<Object?>[
            <String, dynamic>{'insert': 'Testo'},
          ]),
          isNull,
        );
      });

      test('returns null without throwing for malformed remote values', () {
        final malformedValues = <Object?>[
          null,
          1,
          'not an operation list',
          <Object?>['not an operation'],
          <Object?>[
            <String, dynamic>{
              'insert': 'Testo\n',
              'unexpected': true,
            },
          ],
          <Object?>[
            <String, dynamic>{
              'insert': 'Testo\n',
              'attributes': 'not a map',
            },
          ],
        ];

        for (final value in malformedValues) {
          expect(
            () => QuillDocumentCodec.documentFromDelta(value),
            returnsNormally,
          );
          expect(QuillDocumentCodec.documentFromDelta(value), isNull);
        }
      });

      test('does not retain references to source operations', () {
        final source = <Map<String, dynamic>>[
          {
            'insert': 'Testo ',
            'attributes': <String, dynamic>{'bold': true},
          },
          {'insert': 'immutabile\n'},
        ];
        final document = QuillDocumentCodec.documentFromDelta(source)!;
        final serialized = QuillDocumentCodec.serialize(document);

        source[0]['insert'] = 'Testo modificato ';
        (source[0]['attributes']! as Map<String, dynamic>)['bold'] = false;

        const expected = <Map<String, dynamic>>[
          {
            'insert': 'Testo ',
            'attributes': {'bold': true},
          },
          {'insert': 'immutabile\n'},
        ];
        expect(document.toPlainText(), 'Testo immutabile\n');
        expect(
          deepEquality.equals(serialized.descriptionDelta, expected),
          isTrue,
        );
        expect(
          deepEquality.equals(
            QuillDocumentCodec.serialize(document).descriptionDelta,
            expected,
          ),
          isTrue,
        );
      });
    });

    group('documentFromPlainText and serialize', () {
      test('preserves spaces and multiple author-entered newlines', () {
        const authorText = '  Visita guidata  \n\n';

        final document = QuillDocumentCodec.documentFromPlainText(authorText);
        final serialized = QuillDocumentCodec.serialize(document);

        expect(document.toPlainText(), '$authorText\n');
        expect(serialized.description, authorText);
        expect(serialized.descriptionDelta, <Map<String, dynamic>>[
          {'insert': '$authorText\n'},
        ]);
      });

      test('normalizes only a terminal-newline-only document as empty', () {
        final document = QuillDocumentCodec.documentFromDelta(<Object?>[
          <String, dynamic>{'insert': '\n'},
        ]);
        final serialized = QuillDocumentCodec.serialize(document!);

        expect(serialized.description, isNull);
        expect(serialized.descriptionDelta, isNull);
      });

      test('preserves an additional authored newline', () {
        final document = QuillDocumentCodec.documentFromDelta(<Object?>[
          <String, dynamic>{'insert': '\n\n'},
        ]);
        final serialized = QuillDocumentCodec.serialize(document!);

        expect(document.isEmpty(), isFalse);
        expect(serialized.description, '\n');
        expect(serialized.descriptionDelta, <Map<String, dynamic>>[
          {'insert': '\n\n'},
        ]);
      });

      test('adds exactly one Quill-owned newline to legacy plain text', () {
        const legacyDescription = 'Descrizione legacy\n';

        final document = QuillDocumentCodec.documentFromPlainText(
          legacyDescription,
        );
        final serialized = QuillDocumentCodec.serialize(document);

        expect(document.toPlainText(), 'Descrizione legacy\n\n');
        expect(serialized.description, legacyDescription);
      });

      test('returns independent immutable serialized Delta copies', () {
        final document = QuillDocumentCodec.documentFromDelta(<Object?>[
          <String, dynamic>{
            'insert': 'Contenuto\n',
            'attributes': <String, dynamic>{'underline': true},
          },
        ])!;
        final first = QuillDocumentCodec.serialize(document);
        final second = QuillDocumentCodec.serialize(document);
        final firstDelta = first.descriptionDelta!;
        final secondDelta = second.descriptionDelta!;
        final separatelyCopiedResult = firstDelta
            .map(Map<String, dynamic>.from)
            .toList();

        separatelyCopiedResult[0]['insert'] = 'Modificato\n';

        expect(identical(firstDelta, secondDelta), isFalse);
        expect(identical(firstDelta.first, secondDelta.first), isFalse);
        expect(
          () => firstDelta.add(<String, dynamic>{'insert': 'Nuovo\n'}),
          throwsUnsupportedError,
        );
        expect(
          () => firstDelta.first['insert'] = 'Modificato\n',
          throwsUnsupportedError,
        );
        expect(
          firstDelta.first['attributes'],
          isA<Map<String, dynamic>>(),
        );
        final firstAttributes =
            firstDelta.first['attributes']! as Map<String, dynamic>;
        expect(
          () => firstAttributes['underline'] = false,
          throwsUnsupportedError,
        );
        expect(document.toPlainText(), 'Contenuto\n');
        expect(first.descriptionDelta, <Map<String, dynamic>>[
          {
            'insert': 'Contenuto\n',
            'attributes': {'underline': true},
          },
        ]);
        expect(second.descriptionDelta, first.descriptionDelta);
      });
    });

    group('isValidLink', () {
      test('accepts absolute HTTP and HTTPS URLs with hosts', () {
        expect(QuillDocumentCodec.isValidLink('http://example.com'), isTrue);
        expect(
          QuillDocumentCodec.isValidLink('https://example.com/guida'),
          isTrue,
        );
      });

      test('uses the same validator for stored link attributes', () {
        final document = QuillDocumentCodec.documentFromDelta(<Object?>[
          <String, dynamic>{
            'insert': 'Guida',
            'attributes': <String, dynamic>{
              'link': 'https://example.com/guida',
            },
          },
          <String, dynamic>{'insert': '\n'},
        ]);

        expect(document, isNotNull);
      });

      test('rejects unsafe, relative, and hostless URLs', () {
        const invalidUrls = <String>[
          'javascript:alert(1)',
          'file:///tmp/file',
          'data:text/plain,content',
          'mailto:author@example.com',
          'moliseis://content/1',
          '/relative/path',
          'https:///without-host',
        ];

        for (final url in invalidUrls) {
          expect(QuillDocumentCodec.isValidLink(url), isFalse);
          expect(
            QuillDocumentCodec.documentFromDelta(<Object?>[
              <String, dynamic>{
                'insert': 'Collegamento',
                'attributes': <String, dynamic>{'link': url},
              },
              <String, dynamic>{'insert': '\n'},
            ]),
            isNull,
          );
        }
      });
    });
  });
}
