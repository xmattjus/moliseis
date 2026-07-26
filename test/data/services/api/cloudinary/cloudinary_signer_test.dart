import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/data/services/api/cloudinary/cloudinary_signer.dart';

void main() {
  group('CloudinarySigner', () {
    const apiSecret = 'test_api_secret';
    const signer = CloudinarySigner(apiSecret: apiSecret);

    test('signs parameters sorted alphabetically with appended api_secret', () {
      // Hardcoded expected SHA-1 digest for the string
      // 'public_id=sample&timestamp=1315060510<apiSecret>' (UTF-8).
      // Computing the expected value with the same algorithm as the
      // implementation would make the test tautological, so the digest is
      // precomputed independently of `CloudinarySigner`.
      const params = {'public_id': 'sample', 'timestamp': '1315060510'};

      expect(
        signer.sign(params),
        '451634226c689e6ff239858bd61852511087b2b6',
      );
    });

    test(
      'matches the Cloudinary spec example for a minimal signed payload',
      () {
        // From the Cloudinary authentication signatures documentation:
        // secret 'abcd', timestamp 1315060510 -> SHA-1 of
        // 'timestamp=1315060510abcd' =
        // 'a21ad0f63beb4de2e5575204b79ab90bffb02c10'.
        const specSecret = 'abcd';
        const specSigner = CloudinarySigner(apiSecret: specSecret);
        const params = {'timestamp': '1315060510'};

        expect(
          specSigner.sign(params),
          'a21ad0f63beb4de2e5575204b79ab90bffb02c10',
        );
      },
    );

    test(
      'matches the Cloudinary spec example with multiple signed parameters',
      () {
        // From the Cloudinary authentication signatures documentation:
        // secret 'abcd', timestamp 1315060510, public_id 'sample_image',
        // eager 'w_400,h_300,c_pad|w_260,h_200,c_crop' ->
        // 'bfd09f95f331f558cbd1320e67aa8d488770583e'.
        const specSecret = 'abcd';
        const specSigner = CloudinarySigner(apiSecret: specSecret);
        const params = {
          'timestamp': '1315060510',
          'public_id': 'sample_image',
          'eager': 'w_400,h_300,c_pad|w_260,h_200,c_crop',
        };

        expect(
          specSigner.sign(params),
          'bfd09f95f331f558cbd1320e67aa8d488770583e',
        );
      },
    );

    test('produces a deterministic signature for the same inputs', () {
      const params = {
        'public_id': 'abc',
        'timestamp': '123',
        'transformation': 'w_100,h_100,c_limit',
      };

      expect(signer.sign(params), signer.sign(params));
    });

    test('sorts keys alphabetically regardless of insertion order', () {
      final signatureA = signer.sign(const {
        'timestamp': '123',
        'public_id': 'abc',
      });
      final signatureB = signer.sign(const {
        'public_id': 'abc',
        'timestamp': '123',
      });

      expect(signatureA, signatureB);
    });
  });
}
