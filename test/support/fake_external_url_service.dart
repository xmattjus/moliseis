import 'dart:async';

import 'package:moliseis/data/services/external_url_service.dart';
import 'package:moliseis/utils/result.dart';

/// Records URL launches while allowing tests to hold or fail one launch.
final class FakeExternalUrlService extends ExternalUrlService {
  FakeExternalUrlService({required super.logger});

  final List<String> launchedUrls = <String>[];
  Result<void> result = const Result.success(null);
  Completer<Result<void>>? pendingLaunch;

  @override
  Future<Result<void>> launchGenericUrl(String url) async {
    launchedUrls.add(url);
    return pendingLaunch?.future ?? result;
  }
}
