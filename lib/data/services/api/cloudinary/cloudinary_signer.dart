import 'dart:convert' show utf8;

import 'package:crypto/crypto.dart' show sha1;

/// Generates SHA-1 signatures for Cloudinary signed uploads.
class CloudinarySigner {
  /// Creates a signer with the given [apiSecret].
  const CloudinarySigner({required String apiSecret}) : _apiSecret = apiSecret;

  final String _apiSecret;

  /// Signs [params] by sorting keys alphabetically, joining as `k=v`, and
  /// appending the API secret with no separator before SHA-1 hashing.
  ///
  /// Per Cloudinary's authentication signature spec, the string to sign is
  /// the serialized parameters immediately followed by the API secret, with
  /// no `&`, `=`, or other delimiter before the secret. See
  /// https://cloudinary.com/documentation/authentication_signatures.
  String sign(Map<String, String> params) {
    final sortedKeys = params.keys.toList()..sort();
    final pairs = sortedKeys.map((key) => '$key=${params[key]}');
    final payload = '${pairs.join('&')}$_apiSecret';
    final digest = sha1.convert(utf8.encode(payload));
    return digest.toString();
  }
}
