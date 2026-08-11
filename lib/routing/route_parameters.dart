import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/content_type.dart';

/// Canonical route parameter values and their non-throwing decoders.
///
/// Route parameters are external input, so every decode in this codec returns
/// a null-safe result instead of throwing. The canonical values follow the
/// plan's Canonical URI Schema:
///
/// - Category: `category/:categorySlug`, where [allCategorySlug] selects every
///   category and `unknown` is not a navigable category.
/// - Content type: `type=event` or `type=place` query parameter.
/// - Search: `q=<query>` query parameter.
/// - Content id: a positive integer path parameter.
///
/// Legacy numeric category indexes, `isEvent` booleans, and search paths are
/// decoded here so route redirects can canonicalize restored locations.
abstract final class RouteParameters {
  /// The canonical slug that selects every category.
  static const allCategorySlug = 'all';

  /// The canonical content type value for events.
  static const eventType = 'event';

  /// The canonical content type value for places.
  static const placeType = 'place';

  /// The navigable category slugs in canonical order.
  ///
  /// Index `i` of this list corresponds to legacy category index `i`, and
  /// legacy index `-1` corresponds to [allCategorySlug].
  static const List<String> categorySlugs = <String>[
    'nature',
    'history',
    'folklore',
    'food',
    'allure',
    'experience',
  ];

  /// Encodes [category] into its canonical URL slug.
  ///
  /// [ContentCategory.unknown] is not navigable, so it is encoded as
  /// [allCategorySlug], matching the legacy behavior where an unknown category
  /// index produced the "all categories" location.
  static String categorySlug(ContentCategory category) => switch (category) {
    ContentCategory.unknown => allCategorySlug,
    ContentCategory.nature => 'nature',
    ContentCategory.history => 'history',
    ContentCategory.folklore => 'folklore',
    ContentCategory.food => 'food',
    ContentCategory.allure => 'allure',
    ContentCategory.experience => 'experience',
  };

  /// Decodes a canonical category [slug] into the category it selects.
  ///
  /// Returns null for [allCategorySlug], `unknown`, and any unrecognized
  /// value. Callers must treat null as an invalid or non-navigable category.
  static ContentCategory? categoryFromSlug(String? slug) => switch (slug) {
    'nature' => ContentCategory.nature,
    'history' => ContentCategory.history,
    'folklore' => ContentCategory.folklore,
    'food' => ContentCategory.food,
    'allure' => ContentCategory.allure,
    'experience' => ContentCategory.experience,
    _ => null,
  };

  /// Decodes a legacy numeric category [index] into a canonical slug.
  ///
  /// Legacy index `-1` (the "all categories" location) decodes to
  /// [allCategorySlug]; indexes `0..5` decode to the navigable categories in
  /// declaration order. Returns null for out-of-range indexes, which must
  /// render the router error UI rather than be silently accepted.
  static String? categorySlugFromLegacyIndex(int index) {
    if (index == -1) {
      return allCategorySlug;
    }
    if (index >= 0 && index < categorySlugs.length) {
      return categorySlugs[index];
    }
    return null;
  }

  /// Decodes the canonical content type [value] into a [ContentType].
  ///
  /// Returns null for a missing or invalid value. Callers must treat null as
  /// an invalid content type and render the router error UI.
  static ContentType? contentType(String? value) => switch (value) {
    'event' => ContentType.event,
    'place' => ContentType.place,
    _ => null,
  };

  /// Encodes [type] into its canonical content type value.
  static String contentTypeSlug(ContentType type) => switch (type) {
    ContentType.event => eventType,
    ContentType.place => placeType,
  };

  /// Returns true when [type] selects an event post.
  static bool isEvent(ContentType type) => type == ContentType.event;

  /// Decodes the content id of a post route from its raw path value.
  ///
  /// Accepts only positive integers. Returns null for missing, non-numeric,
  /// zero, negative, and overflow values, which must render the router error
  /// UI rather than throw.
  static int? contentId(String? raw) {
    final id = int.tryParse(raw ?? '');
    if (id == null || id <= 0) {
      return null;
    }
    return id;
  }
}
