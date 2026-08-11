abstract class RoutePaths {
  static const category = 'category/:categorySlug';
  static const events = '/events';
  static const favourites = '/favourites';
  static const gallery = '/gallery';
  static const geoMap = '/map';
  static const home = '/home';
  static const homeSearchResults = 'search_results';

  /// Legacy search path used by restored locations, canonicalized through
  /// `redirectLegacySearchResults`.
  static const homeSearchResultsLegacy = 'search_results/:query';

  /// Legacy search post path used by restored locations, canonicalized
  /// through `redirectLegacySearchResults`.
  static const homeSearchResultsLegacyPost = 'search_results/:query/posts/:id';

  static const settings = '/settings';
  static const sync = '/sync';
  static const post = 'posts/:id';
  static const contentSubmission = '/contentSubmission';
  static const contentSubmissionUploadProgress = 'uploadProgress';
  static const logging = '/logging';

  /// Builds the sync location that preserves the requested internal [from]
  /// URI, so the sync redirect can return to it once synchronization ends.
  ///
  /// [from] is percent-encoded to keep the requested location a single query
  /// parameter value.
  static String syncFor(Uri from) =>
      '$sync?from=${Uri.encodeComponent(from.toString())}';
}
