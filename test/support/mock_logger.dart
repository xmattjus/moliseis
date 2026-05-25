import 'package:mocktail/mocktail.dart';
import 'package:moliseis/utils/logging/logging.dart';

class MockLogger extends Mock implements Logger {}

/// Registers fallback values for [MockLogger] verification with mocktail.
/// Call once per test suite in `setUpAll`.
void setUpMockLogger() {
  registerFallbackValue(
    CacheEntryAdded(
      cache: 'weather',
      key: '0, 0',
      addedAt: DateTime.now(),
    ),
  );
  registerFallbackValue(
    const CacheEntryFetched(
      cache: 'weather',
      key: '0, 0',
    ),
  );
  registerFallbackValue(
    CacheEntryEvicted(
      cache: 'weather',
      key: '0, 0',
      fetchedAt: DateTime.now(),
    ),
  );
  registerFallbackValue(const CloudinaryRequestFailed(detail: ''));
  registerFallbackValue(const CloudinaryRequestStarted());
  registerFallbackValue(const EntityInsertFailed(''));
  registerFallbackValue(const EntityInsertSuccess(''));
  registerFallbackValue(const EntityLoadFailed('', method: ''));
  registerFallbackValue(const EntityLoadStarted('', method: ''));
  registerFallbackValue(const EntityRemoveFailed(''));
  registerFallbackValue(const EntityUpdateFailed('', 0));
  registerFallbackValue(const EntityUpdateSuccess(''));
  registerFallbackValue(const ImageLoadFailed());
  registerFallbackValue(const ImageSharingFailed());
  registerFallbackValue(const LocalPersistenceInitFailed());
  registerFallbackValue(const LocalPersistenceSettingsInitFailed());
  registerFallbackValue(const NetworkRequestTimeout());
  registerFallbackValue(const PostRouteContentIdParseFailed(reason: ''));
  registerFallbackValue(const RepositorySyncFailed(''));
  registerFallbackValue(const RepositorySyncStarted(''));
  registerFallbackValue(
    const ReverseGeocodingFetchFailed(
      latitude: 0,
      longitude: 0,
    ),
  );
  registerFallbackValue(
    const ReverseGeocodingFetchStarted(
      latitude: 0,
      longitude: 0,
    ),
  );
  registerFallbackValue(const SentryLoggingDisabled());
  registerFallbackValue(const SentryLoggingEnabled());
  registerFallbackValue(const SnackBarShowFailed());
  registerFallbackValue(const UrlLaunchFailed(''));
  registerFallbackValue(const UrlLaunchStarted(''));
  registerFallbackValue(const UserContributionMediaAddFailed());
  registerFallbackValue(const UserContributionMediaRemovalFailed());
  registerFallbackValue(const UserContributionMediaRetrievalFailed());
  registerFallbackValue(const UserContributionMediaRetrievalStarted());
  registerFallbackValue(const UserContributionUploadFailed());
  registerFallbackValue(const UserContributionUploadStarted());
  registerFallbackValue(
    const WeatherForecastFetchFailed(
      latitude: 0,
      longitude: 0,
    ),
  );
  registerFallbackValue(
    const WeatherForecastFetchStarted(
      latitude: 0,
      longitude: 0,
    ),
  );
}
