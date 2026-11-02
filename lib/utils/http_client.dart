import 'dart:io' show HttpClient, Platform;

import 'package:cronet_http/cronet_http.dart';
import 'package:cupertino_http/cupertino_http.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:moliseis/utils/constants.dart';

const int _maxCacheSize = 2 * 1024 * 1024;

/// Creates an independently owned platform client, falling back to Dart IO.
///
/// [platformClientFactory] permits deterministic platform-failure tests.
/// Each returned client owns its underlying resources and can close separately.
http.Client httpClientFactory({
  http.Client? Function()? platformClientFactory,
}) {
  try {
    final client = (platformClientFactory ?? _platformHttpClient)();
    if (client != null) return client;
  } on Object catch (_) {
    // Cronet can be unavailable without Play Services.
  }
  return IOClient(HttpClient()..userAgent = kUserAgent);
}

http.Client? _platformHttpClient() {
  if (Platform.isAndroid) {
    final engine = CronetEngine.build(
      cacheMode: CacheMode.memory,
      cacheMaxSize: _maxCacheSize,
      enableHttp2: true,
      userAgent: kUserAgent,
    );
    return CronetClient.fromCronetEngine(engine, closeEngine: true);
  }

  if (Platform.isIOS || Platform.isMacOS) {
    final config = URLSessionConfiguration.ephemeralSessionConfiguration()
      ..cache = URLCache.withCapacity(memoryCapacity: _maxCacheSize)
      ..httpAdditionalHeaders = {'User-Agent': kUserAgent};
    return CupertinoClient.fromSessionConfiguration(config);
  }
  return null;
}
