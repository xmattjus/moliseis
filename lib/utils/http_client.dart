import 'dart:io' show HttpClient, Platform;

import 'package:cronet_http/cronet_http.dart';
import 'package:cupertino_http/cupertino_http.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:moliseis/utils/constants.dart';

HttpClient _fallbackClient = HttpClient()..userAgent = kUserAgent;

const _maxCacheSize = 2 * 1024 * 1024;

http.Client httpClientFactory() {
  try {
    if (Platform.isAndroid) {
      final engine = CronetEngine.build(
        cacheMode: CacheMode.memory,
        cacheMaxSize: _maxCacheSize,
        enableHttp2: true,
        userAgent: kUserAgent,
      );
      return CronetClient.fromCronetEngine(engine);
    }

    /// 'You must provide the Content-Length' HTTP header issue
    if (Platform.isIOS || Platform.isMacOS) {
      final config = URLSessionConfiguration.ephemeralSessionConfiguration()
        ..cache = URLCache.withCapacity(memoryCapacity: _maxCacheSize)
        ..httpAdditionalHeaders = {'User-Agent': kUserAgent};
      return CupertinoClient.fromSessionConfiguration(config);
    }
  } catch (_) {
    /// in case no Cronet is available which can happen on Android without Google Play Services
    /// not sure if there is a similar case for Cupertino but better safe than sorry
    return IOClient(_fallbackClient);
  }
  final httpClient = _fallbackClient;
  // To use with Fiddler uncomment the following lines and set the
  // ip address of the machine where Fiddler is running
  // httpClient.findProxy = (uri) => 'PROXY 192.168.1.61:8866';
  // httpClient.badCertificateCallback =
  //     (X509Certificate cert, String host, int port) => true;
  return IOClient(httpClient);
}
