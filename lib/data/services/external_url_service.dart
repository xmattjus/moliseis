import 'package:moliseis/utils/logging/logging.dart';
import 'package:moliseis/utils/result.dart';
import 'package:url_launcher/url_launcher.dart';

/// Service responsible for launching external URLs in the default browser
/// or appropriate applications.
class ExternalUrlService {
  ExternalUrlService({required Logger logger}) : _logger = logger;

  final Logger _logger;

  /// Launches a URL and returns a [Result] indicating success or failure.
  Future<Result<void>> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        return const Result.success(null);
      } else {
        final message = 'Could not handle URL: $url';
        _logger.log(UrlLaunchFailed(url));
        return Result.error(Exception(message));
      }
    } on Exception catch (exception, stackTrace) {
      _logger.log(
        UrlLaunchFailed(url),
        error: exception,
        stackTrace: stackTrace,
      );
      return Result.error(exception);
    }
  }

  /// Launches a generic URL.
  ///
  /// Returns a [Result] containing success or failure information.
  Future<Result<void>> launchGenericUrl(String url) => _launchUrl(url);
}
