import 'package:email_validator/email_validator.dart';
import 'package:string_validator/string_validator.dart' show isURL;

final class StringValidator {
  StringValidator._();

  /// Whether [s] is a valid e-mail address or not.
  static bool isValidEmail(String? s) {
    if (s != null) {
      return EmailValidator.validate(s);
    }

    return false;
  }

  /// Whether [s] is a valid url or not.
  ///
  /// Setting [allowSecureTransportOnly] to false optionally allows an http url
  /// to be considered valid.
  static bool isValidUrl(String? s, [bool allowSecureTransportOnly = true]) {
    final supportedProtocols = allowSecureTransportOnly
        ? ['https']
        : ['http', 'https'];

    return isURL(s, {'protocols': supportedProtocols});
  }
}
