import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/data/services/api/cloudinary/cloudinary_asset_mime_type.dart';

void main() {
  group('cloudinaryImageMimeType', () {
    test('maps known JPEG aliases', () {
      expect(cloudinaryImageMimeType('jpg'), 'image/jpeg');
      expect(cloudinaryImageMimeType(' JPEG '), 'image/jpeg');
    });

    test('maps ordinary known image formats', () {
      expect(cloudinaryImageMimeType('png'), 'image/png');
      expect(cloudinaryImageMimeType('webp'), 'image/webp');
      expect(cloudinaryImageMimeType('tif'), 'image/tiff');
    });

    test('maps SVG to its explicit MIME type', () {
      expect(cloudinaryImageMimeType('svg'), 'image/svg+xml');
    });

    test('returns null for missing or blank formats', () {
      expect(cloudinaryImageMimeType(null), isNull);
      expect(cloudinaryImageMimeType('  '), isNull);
    });

    test('returns null for unknown formats', () {
      expect(cloudinaryImageMimeType('not-a-cloudinary-image-format'), isNull);
    });
  });
}
