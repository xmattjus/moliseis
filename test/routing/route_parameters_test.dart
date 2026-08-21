import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/content_type.dart';
import 'package:moliseis/routing/route_parameters.dart';

void main() {
  group('RouteParameters.categorySlug', () {
    test('encodes every navigable category with its canonical slug', () {
      expect(RouteParameters.categorySlug(ContentCategory.nature), 'nature');
      expect(RouteParameters.categorySlug(ContentCategory.history), 'history');
      expect(
        RouteParameters.categorySlug(ContentCategory.folklore),
        'folklore',
      );
      expect(RouteParameters.categorySlug(ContentCategory.food), 'food');
      expect(RouteParameters.categorySlug(ContentCategory.allure), 'allure');
      expect(
        RouteParameters.categorySlug(ContentCategory.experience),
        'experience',
      );
    });

    test('encodes unknown as the all slug', () {
      expect(
        RouteParameters.categorySlug(ContentCategory.unknown),
        RouteParameters.allCategorySlug,
      );
    });
  });

  group('RouteParameters.categoryFromSlug', () {
    test('decodes every canonical slug', () {
      expect(
        RouteParameters.categoryFromSlug('nature'),
        ContentCategory.nature,
      );
      expect(
        RouteParameters.categoryFromSlug('history'),
        ContentCategory.history,
      );
      expect(
        RouteParameters.categoryFromSlug('folklore'),
        ContentCategory.folklore,
      );
      expect(RouteParameters.categoryFromSlug('food'), ContentCategory.food);
      expect(
        RouteParameters.categoryFromSlug('allure'),
        ContentCategory.allure,
      );
      expect(
        RouteParameters.categoryFromSlug('experience'),
        ContentCategory.experience,
      );
    });

    test('returns null for all, unknown, missing, and invalid slugs', () {
      expect(
        RouteParameters.categoryFromSlug(RouteParameters.allCategorySlug),
        isNull,
      );
      expect(RouteParameters.categoryFromSlug('unknown'), isNull);
      expect(RouteParameters.categoryFromSlug('bogus'), isNull);
      expect(RouteParameters.categoryFromSlug(null), isNull);
      expect(RouteParameters.categoryFromSlug(''), isNull);
    });
  });

  group('RouteParameters.categorySlugFromLegacyIndex', () {
    test('decodes the all-categories index', () {
      expect(
        RouteParameters.categorySlugFromLegacyIndex(-1),
        RouteParameters.allCategorySlug,
      );
    });

    test('decodes every navigable legacy index in declaration order', () {
      expect(RouteParameters.categorySlugFromLegacyIndex(0), 'nature');
      expect(RouteParameters.categorySlugFromLegacyIndex(1), 'history');
      expect(RouteParameters.categorySlugFromLegacyIndex(2), 'folklore');
      expect(RouteParameters.categorySlugFromLegacyIndex(3), 'food');
      expect(RouteParameters.categorySlugFromLegacyIndex(4), 'allure');
      expect(RouteParameters.categorySlugFromLegacyIndex(5), 'experience');
    });

    test('returns null for out-of-range indexes', () {
      expect(RouteParameters.categorySlugFromLegacyIndex(6), isNull);
      expect(RouteParameters.categorySlugFromLegacyIndex(7), isNull);
      expect(RouteParameters.categorySlugFromLegacyIndex(-2), isNull);
      expect(RouteParameters.categorySlugFromLegacyIndex(-100), isNull);
      expect(RouteParameters.categorySlugFromLegacyIndex(100), isNull);
    });
  });

  group('RouteParameters.contentType', () {
    test('decodes event and place', () {
      expect(RouteParameters.contentType('event'), ContentType.event);
      expect(RouteParameters.contentType('place'), ContentType.place);
    });

    test('returns null for missing and invalid values', () {
      expect(RouteParameters.contentType(null), isNull);
      expect(RouteParameters.contentType(''), isNull);
      expect(RouteParameters.contentType('bogus'), isNull);
      expect(RouteParameters.contentType('Event'), isNull);
    });
  });

  group('RouteParameters.contentTypeSlug', () {
    test('encodes event and place', () {
      expect(RouteParameters.contentTypeSlug(ContentType.event), 'event');
      expect(RouteParameters.contentTypeSlug(ContentType.place), 'place');
    });
  });

  group('RouteParameters.isEvent', () {
    test('is true only for events', () {
      expect(RouteParameters.isEvent(ContentType.event), isTrue);
      expect(RouteParameters.isEvent(ContentType.place), isFalse);
    });
  });

  group('RouteParameters.contentId', () {
    test('parses positive ids', () {
      expect(RouteParameters.contentId('1'), 1);
      expect(RouteParameters.contentId('42'), 42);
      expect(
        RouteParameters.contentId('9223372036854775807'),
        9223372036854775807,
      );
    });

    test('returns null for missing, empty, and non-numeric ids', () {
      expect(RouteParameters.contentId(null), isNull);
      expect(RouteParameters.contentId(''), isNull);
      expect(RouteParameters.contentId('abc'), isNull);
      expect(RouteParameters.contentId('1.5'), isNull);
      expect(RouteParameters.contentId('1e3'), isNull);
    });

    test('returns null for zero and negative ids', () {
      expect(RouteParameters.contentId('0'), isNull);
      expect(RouteParameters.contentId('-1'), isNull);
      expect(RouteParameters.contentId('-42'), isNull);
    });

    test('returns null for overflow ids', () {
      expect(RouteParameters.contentId('9223372036854775808'), isNull);
      expect(
        RouteParameters.contentId('9999999999999999999999999999999999'),
        isNull,
      );
    });
  });

  group('RouteParameters.submissionId', () {
    test('parses positive ids', () {
      expect(RouteParameters.submissionId('1'), 1);
      expect(RouteParameters.submissionId('42'), 42);
      expect(
        RouteParameters.submissionId('9223372036854775807'),
        9223372036854775807,
      );
    });

    test('returns null for malformed, non-positive, and overflow ids', () {
      expect(RouteParameters.submissionId(null), isNull);
      expect(RouteParameters.submissionId(''), isNull);
      expect(RouteParameters.submissionId('abc'), isNull);
      expect(RouteParameters.submissionId('0'), isNull);
      expect(RouteParameters.submissionId('-1'), isNull);
      expect(RouteParameters.submissionId('9223372036854775808'), isNull);
    });
  });
}
