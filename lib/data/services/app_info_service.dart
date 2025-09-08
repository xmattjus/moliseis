import 'package:logging/logging.dart';
import 'package:moliseis/data/services/external_url_service.dart';
import 'package:moliseis/utils/result.dart';

/// Service responsible for handling app-specific information URLs
/// such as privacy policy, terms of service, and legal information.
class AppInfoService {
  AppInfoService({required ExternalUrlService externalUrlService})
    : _externalUrlService = externalUrlService;

  final _log = Logger('AppInfoService');
  final ExternalUrlService _externalUrlService;

  // App information URLs
  static const _privacyPolicyUrl =
      'https://sites.google.com/view/molise-is-privacy-policy/';
  static const _termsOfServiceUrl =
      'https://sites.google.com/view/molise-is-terms-of-service/';

  /// Opens the app Privacy Policy web page.
  ///
  /// Returns a [Result] containing success or failure information.
  Future<Result<void>> openPrivacyPolicy() {
    _log.info('Opening privacy policy');
    return _externalUrlService.launchGenericUrl(_privacyPolicyUrl);
  }

  /// Opens the app Terms of Service web page.
  ///
  /// Returns a [Result] containing success or failure information.
  Future<Result<void>> openTermsOfService() {
    _log.info('Opening terms of service');
    return _externalUrlService.launchGenericUrl(_termsOfServiceUrl);
  }
}
