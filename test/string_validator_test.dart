import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/utils/string_validator.dart';

void main() {
  test('Valid e-mail addresses should be found', () {
    final addressesToTest = [
      'email@example.com',
      'firstname.lastname@example.com',
      'email@subdomain.example.com',
      'firstname+lastname@example.com',
      // 'email@123.123.123.123',
      'email@[123.123.123.123]',
      '"email"@example.com',
      '1234567890@example.com',
      'email@example-one.com',
      '_______@example.com',
      'email@example.name',
      'email@example.museum',
      'email@example.co.jp',
      'firstname-lastname@example.com',
      // r'much.”more\ unusual”@example.com',
      // 'very.unusual.”@”.unusual.com@example.com',
      // r'very.”(),:;<>[]”.VERY.”very@\\ "very”.unusual@strange.example.com',
    ];

    for (final emailAddress in addressesToTest) {
      final isValid = StringValidator.isValidEmail(emailAddress);

      expect(isValid, true, reason: '$emailAddress is a valid e-mail address.');
    }
  });

  test('Not valid e-mail addresses should be found', () {
    final addressesToTest = [
      'plainaddress',
      r'#@%^%#$@#$@#.com',
      '@example.com',
      'Joe Smith <email@example.com>',
      'email.example.com',
      'email@example@example.com',
      '.email@example.com',
      'email.@example.com',
      'email..email@example.com',
      // 'あいうえお@example.com',
      'email@example.com (Joe Smith)',
      'email@example',
      'email@-example.com',
      // 'email@example.web',
      'email@111.222.333.44444',
      'email@example..com',
      'Abc..123@example.com',
    ];

    for (final emailAddress in addressesToTest) {
      final isValid = StringValidator.isValidEmail(emailAddress);

      expect(
        isValid,
        false,
        reason: '$emailAddress is not a valid e-mail address.',
      );
    }
  });
}
