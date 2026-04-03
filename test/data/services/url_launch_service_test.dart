import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/data/services/app_info_service.dart';
import 'package:moliseis/data/services/external_url_service.dart';
import 'package:moliseis/data/services/map_url_service.dart';
import 'package:moliseis/data/services/url_launch_service.dart';
import 'package:moliseis/utils/result.dart';
import 'package:talker_flutter/talker_flutter.dart';

void main() {
  group('UrlLaunchService', () {
    late Talker logger;
    late _FakeExternalUrlService externalUrlService;

    setUp(() {
      logger = Talker();
      externalUrlService = _FakeExternalUrlService(logger: logger);
    });

    test('launchGenericUrl delegates to the external service', () async {
      final service = UrlLaunchService(
        logger: logger,
        externalUrlService: externalUrlService,
      );

      final launched = await service.launchGenericUrl('https://example.com');

      expect(launched, isTrue);
      expect(externalUrlService.launchedUrls, ['https://example.com']);
    });

    test(
      'launchGenericUrl returns false when the external service fails',
      () async {
        externalUrlService.nextResult = Result.error(
          Exception('launch failed'),
        );

        final service = UrlLaunchService(
          logger: logger,
          externalUrlService: externalUrlService,
        );

        final launched = await service.launchGenericUrl('https://example.com');

        expect(launched, isFalse);
        expect(externalUrlService.launchedUrls, ['https://example.com']);
      },
    );

    test(
      'default app info service reuses the injected external service',
      () async {
        final service = UrlLaunchService(
          logger: logger,
          externalUrlService: externalUrlService,
        );

        final privacyPolicyOpened = await service.openPrivacyPolicy();
        final termsOfServiceOpened = await service.openTermsOfService();

        expect(privacyPolicyOpened, isTrue);
        expect(termsOfServiceOpened, isTrue);
        expect(externalUrlService.launchedUrls, [
          'https://sites.google.com/view/molise-is-privacy-policy/',
          'https://sites.google.com/view/molise-is-terms-of-service/',
        ]);
      },
    );

    test('default map service reuses the injected external service', () async {
      final service = UrlLaunchService(
        logger: logger,
        externalUrlService: externalUrlService,
      );

      final mapTilerOpened = await service.openMapTilerWebsite();
      final openStreetMapOpened = await service.openOpenStreetMapWebsite();

      expect(mapTilerOpened, isTrue);
      expect(openStreetMapOpened, isTrue);
      expect(externalUrlService.launchedUrls, [
        'https://www.maptiler.com/copyright/',
        'https://www.openstreetmap.org/copyright',
      ]);
    });

    test('openGoogleMaps forwards the search parameters', () async {
      final service = UrlLaunchService(
        logger: logger,
        externalUrlService: externalUrlService,
      );

      final opened = await service.openGoogleMaps('Castelpetroso', 'Isernia');

      expect(opened, isTrue);
      expect(externalUrlService.launchedUrls, [
        'https://www.google.com/maps/search/?api=1&query=Castelpetroso, Isernia, Molise, Italia',
      ]);
    });

    test('uses injected app and map service overrides when provided', () async {
      final appInfoService = _FakeAppInfoService(
        logger: logger,
        externalUrlService: externalUrlService,
      );
      final mapUrlService = _FakeMapUrlService(
        logger: logger,
        externalUrlService: externalUrlService,
      );
      final service = UrlLaunchService(
        logger: logger,
        externalUrlService: externalUrlService,
        appInfoService: appInfoService,
        mapUrlService: mapUrlService,
      );

      final privacyPolicyOpened = await service.openPrivacyPolicy();
      final mapTilerOpened = await service.openMapTilerWebsite();

      expect(privacyPolicyOpened, isTrue);
      expect(mapTilerOpened, isTrue);
      expect(appInfoService.privacyPolicyCalls, 1);
      expect(mapUrlService.mapTilerCalls, 1);
      expect(externalUrlService.launchedUrls, isEmpty);
    });
  });
}

final class _FakeExternalUrlService extends ExternalUrlService {
  _FakeExternalUrlService({required super.logger});

  final List<String> launchedUrls = <String>[];

  Result<void> nextResult = const Result.success(null);

  @override
  Future<Result<void>> launchGenericUrl(String url) async {
    launchedUrls.add(url);
    return nextResult;
  }
}

final class _FakeAppInfoService extends AppInfoService {
  _FakeAppInfoService({
    required super.logger,
    required super.externalUrlService,
  });

  int privacyPolicyCalls = 0;

  @override
  Future<Result<void>> openPrivacyPolicy() async {
    privacyPolicyCalls++;
    return const Result.success(null);
  }

  @override
  Future<Result<void>> openTermsOfService() async {
    return const Result.success(null);
  }
}

final class _FakeMapUrlService extends MapUrlService {
  _FakeMapUrlService({
    required super.logger,
    required super.externalUrlService,
  });

  int mapTilerCalls = 0;

  @override
  Future<Result<void>> openMapTilerAttribution() async {
    mapTilerCalls++;
    return const Result.success(null);
  }

  @override
  Future<Result<void>> openOpenStreetMapAttribution() async {
    return const Result.success(null);
  }

  @override
  Future<Result<void>> searchInGoogleMaps(
    String contentName,
    String? cityName,
  ) async {
    return const Result.success(null);
  }
}
