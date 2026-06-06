import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/domain/models/content_category.dart';

void main() {
  group('contentCategoryFromIndex', () {
    test('returns the correct category for each valid index', () {
      const expected = [
        ContentCategory.unknown,
        ContentCategory.nature,
        ContentCategory.history,
        ContentCategory.folklore,
        ContentCategory.food,
        ContentCategory.allure,
        ContentCategory.experience,
      ];

      for (var i = 0; i < expected.length; i++) {
        expect(
          contentCategoryFromIndex(i),
          expected[i],
          reason: 'mismatch for index $i',
        );
      }
    });

    test('throws AssertionError for index -1', () {
      expect(
        () => contentCategoryFromIndex(-1),
        throwsA(isA<AssertionError>()),
      );
    });

    test('throws AssertionError for index equal to values.length', () {
      expect(
        () => contentCategoryFromIndex(ContentCategory.values.length),
        throwsA(isA<AssertionError>()),
      );
    });

    test('throws AssertionError for large out-of-range index', () {
      expect(
        () => contentCategoryFromIndex(999),
        throwsA(isA<AssertionError>()),
      );
    });

    test('throws AssertionError for negative out-of-range index', () {
      expect(
        () => contentCategoryFromIndex(-100),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('assertValidContentCategoryIndex', () {
    test('does not throw for a valid index', () {
      expect(() => assertValidContentCategoryIndex(0), returnsNormally);
    });

    test('throws AssertionError for index -1', () {
      expect(
        () => assertValidContentCategoryIndex(-1),
        throwsA(isA<AssertionError>()),
      );
    });

    test('throws AssertionError for out-of-range index', () {
      expect(
        () => assertValidContentCategoryIndex(ContentCategory.values.length),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('assertStableContentCategoryEnumIndexes', () {
    test('passes when enum indexes are stable', () {
      expect(assertStableContentCategoryEnumIndexes, returnsNormally);
    });
  });
}
