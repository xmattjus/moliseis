part of 'package:moliseis/utils/logging/log_event.dart';

/// Fired when an entry has been added to a cache.
class CacheEntryAdded extends LogEvent {
  /// Creates an event when an entry with [key] has been added to [cache].
  /// Also registers when the entry has been added to the cache with [addedAt].
  const CacheEntryAdded({
    required this.cache,
    required this.key,
    required this.addedAt,
  });

  final String cache;
  final String key;
  final DateTime addedAt;

  @override
  Map<String, Object?> get data => {
    'cache': cache,
    'key': key,
    'addedAt': addedAt.toUtc(),
  };

  @override
  AppLogLevel get level => AppLogLevel.debug;

  @override
  String get name => 'cache_entry_added';
}

/// Fired when an entry has been retrieved from a cache.
class CacheEntryFetched extends LogEvent {
  /// Creates an event when an entry with [key] has been retrieved from [cache].
  const CacheEntryFetched({required this.cache, required this.key});

  final String cache;
  final String key;

  @override
  Map<String, Object?> get data => {'cache': cache, 'key': key};

  @override
  AppLogLevel get level => AppLogLevel.debug;

  @override
  String get name => 'cache_entry_fetched';
}

/// Fired when an entry has been evicted from a cache.
class CacheEntryEvicted extends LogEvent {
  /// Creates an event when an entry with [key] has been evicted from [cache].
  /// Also registers when the entry has been added to the cache
  /// with [fetchedAt].
  const CacheEntryEvicted({
    required this.cache,
    required this.key,
    required this.fetchedAt,
  });

  final String cache;
  final String key;
  final DateTime fetchedAt;

  @override
  Map<String, Object?> get data => {
    'cache': cache,
    'key': key,
    'fetchedAt': fetchedAt.toUtc(),
  };

  @override
  AppLogLevel get level => AppLogLevel.debug;

  @override
  String get name => 'cache_entry_evicted';
}

/// Fired when a Cloudinary upload request fails.
class CloudinaryRequestFailed extends LogEvent {
  /// Creates an event with a [detail] describing the Cloudinary error.
  const CloudinaryRequestFailed({required this.detail});

  /// Error message or description returned by the Cloudinary API.
  final String detail;

  @override
  Map<String, Object?> get data => {'detail': detail};

  @override
  AppLogLevel get level => AppLogLevel.error;

  @override
  String get name => 'cloudinary_request_failed';
}

/// Fired when a Cloudinary upload request started.
class CloudinaryRequestStarted extends LogEvent {
  /// Creates an event for a Cloudinary request start.
  const CloudinaryRequestStarted();

  @override
  Map<String, Object?> get data => const {};

  @override
  AppLogLevel get level => AppLogLevel.info;

  @override
  String get name => 'cloudinary_request_started';
}

/// Fired when a Cloudinary upload completes successfully.
class CloudinaryUploadCompleted extends LogEvent {
  /// Creates an event for a completed Cloudinary upload of [publicId].
  const CloudinaryUploadCompleted({required this.publicId});

  /// Public ID of the uploaded asset.
  final String publicId;

  @override
  Map<String, Object?> get data => {'publicId': publicId};

  @override
  AppLogLevel get level => AppLogLevel.info;

  @override
  String get name => 'cloudinary_upload_completed';
}

/// Fired when a Cloudinary upload is cancelled by the caller.
class CloudinaryUploadCancelled extends LogEvent {
  /// Creates an event for a cancelled Cloudinary upload.
  const CloudinaryUploadCancelled();

  @override
  Map<String, Object?> get data => const {};

  @override
  AppLogLevel get level => AppLogLevel.info;

  @override
  String get name => 'cloudinary_upload_cancelled';
}

/// Fired when a duplicate Cloudinary upload is detected and skipped.
class CloudinaryDuplicateDetected extends LogEvent {
  /// Creates an event for a duplicate Cloudinary upload of [publicId].
  const CloudinaryDuplicateDetected({required this.publicId});

  /// Public ID of the existing asset.
  final String publicId;

  @override
  Map<String, Object?> get data => {'publicId': publicId};

  @override
  AppLogLevel get level => AppLogLevel.info;

  @override
  String get name => 'cloudinary_duplicate_detected';
}

/// Fired when an image sharing attempt fails.
class ImageSharingFailed extends LogEvent {
  /// Creates an event for a failed image sharing attempt.
  const ImageSharingFailed();

  @override
  Map<String, Object?> get data => const {};

  @override
  AppLogLevel get level => AppLogLevel.warning;

  @override
  String get name => 'image_sharing_failed';
}

/// Fired when a reverse geocoding fetch failed.
class ReverseGeocodingFetchFailed extends LogEvent {
  /// Creates an event for a failed reverse-geocode lookup
  /// at [latitude], [longitude].
  const ReverseGeocodingFetchFailed({
    required this.latitude,
    required this.longitude,
  });

  /// Latitude coordinate of the failed geocoding request.
  final double latitude;

  /// Longitude coordinate of the failed geocoding request.
  final double longitude;

  @override
  Map<String, Object?> get data => {
    'latitude': latitude,
    'longitude': longitude,
  };

  @override
  AppLogLevel get level => AppLogLevel.error;

  @override
  String get name => 'reverse_geocoding_fetch_failed';
}

/// Fired when a reverse geocoding fetch started.
class ReverseGeocodingFetchStarted extends LogEvent {
  /// Creates an event for a reverse-geocode lookup started
  /// at [latitude], [longitude].
  const ReverseGeocodingFetchStarted({
    required this.latitude,
    required this.longitude,
  });

  /// Latitude coordinate being reverse-geocoded.
  final double latitude;

  /// Longitude coordinate being reverse-geocoded.
  final double longitude;

  @override
  Map<String, Object?> get data => {
    'latitude': latitude,
    'longitude': longitude,
  };

  @override
  AppLogLevel get level => AppLogLevel.info;

  @override
  String get name => 'reverse_geocoding_fetch_started';
}

/// Fired when Sentry logging is confirmed as disabled.
class SentryLoggingDisabled extends LogEvent {
  const SentryLoggingDisabled();

  @override
  Map<String, Object?> get data => const {};

  @override
  AppLogLevel get level => AppLogLevel.debug;

  @override
  String get name => 'sentry_crash_reporting_disabled';
}

/// Fired when Sentry logging is confirmed as enabled.
class SentryLoggingEnabled extends LogEvent {
  const SentryLoggingEnabled({this.environment});

  final String? environment;

  @override
  Map<String, Object?> get data => {'environment': environment};

  @override
  AppLogLevel get level => AppLogLevel.debug;

  @override
  String get name => 'sentry_crash_reporting_enabled';
}

/// Fired when Supabase Auth anonymous login fails.
class SupabaseAuthAnonymousLoginFailed extends LogEvent {
  /// Creates an event when a Supabase Auth anonymous login is failed.
  const SupabaseAuthAnonymousLoginFailed();

  @override
  Map<String, Object?> get data => const {};

  @override
  AppLogLevel get level => AppLogLevel.error;

  @override
  String get name => 'supabase_auth_anonymous_login_failed';
}

/// Fired when opening a URL via the system launcher fails.
class UrlLaunchFailed extends LogEvent {
  /// Creates an event for a failed launch of [url].
  const UrlLaunchFailed(this.url);

  /// The URL that could not be opened.
  final String url;

  @override
  Map<String, Object?> get data => {'url': url};

  @override
  AppLogLevel get level => AppLogLevel.warning;

  @override
  String get name => 'url_launch_failed';
}

/// Fired when a weather forecast fetch failed.
class WeatherForecastFetchFailed extends LogEvent {
  /// Creates an event for a failed weather forecast request
  /// at [latitude], [longitude].
  const WeatherForecastFetchFailed({
    required this.latitude,
    required this.longitude,
  });

  /// Latitude coordinate of the failed forecast request.
  final double latitude;

  /// Longitude coordinate of the failed forecast request.
  final double longitude;

  @override
  Map<String, Object?> get data => {
    'latitude': latitude,
    'longitude': longitude,
  };

  @override
  AppLogLevel get level => AppLogLevel.error;

  @override
  String get name => 'weather_forecast_fetch_failed';
}

/// Fired when the user id fetch failed.
class UserIdFetchFailed extends LogEvent {
  const UserIdFetchFailed();

  @override
  Map<String, Object?> get data => {};

  @override
  AppLogLevel get level => AppLogLevel.error;

  @override
  String get name => 'user_id_fetch_failed';
}
