import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/utils/logging/app_log_level.dart';
import 'package:moliseis/utils/logging/log_event.dart';

void main() {
  group('LogEvent subclasses', () {
    group('Core events', () {
      test('ImageLoadFailed has correct contract', () {
        const event = ImageLoadFailed();

        expect(event.name, 'image_load_failed');
        expect(event.level, AppLogLevel.error);
        expect(event.data, isEmpty);
        expect(eventNamePattern.hasMatch(event.name), isTrue);
      });

      test('PostRouteContentIdParseFailed has correct contract', () {
        const event = PostRouteContentIdParseFailed(reason: 'invalid id');

        expect(event.name, 'post_route_content_id_parse_failed');
        expect(event.level, AppLogLevel.error);
        expect(event.data, {'reason': 'invalid id'});
        expect(eventNamePattern.hasMatch(event.name), isTrue);
      });

      test('SnackBarShowFailed has correct contract with reason', () {
        const event = SnackBarShowFailed(reason: 'no context');

        expect(event.name, 'snack_bar_show_failed');
        expect(event.level, AppLogLevel.warning);
        expect(event.data, {'reason': 'no context'});
        expect(eventNamePattern.hasMatch(event.name), isTrue);
      });

      test('SnackBarShowFailed has correct contract without reason', () {
        const event = SnackBarShowFailed();

        expect(event.data, isEmpty);
      });
    });

    group('Network events', () {
      test('NetworkRequestTimeout has correct contract', () {
        const event = NetworkRequestTimeout();

        expect(event.name, 'network_request_timeout');
        expect(event.level, AppLogLevel.warning);
        expect(event.data, isEmpty);
        expect(eventNamePattern.hasMatch(event.name), isTrue);
      });
    });

    group('Local persistence events', () {
      test('LocalPersistenceInitFailed has correct contract', () {
        const event = LocalPersistenceInitFailed();

        expect(event.name, 'local_persistence_init_failed');
        expect(event.level, AppLogLevel.critical);
        expect(event.data, isEmpty);
        expect(eventNamePattern.hasMatch(event.name), isTrue);
      });

      test('LocalPersistenceSettingsInitFailed has correct contract', () {
        const event = LocalPersistenceSettingsInitFailed();

        expect(event.name, 'local_persistence_settings_init_failed');
        expect(event.level, AppLogLevel.error);
        expect(event.data, isEmpty);
        expect(eventNamePattern.hasMatch(event.name), isTrue);
      });
    });

    group('Repository events', () {
      test('RepositorySyncStarted has correct contract', () {
        const event = RepositorySyncStarted('CityRepository');

        expect(event.name, 'repository_sync_started');
        expect(event.level, AppLogLevel.info);
        expect(event.data, {'repositoryName': 'CityRepository'});
        expect(eventNamePattern.hasMatch(event.name), isTrue);
      });

      test('RepositorySyncFailed has correct contract', () {
        const event = RepositorySyncFailed('PlaceRepository');

        expect(event.name, 'repository_sync_failed');
        expect(event.level, AppLogLevel.error);
        expect(event.data, {'repositoryName': 'PlaceRepository'});
        expect(eventNamePattern.hasMatch(event.name), isTrue);
      });

      test('EntityInsertFailed has correct contract with remoteId', () {
        const event = EntityInsertFailed('City', 42);

        expect(event.name, 'entity_insert_failed');
        expect(event.level, AppLogLevel.error);
        expect(event.data, {'entityType': 'City', 'remoteId': 42});
        expect(eventNamePattern.hasMatch(event.name), isTrue);
      });

      test('EntityInsertFailed has correct contract without remoteId', () {
        const event = EntityInsertFailed('City');

        expect(event.data, {'entityType': 'City', 'remoteId': null});
      });

      test('EntityInsertSuccess has correct contract', () {
        const event = EntityInsertSuccess('Place', 7);

        expect(event.name, 'entity_insert_success');
        expect(event.level, AppLogLevel.info);
        expect(event.data, {'entityType': 'Place', 'remoteId': 7});
        expect(eventNamePattern.hasMatch(event.name), isTrue);
      });

      test('EntityRemoveFailed has correct contract', () {
        const event = EntityRemoveFailed('Event', 99);

        expect(event.name, 'entity_remove_failed');
        expect(event.level, AppLogLevel.error);
        expect(event.data, {'entityType': 'Event', 'remoteId': 99});
        expect(eventNamePattern.hasMatch(event.name), isTrue);
      });

      test('EntityUpdateSuccess has correct contract', () {
        const event = EntityUpdateSuccess('Media', 5);

        expect(event.name, 'entity_update_success');
        expect(event.level, AppLogLevel.info);
        expect(event.data, {'entityType': 'Media', 'remoteId': 5});
        expect(eventNamePattern.hasMatch(event.name), isTrue);
      });

      test('EntityUpdateFailed has correct contract', () {
        const event = EntityUpdateFailed('Place', 10, method: 'updateTitle');

        expect(event.name, 'entity_update_failed');
        expect(event.level, AppLogLevel.error);
        expect(event.data, {
          'entityType': 'Place',
          'remoteId': 10,
          'method': 'updateTitle',
        });
        expect(eventNamePattern.hasMatch(event.name), isTrue);
      });

      test('EntityUpdateFailed defaults method to unknown', () {
        const event = EntityUpdateFailed('Place', 10);

        expect(event.data['method'], 'unknown');
      });

      test('EntityLoadFailed has correct contract', () {
        const event = EntityLoadFailed('City', method: 'getAll');

        expect(event.name, 'entity_load_failed');
        expect(event.level, AppLogLevel.error);
        expect(event.data, {'entityType': 'City', 'method': 'getAll'});
        expect(eventNamePattern.hasMatch(event.name), isTrue);
      });

      test('EntityLoadStarted has correct contract', () {
        const event = EntityLoadStarted(
          'Place',
          method: 'getById',
          extra: {'id': 42},
        );

        expect(event.name, 'entity_load_started');
        expect(event.level, AppLogLevel.info);
        expect(event.data, {
          'entityType': 'Place',
          'method': 'getById',
          'id': 42,
        });
        expect(eventNamePattern.hasMatch(event.name), isTrue);
      });

      test('EntityLoadStarted works with null extra', () {
        const event = EntityLoadStarted('Place', method: 'getAll');

        expect(event.data, {'entityType': 'Place', 'method': 'getAll'});
      });
    });

    group('Service events', () {
      test('CloudinaryRequestFailed has correct contract', () {
        const event = CloudinaryRequestFailed(detail: 'timeout');

        expect(event.name, 'cloudinary_request_failed');
        expect(event.level, AppLogLevel.error);
        expect(event.data, {'detail': 'timeout'});
        expect(eventNamePattern.hasMatch(event.name), isTrue);
      });

      test('CloudinaryRequestStarted has correct contract', () {
        const event = CloudinaryRequestStarted();

        expect(event.name, 'cloudinary_request_started');
        expect(event.level, AppLogLevel.info);
        expect(event.data, isEmpty);
        expect(eventNamePattern.hasMatch(event.name), isTrue);
      });

      test('CloudinaryUploadCompleted has correct contract', () {
        const event = CloudinaryUploadCompleted(
          publicId: 'content_submissions/abc',
        );

        expect(event.name, 'cloudinary_upload_completed');
        expect(event.level, AppLogLevel.info);
        expect(event.data, {'publicId': 'content_submissions/abc'});
        expect(eventNamePattern.hasMatch(event.name), isTrue);
      });

      test('CloudinaryUploadCancelled has correct contract', () {
        const event = CloudinaryUploadCancelled();

        expect(event.name, 'cloudinary_upload_cancelled');
        expect(event.level, AppLogLevel.info);
        expect(event.data, isEmpty);
        expect(eventNamePattern.hasMatch(event.name), isTrue);
      });

      test('CloudinaryDuplicateDetected has correct contract', () {
        const event = CloudinaryDuplicateDetected(
          publicId: 'content_submissions/abc',
        );

        expect(event.name, 'cloudinary_duplicate_detected');
        expect(event.level, AppLogLevel.info);
        expect(event.data, {'publicId': 'content_submissions/abc'});
        expect(eventNamePattern.hasMatch(event.name), isTrue);
      });

      test('ImageSharingFailed has correct contract', () {
        const event = ImageSharingFailed();

        expect(event.name, 'image_sharing_failed');
        expect(event.level, AppLogLevel.warning);
        expect(event.data, isEmpty);
        expect(eventNamePattern.hasMatch(event.name), isTrue);
      });

      test('ReverseGeocodingFetchFailed has correct contract', () {
        const event = ReverseGeocodingFetchFailed(
          latitude: 41.56,
          longitude: 14.66,
        );

        expect(event.name, 'reverse_geocoding_fetch_failed');
        expect(event.level, AppLogLevel.error);
        expect(event.data, {'latitude': 41.56, 'longitude': 14.66});
        expect(eventNamePattern.hasMatch(event.name), isTrue);
      });

      test('ReverseGeocodingFetchStarted has correct contract', () {
        const event = ReverseGeocodingFetchStarted(
          latitude: 41.56,
          longitude: 14.66,
        );

        expect(event.name, 'reverse_geocoding_fetch_started');
        expect(event.level, AppLogLevel.info);
        expect(event.data, {'latitude': 41.56, 'longitude': 14.66});
        expect(eventNamePattern.hasMatch(event.name), isTrue);
      });

      test('SentryLoggingDisabled has correct contract', () {
        const event = SentryLoggingDisabled();

        expect(event.name, 'sentry_crash_reporting_disabled');
        expect(event.level, AppLogLevel.debug);
        expect(event.data, isEmpty);
        expect(eventNamePattern.hasMatch(event.name), isTrue);
      });

      test('SentryLoggingEnabled has correct contract', () {
        const event = SentryLoggingEnabled();

        expect(event.name, 'sentry_crash_reporting_enabled');
        expect(event.level, AppLogLevel.debug);
        expect(event.data, equals({'environment': null}));
        expect(eventNamePattern.hasMatch(event.name), isTrue);
      });

      test('UrlLaunchStarted has correct contract', () {
        const event = UrlLaunchStarted(
          'https://example.com',
          method: 'openInBrowser',
        );

        expect(event.name, 'url_launch_started');
        expect(event.level, AppLogLevel.info);
        expect(event.data, {
          'url': 'https://example.com',
          'method': 'openInBrowser',
        });
        expect(eventNamePattern.hasMatch(event.name), isTrue);
      });

      test('UrlLaunchStarted defaults method to unknown', () {
        const event = UrlLaunchStarted('https://example.com');

        expect(event.data['method'], 'unknown');
      });

      test('UrlLaunchFailed has correct contract', () {
        const event = UrlLaunchFailed('https://example.com');

        expect(event.name, 'url_launch_failed');
        expect(event.level, AppLogLevel.warning);
        expect(event.data, {'url': 'https://example.com'});
        expect(eventNamePattern.hasMatch(event.name), isTrue);
      });

      test('WeatherForecastFetchFailed has correct contract', () {
        const event = WeatherForecastFetchFailed(
          latitude: 41.56,
          longitude: 14.66,
        );

        expect(event.name, 'weather_forecast_fetch_failed');
        expect(event.level, AppLogLevel.error);
        expect(event.data, {'latitude': 41.56, 'longitude': 14.66});
        expect(eventNamePattern.hasMatch(event.name), isTrue);
      });

      test('WeatherForecastFetchStarted has correct contract', () {
        const event = WeatherForecastFetchStarted(
          latitude: 41.56,
          longitude: 14.66,
        );

        expect(event.name, 'weather_forecast_fetch_started');
        expect(event.level, AppLogLevel.info);
        expect(event.data, {'latitude': 41.56, 'longitude': 14.66});
        expect(eventNamePattern.hasMatch(event.name), isTrue);
      });
    });

    group('User contribution events', () {
      test('UserContributionMediaRemovalFailed has correct contract', () {
        const event = UserContributionMediaRemovalFailed();

        expect(event.name, 'user_contribution_media_removal_failed');
        expect(event.level, AppLogLevel.error);
        expect(event.data, isEmpty);
        expect(eventNamePattern.hasMatch(event.name), isTrue);
      });

      test('UserContributionMediaRetrievalFailed has correct contract', () {
        const event = UserContributionMediaRetrievalFailed();

        expect(event.name, 'user_contribution_media_retrieval_failed');
        expect(event.level, AppLogLevel.warning);
        expect(event.data, isEmpty);
        expect(eventNamePattern.hasMatch(event.name), isTrue);
      });

      test('UserContributionMediaRetrievalStarted has correct contract', () {
        const event = UserContributionMediaRetrievalStarted();

        expect(event.name, 'user_contribution_media_retrieval_started');
        expect(event.level, AppLogLevel.info);
        expect(event.data, isEmpty);
        expect(eventNamePattern.hasMatch(event.name), isTrue);
      });

      test('UserContributionUploadFailed has correct contract', () {
        const event = UserContributionUploadFailed();

        expect(event.name, 'user_contribution_upload_failed');
        expect(event.level, AppLogLevel.error);
        expect(event.data, isEmpty);
        expect(eventNamePattern.hasMatch(event.name), isTrue);
      });

      test('UserContributionUploadStarted has correct contract', () {
        const event = UserContributionUploadStarted();

        expect(event.name, 'user_contribution_upload_started');
        expect(event.level, AppLogLevel.info);
        expect(event.data, isEmpty);
        expect(eventNamePattern.hasMatch(event.name), isTrue);
      });
    });
  });
}
