import 'package:logging/logging.dart';
import 'package:moliseis/utils/result.dart';
import 'package:url_launcher/url_launcher.dart';

/// Service responsible for launching external URLs in the default browser
/// or appropriate applications.
class ExternalUrlService {
  final _log = Logger('ExternalUrlService');

  /// Launches a URL and returns a [Result] indicating success or failure.
  Future<Result<void>> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        _log.info('Successfully launched URL: $url');
        return const Result.success(null);
      } else {
        final message = 'Could not handle URL: $url';
        _log.severe(message);
        return Result.error(Exception(message));
      }
    } on Exception catch (error, stackTrace) {
      _log.severe(
        'An exception occurred while launching $url.',
        error,
        stackTrace,
      );
      return Result.error(error);
    }
  }

  /// Launches a generic URL.
  ///
  /// Returns a [Result] containing success or failure information.
  Future<Result<void>> launchGenericUrl(String url) => _launchUrl(url);
}
