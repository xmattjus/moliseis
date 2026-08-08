import 'package:flutter_test/flutter_test.dart';

import '../../support/fixtures.dart';

void main() {
  group('ContentBase descriptionDelta', () {
    test('is included in Place equality and hashCode', () {
      final city = testCity();
      final first = makePlace(
        city: city,
        descriptionDelta: [
          {
            'insert': 'Castello ',
            'attributes': {'underline': true},
          },
          {'insert': 'Monforte\n'},
        ],
      );
      final second = makePlace(
        city: city,
        descriptionDelta: [
          {
            'attributes': {'underline': true},
            'insert': 'Castello ',
          },
          {'insert': 'Monforte\n'},
        ],
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
    });

    test('keeps Delta operation order meaningful for content', () {
      final original = makePlace(
        descriptionDelta: [
          {'insert': 'Castello '},
          {'insert': 'Monforte\n'},
        ],
      );
      final reordered = makePlace(
        descriptionDelta: [
          {'insert': 'Monforte\n'},
          {'insert': 'Castello '},
        ],
      );

      expect(original, isNot(reordered));
    });

    test('forwards Delta through Event and Place constructors', () {
      const descriptionDelta = <Map<String, dynamic>>[
        {'insert': 'Contenuto\n'},
      ];

      expect(
        makeEvent(descriptionDelta: descriptionDelta).descriptionDelta,
        descriptionDelta,
      );
      expect(
        makePlace(descriptionDelta: descriptionDelta).descriptionDelta,
        descriptionDelta,
      );
    });
  });
}
