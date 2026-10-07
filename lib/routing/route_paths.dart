abstract class RoutePaths {
  static const admin = '/admin';

  // Relative path segments reused to form admin locations. Editor routes are
  // children of /admin; login is a separate root route.
  static const adminLogin = 'login';
  static const adminSubmissionsNew = 'submissions/new';
  static const adminSubmission = 'submissions/:id';

  /// Full location of the staff login page.
  ///
  /// Login is a root route. [adminLogin] is its relative path segment, so
  /// redirects and imperative navigation use this full location.
  static const adminLoginLocation = '$admin/$adminLogin';

  static const category = 'category/:categorySlug';
  static const events = '/events';
  static const favourites = '/favourites';
  static const gallery = '/gallery';
  static const geoMap = '/map';
  static const home = '/home';
  static const homeSearchResults = 'search_results';

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
